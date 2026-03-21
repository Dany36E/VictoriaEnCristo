import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE READER THEME - 9 temas editoriales premium
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
  final bool isDark;

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
  });

  /// Highlight underline alpha
  Color highlightOverlay(Color highlightColor) =>
      highlightColor.withOpacity(isDark ? 0.18 : 0.25);

  /// Subtle selection background
  Color get selectionBg =>
      isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);

  /// Color para palabras de Cristo en rojo.
  Color get redLetterColor =>
      isDark ? const Color(0xFFE57373) : const Color(0xFFC62828);

  /// Swatch color for theme selector
  Color get swatchColor => background;

  // ══════════════════════════════════════════════════════════════════════════
  // 9 TEMAS
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

  /// Todos los temas disponibles
  static const List<BibleReaderThemeData> all = [
    nightPure,
    charcoalEditorial,
    sepiaNocturno,
    cleanPage,
    parchment,
    greyEditorial,
    lavender,
    mint,
    peach,
  ];

  /// Obtener tema por ID (default: noche pura)
  static BibleReaderThemeData fromId(String id) {
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
