import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/denuncia.dart';
import '../services/api_service.dart';
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

  String _textoDistancia(Denuncia d) {
    final origem = widget.posicaoUsuario;
    if (origem == null) return '';
    final m = _distancia(origem, d.coordenada);
    return m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entulhos registrados', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(_carregar);
          await _futureDenuncias;
        },
        child: FutureBuilder<List<Denuncia>>(
          future: _futureDenuncias,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Erro: ${snapshot.error}', textAlign: TextAlign.center),
                ),
              ]);
            }
            final denuncias = snapshot.data ?? [];
            if (denuncias.isEmpty) {
              return ListView(children: const [
                Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum entulho para recolher. 🎉', textAlign: TextAlign.center),
                ),
              ]);
            }

            return ListView.builder(
              itemCount: denuncias.length,
              itemBuilder: (context, index) {
                final item = denuncias[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: FotoEntulho(item.caminhosFotos.isEmpty ? '' : item.caminhosFotos.first),
                      ),
                    ),
                    title: Text(
                      item.pontoReferencia.isEmpty ? 'Sem ponto de referência' : item.pontoReferencia,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text([
                      _textoDistancia(item),
                      if (item.criadoEm != null) formatarData(item.criadoEm!),
                    ].where((t) => t.isNotEmpty).join(' · ')),
                    onTap: () async {
                      final recolhido = await exibirDetalhesDenuncia(context, item);
                      if (recolhido && mounted) setState(() => denuncias.remove(item));
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
