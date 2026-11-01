import 'package:latlong2/latlong.dart';

import '../models/denuncia.dart';

// Quantas paradas cabem numa rota do Google Maps aberta por link no celular:
// o app aceita só 3 paradas no caminho (com mais, ele ignora todas) + o destino.
const maxParadasRota = 4;

const _distancia = Distance();

double distanciaAte(LatLng origem, Denuncia d) => _distancia(origem, d.coordenada);

// Ordena os entulhos na ordem de visita: começa pelo mais perto de [origem]
// e, de cada entulho, segue para o mais perto que ainda falta.
// Não é a rota perfeita, mas é rápida e evita ir e voltar pelo mesmo caminho.
List<Denuncia> ordenarParaColeta(LatLng origem, List<Denuncia> entulhos, {int? limite}) {
  final faltam = [...entulhos];
  final ordem = <Denuncia>[];
  var atual = origem;
  while (faltam.isNotEmpty && (limite == null || ordem.length < limite)) {
    var melhor = 0;
    var menor = double.infinity;
    for (var i = 0; i < faltam.length; i++) {
      final dist = _distancia(atual, faltam[i].coordenada);
      if (dist < menor) {
        menor = dist;
        melhor = i;
      }
    }
    final proximo = faltam.removeAt(melhor);
    ordem.add(proximo);
    atual = proximo.coordenada;
  }
  return ordem;
}

// Link do Google Maps com a rota saindo da posição atual e passando pelos
// entulhos na ordem dada (o último é o destino final).
Uri urlRotaGoogleMaps(List<Denuncia> paradas) {
  String ponto(Denuncia d) => '${d.coordenada.latitude},${d.coordenada.longitude}';
  final destino = paradas.last;
  final caminho = paradas.sublist(0, paradas.length - 1);
  return Uri.parse('https://www.google.com/maps/dir/').replace(queryParameters: {
    'api': '1',
    'destination': ponto(destino),
    if (caminho.isNotEmpty) 'waypoints': caminho.map(ponto).join('|'),
    'travelmode': 'driving',
  });
}
