import { test } from 'node:test';
import assert from 'node:assert/strict';
import { cpfValido, limparCpf } from '../src/cpf.js';

test('limparCpf tira pontos, traço e espaços', () => {
  assert.equal(limparCpf('529.982.247-25'), '52998224725');
  assert.equal(limparCpf(' 111 444 777 35 '), '11144477735');
  assert.equal(limparCpf(undefined), '');
});

test('cpfValido aceita CPFs com dígitos verificadores corretos', () => {
  assert.equal(cpfValido('529.982.247-25'), true);
  assert.equal(cpfValido('11144477735'), true);
});

test('cpfValido recusa dígito errado, tamanho errado e números repetidos', () => {
  assert.equal(cpfValido('529.982.247-26'), false);
  assert.equal(cpfValido('1234567890'), false);
  assert.equal(cpfValido('111.111.111-11'), false);
  assert.equal(cpfValido(''), false);
});
