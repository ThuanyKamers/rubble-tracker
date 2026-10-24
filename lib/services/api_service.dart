import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../config.dart';
import '../models/denuncia.dart';
import '../models/usuario.dart';
import 'sessao.dart';

class ApiException implements Exception {
  final int status;
  final String mensagem;
  final String? codigo;
  final Map<String, dynamic> dados;

  ApiException(this.status, this.mensagem, {this.codigo, this.dados = const {}});

  bool get sessaoExpirada => status == 401;
  bool get contaBloqueada => codigo == 'CONTA_BLOQUEADA';
  bool get limiteDeRegistros => codigo == 'LIMITE_REGISTROS';

  @override
  String toString() => mensagem;
}

class ResultadoRegistro {
  // true quando o entulho já existia e o registro virou uma confirmação.
  final bool duplicada;
  final Denuncia denuncia;

  ResultadoRegistro(this.duplicada, this.denuncia);
}

class ApiService {
  static const _timeout = Duration(seconds: 30);

  static Map<String, String> get _headers => {
    if (Sessao.token != null) 'Authorization': 'Bearer ${Sessao.token}',
  };

  static dynamic _tratar(http.Response response) {
    dynamic corpo;
    try {
      corpo = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      corpo = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return corpo;

    final mapa = corpo is Map<String, dynamic> ? corpo : <String, dynamic>{};
    throw ApiException(
      response.statusCode,
      (mapa['error'] as String?) ?? 'Erro ${response.statusCode} no servidor.',
      codigo: mapa['codigo'] as String?,
      dados: mapa,
    );
  }

  static Future<T> _comConexao<T>(Future<T> Function() chamada) async {
    try {
      return await chamada();
    } on SocketException {
      throw ApiException(0, 'Sem conexão com o servidor. Verifique sua internet.');
    } on TimeoutException {
      throw ApiException(0, 'O servidor demorou para responder. Tente de novo.');
    }
  }

  // ------------------------------------------------------------ Contas

  static Future<Usuario> login(String cpf, String senha) =>
      _entrar('/auth/login', {'cpf': cpf, 'senha': senha});

  static Future<Usuario> cadastrar(String nome, String cpf, String senha) =>
      _entrar('/auth/cadastro', {'nome': nome, 'cpf': cpf, 'senha': senha});

  static Future<Usuario> _entrar(String rota, Map<String, String> dados) => _comConexao(() async {
    final response = await http
        .post(
          Uri.parse('$apiUrl$rota'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(dados),
        )
        .timeout(_timeout);
    final corpo = _tratar(response) as Map<String, dynamic>;
    final usuario = Usuario.fromJson(corpo['usuario'] as Map<String, dynamic>);
    await Sessao.salvar(corpo['token'] as String, usuario);
    return usuario;
  });

  // ---------------------------------------------------------- Entulhos

  static Future<List<Denuncia>> fetchDenuncias({
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
    String status = 'ativo',
  }) => _comConexao(() async {
    final url = Uri.parse('$apiUrl/denuncias').replace(
      queryParameters: {
        'status': status,
        if (minLat != null && maxLat != null && minLng != null && maxLng != null) ...{
          'minLat': '$minLat',
          'maxLat': '$maxLat',
          'minLng': '$minLng',
          'maxLng': '$maxLng',
        },
      },
    );
    final response = await http.get(url, headers: _headers).timeout(_timeout);
    final lista = _tratar(response) as List;
    return lista.map((e) => Denuncia.fromJson(e as Map<String, dynamic>)).toList();
  });

  // Registra um entulho. Se já houver um muito perto, lança ApiException com
  // codigo ENTULHO_PROXIMO e a lista em dados['candidatos'].
  static Future<ResultadoRegistro> criarDenuncia({
    required Position posicao,
    required String pontoReferencia,
    required List<XFile> fotos,
    bool forcarNovo = false,
  }) => _enviarRegistro('/denuncias', posicao, pontoReferencia, fotos, forcarNovo: forcarNovo);

  // O cidadão confirmou que é o mesmo entulho de um registro próximo.
  static Future<ResultadoRegistro> confirmarDenuncia({
    required int denunciaId,
    required Position posicao,
    required String pontoReferencia,
    required List<XFile> fotos,
  }) => _enviarRegistro('/denuncias/$denunciaId/confirmar', posicao, pontoReferencia, fotos);

  static Future<ResultadoRegistro> _enviarRegistro(
    String rota,
    Position posicao,
    String pontoReferencia,
    List<XFile> fotos, {
    bool forcarNovo = false,
  }) => _comConexao(() async {
    final request = http.MultipartRequest('POST', Uri.parse('$apiUrl$rota'))
      ..headers.addAll(_headers)
      ..fields['latitude'] = posicao.latitude.toString()
      ..fields['longitude'] = posicao.longitude.toString()
      ..fields['precisao_m'] = posicao.accuracy.toString()
      ..fields['ponto_referencia'] = pontoReferencia
      ..fields['forcar_novo'] = forcarNovo.toString();

    for (final foto in fotos) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'fotos',
          await foto.readAsBytes(),
          filename: foto.name.isEmpty ? 'foto.jpg' : foto.name,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    final response = await http.Response.fromStream(
      await request.send().timeout(const Duration(seconds: 90)),
    );
    final corpo = _tratar(response) as Map<String, dynamic>;
    return ResultadoRegistro(
      corpo['duplicada'] == true,
      Denuncia.fromJson(corpo['denuncia'] as Map<String, dynamic>),
    );
  });

  // O trabalhador não encontrou entulho no local: o registro era falso.
  // Devolve true quando a conta de quem registrou acabou de ser bloqueada.
  static Future<bool> descartarDenuncia(int id) => _comConexao(() async {
    final response = await http
        .patch(Uri.parse('$apiUrl/denuncias/$id/descartar'), headers: _headers)
        .timeout(_timeout);
    final corpo = _tratar(response) as Map<String, dynamic>;
    return corpo['autor_bloqueado'] == true;
  });

  static Future<Denuncia> marcarRecolhido(int id) => _comConexao(() async {
    final response = await http
        .patch(Uri.parse('$apiUrl/denuncias/$id/recolher'), headers: _headers)
        .timeout(_timeout);
    return Denuncia.fromJson(_tratar(response) as Map<String, dynamic>);
  });
}
