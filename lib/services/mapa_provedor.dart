import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

// Qual servidor de mapas o app usa. Escolhido na hora de compilar, sem mexer
// no código:
//   flutter run --dart-define=MAP_PROVIDER=google --dart-define=MAP_API_KEY=sua-chave
// ou, para não digitar a chave toda vez, com um arquivo (veja config/mapa.example.json):
//   flutter run --dart-define-from-file=config/mapa.json
//
// Sem MAP_PROVIDER, ou sem chave, o app usa o OpenStreetMap gratuito.
enum ProvedorMapa { openStreetMap, google, mapbox, mapTiler, stadia, here }

const String _provedorEscolhido = String.fromEnvironment('MAP_PROVIDER');
const String _chave = String.fromEnvironment('MAP_API_KEY');
// Estilo opcional de cada provedor (ex.: "streets-v12" no Mapbox,
// "streets-v2" no MapTiler, "osm_bright" no Stadia, "roadmap" no Google).
const String _estilo = String.fromEnvironment('MAP_STYLE');

const String _pacoteApp = 'com.cidadelimpa.app';

ProvedorMapa get provedorMapa {
  final escolhido = switch (_provedorEscolhido.toLowerCase()) {
    'google' => ProvedorMapa.google,
    'mapbox' => ProvedorMapa.mapbox,
    'maptiler' => ProvedorMapa.mapTiler,
    'stadia' => ProvedorMapa.stadia,
    'here' => ProvedorMapa.here,
    _ => ProvedorMapa.openStreetMap,
  };
  if (escolhido != ProvedorMapa.openStreetMap && _chave.isEmpty) {
    debugPrint('MAP_PROVIDER=$_provedorEscolhido sem MAP_API_KEY: usando OpenStreetMap.');
    return ProvedorMapa.openStreetMap;
  }
  return escolhido;
}

String _estiloOu(String padrao) => _estilo.isEmpty ? padrao : _estilo;

String _urlTiles(ProvedorMapa provedor, {String? sessaoGoogle}) => switch (provedor) {
      ProvedorMapa.openStreetMap => 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      ProvedorMapa.google =>
        'https://tile.googleapis.com/v1/2dtiles/{z}/{x}/{y}?session=$sessaoGoogle&key=$_chave',
      ProvedorMapa.mapbox =>
        'https://api.mapbox.com/styles/v1/mapbox/${_estiloOu('streets-v12')}/tiles/256/{z}/{x}/{y}@2x?access_token=$_chave',
      ProvedorMapa.mapTiler =>
        'https://api.maptiler.com/maps/${_estiloOu('streets-v2')}/256/{z}/{x}/{y}@2x.png?key=$_chave',
      ProvedorMapa.stadia =>
        'https://tiles.stadiamaps.com/tiles/${_estiloOu('osm_bright')}/{z}/{x}/{y}@2x.png?api_key=$_chave',
      ProvedorMapa.here =>
        'https://maps.hereapi.com/v3/base/mc/{z}/{x}/{y}/png?style=${_estiloOu('explore.day')}&size=512&apiKey=$_chave',
    };

List<String> _creditos(ProvedorMapa provedor) => switch (provedor) {
      ProvedorMapa.openStreetMap => ['© OpenStreetMap contributors'],
      ProvedorMapa.google => ['Dados do mapa © Google'],
      ProvedorMapa.mapbox => ['© Mapbox', '© OpenStreetMap contributors'],
      ProvedorMapa.mapTiler => ['© MapTiler', '© OpenStreetMap contributors'],
      ProvedorMapa.stadia => ['© Stadia Maps', '© OpenMapTiles', '© OpenStreetMap contributors'],
      ProvedorMapa.here => ['© HERE'],
    };

// O Google Map Tiles API exige uma "sessão" antes de baixar os tiles.
// Ela vale por cerca de 2 semanas; criamos uma por execução do app.
Future<String?>? _sessaoGoogle;

Future<String?> _criarSessaoGoogle() async {
  try {
    final resposta = await http
        .post(
          Uri.parse('https://tile.googleapis.com/v1/createSession?key=$_chave'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'mapType': _estiloOu('roadmap'),
            'language': 'pt-BR',
            'region': 'BR',
            'scale': 'scaleFactor2x',
            'highDpi': true,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (resposta.statusCode != 200) {
      debugPrint('Google Map Tiles: erro ${resposta.statusCode} ${resposta.body}');
      return null;
    }
    return (jsonDecode(resposta.body) as Map<String, dynamic>)['session'] as String?;
  } catch (e) {
    debugPrint('Google Map Tiles: $e');
    return null;
  }
}

// Camada de fundo do mapa, com o provedor configurado. Se o Google falhar
// (chave inválida, sem internet), volta para o OpenStreetMap.
class CamadaMapa extends StatefulWidget {
  final int keepBuffer;
  final int panBuffer;

  const CamadaMapa({super.key, this.keepBuffer = 2, this.panBuffer = 1});

  @override
  State<CamadaMapa> createState() => _CamadaMapaState();
}

class _CamadaMapaState extends State<CamadaMapa> {
  late ProvedorMapa _provedor = provedorMapa;
  String? _sessao;

  @override
  void initState() {
    super.initState();
    if (_provedor == ProvedorMapa.google) {
      _sessaoGoogle ??= _criarSessaoGoogle();
      _sessaoGoogle!.then((sessao) {
        if (!mounted) return;
        setState(() {
          _sessao = sessao;
          if (sessao == null) _provedor = ProvedorMapa.openStreetMap;
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_provedor == ProvedorMapa.google && _sessao == null) {
      return const SizedBox.shrink();
    }
    return TileLayer(
      urlTemplate: _urlTiles(_provedor, sessaoGoogle: _sessao),
      userAgentPackageName: _pacoteApp,
      maxNativeZoom: _provedor == ProvedorMapa.openStreetMap ? 19 : 20,
      keepBuffer: widget.keepBuffer,
      panBuffer: widget.panBuffer,
    );
  }
}

// Créditos exigidos pelo provedor de mapas, no canto do mapa.
class CreditosMapa extends StatelessWidget {
  const CreditosMapa({super.key});

  @override
  Widget build(BuildContext context) {
    return RichAttributionWidget(
      alignment: AttributionAlignment.bottomLeft,
      showFlutterMapAttribution: false,
      attributions: [
        for (final credito in _creditos(provedorMapa)) TextSourceAttribution(credito),
      ],
    );
  }
}
