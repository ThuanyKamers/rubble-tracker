const RAIO_TERRA_M = 6371008.8;

// Distância em metros entre dois pontos (fórmula de Haversine).
export function distanciaMetros(lat1, lng1, lat2, lng2) {
  const rad = (g) => (g * Math.PI) / 180;
  const dLat = rad(lat2 - lat1);
  const dLng = rad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(rad(lat1)) * Math.cos(rad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * RAIO_TERRA_M * Math.asin(Math.sqrt(a));
}

// Retângulo (em graus) que contém um círculo de "metros" ao redor do ponto.
// Serve para o banco filtrar rápido antes do cálculo exato da distância.
export function caixaAoRedor(lat, lng, metros) {
  const dLat = metros / 111320;
  const dLng = metros / (111320 * Math.cos((lat * Math.PI) / 180));
  return {
    minLat: lat - dLat,
    maxLat: lat + dLat,
    minLng: lng - dLng,
    maxLng: lng + dLng,
  };
}
