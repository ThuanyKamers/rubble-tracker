import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import 'login_tela.dart';

// Apresentação curta mostrada só na primeira vez que o app é aberto.
class IntroducaoTela extends StatefulWidget {
  static const _chave = 'viu_introducao';

  const IntroducaoTela({super.key});

  static Future<bool> jaViu() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_chave) ?? false;
  }

  @override
  State<IntroducaoTela> createState() => _IntroducaoTelaState();
}

class _IntroducaoTelaState extends State<IntroducaoTela> {
  final _paginas = PageController();
  int _atual = 0;

  static const _slides = [
    (
      icone: Icons.photo_camera_rounded,
      titulo: 'Viu entulho na rua?',
      texto: 'Tire ou escolha até 3 fotos e conte um ponto de referência, '
          'como "na frente da loja de 10".',
    ),
    (
      icone: Icons.location_on_rounded,
      titulo: 'Marcado no ponto exato',
      texto: 'O GPS coloca o alfinete exatamente onde você está. Se alguém já '
          'registrou o mesmo entulho, o app percebe e não duplica.',
    ),
    (
      icone: Icons.local_shipping_rounded,
      titulo: 'A prefeitura recolhe',
      texto: 'A equipe de coleta vê todos os pontos no mapa, traça a rota '
          'e marca como recolhido. Palhoça mais limpa!',
    ),
  ];

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _concluir() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(IntroducaoTela._chave, true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginTela()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ultima = _atual == _slides.length - 1;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: AnimatedOpacity(
                opacity: ultima ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                child: TextButton(onPressed: ultima ? null : _concluir, child: const Text('Pular')),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _paginas,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _atual = i),
                itemBuilder: (context, i) {
                  final s = _slides[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 180,
                          height: 180,
                          decoration: const BoxDecoration(
                            color: Cores.verdeClaro,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(s.icone, size: 90, color: Cores.verde),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          s.titulo,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Cores.texto,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.texto,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Cores.textoSuave, height: 1.45),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_slides.length, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _atual ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _atual ? Cores.verde : const Color(0xFFD5E0DA),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                onPressed: ultima
                    ? _concluir
                    : () => _paginas.nextPage(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                        ),
                child: Text(ultima ? 'Começar' : 'Próximo'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
