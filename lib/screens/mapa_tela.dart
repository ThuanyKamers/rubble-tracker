import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/denuncia.dart';
import '../services/api_service.dart';
import '../services/localizacao.dart';
import '../services/sessao.dart';
import '../widgets/detalhes_denuncia.dart';
import 'formulario_entulho_tela.dart';
import 'lista_denuncias_tela.dart';
import 'login_tela.dart';

class MapaTela extends StatefulWidget {
  const MapaTela({super.key});

  @override
  State<MapaTela> createState() => _MapaTelaState();
}

class _MapaTelaState extends State<MapaTela> {
  final MapController _mapController = MapController();
  List<Denuncia> _denuncias = [];
  bool _carregando = false;
  bool _recarregarDepois = false;
  bool _mapaPronto = false;
  bool _centralizouNoUsuario = false;
  LatLng? _posicaoUsuario;
  StreamSubscription<Position>? _gps;
  Timer? _espera;

  bool get _ehTrabalhador => Sessao.usuario?.ehTrabalhador ?? false;

  @override
  void initState() {
    super.initState();
    _iniciarGps();
  }

  @override
  void dispose() {
    _gps?.cancel();
    _espera?.cancel();
    super.dispose();
  }

  Future<void> _iniciarGps() async {
    final erro = await Localizacao.prepararGps();
    if (erro != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
      }
      return;
    }
    _gps = Localizacao.acompanhar().listen((p) {
      if (!mounted) return;
      setState(() => _posicaoUsuario = LatLng(p.latitude, p.longitude));
      if (!_centralizouNoUsuario && _mapaPronto) {
        _centralizouNoUsuario = true;
        _mapController.move(_posicaoUsuario!, 17);
        _atualizarDenunciasDaArea();
      }
    }, onError: (_) {});
  }

  void _agendarAtualizacao() {
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 400), _atualizarDenunciasDaArea);
  }

  Future<void> _atualizarDenunciasDaArea() async {
    if (!_mapaPronto) return;
    if (_carregando) {
      _recarregarDepois = true;
      return;
    }

    setState(() => _carregando = true);
    try {
      final bounds = _mapController.camera.visibleBounds;
      final dados = await ApiService.fetchDenuncias(
        minLat: bounds.southWest.latitude,
        maxLat: bounds.northEast.latitude,
        minLng: bounds.southWest.longitude,
        maxLng: bounds.northEast.longitude,
      );
      if (mounted) setState(() => _denuncias = dados);
    } on ApiException catch (e) {
      if (e.sessaoExpirada) return _sair();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.mensagem)));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }

    if (_recarregarDepois) {
      _recarregarDepois = false;
      _atualizarDenunciasDaArea();
    }
  }

  Future<void> _sair() async {
    await Sessao.sair();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginTela()),
      (_) => false,
    );
  }

  Future<void> _abrirDenuncia(Denuncia denuncia) async {
    final recolhido = await exibirDetalhesDenuncia(context, denuncia);
    if (recolhido && mounted) {
      setState(() => _denuncias.removeWhere((d) => d.id == denuncia.id));
    }
  }

  Future<void> _reportarEntulho() async {
    final registrada = await Navigator.push<Denuncia>(
      context,
      MaterialPageRoute(builder: (context) => const FormularioEntulhoTela()),
    );
    if (registrada != null && mounted) {
      _mapController.move(registrada.coordenada, 18);
    }
    _atualizarDenunciasDaArea();
  }

  Future<void> _abrirLista() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ListaDenunciasTela(posicaoUsuario: _posicaoUsuario)),
    );
    _atualizarDenunciasDaArea();
  }

  Marker _marcador(Denuncia d) {
    return Marker(
      key: ValueKey('denuncia_${d.id}'),
      point: d.coordenada,
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => _abrirDenuncia(d),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
              ),
              child: const Center(
                child: Icon(Icons.delete_outline, color: Colors.white, size: 22),
              ),
            ),
            if (d.confirmacoes > 1)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
                  child: Text(
                    '${d.confirmacoes}',
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ehTrabalhador ? 'Entulhos para recolher' : 'Cidade Limpa',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_ehTrabalhador)
            IconButton(
              tooltip: 'Ver em lista',
              icon: const Icon(Icons.list),
              onPressed: _abrirLista,
            ),
          PopupMenuButton<String>(
            iconColor: Colors.white,
            onSelected: (_) => _sair(),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(Sessao.usuario?.nome ?? ''),
              ),
              const PopupMenuItem(value: 'sair', child: Text('Sair')),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(latitudeInicial, longitudeInicial),
              initialZoom: 15.0,
              maxZoom: 19,
              onMapReady: () {
                _mapaPronto = true;
                if (_posicaoUsuario != null && !_centralizouNoUsuario) {
                  _centralizouNoUsuario = true;
                  _mapController.move(_posicaoUsuario!, 17);
                }
                _atualizarDenunciasDaArea();
              },
              onMapEvent: (event) {
                if (event is MapEventMoveEnd ||
                    event is MapEventFlingAnimationEnd ||
                    event is MapEventDoubleTapZoomEnd ||
                    event is MapEventScrollWheelZoom) {
                  _agendarAtualizacao();
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.cidadelimpa.app',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  if (_posicaoUsuario != null)
                    Marker(
                      key: const ValueKey('user_location'),
                      point: _posicaoUsuario!,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                      ),
                    ),
                  ..._denuncias.map(_marcador),
                ],
              ),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          if (_carregando)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.green),
                ),
              ),
            ),
          Positioned(
            left: 16,
            bottom: 24,
            child: FloatingActionButton.small(
              heroTag: 'minha_localizacao',
              backgroundColor: Colors.white,
              tooltip: 'Minha localização',
              onPressed: _posicaoUsuario == null
                  ? null
                  : () => _mapController.move(_posicaoUsuario!, 17),
              child: const Icon(Icons.my_location, color: Colors.blue),
            ),
          ),
        ],
      ),
      floatingActionButton: _ehTrabalhador
          ? null
          : FloatingActionButton.extended(
              heroTag: 'reportar',
              onPressed: _reportarEntulho,
              backgroundColor: Colors.green,
              icon: const Icon(Icons.add_a_photo, color: Colors.white),
              label: const Text('Reportar Entulho', style: TextStyle(color: Colors.white)),
            ),
    );
  }
}
