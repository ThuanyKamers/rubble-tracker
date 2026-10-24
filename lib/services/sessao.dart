import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/usuario.dart';

// Guarda o login no aparelho para o usuário não precisar entrar toda vez.
class Sessao {
  static String? token;
  static Usuario? usuario;

  static Future<bool> carregar() async {
    final prefs = await SharedPreferences.getInstance();
    final t = prefs.getString('token');
    final u = prefs.getString('usuario');
    if (t == null || u == null) return false;
    token = t;
    usuario = Usuario.fromJson(jsonDecode(u) as Map<String, dynamic>);
    return true;
  }

  static Future<void> salvar(String novoToken, Usuario novoUsuario) async {
    token = novoToken;
    usuario = novoUsuario;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', novoToken);
    await prefs.setString('usuario', jsonEncode(novoUsuario.toJson()));
  }

  static Future<void> sair() async {
    token = null;
    usuario = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('usuario');
  }
}
