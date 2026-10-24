import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../models/denuncia.dart';
import '../services/api_service.dart';
import '../services/localizacao.dart';
import '../widgets/foto_entulho.dart';

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
    _gps = Localizacao.acompanhar().listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _leituras.add(p);
          final limite = DateTime.now().subtract(const Duration(seconds: 20));
          _leituras.removeWhere((l) => l.timestamp.isBefore(limite));
        });
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

  Future<void> _tirarFoto() async {
    if (_fotosLista.length >= _maxFotos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Limite máximo de 3 fotos atingido!')),
      );
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

  void _mensagem(String texto, {Color? cor}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto), backgroundColor: cor));
  }

  Future<void> _enviar() async {
    if (_fotosLista.isEmpty) {
      return _mensagem('Por favor, tire pelo menos 1 foto do local.', cor: Colors.amber.shade800);
    }
    final posicao = _melhorPosicao;
    if (posicao == null || !_gpsPronto) {
      return _mensagem('Aguarde o GPS ficar preciso antes de enviar.', cor: Colors.amber.shade800);
    }

    setState(() => _enviando = true);
    try {
      final resultado = await _registrar(posicao);
      if (resultado == null || !mounted) return;

      _mensagem(
        resultado.duplicada
            ? 'Esse entulho já estava registrado. Sua confirmação e fotos foram adicionadas!'
            : 'Entulho registrado! Obrigado por ajudar a cidade.',
        cor: Colors.green,
      );
      Navigator.pop(context, resultado.denuncia);
    } on ApiException catch (e) {
      if (mounted) _mensagem(e.mensagem, cor: Colors.red);
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Já tem entulho registrado aqui perto',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text('Se for o mesmo, toque nele. Se for outro, registre como novo.'),
              const SizedBox(height: 12),
              ...candidatos.map((c) => Card(
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: FotoEntulho(c.caminhosFotos.isEmpty ? '' : c.caminhosFotos.first),
                        ),
                      ),
                      title: Text(
                        c.pontoReferencia.isEmpty ? 'Sem ponto de referência' : c.pontoReferencia,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text('A ${c.distanciaM?.round() ?? '?'} m de você'),
                      trailing: const Text('É este', style: TextStyle(color: Colors.green)),
                      onTap: () => Navigator.pop(context, _Escolha.mesmo(c.id)),
                    ),
                  )),
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () => Navigator.pop(context, _Escolha.novo),
                child: const Text('É outro entulho, registrar novo'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusGps() {
    final p = _melhorPosicao;
    late final IconData icone;
    late final Color cor;
    late final String texto;

    if (_erroGps != null) {
      icone = Icons.location_off;
      cor = Colors.red;
      texto = _erroGps!;
    } else if (p == null) {
      icone = Icons.gps_not_fixed;
      cor = Colors.orange;
      texto = 'Procurando sua localização...';
    } else if (p.isMocked) {
      icone = Icons.gps_off;
      cor = Colors.red;
      texto = 'Localização simulada detectada. Desative apps de GPS falso.';
    } else if (p.accuracy > precisaoMaximaGpsM) {
      icone = Icons.gps_not_fixed;
      cor = Colors.orange;
      texto = 'Melhorando a precisão (±${p.accuracy.round()} m). '
          'Fique perto do entulho, em lugar aberto.';
    } else {
      icone = Icons.gps_fixed;
      cor = Colors.green;
      texto = 'Localização pronta (±${p.accuracy.round()} m)';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor),
      ),
      child: Row(
        children: [
          Icon(icone, color: cor),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Entulho', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _statusGps(),
            const SizedBox(height: 24),
            const Text(
              'Fotos do Entulho (Máx. 3)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_maxFotos, (index) {
                final temFoto = index < _fotosLista.length;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: temFoto
                          ? () => abrirFotoEmTelaCheia(context, _fotosLista[index].path)
                          : _tirarFoto,
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: temFoto ? Colors.green : Colors.grey[400]!,
                            width: 2,
                          ),
                        ),
                        child: temFoto
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: FotoEntulho(_fotosLista[index].path),
                              )
                            : Icon(Icons.add_a_photo, color: Colors.grey[600], size: 32),
                      ),
                    ),
                    if (temFoto)
                      Positioned(
                        top: -8,
                        right: -8,
                        child: GestureDetector(
                          onTap: () => setState(() => _fotosLista.removeAt(index)),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
            const SizedBox(height: 8),
            Text(
              'Fotos adicionadas: ${_fotosLista.length} de $_maxFotos',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            const Text(
              'Ponto de Referência (Opcional)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _referenciaController,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Ex: Na frente da loja de 10, ao lado da clínica.',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: FloatingActionButton.extended(
          backgroundColor: _gpsPronto && !_enviando ? Colors.green : Colors.grey,
          onPressed: _enviando ? null : _enviar,
          label: _enviando
              ? const Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 12),
                    Text('Enviando...', style: TextStyle(fontSize: 18, color: Colors.white)),
                  ],
                )
              : const Text('Enviar Denúncia', style: TextStyle(fontSize: 18, color: Colors.white)),
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
