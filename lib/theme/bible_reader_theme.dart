import 'package:flutter/material.dart';

import '../vec/vec_tema.dart';
import 'contraste.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE READER THEME - 10 temas editoriales premium
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Cada tema define una paleta completa para el lector:
/// bg, surface, textPrimary, textSecondary, accent, verseNumber, toolbar.
///
/// Se aplica via BibleReaderThemeData.fromId(themeId).
/// ═══════════════════════════════════════════════════════════════════════════

class BibleReaderThemeData {
  final String id;
  final String name;
  final Color background;
  final Color surface;       // toolbar, sheets
  final Color textPrimary;
  final Color textSecondary; // verse numbers, subtle UI
  final Color accent;        // #D4AF37 family
  final Color toolbarBg;
  /// Fondo oscuro con texto claro, para elegir caminos de dibujo. Los temas
  /// papel dicen false aunque su papel sea oscuro: todos siguen el camino del
  /// papel claro y sus colores cambian solos (VecColores). Para saber si la
  /// pantalla de verdad es oscura (barras del sistema, sombras) usa [oscuro].
  final bool isDark;

  /// Papel del kit si es un tema papel (claro, kraft oscuro o noche azul).
  final VecPaleta? paleta;

  const BibleReaderThemeData({
    required this.id,
    required this.name,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.toolbarBg,
    required this.isDark,
    this.paleta,
  });

  /// Tema «papel recortado» con la [paleta] que se le dé.
  BibleReaderThemeData._papel(VecPaleta p, {required this.id, required this.name})
      : paleta = p,
        background = p.crema,
        surface = p.papel,
        textPrimary = p.tinta,
        // En claro, un poco más oscuro que el gris del kit para que los
        // textos chicos del lector se lean bien sobre el papel (5.8:1 sobre
        // crema). En oscuro el gris ya pasa de 4.5 en todas las superficies.
        textSecondary = p.oscura ? p.gris : const Color(0xFF66584A),
        accent = p.terracota,
        toolbarBg = p.papel,
        isDark = false;

  /// Si es uno de los temas papel.
  bool get isPaper => paleta != null;

  /// Si la página se ve oscura (también los papeles kraft y noche).
  bool get oscuro => paleta?.oscura ?? isDark;

  /// Texto o ícono sobre un relleno de [accent]: en los temas papel el que más
  /// se lea (en los oscuros el acento es claro); en los demás, negro o blanco.
  Color get sobreAcento =>
      isPaper ? textoSobre(accent) : (isDark ? Colors.black : Colors.white);

  /// Highlight underline alpha
  Color highlightOverlay(Color highlightColor) =>
      highlightColor.withValues(alpha: oscuro ? 0.18 : 0.25);

  /// Subtle selection background
  Color get selectionBg =>
      oscuro ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);

  /// Color para palabras de Cristo en rojo.
  Color get redLetterColor =>
      oscuro ? const Color(0xFFE57373) : const Color(0xFFC62828);

  /// Swatch color for theme selector. La opción de papel muestra el papel
  /// que de verdad se aplica (sigue al de la app).
  Color get swatchColor => isPaper ? papelActivo.background : background;

  /// Si la muestra del selector es oscura (para la palomita encima).
  bool get muestraOscura => isPaper ? papelActivo.oscuro : isDark;

  /// Texto secundario atenuado (fechas, contadores, avisos): [textSecondary]
  /// con la opacidad [alpha]. Si así no llega a contraste 4.5 (WCAG AA) sobre
  /// la página, usa [textoAtenuado], que sí llega: el gris con poca opacidad
  /// casi desaparece en los temas claros y sobre el papel con textura.
  Color textoTenue(double alpha) {
    final color = textSecondary.withValues(alpha: alpha);
    if (_seLee(color, null)) return color;
    return textoAtenuado(alpha: alpha);
  }

  /// Contraste 4.7 (4.5 con margen) sobre [sobre] o, si no se da, sobre la
  /// página. En los temas papel también sobre [surface]: los paneles y
  /// encabezados del papel son de ese tono, y en los papeles oscuros es más
  /// claro que la hoja.
  bool _seLee(Color color, Color? sobre) {
    if (sobre != null) return contrasteWcag(color, sobre) >= 4.7;
    return contrasteWcag(color, fondoVisible) >= 4.7 &&
        (!isPaper || contrasteWcag(color, surface) >= 4.7);
  }

  /// Texto de apoyo (pistas de búsqueda, avisos de lista vacía) que se nota
  /// más suave que el principal pero sigue siendo legible: [textPrimary] con
  /// la opacidad [alpha], subiéndola hasta llegar a contraste 4.5 (WCAG AA)
  /// sobre [sobre] (por defecto, la página; ver [_seLee]). Algunos temas tienen un
  /// `textSecondary` muy claro.
  Color textoAtenuado({double alpha = 0.72, Color? sobre}) {
    for (var a = alpha; a < 1; a += 0.04) {
      final color = textPrimary.withValues(alpha: a);
      // Un poco de margen: el fondo real varía un poco (redondeo, mezclas).
      if (_seLee(color, sobre)) return color;
    }
    return textPrimary;
  }

  /// El color que se ve detrás del texto de la página, para calcular colores
  /// legibles (`legibleSobre`). En el tema papel es el tono de la textura,
  /// más oscuro que [background].
  Color get fondoVisible => paleta?.papelTexturado ?? background;

  /// Fondo para `Scaffold.backgroundColor`. En el tema papel es transparente:
  /// cada página pinta el papel con textura (FondoPapel) por detrás.
  Color get pageBg => isPaper ? Colors.transparent : background;

  // ══════════════════════════════════════════════════════════════════════════
  // 10 TEMAS
  // ══════════════════════════════════════════════════════════════════════════

  static const nightPure = BibleReaderThemeData(
    id: 'night_pure',
    name: 'Noche pura',
    background: Color(0xFF0A0A12),
    surface: Color(0xFF14141E),
    textPrimary: Color(0xFFF0F0F0),
    textSecondary: Color(0xFF666666),
    accent: Color(0xFFD4AF37),
    toolbarBg: Color(0xFF1E1E2E),
    isDark: true,
  );

  static const charcoalEditorial = BibleReaderThemeData(
    id: 'charcoal',
    name: 'Carbón editorial',
    background: Color(0xFF1A1A1A),
    surface: Color(0xFF242424),
    textPrimary: Color(0xFFE8E8E8),
    textSecondary: Color(0xFF555555),
    accent: Color(0xFFD4AF37),
    toolbarBg: Color(0xFF2A2A2A),
    isDark: true,
  );

  static const sepiaNocturno = BibleReaderThemeData(
    id: 'sepia_night',
    name: 'Sepia nocturno',
    background: Color(0xFF1C1408),
    surface: Color(0xFF261C0E),
    textPrimary: Color(0xFFE8D5A3),
    textSecondary: Color(0xFF8B7355),
    accent: Color(0xFFD4AF37),
    toolbarBg: Color(0xFF2A2010),
    isDark: true,
  );

  static const cleanPage = BibleReaderThemeData(
    id: 'clean_page',
    name: 'Página limpia',
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A1A),
    textSecondary: Color(0xFF999999),
    accent: Color(0xFFB8960C),
    toolbarBg: Color(0xFFFFFFFF),
    isDark: false,
  );

  static const parchment = BibleReaderThemeData(
    id: 'parchment',
    name: 'Pergamino',
    background: Color(0xFFF5F0E8),
    surface: Color(0xFFFAF6EF),
    textPrimary: Color(0xFF3E2723),
    textSecondary: Color(0xFFA1887F),
    accent: Color(0xFF8B6914),
    toolbarBg: Color(0xFFFAF6EF),
    isDark: false,
  );

  static const greyEditorial = BibleReaderThemeData(
    id: 'grey_editorial',
    name: 'Gris editorial',
    background: Color(0xFFF2F2F2),
    surface: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF212121),
    textSecondary: Color(0xFF757575),
    accent: Color(0xFFB8960C),
    toolbarBg: Color(0xFFFFFFFF),
    isDark: false,
  );

  static const lavender = BibleReaderThemeData(
    id: 'lavender',
    name: 'Lavanda suave',
    background: Color(0xFFEDE7F6),
    surface: Color(0xFFF3EDF7),
    textPrimary: Color(0xFF311B92),
    textSecondary: Color(0xFF9575CD),
    accent: Color(0xFF7B1FA2),
    toolbarBg: Color(0xFFF3EDF7),
    isDark: false,
  );

  static const mint = BibleReaderThemeData(
    id: 'mint',
    name: 'Menta editorial',
    background: Color(0xFFE8F5E9),
    surface: Color(0xFFEEF7EF),
    textPrimary: Color(0xFF1B5E20),
    textSecondary: Color(0xFF66BB6A),
    accent: Color(0xFF2E7D32),
    toolbarBg: Color(0xFFEEF7EF),
    isDark: false,
  );

  static const peach = BibleReaderThemeData(
    id: 'peach',
    name: 'Durazno suave',
    background: Color(0xFFFFF3E0),
    surface: Color(0xFFFFF8EE),
    textPrimary: Color(0xFFBF360C),
    textSecondary: Color(0xFFFFAB40),
    accent: Color(0xFFE65100),
    toolbarBg: Color(0xFFFFF8EE),
    isDark: false,
  );

  /// Estilo «papel recortado» (kit victoria-en-cristo-estilo).
  static final paper = BibleReaderThemeData._papel(VecPaleta.claro, id: 'papel', name: 'Papel recortado');

  /// Papel oscuro café (kraft).
  static final paperKraft = BibleReaderThemeData._papel(VecPaleta.kraftOscuro, id: 'papel_kraft', name: 'Papel kraft');

  /// Papel oscuro azul de noche.
  static final paperNoche = BibleReaderThemeData._papel(VecPaleta.nocheAzul, id: 'papel_noche', name: 'Papel noche');

  /// Todos los temas disponibles
  static final List<BibleReaderThemeData> all = [
    nightPure,
    charcoalEditorial,
    sepiaNocturno,
    cleanPage,
    parchment,
    greyEditorial,
    lavender,
    mint,
    peach,
    paper,
  ];

  /// El papel del lector sigue al de la app (claro, kraft o noche): los
  /// colores del kit (VecColores) son uno solo para toda la app, así que el
  /// lector no puede ir en un papel distinto. Por eso en los selectores del
  /// lector hay una sola opción de papel («Papel recortado»).
  static BibleReaderThemeData get papelActivo {
    final paleta = VecColores.actual;
    if (identical(paleta, VecPaleta.kraftOscuro)) return paperKraft;
    if (identical(paleta, VecPaleta.nocheAzul)) return paperNoche;
    return paper;
  }

  /// Obtener tema por ID (default: noche pura)
  static BibleReaderThemeData fromId(String id) {
    if (id == paper.id || id == paperKraft.id || id == paperNoche.id) {
      return papelActivo;
    }
    return all.firstWhere(
      (t) => t.id == id,
      orElse: () => nightPure,
    );
  }

  /// Migrar IDs legacy ('dark', 'sepia', 'light') al nuevo sistema
  static String migrateId(String oldId) {
    switch (oldId) {
      case 'dark':
        return 'night_pure';
      case 'sepia':
        return 'sepia_night';
      case 'light':
        return 'clean_page';
      // Con «usar el tema de la app» llegan los ids de los papeles oscuros: en
      // el lector son la misma opción de papel (ver papelActivo).
      case 'papel_kraft':
      case 'papel_noche':
        return 'papel';
      default:
        return oldId;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // DESIGN TOKENS — Espaciado y tamaño consistente
  // ══════════════════════════════════════════════════════════════════════════

  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 16.0;
  static const double spacingL = 24.0;
  static const double spacingXL = 32.0;

  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 16.0;

  static const double iconSizeS = 16.0;
  static const double iconSizeM = 20.0;
  static const double iconSizeL = 24.0;

  static const double toolbarHeight = 44.0;
  static const double headerHeight = 48.0;
  static const double chapterRowHeight = 52.0;
  static const double chipHeight = 28.0;
}
