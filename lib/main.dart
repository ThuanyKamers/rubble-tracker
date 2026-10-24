import 'package:flutter/material.dart';

import 'screens/login_tela.dart';
import 'screens/mapa_tela.dart';
import 'services/sessao.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logado = await Sessao.carregar();
  runApp(CidadeLimpaApp(logado: logado));
}

class CidadeLimpaApp extends StatelessWidget {
  final bool logado;

  const CidadeLimpaApp({super.key, this.logado = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cidade Limpa',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: logado ? const MapaTela() : const LoginTela(),
    );
  }
}
