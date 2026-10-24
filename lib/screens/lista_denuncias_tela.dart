import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/denuncia.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/detalhes_denuncia.dart';
import '../widgets/foto_entulho.dart';

// Lista de entulhos para o trabalhador, do mais próximo para o mais distante.
class ListaDenunciasTela extends StatefulWidget {
  final LatLng? posicaoUsuario;

  const ListaDenunciasTela({super.key, this.posicaoUsuario});

  @override
  State<ListaDenunciasTela> createState() => _ListaDenunciasTelaState();
}

class _ListaDenunciasTelaState extends State<ListaDenunciasTela> {
  late Future<List<Denuncia>> _futureDenuncias;
  final _distancia = const Distance();

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() {
    _futureDenuncias = ApiService.fetchDenuncias().then((lista) {
      final origem = widget.posicaoUsuario;
      if (origem != null) {
        lista.sort((a, b) =>
            _distancia(origem, a.coordenada).compareTo(_distancia(origem, b.coordenada)));
      }
      return lista;
    });
  }

  Future<void> _recarregar() async {
    setState(_carregar);
    await _futureDenuncias.catchError((_) => <Denuncia>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entulhos para recolher')),
      body: RefreshIndicator(
        color: Cores.verde,
        onRefresh: _recarregar,
        child: FutureBuilder<List<Denuncia>>(
          future: _futureDenuncias,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _Esqueleto();
            }
            if (snapshot.hasError) {
              return _Mensagem(
                icone: Icons.wifi_off_rounded,
                titulo: 'Não foi possível carregar',
                texto: '${snapshot.error}',
                botao: TextButton.icon(
                  onPressed: _recarregar,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Tentar de novo'),
                ),
              );
            }
            final denuncias = snapshot.data ?? [];
            if (denuncias.isEmpty) {
              return const _Mensagem(
                icone: Icons.celebration_rounded,
                titulo: 'Tudo limpo!',
                texto: 'Não há nenhum entulho esperando coleta agora.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: denuncias.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    widget.posicaoUsuario == null
                        ? '${denuncias.length} entulho(s) aguardando coleta'
                        : '${denuncias.length} entulho(s), do mais perto ao mais longe',
                    style: const TextStyle(color: Cores.textoSuave),
                  );
                }
                final item = denuncias[index - 1];
                final metros = widget.posicaoUsuario == null
                    ? null
                    : _distancia(widget.posicaoUsuario!, item.coordenada);
                return _CartaoEntulho(
                  denuncia: item,
                  distanciaM: metros,
                  onTap: () async {
                    final recolhido = await exibirDetalhesDenuncia(
                      context,
                      item,
                      origem: widget.posicaoUsuario,
                    );
                    if (recolhido && mounted) setState(() => denuncias.remove(item));
                  },
                  onRota: () => abrirRota(context, item.coordenada),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CartaoEntulho extends StatelessWidget {
  final Denuncia denuncia;
  final double? distanciaM;
  final VoidCallback onTap;
  final VoidCallback onRota;

  const _CartaoEntulho({
    required this.denuncia,
    required this.distanciaM,
    required this.onTap,
    required this.onRota,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 76,
                  height: 76,
                  color: Cores.fundo,
                  child: FotoEntulho(
                    denuncia.caminhosFotos.isEmpty ? '' : denuncia.caminhosFotos.first,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      denuncia.pontoReferencia.isEmpty
                          ? 'Sem ponto de referência'
                          : denuncia.pontoReferencia,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (distanciaM != null)
                          _Chip(Icons.near_me_rounded, formatarDistancia(distanciaM!), Cores.azul),
                        if (denuncia.criadoEm != null)
                          _Chip(Icons.schedule_rounded, tempoDesde(denuncia.criadoEm!), Cores.textoSuave),
                        if (denuncia.confirmacoes > 1)
                          _Chip(Icons.groups_rounded, '${denuncia.confirmacoes}', Cores.alerta),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Como chegar',
                onPressed: onRota,
                icon: const Icon(Icons.directions_rounded, color: Cores.verde),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color cor;

  const _Chip(this.icone, this.texto, this.cor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 13, color: cor),
          const SizedBox(width: 4),
          Text(texto, style: TextStyle(fontSize: 12, color: cor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Mensagem extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? botao;

  const _Mensagem({required this.icone, required this.titulo, required this.texto, this.botao});

  @override
  Widget build(BuildContext context) {
    // ListView para o "puxar para atualizar" funcionar mesmo sem itens.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        CircleAvatar(
          radius: 40,
          backgroundColor: Cores.verdeClaro,
          child: Icon(icone, size: 40, color: Cores.verde),
        ),
        const SizedBox(height: 20),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Cores.textoSuave)),
        if (botao != null) ...[const SizedBox(height: 12), Center(child: botao)],
      ],
    );
  }
}

// Cartões cinza enquanto a lista carrega.
class _Esqueleto extends StatelessWidget {
  const _Esqueleto();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 24),
      itemCount: 4,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 76,
              decoration: BoxDecoration(
                color: const Color(0xFFE9EEEB),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(height: 14, color: const Color(0xFFE9EEEB)),
                  const SizedBox(height: 10),
                  Container(height: 12, width: 120, color: const Color(0xFFF0F3F1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
