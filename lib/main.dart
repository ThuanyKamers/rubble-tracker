import 'package:flutter/material.dart';

import 'screens/introducao_tela.dart';
import 'screens/login_tela.dart';
import 'screens/mapa_tela.dart';
import 'services/sessao.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final logado = await Sessao.carregar();
  final viuIntroducao = await IntroducaoTela.jaViu();
  runApp(CidadeLimpaApp(logado: logado, viuIntroducao: viuIntroducao));
}

class CidadeLimpaApp extends StatelessWidget {
  final bool logado;
  final bool viuIntroducao;

  const CidadeLimpaApp({super.key, this.logado = false, this.viuIntroducao = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cidade Limpa',
      debugShowCheckedModeBanner: false,
      theme: temaDoApp(),
      home: logado
          ? const MapaTela()
          : viuIntroducao
              ? const LoginTela()
              : const IntroducaoTela(),
    );
  }
}
