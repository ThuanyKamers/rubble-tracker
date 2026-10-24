import 'package:flutter/material.dart';

import '../theme.dart';

// Fundo verde com o logo no topo e um painel branco com o formulário.
// Usado nas telas de login e cadastro.
class LayoutEntrada extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final Widget child;
  final bool mostrarVoltar;

  const LayoutEntrada({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.child,
    this.mostrarVoltar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Cores.verdeEscuro,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Cores.verde, Cores.verdeEscuro],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (mostrarVoltar)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                            onPressed: () => Navigator.maybePop(context),
                          ),
                        )
                      else
                        const SizedBox(height: 32),
                      const _Logo(),
                      const SizedBox(height: 28),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            24,
                            28,
                            24,
                            24 + MediaQuery.paddingOf(context).bottom,
                          ),
                          decoration: const BoxDecoration(
                            color: Cores.fundo,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                titulo,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Cores.texto,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitulo,
                                style: const TextStyle(fontSize: 15, color: Cores.textoSuave),
                              ),
                              const SizedBox(height: 24),
                              child,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8)),
            ],
          ),
          child: const Icon(Icons.recycling_rounded, size: 48, color: Cores.verde),
        ),
        const SizedBox(height: 16),
        const Text(
          'Cidade Limpa',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Palhoça sem entulho nas ruas',
          style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.85)),
        ),
      ],
    );
  }
}
