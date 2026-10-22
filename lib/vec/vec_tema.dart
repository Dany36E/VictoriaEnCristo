// Victoria en Cristo — estilo «papel recortado» para Flutter.
// Colores, letras, sombras y el ThemeData listo para usar.
// Requiere las fuentes declaradas en pubspec.yaml (ver pubspec_fragmento.yaml).

import 'package:flutter/material.dart';

/// Paleta oficial. Nunca uses blanco ni negro puros: el papel es crema y la tinta es café oscuro.
class VecColores {
  VecColores._();

  // papel
  static const papel = Color(0xFFFBF7EE); // tarjetas, globos, bordes de sticker
  static const crema = Color(0xFFF3ECDF); // fondo general
  static const cremaOscuro = Color(0xFFEFE6D6); // casillas apagadas, separadores
  static const kraft = Color(0xFFB98F5E);
  // Lo que de verdad se ve detrás del texto en el fondo con textura: el
  // promedio de la textura a media opacidad sobre el crema (#EDE4D4), un poco
  // más oscuro para que las manchas no le quiten contraste. Solo para
  // calcular colores de texto legibles, no para pintar.
  static const papelTexturado = Color(0xFFEAE1D0);

  // tinta
  static const tinta = Color(0xFF2B2622); // texto principal
  static const lapiz = Color(0xFF3A332C); // contornos
  // El kit usa #8a7a64, #c8553d y #2f7f7a; aquí van un poco más oscuros para
  // que el texto llegue a contraste 4.5:1 (WCAG AA) sobre el papel con
  // textura.
  static const gris = Color(0xFF6F6150); // texto secundario

  // acentos
  static const terracota = Color(0xFFA8452F); // principal: palabras clave, Victoria
  static const azul = Color(0xFF3D6890); // Timoteo
  static const azulClaro = Color(0xFF4F7FA8);
  static const mostaza = Color(0xFFE0A73A); // cinta, cruz, estrellas
  static const mostazaClaro = Color(0xFFEFC56A);
  static const verde = Color(0xFF276F6A); // confirmaciones (kit: #2f7f7a)
  static const noche = Color(0xFF2F4A68);
  static const rosa = Color(0xFFF1A9A0);
  static const salvia = Color(0xFF9DBB8E);
}

/// Las tres letras del estilo.
class VecFuentes {
  VecFuentes._();
  static const titulo = 'LilitaOne'; // títulos, botones, chips, etiquetas
  static const texto = 'PatrickHand'; // texto corrido, versículos
  static const mano = 'CaveatBrush'; // notas a mano, cartas
}

/// Sombras: una sólida hacia abajo (papel grueso) + una difusa cálida.
class VecSombras {
  VecSombras._();

  static const papel = [
    BoxShadow(color: Color(0x2E2B2622), offset: Offset(0, 9), blurRadius: 0),
    BoxShadow(color: Color(0x384A3016), offset: Offset(0, 16), blurRadius: 26),
  ];
  static const chip = [
    BoxShadow(color: Color(0x472B2622), offset: Offset(0, 8), blurRadius: 0),
  ];
  static const presionado = [
    BoxShadow(color: Color(0x472B2622), offset: Offset(0, 3), blurRadius: 0),
  ];
  static const brillo = [
    BoxShadow(color: Color(0x8CFFD68C), spreadRadius: 8, blurRadius: 0),
    BoxShadow(color: Color(0x8CFFC86E), spreadRadius: 18, blurRadius: 60),
  ];
}

class VecRadios {
  VecRadios._();
  static const s = 10.0;
  static const m = 14.0;
  static const l = 22.0;
  static const pildora = 999.0;
}

/// Movimiento: entra con rebote (como back.out) en ~0.4 s.
class VecMovimiento {
  VecMovimiento._();
  static const duracion = Duration(milliseconds: 420);
  // Igual que --vec-rebote del CSS: cubic-bezier(.34, 1.56, .64, 1).
  static const rebote = Cubic(0.34, 1.56, 0.64, 1);
}

/// Tema de Material listo para MaterialApp(theme: vecTema()).
ThemeData vecTema() {
  const base = TextStyle(fontFamily: VecFuentes.texto, color: VecColores.tinta);
  const titulo = TextStyle(fontFamily: VecFuentes.titulo, color: VecColores.tinta, height: 1.05);
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: VecColores.crema,
    colorScheme: ColorScheme.fromSeed(
      seedColor: VecColores.terracota,
      primary: VecColores.terracota,
      secondary: VecColores.verde,
      tertiary: VecColores.mostaza,
      surface: VecColores.papel,
      onSurface: VecColores.tinta,
    ),
    fontFamily: VecFuentes.texto,
    textTheme: TextTheme(
      displayLarge: titulo.copyWith(fontSize: 44),
      headlineMedium: titulo.copyWith(fontSize: 30),
      titleLarge: titulo.copyWith(fontSize: 22),
      titleMedium: titulo.copyWith(fontSize: 18),
      bodyLarge: base.copyWith(fontSize: 20, height: 1.3),
      bodyMedium: base.copyWith(fontSize: 17, height: 1.3),
      labelLarge: titulo.copyWith(fontSize: 18),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VecColores.papel,
      hintStyle: base.copyWith(color: VecColores.gris, fontSize: 18),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VecRadios.s),
        borderSide: const BorderSide(color: VecColores.tinta, width: 4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VecRadios.s),
        borderSide: const BorderSide(color: VecColores.terracota, width: 4),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(VecColores.papel),
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? VecColores.verde : VecColores.cremaOscuro,
      ),
      trackOutlineColor: WidgetStateProperty.all(VecColores.tinta),
    ),
  );
}
