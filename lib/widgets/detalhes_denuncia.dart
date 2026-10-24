import 'package:flutter/material.dart';

import '../models/denuncia.dart';
import '../services/api_service.dart';
import '../services/sessao.dart';
import 'foto_entulho.dart';

String formatarData(DateTime d) {
  String dois(int n) => n.toString().padLeft(2, '0');
  return '${dois(d.day)}/${dois(d.month)}/${d.year} às ${dois(d.hour)}:${dois(d.minute)}';
}

// Abre os detalhes de um entulho. Devolve true se o trabalhador marcou como recolhido.
Future<bool> exibirDetalhesDenuncia(BuildContext context, Denuncia denuncia) async {
  final recolhido = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _DetalhesDenuncia(denuncia: denuncia),
  );
  return recolhido ?? false;
}

class _DetalhesDenuncia extends StatefulWidget {
  final Denuncia denuncia;

  const _DetalhesDenuncia({required this.denuncia});

  @override
  State<_DetalhesDenuncia> createState() => _DetalhesDenunciaState();
}

class _DetalhesDenunciaState extends State<_DetalhesDenuncia> {
  bool _enviando = false;

  Future<void> _marcarRecolhido() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como recolhido?'),
        content: const Text('O entulho vai sair do mapa para todos.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Recolhido')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    setState(() => _enviando = true);
    try {
      await ApiService.marcarRecolhido(widget.denuncia.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entulho marcado como recolhido.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.mensagem), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final denuncia = widget.denuncia;
    final ehTrabalhador = Sessao.usuario?.ehTrabalhador ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  denuncia.recolhida ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: denuncia.recolhida ? Colors.green : Colors.redAccent,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Text(
                  denuncia.recolhida ? 'Entulho recolhido' : 'Entulho para recolher',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (denuncia.criadoEm != null)
              Text(
                'Registrado em ${formatarData(denuncia.criadoEm!)}',
                style: const TextStyle(color: Colors.black54),
              ),
            if (denuncia.confirmacoes > 1)
              Text(
                'Confirmado por ${denuncia.confirmacoes} cidadãos',
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 15),
            const Text(
              'Descrição / Ponto de Referência:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 5),
            Text(
              denuncia.pontoReferencia.isEmpty ? 'Sem ponto de referência' : denuncia.pontoReferencia,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 15),
            const Text(
              'Fotos:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            if (denuncia.caminhosFotos.isEmpty)
              const Text('Nenhuma foto anexada.', style: TextStyle(color: Colors.black45))
            else
              SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: denuncia.caminhosFotos.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final foto = denuncia.caminhosFotos[index];
                    return GestureDetector(
                      onTap: () => abrirFotoEmTelaCheia(context, foto),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(width: 140, child: FotoEntulho(foto)),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 20),
            if (ehTrabalhador && !denuncia.recolhida)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _enviando ? null : _marcarRecolhido,
                  icon: _enviando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Marcar como recolhido', style: TextStyle(fontSize: 16)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Fechar'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
