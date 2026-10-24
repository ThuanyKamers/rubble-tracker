import express from 'express';
import cors from 'cors';
import multer from 'multer';
import bcrypt from 'bcryptjs';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';

import { pool, migrar } from './db.js';
import { gerarToken, exigirLogin, exigirPerfil } from './auth.js';
import { limparCpf, cpfValido } from './cpf.js';
import { distanciaMetros, caixaAoRedor } from './geo.js';

const app = express();
const port = Number(process.env.PORT || 3000);

// Dois registros a até RAIO_DUPLICADO_M metros são o mesmo entulho.
// Entre esse raio e RAIO_SUSPEITO_M o app pergunta ao cidadão se é o mesmo.
// Acima disso é sempre um entulho novo.
const RAIO_DUPLICADO_M = Number(process.env.RAIO_DUPLICADO_M || 6);
const RAIO_SUSPEITO_M = Number(process.env.RAIO_SUSPEITO_M || 15);
// Leituras de GPS piores que isso são recusadas, pois não dá para
// diferenciar entulhos a 10 m de distância com elas.
const PRECISAO_MAXIMA_M = Number(process.env.PRECISAO_MAXIMA_M || 20);
const MAX_FOTOS = 3;

const UPLOAD_DIR = process.env.UPLOAD_DIR || path.resolve('uploads');
fs.mkdirSync(UPLOAD_DIR, { recursive: true });

const EXTENSOES_IMAGEM = ['.jpg', '.jpeg', '.png', '.heic', '.webp'];

const upload = multer({
  storage: multer.diskStorage({
    destination: UPLOAD_DIR,
    filename: (req, file, cb) => {
      const ext = path.extname(file.originalname).toLowerCase() || '.jpg';
      cb(null, `${crypto.randomUUID()}${ext}`);
    },
  }),
  limits: { files: MAX_FOTOS, fileSize: 10 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase();
    cb(null, file.mimetype.startsWith('image/') || EXTENSOES_IMAGEM.includes(ext));
  },
});

app.use(cors());
app.use(express.json());
app.use('/uploads', express.static(UPLOAD_DIR, { maxAge: '7d' }));

class ErroApi extends Error {
  constructor(status, mensagem, extra = {}) {
    super(mensagem);
    this.status = status;
    this.extra = extra;
  }
}

const rota = (fn) => (req, res, next) => fn(req, res, next).catch(next);

function apagarArquivos(arquivos = []) {
  for (const f of arquivos) fs.promises.unlink(f.path).catch(() => {});
}

function usuarioPublico(u) {
  return { id: u.id, nome: u.nome, perfil: u.perfil };
}

const SELECT_DENUNCIA = `
  SELECT d.id,
         d.latitude::float8 AS latitude,
         d.longitude::float8 AS longitude,
         d.ponto_referencia,
         d.status,
         d.precisao_m,
         d.criado_em,
         d.recolhido_em,
         GREATEST((SELECT count(*) FROM registros r WHERE r.denuncia_id = d.id), 1)::int AS confirmacoes,
         COALESCE((SELECT json_agg('/uploads/' || f.arquivo ORDER BY f.id)
                   FROM fotos f WHERE f.denuncia_id = d.id), '[]'::json) AS fotos,
         d.caminho_foto
  FROM denuncias d
`;

// Registros antigos guardavam uma única foto (base64 ou URL) em caminho_foto.
function formatarDenuncia(row) {
  const { caminho_foto, ...denuncia } = row;
  if (caminho_foto) denuncia.fotos = [caminho_foto, ...denuncia.fotos];
  return denuncia;
}

async function buscarDenuncia(client, id) {
  const { rows } = await client.query(`${SELECT_DENUNCIA} WHERE d.id = $1`, [id]);
  return rows[0] ? formatarDenuncia(rows[0]) : null;
}

function lerPosicao(body) {
  const latitude = Number(body.latitude);
  const longitude = Number(body.longitude);
  const precisao = body.precisao_m === undefined ? null : Number(body.precisao_m);

  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
    throw new ErroApi(400, 'Localização inválida.');
  }
  if (precisao === null || !Number.isFinite(precisao)) {
    throw new ErroApi(400, 'Informe a precisão do GPS.');
  }
  if (precisao > PRECISAO_MAXIMA_M) {
    throw new ErroApi(422,
      `O GPS está impreciso (±${Math.round(precisao)} m). ` +
      'Vá para um lugar aberto, aguarde alguns segundos e tente de novo.',
      { codigo: 'GPS_IMPRECISO', precisao_maxima_m: PRECISAO_MAXIMA_M });
  }
  return { latitude, longitude, precisao };
}

// Entulhos ativos perto do ponto, do mais próximo para o mais distante.
async function entulhosProximos(client, latitude, longitude, raio) {
  const caixa = caixaAoRedor(latitude, longitude, raio);
  const { rows } = await client.query(
    `${SELECT_DENUNCIA}
     WHERE d.status = 'ativo'
       AND d.latitude BETWEEN $1 AND $2
       AND d.longitude BETWEEN $3 AND $4`,
    [caixa.minLat, caixa.maxLat, caixa.minLng, caixa.maxLng],
  );
  return rows
    .map((row) => ({
      ...formatarDenuncia(row),
      distancia_m: distanciaMetros(latitude, longitude, row.latitude, row.longitude),
    }))
    .filter((d) => d.distancia_m <= raio)
    .sort((a, b) => a.distancia_m - b.distancia_m);
}

// Junta o registro do cidadão a um entulho que já existe.
async function adicionarRegistro(client, denunciaId, usuarioId, pos, descricao, arquivos) {
  const { rows } = await client.query(
    `INSERT INTO registros (denuncia_id, usuario_id, latitude, longitude, precisao_m, descricao)
     VALUES ($1, $2, $3, $4, $5, $6)
     ON CONFLICT (denuncia_id, usuario_id) DO NOTHING
     RETURNING id`,
    [denunciaId, usuarioId, pos.latitude, pos.longitude, pos.precisao, descricao],
  );
  if (rows.length === 0) {
    throw new ErroApi(409, 'Você já registrou este entulho.', { codigo: 'JA_REGISTRADO', denuncia_id: denunciaId });
  }
  for (const f of arquivos) {
    await client.query(
      'INSERT INTO fotos (denuncia_id, registro_id, arquivo) VALUES ($1, $2, $3)',
      [denunciaId, rows[0].id, f.filename],
    );
  }
  if (descricao) {
    await client.query(
      `UPDATE denuncias SET ponto_referencia = $2
       WHERE id = $1 AND COALESCE(ponto_referencia, '') = ''`,
      [denunciaId, descricao],
    );
  }
}

async function emTransacao(fn) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Um registro por vez: evita que dois cidadãos no mesmo lugar, ao mesmo
    // tempo, criem dois entulhos antes de um ver o do outro.
    await client.query('SELECT pg_advisory_xact_lock(424242)');
    const resultado = await fn(client);
    await client.query('COMMIT');
    return resultado;
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {});
    throw err;
  } finally {
    client.release();
  }
}

app.get('/', (req, res) => {
  res.send('API do Cidade Limpa está online! 🚀');
});

// ---------------------------------------------------------------- Contas

app.post('/auth/cadastro', rota(async (req, res) => {
  const nome = String(req.body.nome || '').trim();
  const cpf = limparCpf(req.body.cpf);
  const senha = String(req.body.senha || '');

  if (nome.length < 3) throw new ErroApi(400, 'Informe seu nome completo.');
  if (!cpfValido(cpf)) throw new ErroApi(400, 'CPF inválido.');
  if (senha.length < 6) throw new ErroApi(400, 'A senha precisa ter pelo menos 6 caracteres.');

  const hash = await bcrypt.hash(senha, 10);
  const { rows } = await pool.query(
    `INSERT INTO usuarios (nome, cpf, senha_hash, perfil)
     VALUES ($1, $2, $3, 'cidadao')
     ON CONFLICT (cpf) DO NOTHING
     RETURNING *`,
    [nome, cpf, hash],
  );
  if (rows.length === 0) throw new ErroApi(409, 'Este CPF já tem cadastro. Faça login.');

  res.status(201).json({ token: gerarToken(rows[0]), usuario: usuarioPublico(rows[0]) });
}));

app.post('/auth/login', rota(async (req, res) => {
  const cpf = limparCpf(req.body.cpf);
  const senha = String(req.body.senha || '');

  const { rows } = await pool.query('SELECT * FROM usuarios WHERE cpf = $1', [cpf]);
  const usuario = rows[0];
  if (!usuario || !(await bcrypt.compare(senha, usuario.senha_hash))) {
    throw new ErroApi(401, 'CPF ou senha incorretos.');
  }
  res.json({ token: gerarToken(usuario), usuario: usuarioPublico(usuario) });
}));

// -------------------------------------------------------------- Entulhos

// Entulhos da área visível do mapa. status=ativo (padrão) ou recolhido.
app.get('/denuncias', exigirLogin, rota(async (req, res) => {
  const { minLat, maxLat, minLng, maxLng } = req.query;
  const status = req.query.status === 'recolhido' ? 'recolhido' : 'ativo';

  const valores = [status];
  let filtro = 'WHERE d.status = $1';
  if (minLat && maxLat && minLng && maxLng) {
    valores.push(minLat, maxLat, minLng, maxLng);
    filtro += ' AND d.latitude BETWEEN $2 AND $3 AND d.longitude BETWEEN $4 AND $5';
  }

  const { rows } = await pool.query(
    `${SELECT_DENUNCIA} ${filtro} ORDER BY d.id DESC LIMIT 500`,
    valores,
  );
  res.json(rows.map(formatarDenuncia));
}));

// Novo registro de entulho (multipart: latitude, longitude, precisao_m,
// ponto_referencia, forcar_novo e de 1 a 3 arquivos no campo "fotos").
app.post('/denuncias', exigirLogin, exigirPerfil('cidadao'), upload.array('fotos', MAX_FOTOS),
  rota(async (req, res) => {
    const arquivos = req.files || [];
    try {
      if (arquivos.length === 0) throw new ErroApi(400, 'Tire pelo menos 1 foto do entulho.');
      const pos = lerPosicao(req.body);
      const descricao = String(req.body.ponto_referencia || '').trim().slice(0, 500) || null;
      const forcarNovo = req.body.forcar_novo === 'true';

      const resultado = await emTransacao(async (client) => {
        const proximos = await entulhosProximos(client, pos.latitude, pos.longitude, RAIO_SUSPEITO_M);
        const mesmoLugar = proximos.find((d) => d.distancia_m <= RAIO_DUPLICADO_M);

        if (mesmoLugar) {
          await adicionarRegistro(client, mesmoLugar.id, req.usuario.id, pos, descricao, arquivos);
          return { status: 200, corpo: { duplicada: true, denuncia: await buscarDenuncia(client, mesmoLugar.id) } };
        }

        if (proximos.length > 0 && !forcarNovo) {
          throw new ErroApi(409,
            'Já existe um entulho registrado muito perto daqui. É o mesmo?',
            { codigo: 'ENTULHO_PROXIMO', candidatos: proximos });
        }

        const { rows } = await client.query(
          `INSERT INTO denuncias (latitude, longitude, precisao_m, ponto_referencia, status, criado_por)
           VALUES ($1, $2, $3, $4, 'ativo', $5)
           RETURNING id`,
          [pos.latitude, pos.longitude, pos.precisao, descricao, req.usuario.id],
        );
        await adicionarRegistro(client, rows[0].id, req.usuario.id, pos, descricao, arquivos);
        return { status: 201, corpo: { duplicada: false, denuncia: await buscarDenuncia(client, rows[0].id) } };
      });

      res.status(resultado.status).json(resultado.corpo);
    } catch (err) {
      apagarArquivos(arquivos);
      throw err;
    }
  }));

// O cidadão disse que é o mesmo entulho de um registro próximo.
app.post('/denuncias/:id/confirmar', exigirLogin, exigirPerfil('cidadao'), upload.array('fotos', MAX_FOTOS),
  rota(async (req, res) => {
    const arquivos = req.files || [];
    try {
      const pos = lerPosicao(req.body);
      const descricao = String(req.body.ponto_referencia || '').trim().slice(0, 500) || null;
      const id = Number(req.params.id);

      const denuncia = await emTransacao(async (client) => {
        const { rows } = await client.query(
          `SELECT latitude::float8 AS latitude, longitude::float8 AS longitude, status
           FROM denuncias WHERE id = $1`, [id]);
        if (!rows[0] || rows[0].status !== 'ativo') {
          throw new ErroApi(404, 'Este entulho já foi recolhido ou não existe mais.');
        }
        const distancia = distanciaMetros(pos.latitude, pos.longitude, rows[0].latitude, rows[0].longitude);
        if (distancia > RAIO_SUSPEITO_M) {
          throw new ErroApi(400, 'Você está longe demais deste entulho para confirmá-lo.');
        }
        await adicionarRegistro(client, id, req.usuario.id, pos, descricao, arquivos);
        return buscarDenuncia(client, id);
      });

      res.json({ duplicada: true, denuncia });
    } catch (err) {
      apagarArquivos(arquivos);
      throw err;
    }
  }));

// Trabalhador marca o entulho como recolhido.
app.patch('/denuncias/:id/recolher', exigirLogin, exigirPerfil('trabalhador'), rota(async (req, res) => {
  const { rows } = await pool.query(
    `UPDATE denuncias
     SET status = 'recolhido', recolhido_por = $2, recolhido_em = now()
     WHERE id = $1 AND status = 'ativo'
     RETURNING id`,
    [Number(req.params.id), req.usuario.id],
  );
  if (rows.length === 0) throw new ErroApi(404, 'Este entulho já foi recolhido ou não existe.');
  res.json(await buscarDenuncia(pool, rows[0].id));
}));

// ---------------------------------------------------------------- Erros

app.use((err, req, res, next) => {
  if (err instanceof ErroApi) {
    return res.status(err.status).json({ error: err.message, ...err.extra });
  }
  if (err instanceof multer.MulterError) {
    const mensagem = err.code === 'LIMIT_FILE_SIZE' ? 'Foto grande demais (máx. 10 MB).'
      : err.code === 'LIMIT_FILE_COUNT' || err.code === 'LIMIT_UNEXPECTED_FILE' ? 'Envie no máximo 3 fotos.'
      : 'Erro no envio das fotos.';
    return res.status(400).json({ error: mensagem });
  }
  console.error(err);
  res.status(500).json({ error: 'Erro interno no servidor.' });
});

await migrar();
app.listen(port, () => {
  console.log(`Servidor rodando na porta ${port}`);
});
