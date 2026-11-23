import 'package:latlong2/latlong.dart';

import '../config.dart';

class Denuncia {
  final int id;
  final LatLng coordenada;
  final String pontoReferencia;
  final List<String> caminhosFotos;
  final String status;
  final int confirmacoes;
  final DateTime? criadoEm;
  final DateTime? recolhidoEm;
  final double? distanciaM;

  Denuncia({
    required this.id,
    required this.coordenada,
    required this.pontoReferencia,
    required this.caminhosFotos,
    this.status = 'ativo',
    this.confirmacoes = 1,
    this.criadoEm,
    this.recolhidoEm,
    this.distanciaM,
  });

  bool get recolhida => status == 'recolhido';
  // O trabalhador foi ao local e não encontrou o entulho.
  bool get descartada => status == 'descartado';

  factory Denuncia.fromJson(Map<String, dynamic> json) {
    final fotos = (json['fotos'] as List? ?? const [])
        .map((f) => f.toString())
        // Fotos guardadas no servidor vêm como "/uploads/arquivo.jpg"
        .map((f) => f.startsWith('/') ? '$apiUrl$f' : f)
        .toList();

    return Denuncia(
      id: json['id'] as int,
      coordenada: LatLng(
        double.parse(json['latitude'].toString()),
        double.parse(json['longitude'].toString()),
      ),
      pontoReferencia: (json['ponto_referencia'] as String?) ?? '',
      caminhosFotos: fotos,
      status: (json['status'] as String?) ?? 'ativo',
      confirmacoes: (json['confirmacoes'] as int?) ?? 1,
      criadoEm: DateTime.tryParse(json['criado_em']?.toString() ?? '')?.toLocal(),
      recolhidoEm: DateTime.tryParse(json['recolhido_em']?.toString() ?? '')?.toLocal(),
      distanciaM: (json['distancia_m'] as num?)?.toDouble(),
    );
  }
}
