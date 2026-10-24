import pkg from 'pg';

const { Pool } = pkg;

export const pool = new Pool({
  user: process.env.POSTGRES_USER,
  host: process.env.POSTGRES_HOST || 'localhost',
  database: process.env.POSTGRES_DB,
  password: process.env.POSTGRES_PASSWORD,
  port: Number(process.env.POSTGRES_PORT || 5432),
});

// Cria as tabelas na primeira execução e atualiza a tabela "denuncias"
// antiga (latitude, longitude, ponto_referencia, caminho_foto, status)
// sem apagar os registros que já existem.
export async function migrar() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS usuarios (
      id SERIAL PRIMARY KEY,
      nome TEXT NOT NULL,
      cpf CHAR(11) NOT NULL UNIQUE,
      senha_hash TEXT NOT NULL,
      perfil TEXT NOT NULL CHECK (perfil IN ('cidadao', 'trabalhador')),
      criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
    );

    CREATE TABLE IF NOT EXISTS denuncias (
      id SERIAL PRIMARY KEY,
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      ponto_referencia TEXT,
      caminho_foto TEXT,
      status TEXT NOT NULL DEFAULT 'ativo'
    );

    ALTER TABLE denuncias
      ADD COLUMN IF NOT EXISTS precisao_m REAL,
      ADD COLUMN IF NOT EXISTS criado_por INT REFERENCES usuarios(id),
      ADD COLUMN IF NOT EXISTS criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
      ADD COLUMN IF NOT EXISTS recolhido_por INT REFERENCES usuarios(id),
      ADD COLUMN IF NOT EXISTS recolhido_em TIMESTAMPTZ;

    CREATE INDEX IF NOT EXISTS denuncias_status_lat_lng_idx
      ON denuncias (status, latitude, longitude);

    -- Cada vez que um cidadão registra (ou confirma) um entulho.
    CREATE TABLE IF NOT EXISTS registros (
      id SERIAL PRIMARY KEY,
      denuncia_id INT NOT NULL REFERENCES denuncias(id) ON DELETE CASCADE,
      usuario_id INT NOT NULL REFERENCES usuarios(id),
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      precisao_m REAL,
      descricao TEXT,
      criado_em TIMESTAMPTZ NOT NULL DEFAULT now(),
      UNIQUE (denuncia_id, usuario_id)
    );

    CREATE TABLE IF NOT EXISTS fotos (
      id SERIAL PRIMARY KEY,
      denuncia_id INT NOT NULL REFERENCES denuncias(id) ON DELETE CASCADE,
      registro_id INT REFERENCES registros(id) ON DELETE SET NULL,
      arquivo TEXT NOT NULL,
      criado_em TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}
