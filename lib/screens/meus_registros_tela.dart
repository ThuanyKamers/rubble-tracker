import 'package:flutter/material.dart';

import '../models/denuncia.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/detalhes_denuncia.dart';
import '../widgets/foto_entulho.dart';

// Entulhos que o cidadão registrou ou confirmou, com a situação de cada um.
class MeusRegistrosTela extends StatefulWidget {
  const MeusRegistrosTela({super.key});

  @override
  State<MeusRegistrosTela> createState() => _MeusRegistrosTelaState();
}

class _MeusRegistrosTelaState extends State<MeusRegistrosTela> {
  late Future<List<Denuncia>> _futuro;

  @override
  void initState() {
    super.initState();
    _futuro = ApiService.fetchMeusRegistros();
  }

  Future<void> _recarregar() async {
    setState(() => _futuro = ApiService.fetchMeusRegistros());
    await _futuro.catchError((_) => <Denuncia>[]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meus registros')),
      body: RefreshIndicator(
        color: Cores.verde,
        onRefresh: _recarregar,
        child: FutureBuilder<List<Denuncia>>(
          future: _futuro,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Cores.verde));
            }
            if (snapshot.hasError) {
              return _Aviso(
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
            final registros = snapshot.data ?? [];
            if (registros.isEmpty) {
              return const _Aviso(
                icone: Icons.add_a_photo_rounded,
                titulo: 'Nenhum registro ainda',
                texto: 'Quando você reportar um entulho, ele aparece aqui e você acompanha até ser recolhido.',
              );
            }

            final recolhidos = registros.where((d) => d.recolhida).length;
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: registros.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    '${registros.length} registro(s), $recolhidos já recolhido(s). Obrigado por ajudar!',
                    style: const TextStyle(color: Cores.textoSuave),
                  );
                }
                final item = registros[index - 1];
                return _CartaoRegistro(
                  denuncia: item,
                  onTap: () => exibirDetalhesDenuncia(context, item),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _CartaoRegistro extends StatelessWidget {
  final Denuncia denuncia;
  final VoidCallback onTap;

  const _CartaoRegistro({required this.denuncia, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (cor, icone, situacao) = denuncia.recolhida
        ? (
            Cores.verde,
            Icons.task_alt_rounded,
            denuncia.recolhidoEm == null
                ? 'Recolhido'
                : 'Recolhido ${tempoDesde(denuncia.recolhidoEm!)}',
          )
        : denuncia.descartada
            ? (Cores.textoSuave, Icons.help_outline_rounded, 'Não encontrado pela equipe')
            : (Cores.alerta, Icons.schedule_rounded, 'Aguardando coleta');

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
                      denuncia.pontoReferencia.isEmpty ? 'Sem ponto de referência' : denuncia.pontoReferencia,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                    if (denuncia.criadoEm != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Registrado ${tempoDesde(denuncia.criadoEm!)}',
                        style: const TextStyle(fontSize: 13, color: Cores.textoSuave),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icone, size: 14, color: cor),
                          const SizedBox(width: 4),
                          Text(situacao, style: TextStyle(fontSize: 12.5, color: cor, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String texto;
  final Widget? botao;

  const _Aviso({required this.icone, required this.titulo, required this.texto, this.botao});

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
        Text(titulo, textAlign: TextAlign.center, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(texto, textAlign: TextAlign.center, style: const TextStyle(color: Cores.textoSuave)),
        if (botao != null) ...[const SizedBox(height: 12), Center(child: botao)],
      ],
    );
  }
}
