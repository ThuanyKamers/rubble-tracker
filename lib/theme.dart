import 'package:flutter/material.dart';

// Cores e estilos do app em um lugar só, para as telas ficarem consistentes.
class Cores {
  static const verde = Color(0xFF1B8A4B);
  static const verdeEscuro = Color(0xFF0F5E32);
  static const verdeClaro = Color(0xFFE6F4EC);
  static const entulho = Color(0xFFE5533D);
  static const alerta = Color(0xFFF2994A);
  static const azul = Color(0xFF2F80ED);
  static const fundo = Color(0xFFF5F7F6);
  static const texto = Color(0xFF1D2A23);
  static const textoSuave = Color(0xFF6B7A72);
}

ThemeData temaDoApp() {
  final esquema = ColorScheme.fromSeed(
    seedColor: Cores.verde,
    primary: Cores.verde,
    surface: Colors.white,
  );
  final bordaCampo = OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide.none,
  );

  return ThemeData(
    colorScheme: esquema,
    scaffoldBackgroundColor: Cores.fundo,
    appBarTheme: const AppBarTheme(
      backgroundColor: Cores.fundo,
      foregroundColor: Cores.texto,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Cores.texto),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: bordaCampo,
      enabledBorder: bordaCampo.copyWith(
        borderSide: const BorderSide(color: Color(0xFFE1E7E3)),
      ),
      focusedBorder: bordaCampo.copyWith(
        borderSide: const BorderSide(color: Cores.verde, width: 2),
      ),
      errorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: esquema.error),
      ),
      focusedErrorBorder: bordaCampo.copyWith(
        borderSide: BorderSide(color: esquema.error, width: 2),
      ),
      prefixIconColor: Cores.textoSuave,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Cores.verde,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFB9C7BF),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Cores.verde,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: Cores.verde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Cores.verde,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: Cores.verde,
      foregroundColor: Colors.white,
      extendedTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentTextStyle: const TextStyle(fontSize: 15),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE6ECE8)),
      ),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      },
    ),
  );
}

// Mensagens rápidas no rodapé, com ícone e cor por tipo.
enum TipoAviso { sucesso, erro, info }

void mostrarAviso(BuildContext context, String texto, {TipoAviso tipo = TipoAviso.info}) {
  final (cor, icone) = switch (tipo) {
    TipoAviso.sucesso => (Cores.verde, Icons.check_circle_rounded),
    TipoAviso.erro => (const Color(0xFFD64545), Icons.error_rounded),
    TipoAviso.info => (const Color(0xFF34413A), Icons.info_rounded),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: cor,
      content: Row(
        children: [
          Icon(icone, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(child: Text(texto)),
        ],
      ),
    ));
}

// Indicador de carregamento pequeno para usar dentro de botões.
class CarregandoBotao extends StatelessWidget {
  const CarregandoBotao({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
      );
}
