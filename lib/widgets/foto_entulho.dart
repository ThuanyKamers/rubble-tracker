import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

// Mostra uma foto vinda do servidor (URL), de um registro antigo (base64)
// ou do próprio celular (caminho de arquivo).
class FotoEntulho extends StatelessWidget {
  final String caminho;
  final BoxFit fit;

  const FotoEntulho(this.caminho, {super.key, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    const quebrada = Center(child: Icon(Icons.broken_image, size: 40, color: Colors.grey));

    if (caminho.isEmpty) {
      return const Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey));
    }
    if (caminho.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(caminho.split(',').last),
          fit: fit,
          errorBuilder: (_, _, _) => quebrada,
        );
      } catch (_) {
        return quebrada;
      }
    }
    if (caminho.startsWith('http')) {
      return Image.network(
        caminho,
        fit: fit,
        errorBuilder: (_, _, _) => quebrada,
        frameBuilder: (context, child, frame, sincrono) => sincrono
            ? child
            : AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 250),
                child: child,
              ),
        loadingBuilder: (context, child, progresso) => progresso == null
            ? child
            : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return Image.file(File(caminho), fit: fit, errorBuilder: (_, _, _) => quebrada);
  }
}

void abrirFotoEmTelaCheia(BuildContext context, String caminho) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: Hero(tag: caminho, child: FotoEntulho(caminho, fit: BoxFit.contain)),
          ),
        ),
      ),
    ),
  );
}
