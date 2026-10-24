// Desbloqueia a conta de um cidadão bloqueado por registros falsos.
// Uso: npm run desbloquear-usuario -- <cpf>
import { pool, migrar } from './db.js';
import { limparCpf } from './cpf.js';

const cpf = limparCpf(process.argv[2]);
if (cpf.length !== 11) {
  console.error('Uso: npm run desbloquear-usuario -- <cpf>');
  process.exit(1);
}

await migrar();
const { rows } = await pool.query(
  'UPDATE usuarios SET bloqueado = false WHERE cpf = $1 RETURNING nome',
  [cpf],
);
console.log(rows[0] ? `Conta de ${rows[0].nome} desbloqueada.` : 'Nenhuma conta com esse CPF.');
await pool.end();
