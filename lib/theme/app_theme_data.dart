import 'package:flutter/material.dart';

import '../vec/vec_tema.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// APP THEME DATA — los tres papeles de la app
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Estilo «papel recortado» del kit victoria-en-cristo-estilo (lib/vec): el
/// papel claro y dos papeles oscuros (kraft y noche). Los colores del kit
/// (VecColores) siguen al papel activo; aquí van los colores con nombre de
/// interfaz (fondo, tarjetas, texto, acento) para toda la app.
///
/// Uso: final t = AppThemeData.of(context);
///      Scaffold(backgroundColor: t.pageBg, ...)
/// ═══════════════════════════════════════════════════════════════════════════

class AppThemeData {
  final String id;
  final String name;
  final Color scaffoldBg;
  final Color surface; // barras, encabezados
  final Color cardBg;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent; // terracota
  final Color accentSoft; // acento al 15 %, para fondos suaves
  final Color divider;
  final Color inputBg; // campos de texto, buscadores

  /// El papel del kit: claro, kraft oscuro o noche azul.
  final VecPaleta paleta;

  /// Tema «papel recortado» con la [paleta] que se le dé.
  AppThemeData._papel(this.paleta, {required this.id, required this.name})
    : scaffoldBg = paleta.crema,
      surface = paleta.papel,
      cardBg = paleta.papel,
      cardBorder = paleta.cremaOscuro,
      textPrimary = paleta.tinta,
      // El texto secundario de toda la app necesita ≥ 4.5:1 (WCAG AA) sobre
      // el papel con textura, así que usa el lápiz del kit en vez del gris.
      textSecondary = paleta.lapiz,
      accent = paleta.terracota,
      accentSoft = paleta.terracota.withValues(alpha: 0.15),
      divider = paleta.cremaOscuro,
      inputBg = paleta.papel;

  /// Si la pantalla se ve oscura (papeles kraft y noche).
  bool get oscuro => paleta.oscura;

  /// Texto o ícono sobre un relleno de [accent]: papel o tinta, el que más se
  /// lea (en los papeles oscuros el acento es claro).
  Color get sobreAcento => textoSobre(accent);

  /// Fondo para `Scaffold.backgroundColor`: transparente, porque cada página
  /// pinta el papel con textura (FondoPapel) por detrás.
  Color get pageBg => Colors.transparent;

  /// El color que se ve detrás del texto de la página, para calcular colores
  /// legibles (`legibleSobre`): el tono de la textura, más oscuro que
  /// [scaffoldBg] en el papel claro.
  Color get fondoVisible => paleta.papelTexturado;

  // Helpers derivados
  Color get overlayBg => oscuro
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.04);

  Color get shimmerBase => oscuro
      ? Colors.white.withValues(alpha: 0.05)
      : Colors.black.withValues(alpha: 0.04);

  Color get shimmerHighlight => oscuro
      ? Colors.white.withValues(alpha: 0.1)
      : Colors.black.withValues(alpha: 0.08);

  /// Sin degradado en los encabezados: se ve la hoja con textura.
  LinearGradient get headerGradient => const LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Colors.transparent],
  );

  /// Sombra de papel grueso del kit.
  List<BoxShadow> get cardShadow => VecSombras.papel;

  /// Tarjeta de papel: sin contorno, solo sombra sólida y cálida.
  BoxDecoration get cardDecoration => BoxDecoration(
    color: cardBg,
    borderRadius: BorderRadius.circular(VecRadios.m),
    boxShadow: cardShadow,
  );

  // ══════════════════════════════════════════════════════════════════════════
  // TEMAS — los tres papeles del kit (mismos ids que BibleReaderThemeData)
  // ══════════════════════════════════════════════════════════════════════════

  // ─── PAPER THEME ───────────────────────────────────────────────────────

  /// Estilo «papel recortado» de los videos (kit victoria-en-cristo-estilo).
  static final paper = AppThemeData._papel(
    VecPaleta.claro,
    id: 'papel',
    name: 'Papel recortado',
  );

  /// Papel oscuro café (kraft), mismo kit con tinta crema.
  static final paperKraft = AppThemeData._papel(
    VecPaleta.kraftOscuro,
    id: 'papel_kraft',
    name: 'Papel kraft',
  );

  /// Papel oscuro azul de noche.
  static final paperNoche = AppThemeData._papel(
    VecPaleta.nocheAzul,
    id: 'papel_noche',
    name: 'Papel noche',
  );

  /// Todos los temas disponibles
  static final List<AppThemeData> all = [paper, paperKraft, paperNoche];

  /// Obtener tema por ID (por defecto, el papel claro)
  static AppThemeData fromId(String id) {
    return all.firstWhere((t) => t.id == id, orElse: () => paper);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INHERITED WIDGET — Acceso via AppThemeData.of(context)
  // ══════════════════════════════════════════════════════════════════════════

  static AppThemeData of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<_AppThemeInherited>();
    return inherited?.theme ?? paper;
  }

  /// Wrap your MaterialApp's child with this to provide the theme
  static Widget provider({required AppThemeData theme, required Widget child}) {
    return _AppThemeInherited(theme: theme, child: child);
  }
}

class _AppThemeInherited extends InheritedWidget {
  final AppThemeData theme;

  const _AppThemeInherited({required this.theme, required super.child});

  @override
  bool updateShouldNotify(_AppThemeInherited oldWidget) {
    return theme.id != oldWidget.theme.id;
  }
}
