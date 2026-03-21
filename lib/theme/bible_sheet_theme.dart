import 'package:flutter/material.dart';
import 'bible_reader_theme.dart';
import '../services/bible/bible_user_data_service.dart';

/// Helper centralizado para colores de bottom sheets del módulo Biblia.
/// Respeta el tema actual del lector (claro/oscuro).
class BibleSheetTheme {
  BibleSheetTheme._();

  static BibleReaderThemeData get _t => BibleReaderThemeData.fromId(
        BibleReaderThemeData.migrateId(
            BibleUserDataService.I.readerThemeNotifier.value),
      );

  static Color get background => _t.surface;
  static Color get textPrimary => _t.textPrimary;
  static Color get textSecondary => _t.textSecondary;
  static Color get divider => _t.textSecondary.withOpacity(0.15);
  static Color get accent => const Color(0xFFD4AF37);
  static Color get inputBackground =>
      _t.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04);
  static Color get hintColor =>
      _t.isDark ? Colors.white24 : Colors.black26;
  static Color get handleColor =>
      _t.isDark ? Colors.white24 : Colors.black26;
  static Color get subtleText =>
      _t.isDark ? Colors.white38 : Colors.black38;

  static BoxDecoration get sheetDecoration => BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      );
}
