import 'package:geolocator/geolocator.dart';

class Localizacao {
  // Pede permissão e confere se o GPS está ligado.
  // Devolve uma mensagem de erro, ou null se está tudo certo.
  static Future<String?> prepararGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Ligue a localização (GPS) do celular.';
    }
    var permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }
    if (permissao == LocationPermission.denied) {
      return 'Precisamos da sua localização para marcar o entulho no mapa.';
    }
    if (permissao == LocationPermission.deniedForever) {
      return 'A localização foi bloqueada. Libere nas configurações do celular.';
    }
    return null;
  }

  // Posições contínuas com a maior precisão que o aparelho oferece.
  static Stream<Position> acompanhar() => Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      );
}
