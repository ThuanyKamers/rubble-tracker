import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/denuncia.dart';
import '../services/api_service.dart';
import '../services/localizacao.dart';
import '../theme.dart';
import '../widgets/foto_entulho.dart';
import '../widgets/pino_mapa.dart';

// Formulário do cidadão. Ao salvar, devolve a Denuncia registrada (ou confirmada).
class FormularioEntulhoTela extends StatefulWidget {
  const FormularioEntulhoTela({super.key});

  @override
  State<FormularioEntulhoTela> createState() => _FormularioEntulhoTelaState();
}

class _FormularioEntulhoTelaState extends State<FormularioEntulhoTela> {
  static const _maxFotos = 3;

  final _referenciaController = TextEditingController();
  final List<XFile> _fotosLista = [];
  final ImagePicker _picker = ImagePicker();
  final MapController _miniMapa = MapController();
  bool _miniMapaPronto = false;

  StreamSubscription<Position>? _gps;
  // Leituras recentes do GPS; usamos a mais precisa dos últimos segundos.
  final List<Position> _leituras = [];
  String? _erroGps;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _iniciarGps();
  }

  @override
  void dispose() {
    _gps?.cancel();
    _referenciaController.dispose();
    super.dispose();
  }

  Future<void> _iniciarGps() async {
    final erro = await Localizacao.prepararGps();
    if (!mounted) return;
    if (erro != null) {
      setState(() => _erroGps = erro);
      return;
    }
    setState(() => _erroGps = null);
    _gps?.cancel();
    _gps = Localizacao.acompanhar().listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _leituras.add(p);
          final limite = DateTime.now().subtract(const Duration(seconds: 20));
          _leituras.removeWhere((l) => l.timestamp.isBefore(limite));
        });
        final melhor = _melhorPosicao;
        if (melhor != null && _miniMapaPronto) {
          _miniMapa.move(LatLng(melhor.latitude, melhor.longitude), 18);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _erroGps = 'Não foi possível ler o GPS.');
      },
    );
  }

  Position? get _melhorPosicao {
    if (_leituras.isEmpty) return null;
    return _leituras.reduce((a, b) => b.accuracy <= a.accuracy ? b : a);
  }

  bool get _gpsPronto {
    final p = _melhorPosicao;
    return p != null && !p.isMocked && p.accuracy <= precisaoMaximaGpsM;
  }

  bool get _podeEnviar => _fotosLista.isNotEmpty && _gpsPronto && !_enviando;

  Future<void> _tirarFoto() async {
    if (_fotosLista.length >= _maxFotos) {
      mostrarAviso(context, 'Você já adicionou as 3 fotos.');
      return;
    }

    // Só câmera: a foto precisa ser tirada na hora, no local.
    final XFile? fotoTirada = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
      maxWidth: 1920,
      imageQuality: 70,
    );
    if (fotoTirada != null && mounted) {
      setState(() => _fotosLista.add(fotoTirada));
    }
  }

  Future<void> _enviar() async {
    FocusScope.of(context).unfocus();
    if (_fotosLista.isEmpty) {
      return mostrarAviso(context, 'Tire pelo menos 1 foto do entulho.');
    }
    final posicao = _melhorPosicao;
    if (posicao == null || !_gpsPronto) {
      return mostrarAviso(context, 'Aguarde a localização ficar precisa.');
    }

    setState(() => _enviando = true);
    try {
      final resultado = await _registrar(posicao);
      if (resultado == null || !mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => _SucessoTela(duplicada: resultado.duplicada),
        ),
      );
      if (mounted) Navigator.pop(context, resultado.denuncia);
    } on ApiException catch (e) {
      if (mounted) mostrarAviso(context, e.mensagem, tipo: TipoAviso.erro);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // Envia o registro. Se o servidor achar um entulho muito perto, pergunta ao
  // cidadão se é o mesmo. Devolve null se o cidadão cancelar.
  Future<ResultadoRegistro?> _registrar(Position posicao) async {
    final referencia = _referenciaController.text.trim();
    try {
      return await ApiService.criarDenuncia(
        posicao: posicao,
        pontoReferencia: referencia,
        fotos: _fotosLista,
      );
    } on ApiException catch (e) {
      if (e.codigo != 'ENTULHO_PROXIMO' || !mounted) rethrow;

      final candidatos = (e.dados['candidatos'] as List? ?? const [])
          .map((c) => Denuncia.fromJson(c as Map<String, dynamic>))
          .toList();
      final escolha = await _perguntarSeEhOMesmo(candidatos);
      if (escolha == null) return null;

      if (escolha == _Escolha.novo) {
        return ApiService.criarDenuncia(
          posicao: posicao,
          pontoReferencia: referencia,
          fotos: _fotosLista,
          forcarNovo: true,
        );
      }
      return ApiService.confirmarDenuncia(
        denunciaId: escolha.denunciaId!,
        posicao: posicao,
        pontoReferencia: referencia,
        fotos: _fotosLista,
      );
    }
  }

  Future<_Escolha?> _perguntarSeEhOMesmo(List<Denuncia> candidatos) {
    return showModalBottomSheet<_Escolha>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.travel_explore_rounded, size: 40, color: Cores.alerta),
            const SizedBox(height: 8),
            const Text(
              'Já existe um entulho registrado bem perto daqui',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Se for o mesmo, toque nele: suas fotos são adicionadas a ele. '
              'Se for outro, registre como novo.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Cores.textoSuave),
            ),
            const SizedBox(height: 16),
            ...candidatos.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(10),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: FotoEntulho(c.caminhosFotos.isEmpty ? '' : c.caminhosFotos.first),
                      ),
                    ),
                    title: Text(
                      c.pontoReferencia.isEmpty ? 'Sem ponto de referência' : c.pontoReferencia,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('A ${c.distanciaM?.round() ?? '?'} m de você'),
                    trailing: const Text(
                      'É este',
                      style: TextStyle(color: Cores.verde, fontWeight: FontWeight.w700),
                    ),
                    onTap: () => Navigator.pop(context, _Escolha.mesmo(c.id)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton(
              onPressed: () => Navigator.pop(context, _Escolha.novo),
              child: const Text('É outro entulho, registrar novo'),
            ),
            const SizedBox(height: 6),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Seções

  Widget _fotos() {
    return Row(
      spacing: 12,
      children: List.generate(_maxFotos, (index) {
        final temFoto = index < _fotosLista.length;
        final ehProxima = index == _fotosLista.length;

        return Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Material(
                    color: temFoto ? Colors.black : (ehProxima ? Cores.verdeClaro : Colors.white),
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: temFoto
                          ? () => abrirFotoEmTelaCheia(context, _fotosLista[index].path)
                          : _tirarFoto,
                      child: temFoto
                          ? FotoEntulho(_fotosLista[index].path)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_rounded,
                                  size: 30,
                                  color: ehProxima ? Cores.verde : const Color(0xFFB9C7BF),
                                ),
                                if (ehProxima) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    index == 0 ? 'Tirar foto' : 'Mais uma',
                                    style: const TextStyle(
                                      color: Cores.verde,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                  ),
                ),
                if (temFoto)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => setState(() => _fotosLista.removeAt(index)),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded, size: 18, color: Cores.entulho),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _localizacao() {
    final p = _melhorPosicao;
    late final IconData icone;
    late final Color cor;
    late final String texto;

    if (_erroGps != null) {
      icone = Icons.location_off_rounded;
      cor = Cores.entulho;
      texto = _erroGps!;
    } else if (p == null) {
      icone = Icons.gps_not_fixed_rounded;
      cor = Cores.alerta;
      texto = 'Procurando sua localização...';
    } else if (p.isMocked) {
      icone = Icons.gps_off_rounded;
      cor = Cores.entulho;
      texto = 'Localização simulada detectada. Desative apps de GPS falso.';
    } else if (p.accuracy > precisaoMaximaGpsM) {
      icone = Icons.gps_not_fixed_rounded;
      cor = Cores.alerta;
      texto =
          'Melhorando a precisão (±${p.accuracy.round()} m). '
          'Fique perto do entulho, em lugar aberto.';
    } else {
      icone = Icons.gps_fixed_rounded;
      cor = Cores.verde;
      texto =
          'Localização precisa (±${p.accuracy.round()} m). '
          'O alfinete vai exatamente aqui.';
    }

    final centro = p == null
        ? const LatLng(latitudeInicial, longitudeInicial)
        : LatLng(p.latitude, p.longitude);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          SizedBox(
            height: 160,
            child: IgnorePointer(
              child: FlutterMap(
                mapController: _miniMapa,
                options: MapOptions(
                  initialCenter: centro,
                  initialZoom: p == null ? 14 : 18,
                  onMapReady: () => _miniMapaPronto = true,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.cidadelimpa.app',
                    maxNativeZoom: 19,
                  ),
                  if (p != null) ...[
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: centro,
                          radius: p.accuracy,
                          useRadiusInMeter: true,
                          color: cor.withValues(alpha: 0.15),
                          borderColor: cor,
                          borderStrokeWidth: 1.5,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: centro,
                          width: 48,
                          height: 56,
                          alignment: alinhamentoPino,
                          child: const PinoEntulho(),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            color: cor.withValues(alpha: 0.1),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (p == null && _erroGps == null)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cor),
                  )
                else
                  Icon(icone, color: cor),
                const SizedBox(width: 10),
                Expanded(child: Text(texto, style: const TextStyle(fontSize: 13.5))),
                if (_erroGps != null)
                  TextButton(
                    onPressed: () async {
                      await Geolocator.openLocationSettings();
                      _iniciarGps();
                    },
                    child: const Text('Ajustar'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _oQueFalta {
    if (_fotosLista.isEmpty) return 'Tire pelo menos 1 foto para enviar';
    if (!_gpsPronto) return 'Aguardando a localização ficar precisa';
    return 'Tudo pronto!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar entulho')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _Passo(
            numero: 1,
            titulo: 'Fotos do entulho',
            subtitulo: 'Tire de 1 a 3 fotos na hora, no local.',
            feito: _fotosLista.isNotEmpty,
          ),
          const SizedBox(height: 12),
          _fotos(),
          const SizedBox(height: 28),
          _Passo(
            numero: 2,
            titulo: 'Localização',
            subtitulo: 'Usamos o GPS para marcar o ponto exato.',
            feito: _gpsPronto,
          ),
          const SizedBox(height: 12),
          _localizacao(),
          const SizedBox(height: 28),
          _Passo(
            numero: 3,
            titulo: 'Ponto de referência',
            subtitulo: 'Opcional, mas ajuda muito a equipe de coleta.',
            feito: _referenciaController.text.trim().isNotEmpty,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _referenciaController,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Ex.: Na frente da loja de 10, ao lado da clínica.',
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _oQueFalta,
                  key: ValueKey(_oQueFalta),
                  style: TextStyle(
                    fontSize: 13,
                    color: _podeEnviar || _enviando ? Cores.verde : Cores.textoSuave,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _podeEnviar ? _enviar : null,
                icon: _enviando ? const CarregandoBotao() : const Icon(Icons.send_rounded),
                label: Text(_enviando ? 'Enviando...' : 'Enviar registro'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Passo extends StatelessWidget {
  final int numero;
  final String titulo;
  final String subtitulo;
  final bool feito;

  const _Passo({
    required this.numero,
    required this.titulo,
    required this.subtitulo,
    required this.feito,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: feito ? Cores.verde : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Cores.verde, width: 2),
          ),
          child: Center(
            child: feito
                ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                : Text(
                    '$numero',
                    style: const TextStyle(color: Cores.verde, fontWeight: FontWeight.w800),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              Text(subtitulo, style: const TextStyle(fontSize: 13, color: Cores.textoSuave)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SucessoTela extends StatelessWidget {
  final bool duplicada;

  const _SucessoTela({required this.duplicada});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (context, v, child) => Transform.scale(scale: v, child: child),
                child: const CircleAvatar(
                  radius: 56,
                  backgroundColor: Cores.verdeClaro,
                  child: Icon(Icons.check_rounded, size: 64, color: Cores.verde),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                duplicada ? 'Confirmação enviada!' : 'Entulho registrado!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(
                duplicada
                    ? 'Esse entulho já estava no mapa. Suas fotos foram adicionadas '
                          'e ele ganhou prioridade para a equipe de coleta.'
                    : 'A equipe de coleta da prefeitura já pode ver o local no mapa. '
                          'Obrigado por ajudar a deixar Palhoça mais limpa!',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Cores.textoSuave, height: 1.4),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.map_rounded),
                label: const Text('Ver no mapa'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Escolha {
  final int? denunciaId;

  const _Escolha._(this.denunciaId);

  static const novo = _Escolha._(null);

  factory _Escolha.mesmo(int id) => _Escolha._(id);
}
