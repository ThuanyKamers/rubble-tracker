import 'package:flutter/material.dart';

import '../theme.dart';

// Alinhamento do Marker para a ponta do alfinete (que fica um pouco acima
// da base do ícone) cair exatamente no ponto registrado.
const alinhamentoPino = Alignment(0, -0.82);

// Alfinete de entulho no mapa.
// Use com Marker(alignment: alinhamentoPino, width: 48, height: 56).
class PinoEntulho extends StatelessWidget {
  final int confirmacoes;
  final bool selecionado;

  const PinoEntulho({super.key, this.confirmacoes = 1, this.selecionado = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: selecionado ? 1.2 : 1,
      alignment: Alignment.bottomCenter,
      duration: const Duration(milliseconds: 180),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          const Icon(
            Icons.location_on,
            size: 56,
            color: Cores.entulho,
            shadows: [Shadow(color: Colors.black38, blurRadius: 6, offset: Offset(0, 2))],
          ),
          Positioned(
            top: 9,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: const Icon(Icons.delete_outline_rounded, size: 18, color: Cores.entulho),
            ),
          ),
          if (confirmacoes > 1)
            Positioned(
              right: -2,
              top: 0,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Cores.alerta,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(
                  '$confirmacoes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Ponto azul da posição do usuário.
class PontoUsuario extends StatelessWidget {
  const PontoUsuario({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Cores.azul.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      padding: const EdgeInsets.all(5),
      child: Container(
        decoration: BoxDecoration(
          color: Cores.azul,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
        ),
      ),
    );
  }
}
