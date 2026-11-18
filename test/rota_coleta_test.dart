import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:projeto_lara/models/denuncia.dart';
import 'package:projeto_lara/services/rota_coleta.dart';

Denuncia _entulho(int id, double lat, double lng) => Denuncia(
      id: id,
      coordenada: LatLng(lat, lng),
      pontoReferencia: '',
      caminhosFotos: const [],
    );

void main() {
  const origem = LatLng(-27.6481, -48.6675);

  test('Rota de coleta começa pelo mais perto e segue para o mais perto do anterior', () {
    final longe = _entulho(1, -27.6581, -48.6675); // ~1,1 km ao sul
    final perto = _entulho(2, -27.6491, -48.6675); // ~110 m ao sul
    final meio = _entulho(3, -27.6531, -48.6675); // ~550 m ao sul

    final ordem = ordenarParaColeta(origem, [longe, perto, meio]);

    expect(ordem.map((d) => d.id), [2, 3, 1]);
  });

  test('Rota de coleta respeita o limite de paradas', () {
    final entulhos = [for (var i = 1; i <= 10; i++) _entulho(i, -27.6481 - i * 0.001, -48.6675)];

    final ordem = ordenarParaColeta(origem, entulhos, limite: maxParadasRota);

    expect(ordem.length, maxParadasRota);
    expect(ordem.first.id, 1);
  });

  test('Link do Google Maps leva as paradas e termina no último entulho', () {
    final paradas = [_entulho(1, -27.1, -48.1), _entulho(2, -27.2, -48.2), _entulho(3, -27.3, -48.3)];

    final url = urlRotaGoogleMaps(paradas);

    expect(url.queryParameters['destination'], '-27.3,-48.3');
    expect(url.queryParameters['waypoints'], '-27.1,-48.1|-27.2,-48.2');
    expect(url.queryParameters['travelmode'], 'driving');
  });
}
