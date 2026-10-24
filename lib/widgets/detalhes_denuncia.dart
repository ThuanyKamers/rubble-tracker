import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/denuncia.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import '../theme.dart';
import 'foto_entulho.dart';

String formatarData(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
}

// "há 5 min", "há 2 h", "há 3 dias" ou a data, para datas mais antigas.
String tempoDesde(DateTime d) {
  final dif = DateTime.now().difference(d);
  if (dif.inMinutes < 1) return 'agora mesmo';
  if (dif.inMinutes < 60) return 'há ${dif.inMinutes} min';
  if (dif.inHours < 24) return 'há ${dif.inHours} h';
  if (dif.inDays < 7) return dif.inDays == 1 ? 'há 1 dia' : 'há ${dif.inDays} dias';
  return formatarData(d).split(' às ').first;
}

String formatarDistancia(double metros) =>
    metros < 1000 ? '${metros.round()} m' : '${(metros / 1000).toStringAsFixed(1)} km';

// Abre a rota até o entulho no Google Maps (ou no navegador).
Future<void> abrirRota(BuildContext context, LatLng destino) async {
  final url = Uri.parse(
    'https://www.google.com/maps/dir/?api=1'
    '&destination=${destino.latitude},${destino.longitude}&travelmode=driving',
  );
  final abriu = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!abriu && context.mounted) {
    mostrarAviso(context, 'Não foi possível abrir o mapa.', tipo: TipoAviso.erro);
  }
}

// Abre os detalhes de um entulho. Devolve true se o trabalhador marcou como recolhido.
Future<bool> exibirDetalhesDenuncia(
  BuildContext context,
  Denuncia denuncia, {
  LatLng? origem,
}) async {
  final recolhido = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _DetalhesDenuncia(denuncia: denuncia, origem: origem),
  );
  return recolhido ?? false;
}

class _DetalhesDenuncia extends StatefulWidget {
  final Denuncia denuncia;
  final LatLng? origem;

  const _DetalhesDenuncia({required this.denuncia, this.origem});

  @override
  State<_DetalhesDenuncia> createState() => _DetalhesDenunciaState();
}

class _DetalhesDenunciaState extends State<_DetalhesDenuncia> {
  bool _enviando = false;
  int _fotoAtual = 0;

  Future<void> _marcarRecolhido() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.task_alt_rounded, color: Cores.verde, size: 36),
        title: const Text('Entulho recolhido?'),
        content: const Text(
          'Ele vai sair do mapa para todos os cidadãos e da lista da equipe.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim, recolhi'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      await ApiService.marcarRecolhido(widget.denuncia.id);
      if (!mounted) return;
      mostrarAviso(context, 'Pronto! Entulho marcado como recolhido.', tipo: TipoAviso.sucesso);
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      mostrarAviso(context, e.mensagem, tipo: TipoAviso.erro);
    }
  }

  @override
  Widget build(BuildContext context) {
    final denuncia = widget.denuncia;
    final ehTrabalhador = Sessao.usuario?.ehTrabalhador ?? false;
    final distancia = widget.origem == null
        ? null
        : const Distance()(widget.origem!, denuncia.coordenada);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Carrossel(
            fotos: denuncia.caminhosFotos,
            atual: _fotoAtual,
            onMudou: (i) => setState(() => _fotoAtual = i),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _Etiqueta(
                icone: denuncia.recolhida ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                texto: denuncia.recolhida ? 'Recolhido' : 'Aguardando coleta',
                cor: denuncia.recolhida ? Cores.verde : Cores.entulho,
              ),
              const SizedBox(width: 8),
              if (distancia != null)
                _Etiqueta(
                  icone: Icons.near_me_rounded,
                  texto: formatarDistancia(distancia),
                  cor: Cores.azul,
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            denuncia.pontoReferencia.isEmpty ? 'Sem ponto de referência' : denuncia.pontoReferencia,
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: denuncia.pontoReferencia.isEmpty ? Cores.textoSuave : Cores.texto,
            ),
          ),
          const SizedBox(height: 12),
          if (denuncia.criadoEm != null)
            _Linha(
              icone: Icons.schedule_rounded,
              texto: 'Registrado ${tempoDesde(denuncia.criadoEm!)} '
                  '(${formatarData(denuncia.criadoEm!)})',
            ),
          _Linha(
            icone: Icons.groups_rounded,
            texto: denuncia.confirmacoes > 1
                ? 'Confirmado por ${denuncia.confirmacoes} cidadãos'
                : 'Registrado por 1 cidadão',
          ),
          const SizedBox(height: 20),
          if (ehTrabalhador && !denuncia.recolhida) ...[
            FilledButton.icon(
              onPressed: _enviando ? null : _marcarRecolhido,
              icon: _enviando ? const CarregandoBotao() : const Icon(Icons.task_alt_rounded),
              label: const Text('Marcar como recolhido'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => abrirRota(context, denuncia.coordenada),
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Como chegar'),
            ),
          ] else
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Fechar'),
            ),
        ],
      ),
    );
  }
}

class _Carrossel extends StatelessWidget {
  final List<String> fotos;
  final int atual;
  final ValueChanged<int> onMudou;

  const _Carrossel({required this.fotos, required this.atual, required this.onMudou});

  @override
  Widget build(BuildContext context) {
    if (fotos.isEmpty) {
      return Container(
        height: 140,
        decoration: BoxDecoration(color: Cores.fundo, borderRadius: BorderRadius.circular(18)),
        child: const Center(
          child: Text('Nenhuma foto anexada.', style: TextStyle(color: Cores.textoSuave)),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        height: 230,
        child: Stack(
          children: [
            PageView.builder(
              itemCount: fotos.length,
              onPageChanged: onMudou,
              itemBuilder: (context, i) => GestureDetector(
                onTap: () => abrirFotoEmTelaCheia(context, fotos[i]),
                child: Hero(
                  tag: fotos[i],
                  child: Container(color: Cores.fundo, child: FotoEntulho(fotos[i])),
                ),
              ),
            ),
            if (fotos.length > 1)
              Positioned(
                bottom: 10,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(fotos.length, (i) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == atual ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == atual ? Colors.white : Colors.white70,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
                      ),
                    );
                  }),
                ),
              ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.zoom_out_map_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      '${atual + 1}/${fotos.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color cor;

  const _Etiqueta({required this.icone, required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 16, color: cor),
          const SizedBox(width: 5),
          Text(texto, style: TextStyle(color: cor, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final IconData icone;
  final String texto;

  const _Linha({required this.icone, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icone, size: 18, color: Cores.textoSuave),
          const SizedBox(width: 8),
          Expanded(child: Text(texto, style: const TextStyle(color: Cores.textoSuave))),
        ],
      ),
    );
  }
}
