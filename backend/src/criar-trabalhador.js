// Cria (ou atualiza a senha de) uma conta de trabalhador da prefeitura.
// Uso: npm run criar-trabalhador -- <cpf> <senha> "<nome completo>"
import bcrypt from 'bcryptjs';
import { pool, migrar } from './db.js';
import { limparCpf, cpfValido } from './cpf.js';

const [cpfArg, senha, ...partesNome] = process.argv.slice(2);
const cpf = limparCpf(cpfArg);
const nome = partesNome.join(' ').trim();

if (!cpfValido(cpf) || !senha || senha.length < 6 || nome.length < 3) {
  console.error('Uso: npm run criar-trabalhador -- <cpf> <senha (mín. 6)> "<nome completo>"');
  process.exit(1);
}

await migrar();
const hash = await bcrypt.hash(senha, 10);
const { rows } = await pool.query(
  `INSERT INTO usuarios (nome, cpf, senha_hash, perfil)
   VALUES ($1, $2, $3, 'trabalhador')
   ON CONFLICT (cpf) DO UPDATE
     SET nome = EXCLUDED.nome, senha_hash = EXCLUDED.senha_hash, perfil = 'trabalhador'
   RETURNING id`,
  [nome, cpf, hash],
);
console.log(`Trabalhador ${nome} pronto (id ${rows[0].id}).`);
await pool.end();
