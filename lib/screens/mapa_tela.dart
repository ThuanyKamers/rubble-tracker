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
import '../theme.dart';
import '../widgets/detalhes_denuncia.dart';
import '../widgets/pino_mapa.dart';
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
  bool _jaCarregou = false;
  bool _recarregarDepois = false;
  bool _mapaPronto = false;
  bool _centralizouNoUsuario = false;
  int? _selecionada;
  String? _erroGps;
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
    if (!mounted) return;
    setState(() => _erroGps = erro);
    if (erro != null) return;

    _gps?.cancel();
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
      if (mounted) {
        setState(() {
          _denuncias = dados;
          _jaCarregou = true;
        });
      }
    } on ApiException catch (e) {
      if (e.sessaoExpirada) return _sair();
      if (mounted) mostrarAviso(context, e.mensagem, tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() => _carregando = false);
    }

    if (_recarregarDepois) {
      _recarregarDepois = false;
      _atualizarDenunciasDaArea();
    }
  }

  Future<void> _confirmarSaida() async {
    final sair = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text('Você vai precisar do CPF e da senha para entrar de novo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (sair == true) _sair();
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
    setState(() => _selecionada = denuncia.id);
    final recolhido = await exibirDetalhesDenuncia(
      context,
      denuncia,
      origem: _posicaoUsuario,
    );
    if (!mounted) return;
    setState(() {
      _selecionada = null;
      if (recolhido) _denuncias.removeWhere((d) => d.id == denuncia.id);
    });
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

  void _irParaMinhaLocalizacao() {
    if (_posicaoUsuario != null) {
      _mapController.move(_posicaoUsuario!, 17);
    } else {
      _iniciarGps();
      mostrarAviso(context, _erroGps ?? 'Procurando sua localização...');
    }
  }

  Marker _marcador(Denuncia d) {
    return Marker(
      key: ValueKey('denuncia_${d.id}'),
      point: d.coordenada,
      width: 48,
      height: 56,
      alignment: alinhamentoPino,
      child: GestureDetector(
        onTap: () => _abrirDenuncia(d),
        child: PinoEntulho(confirmacoes: d.confirmacoes, selecionado: _selecionada == d.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rodape = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: const LatLng(latitudeInicial, longitudeInicial),
              initialZoom: 15.0,
              maxZoom: 19,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
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
                keepBuffer: 4,
                panBuffer: 1,
              ),
              MarkerLayer(
                markers: [
                  if (_posicaoUsuario != null)
                    Marker(
                      key: const ValueKey('user_location'),
                      point: _posicaoUsuario!,
                      width: 32,
                      height: 32,
                      child: const PontoUsuario(),
                    ),
                  ..._denuncias.map(_marcador),
                ],
              ),
              const RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
                showFlutterMapAttribution: false,
                attributions: [TextSourceAttribution('OpenStreetMap contributors')],
              ),
            ],
          ),
          // Cabeçalho flutuante
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _Cabecalho(
                    ehTrabalhador: _ehTrabalhador,
                    quantidade: _denuncias.length,
                    carregando: _carregando,
                    onSair: _confirmarSaida,
                  ),
                  const SizedBox(height: 10),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _erroGps != null
                        ? _Faixa(
                            key: const ValueKey('gps'),
                            icone: Icons.location_off_rounded,
                            cor: Cores.entulho,
                            texto: _erroGps!,
                            acao: 'Ativar',
                            onAcao: () async {
                              await Geolocator.openLocationSettings();
                              _iniciarGps();
                            },
                          )
                        : (_jaCarregou && !_carregando && _denuncias.isEmpty)
                            ? _Faixa(
                                key: const ValueKey('vazio'),
                                icone: Icons.celebration_rounded,
                                cor: Cores.verde,
                                texto: _ehTrabalhador
                                    ? 'Nenhum entulho nesta área. Arraste o mapa para ver outros bairros.'
                                    : 'Nenhum entulho registrado aqui. Viu algum? Toque em "Reportar entulho".',
                              )
                            : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          // Botões do lado direito
          Positioned(
            right: 16,
            bottom: 104 + rodape,
            child: Column(
              children: [
                _BotaoRedondo(
                  icone: Icons.refresh_rounded,
                  tooltip: 'Atualizar',
                  onTap: _atualizarDenunciasDaArea,
                ),
                const SizedBox(height: 12),
                _BotaoRedondo(
                  icone: Icons.my_location_rounded,
                  cor: Cores.azul,
                  tooltip: 'Minha localização',
                  onTap: _irParaMinhaLocalizacao,
                ),
              ],
            ),
          ),
          // Ação principal
          Positioned(
            left: 16,
            right: 16,
            bottom: 24 + rodape,
            child: _ehTrabalhador
                ? FilledButton.icon(
                    onPressed: _abrirLista,
                    icon: const Icon(Icons.format_list_bulleted_rounded),
                    label: const Text('Ver lista por distância'),
                  )
                : FilledButton.icon(
                    onPressed: _reportarEntulho,
                    icon: const Icon(Icons.add_a_photo_rounded),
                    label: const Text('Reportar entulho'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Cabecalho extends StatelessWidget {
  final bool ehTrabalhador;
  final int quantidade;
  final bool carregando;
  final VoidCallback onSair;

  const _Cabecalho({
    required this.ehTrabalhador,
    required this.quantidade,
    required this.carregando,
    required this.onSair,
  });

  @override
  Widget build(BuildContext context) {
    final nome = Sessao.usuario?.nome ?? '';
    final primeiroNome = nome.split(' ').first;
    final inicial = nome.isEmpty ? '?' : nome[0].toUpperCase();

    return Material(
      color: Colors.white,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Cores.verdeClaro,
              child: Text(
                inicial,
                style: const TextStyle(color: Cores.verde, fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Olá, $primeiroNome',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Cores.texto),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        ehTrabalhador ? Icons.engineering_rounded : Icons.person_rounded,
                        size: 14,
                        color: Cores.textoSuave,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          ehTrabalhador ? 'Equipe de coleta' : 'Cidadão',
                          style: const TextStyle(fontSize: 13, color: Cores.textoSuave),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _Contador(quantidade: quantidade, carregando: carregando),
            IconButton(
              tooltip: 'Sair',
              icon: const Icon(Icons.logout_rounded, color: Cores.textoSuave),
              onPressed: onSair,
            ),
          ],
        ),
      ),
    );
  }
}

class _Contador extends StatelessWidget {
  final int quantidade;
  final bool carregando;

  const _Contador({required this.quantidade, required this.carregando});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Entulhos visíveis no mapa',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Cores.entulho.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (carregando)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Cores.entulho),
              )
            else
              const Icon(Icons.delete_outline_rounded, size: 16, color: Cores.entulho),
            const SizedBox(width: 4),
            Text(
              '$quantidade',
              style: const TextStyle(color: Cores.entulho, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _Faixa extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String texto;
  final String? acao;
  final VoidCallback? onAcao;

  const _Faixa({
    super.key,
    required this.icone,
    required this.cor,
    required this.texto,
    this.acao,
    this.onAcao,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icone, color: cor),
            const SizedBox(width: 10),
            Expanded(child: Text(texto, style: const TextStyle(fontSize: 13.5, color: Cores.texto))),
            if (acao != null) TextButton(onPressed: onAcao, child: Text(acao!)),
          ],
        ),
      ),
    );
  }
}

class _BotaoRedondo extends StatelessWidget {
  final IconData icone;
  final String tooltip;
  final VoidCallback onTap;
  final Color cor;

  const _BotaoRedondo({
    required this.icone,
    required this.tooltip,
    required this.onTap,
    this.cor = Cores.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 52, height: 52, child: Icon(icone, color: cor)),
        ),
      ),
    );
  }
}
