// Victoria en Cristo — estilo «papel recortado» para Flutter.
// Colores, letras, sombras y el ThemeData listo para usar.
// Requiere las fuentes declaradas en pubspec.yaml (ver pubspec_fragmento.yaml).

import 'package:flutter/material.dart';

/// Los tonos de una hoja del kit: papel claro (crema y tinta café) o uno de
/// los papeles oscuros (kraft oscuro o noche azul, con tinta crema). Se invierten los papeles: lo que en
/// claro es «papel» (tarjetas y texto sobre chips de color) en oscuro es café,
/// y la «tinta» es crema. Los acentos se aclaran para leerse sobre café.
class VecPaleta {
  const VecPaleta({
    required this.oscura,
    required this.papel,
    required this.crema,
    required this.cremaOscuro,
    required this.kraft,
    required this.papelTexturado,
    required this.tinta,
    required this.lapiz,
    required this.gris,
    required this.terracota,
    required this.azul,
    required this.azulClaro,
    required this.mostaza,
    required this.mostazaClaro,
    required this.verde,
    required this.noche,
    required this.rosa,
    required this.salvia,
  });

  final bool oscura;
  final Color papel; // tarjetas, globos, bordes de sticker
  final Color crema; // fondo general
  final Color cremaOscuro; // casillas apagadas, separadores
  final Color kraft;
  // Lo que de verdad se ve detrás del texto en el fondo con textura. Solo
  // para calcular colores de texto legibles, no para pintar.
  final Color papelTexturado;
  final Color tinta; // texto principal
  final Color lapiz; // contornos
  final Color gris; // texto secundario
  final Color terracota; // principal: palabras clave, Victoria
  final Color azul; // Timoteo
  final Color azulClaro;
  final Color mostaza; // cinta, cruz, estrellas
  final Color mostazaClaro;
  final Color verde; // confirmaciones
  final Color noche;
  final Color rosa;
  final Color salvia;

  /// Papel crema. Terracota, gris y verde van un poco más oscuros que en el
  /// kit (#c8553d, #8a7a64, #2f7f7a) para llegar a contraste 4.5:1 sobre el
  /// papel con textura. papelTexturado: la textura a media opacidad sobre el
  /// crema (#EDE4D4), un poco más oscuro por las manchas.
  static const claro = VecPaleta(
    oscura: false,
    papel: Color(0xFFFBF7EE),
    crema: Color(0xFFF3ECDF),
    cremaOscuro: Color(0xFFEFE6D6),
    kraft: Color(0xFFB98F5E),
    papelTexturado: Color(0xFFEAE1D0),
    tinta: Color(0xFF2B2622),
    lapiz: Color(0xFF3A332C),
    gris: Color(0xFF6F6150),
    terracota: Color(0xFFA8452F),
    azul: Color(0xFF3D6890),
    azulClaro: Color(0xFF4F7FA8),
    mostaza: Color(0xFFE0A73A),
    mostazaClaro: Color(0xFFEFC56A),
    verde: Color(0xFF276F6A),
    noche: Color(0xFF2F4A68),
    rosa: Color(0xFFF1A9A0),
    salvia: Color(0xFF9DBB8E),
  );

  /// Kraft oscuro (propuesta B). Todo el texto pasa
  /// de 4.5:1 sobre la hoja y las tarjetas; papelTexturado es la textura
  /// teñida del café encima (ver FondoPapel), un poco más oscura.
  static const kraftOscuro = VecPaleta(
    oscura: true,
    papel: Color(0xFF3A2E24),
    crema: Color(0xFF2A2119),
    cremaOscuro: Color(0xFF4A3B2F),
    kraft: Color(0xFF8C6A45),
    papelTexturado: Color(0xFF261E17),
    tinta: Color(0xFFF3ECDF),
    lapiz: Color(0xFFE8DFD0),
    gris: Color(0xFFD0BEA2),
    terracota: Color(0xFFEF9274),
    azul: Color(0xFF9CBDE0),
    azulClaro: Color(0xFFB3CDE8),
    mostaza: Color(0xFFE0A73A),
    mostazaClaro: Color(0xFFEFC56A),
    verde: Color(0xFF7CCABE),
    noche: Color(0xFFA9C6E8),
    rosa: Color(0xFFF1A9A0),
    salvia: Color(0xFF9DBB8E),
  );

  /// Noche azul (propuesta A): el mismo papel oscuro sobre azul de noche.
  static const nocheAzul = VecPaleta(
    oscura: true,
    papel: Color(0xFF2A3545),
    crema: Color(0xFF1D2633),
    cremaOscuro: Color(0xFF3A475A),
    kraft: Color(0xFF8A7660),
    papelTexturado: Color(0xFF1B232F),
    tinta: Color(0xFFF3ECDF),
    lapiz: Color(0xFFE8DFD0),
    gris: Color(0xFFC7BBA8),
    terracota: Color(0xFFEC8D73),
    azul: Color(0xFF8DB4DA),
    azulClaro: Color(0xFFA6C5E4),
    mostaza: Color(0xFFE0A73A),
    mostazaClaro: Color(0xFFEFC56A),
    verde: Color(0xFF6CC3B8),
    noche: Color(0xFF9CC3EA),
    rosa: Color(0xFFF1A9A0),
    salvia: Color(0xFF9DBB8E),
  );
}

/// Paleta del modo activo. Nunca uses blanco ni negro puros. Cambia con
/// [actual], que pone ThemeService al elegir el tema; para algo que siempre
/// debe ir en claro (p. ej. el PDF) usa [VecPaleta.claro].
class VecColores {
  VecColores._();

  /// El papel activo. Después de cambiarlo hay que volver a construir la app
  /// (ver ThemeService), porque estos colores no avisan.
  static VecPaleta actual = VecPaleta.claro;
  static bool get oscuro => actual.oscura;

  // papel
  static Color get papel => actual.papel;
  static Color get crema => actual.crema;
  static Color get cremaOscuro => actual.cremaOscuro;
  static Color get kraft => actual.kraft;
  static Color get papelTexturado => actual.papelTexturado;

  // tinta
  static Color get tinta => actual.tinta;
  static Color get lapiz => actual.lapiz;
  static Color get gris => actual.gris;

  // acentos
  static Color get terracota => actual.terracota;
  static Color get azul => actual.azul;
  static Color get azulClaro => actual.azulClaro;
  static Color get mostaza => actual.mostaza;
  static Color get mostazaClaro => actual.mostazaClaro;
  static Color get verde => actual.verde;
  static Color get noche => actual.noche;
  static Color get rosa => actual.rosa;
  static Color get salvia => actual.salvia;
}

/// Papel o tinta, el que más se lea sobre [fondo]. En claro el papel va sobre
/// terracota y la tinta sobre mostaza; en oscuro el «papel» es café y va sobre
/// todos los acentos.
Color textoSobre(Color fondo) {
  double contraste(Color a) {
    final (x, y) = (a.computeLuminance(), fondo.computeLuminance());
    return ((x > y ? x : y) + 0.05) / ((x > y ? y : x) + 0.05);
  }

  return contraste(VecColores.papel) >= contraste(VecColores.tinta) ? VecColores.papel : VecColores.tinta;
}

/// Las tres letras del estilo.
class VecFuentes {
  VecFuentes._();
  static const titulo = 'LilitaOne'; // títulos, botones, chips, etiquetas
  static const texto = 'PatrickHand'; // texto corrido, versículos
  static const mano = 'CaveatBrush'; // notas a mano, cartas
}

/// Sombras: una sólida hacia abajo (papel grueso) + una difusa cálida. En los
/// papeles oscuros la tinta café no se notaría: van en negro, más opacas.
class VecSombras {
  VecSombras._();

  static List<BoxShadow> get papel => VecColores.oscuro ? _papelOscuro : _papelClaro;
  static List<BoxShadow> get chip => VecColores.oscuro ? _chipOscuro : _chipClaro;
  static List<BoxShadow> get presionado => VecColores.oscuro ? _presionadoOscuro : _presionadoClaro;

  static const _papelClaro = [
    BoxShadow(color: Color(0x2E2B2622), offset: Offset(0, 9), blurRadius: 0),
    BoxShadow(color: Color(0x384A3016), offset: Offset(0, 16), blurRadius: 26),
  ];
  static const _chipClaro = [
    BoxShadow(color: Color(0x472B2622), offset: Offset(0, 8), blurRadius: 0),
  ];
  static const _presionadoClaro = [
    BoxShadow(color: Color(0x472B2622), offset: Offset(0, 3), blurRadius: 0),
  ];
  static const _papelOscuro = [
    BoxShadow(color: Color(0x59000000), offset: Offset(0, 9), blurRadius: 0),
    BoxShadow(color: Color(0x40000000), offset: Offset(0, 16), blurRadius: 26),
  ];
  static const _chipOscuro = [
    BoxShadow(color: Color(0x73000000), offset: Offset(0, 8), blurRadius: 0),
  ];
  static const _presionadoOscuro = [
    BoxShadow(color: Color(0x73000000), offset: Offset(0, 3), blurRadius: 0),
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
  final base = TextStyle(fontFamily: VecFuentes.texto, color: VecColores.tinta);
  final titulo = TextStyle(fontFamily: VecFuentes.titulo, color: VecColores.tinta, height: 1.05);
  return ThemeData(
    useMaterial3: true,
    brightness: VecColores.oscuro ? Brightness.dark : Brightness.light,
    scaffoldBackgroundColor: VecColores.crema,
    colorScheme: ColorScheme.fromSeed(
      brightness: VecColores.oscuro ? Brightness.dark : Brightness.light,
      seedColor: VecColores.terracota,
      primary: VecColores.terracota,
      secondary: VecColores.verde,
      tertiary: VecColores.mostaza,
      onPrimary: textoSobre(VecColores.terracota),
      onSecondary: textoSobre(VecColores.verde),
      onTertiary: textoSobre(VecColores.mostaza),
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
        borderSide: BorderSide(color: VecColores.tinta, width: 4),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VecRadios.s),
        borderSide: BorderSide(color: VecColores.terracota, width: 4),
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
