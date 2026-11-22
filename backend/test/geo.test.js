import { test } from 'node:test';
import assert from 'node:assert/strict';
import { caixaAoRedor, distanciaMetros } from '../src/geo.js';

// Centro de Palhoça (SC)
const LAT = -27.6481;
const LNG = -48.6675;

test('distância de um ponto até ele mesmo é zero', () => {
  assert.equal(distanciaMetros(LAT, LNG, LAT, LNG), 0);
});

test('0,0001 grau de latitude dá cerca de 11 metros', () => {
  const d = distanciaMetros(LAT, LNG, LAT + 0.0001, LNG);
  assert.ok(Math.abs(d - 11.12) < 0.05, `esperado ~11,12 m, veio ${d}`);
});

test('distingue entulhos a 6 m (mesmo lugar) de entulhos a 10 m (separados)', () => {
  const grausPorMetro = 1 / 111195;
  const a6m = distanciaMetros(LAT, LNG, LAT + 6 * grausPorMetro, LNG);
  const a10m = distanciaMetros(LAT, LNG, LAT + 10 * grausPorMetro, LNG);
  assert.ok(Math.abs(a6m - 6) < 0.05, `esperado ~6 m, veio ${a6m}`);
  assert.ok(Math.abs(a10m - 10) < 0.05, `esperado ~10 m, veio ${a10m}`);
});

test('a caixa ao redor contém todo o círculo do raio pedido', () => {
  const raio = 15;
  const caixa = caixaAoRedor(LAT, LNG, raio);
  assert.ok(caixa.minLat < LAT && LAT < caixa.maxLat);
  assert.ok(caixa.minLng < LNG && LNG < caixa.maxLng);
  // Os quatro lados ficam a pelo menos "raio" metros do centro.
  assert.ok(distanciaMetros(LAT, LNG, caixa.maxLat, LNG) >= raio - 0.05);
  assert.ok(distanciaMetros(LAT, LNG, caixa.minLat, LNG) >= raio - 0.05);
  assert.ok(distanciaMetros(LAT, LNG, LAT, caixa.maxLng) >= raio - 0.05);
  assert.ok(distanciaMetros(LAT, LNG, LAT, caixa.minLng) >= raio - 0.05);
});
