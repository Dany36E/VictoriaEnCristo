import 'package:flutter/material.dart';

import '../vec/vec_tema.dart';
import 'contraste.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE READER THEME — el papel del lector de la Biblia
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Colores con nombre de lector (fondo, barras, texto, acento) para los tres
/// papeles del kit. El lector siempre va en el papel de la app (ver
/// [papelActivo]); se pide con BibleReaderThemeData.fromId(themeId).
/// ═══════════════════════════════════════════════════════════════════════════

class BibleReaderThemeData {
  final String id;
  final String name;
  final Color background;
  final Color surface; // barras, hojas
  final Color textPrimary;
  final Color textSecondary; // números de versículo, detalles
  final Color accent; // terracota
  final Color toolbarBg;

  /// El papel del kit: claro, kraft oscuro o noche azul.
  final VecPaleta paleta;

  /// Tema «papel recortado» con la [paleta] que se le dé.
  BibleReaderThemeData._papel(this.paleta, {required this.id, required this.name})
      : background = paleta.crema,
        surface = paleta.papel,
        textPrimary = paleta.tinta,
        // En claro, un poco más oscuro que el gris del kit para que los
        // textos chicos del lector se lean bien sobre el papel (5.8:1 sobre
        // crema). En oscuro el gris ya pasa de 4.5 en todas las superficies.
        textSecondary = paleta.oscura ? paleta.gris : const Color(0xFF66584A),
        accent = paleta.terracota,
        toolbarBg = paleta.papel;

  /// Si la página se ve oscura (papeles kraft y noche).
  bool get oscuro => paleta.oscura;

  /// Texto o ícono sobre un relleno de [accent]: papel o tinta, el que más se
  /// lea (en los papeles oscuros el acento es claro).
  Color get sobreAcento => textoSobre(accent);

  /// Highlight underline alpha
  Color highlightOverlay(Color highlightColor) =>
      highlightColor.withValues(alpha: oscuro ? 0.18 : 0.25);

  /// Subtle selection background
  Color get selectionBg =>
      oscuro ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04);

  /// Color para palabras de Cristo en rojo.
  Color get redLetterColor =>
      oscuro ? const Color(0xFFE57373) : const Color(0xFFC62828);

  /// Texto secundario atenuado (fechas, contadores, avisos): [textSecondary]
  /// con la opacidad [alpha]. Si así no llega a contraste 4.5 (WCAG AA) sobre
  /// la página, usa [textoAtenuado], que sí llega: el gris con poca opacidad
  /// casi desaparece sobre el papel con textura.
  Color textoTenue(double alpha) {
    final color = textSecondary.withValues(alpha: alpha);
    if (_seLee(color, null)) return color;
    return textoAtenuado(alpha: alpha);
  }

  /// Contraste 4.7 (4.5 con margen) sobre [sobre] o, si no se da, sobre la
  /// página y sobre [surface]: los paneles y encabezados del papel son de ese
  /// tono, y en los papeles oscuros es más claro que la hoja.
  bool _seLee(Color color, Color? sobre) {
    if (sobre != null) return contrasteWcag(color, sobre) >= 4.7;
    return contrasteWcag(color, fondoVisible) >= 4.7 &&
        contrasteWcag(color, surface) >= 4.7;
  }

  /// Texto de apoyo (pistas de búsqueda, avisos de lista vacía) que se nota
  /// más suave que el principal pero sigue siendo legible: [textPrimary] con
  /// la opacidad [alpha], subiéndola hasta llegar a contraste 4.5 (WCAG AA)
  /// sobre [sobre] (por defecto, la página; ver [_seLee]).
  Color textoAtenuado({double alpha = 0.72, Color? sobre}) {
    for (var a = alpha; a < 1; a += 0.04) {
      final color = textPrimary.withValues(alpha: a);
      // Un poco de margen: el fondo real varía un poco (redondeo, mezclas).
      if (_seLee(color, sobre)) return color;
    }
    return textPrimary;
  }

  /// El color que se ve detrás del texto de la página, para calcular colores
  /// legibles (`legibleSobre`): el tono de la textura.
  Color get fondoVisible => paleta.papelTexturado;

  /// Fondo para `Scaffold.backgroundColor`: transparente, porque cada página
  /// pinta el papel con textura (FondoPapel) por detrás.
  Color get pageBg => Colors.transparent;

  // ══════════════════════════════════════════════════════════════════════════
  // TEMAS — los tres papeles (mismos ids que AppThemeData)
  // ══════════════════════════════════════════════════════════════════════════

  /// Estilo «papel recortado» (kit victoria-en-cristo-estilo).
  static final paper = BibleReaderThemeData._papel(VecPaleta.claro, id: 'papel', name: 'Papel recortado');

  /// Papel oscuro café (kraft).
  static final paperKraft = BibleReaderThemeData._papel(VecPaleta.kraftOscuro, id: 'papel_kraft', name: 'Papel kraft');

  /// Papel oscuro azul de noche.
  static final paperNoche = BibleReaderThemeData._papel(VecPaleta.nocheAzul, id: 'papel_noche', name: 'Papel noche');

  /// Todos los temas.
  static final List<BibleReaderThemeData> all = [paper, paperKraft, paperNoche];

  /// El papel del lector sigue al de la app (claro, kraft o noche): los
  /// colores del kit (VecColores) son uno solo para toda la app.
  static BibleReaderThemeData get papelActivo {
    final paleta = VecColores.actual;
    if (identical(paleta, VecPaleta.kraftOscuro)) return paperKraft;
    if (identical(paleta, VecPaleta.nocheAzul)) return paperNoche;
    return paper;
  }

  /// El tema del lector: siempre el papel activo de la app. El id guardado
  /// (incluidos los de los temas de antes) ya no elige nada.
  static BibleReaderThemeData fromId(String id) => papelActivo;

  /// Ids de antes ('dark', 'night_pure'…): todos son ahora el papel.
  static String migrateId(String oldId) => papelActivo.id;

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
