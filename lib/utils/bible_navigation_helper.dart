import 'package:flutter/material.dart';
import '../models/bible/bible_version.dart';
import '../services/bible/bible_user_data_service.dart';
import '../services/bible/treasury_service.dart';
import '../screens/bible/bible_reader_screen.dart';

/// Mapa inverso: nombre español → número de libro (1-based).
const _spanishNameToBookNumber = <String, int>{
  'génesis': 1, 'éxodo': 2, 'levítico': 3, 'números': 4, 'deuteronomio': 5,
  'josué': 6, 'jueces': 7, 'rut': 8,
  '1 samuel': 9, '2 samuel': 10, '1 reyes': 11, '2 reyes': 12,
  '1 crónicas': 13, '2 crónicas': 14, 'esdras': 15, 'nehemías': 16,
  'ester': 17, 'job': 18, 'salmos': 19, 'proverbios': 20,
  'eclesiastés': 21, 'cantares': 22, 'isaías': 23, 'jeremías': 24,
  'lamentaciones': 25, 'ezequiel': 26, 'daniel': 27,
  'oseas': 28, 'joel': 29, 'amós': 30, 'abdías': 31, 'jonás': 32,
  'miqueas': 33, 'nahúm': 34, 'habacuc': 35, 'sofonías': 36,
  'hageo': 37, 'zacarías': 38, 'malaquías': 39,
  'mateo': 40, 'marcos': 41, 'lucas': 42, 'juan': 43, 'hechos': 44,
  'romanos': 45, '1 corintios': 46, '2 corintios': 47, 'gálatas': 48,
  'efesios': 49, 'filipenses': 50, 'colosenses': 51,
  '1 tesalonicenses': 52, '2 tesalonicenses': 53,
  '1 timoteo': 54, '2 timoteo': 55, 'tito': 56, 'filemón': 57,
  'hebreos': 58, 'santiago': 59, '1 pedro': 60, '2 pedro': 61,
  '1 juan': 62, '2 juan': 63, '3 juan': 64, 'judas': 65, 'apocalipsis': 66,
};

/// Helper estático para navegar a un versículo bíblico desde cualquier contexto.
class BibleNavigationHelper {
  BibleNavigationHelper._();

  /// Navega al capítulo indicado por una referencia en español ("Filipenses 4:13").
  /// Soporta formatos: "Libro cap:ver", "Libro cap:ver-ver", "1 Libro cap:ver".
  static void navigateToSpanishRef(BuildContext context, String ref) {
    final parsed = parseSpanishRef(ref);
    if (parsed == null) return;

    final version = BibleUserDataService.I.preferredVersionNotifier.value;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: parsed.bookNumber,
          bookName: parsed.bookName,
          chapter: parsed.chapter,
          version: version,
        ),
      ),
    );
  }

  /// Parsea una referencia en español. Devuelve null si no se puede parsear.
  static ({int bookNumber, String bookName, int chapter})? parseSpanishRef(
      String ref) {
    // Regex: captura nombre del libro (puede empezar con dígito) y cap:ver
    final match = RegExp(r'^(.+?)\s+(\d+)(?::(\d+))?').firstMatch(ref.trim());
    if (match == null) return null;

    final rawBook = match.group(1)!.toLowerCase();
    final chapter = int.tryParse(match.group(2)!);
    if (chapter == null) return null;

    final bookNumber = _spanishNameToBookNumber[rawBook];
    if (bookNumber == null) return null;

    // Devolver el nombre con la capitalización original
    final bookName = match.group(1)!;
    return (bookNumber: bookNumber, bookName: bookName, chapter: chapter);
  }

  /// Navega al capítulo/versículo indicado por una referencia OSIS ("ROM.5.8").
  static void navigateToOsis(BuildContext context, String osisRef) {
    final parsed = TreasuryService.parseReference(osisRef);
    if (parsed == null) return;

    final bookName = TreasuryService.formatReference(osisRef).split(' ').first;
    final version = BibleUserDataService.I.preferredVersionNotifier.value;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: parsed.bookNumber,
          bookName: bookName,
          chapter: parsed.chapter,
          version: version,
        ),
      ),
    );
  }

  /// Navega directamente con bookNumber, bookName, chapter, version.
  static void navigateTo(
    BuildContext context, {
    required int bookNumber,
    required String bookName,
    required int chapter,
    BibleVersion? version,
  }) {
    final v = version ?? BibleUserDataService.I.preferredVersionNotifier.value;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: bookNumber,
          bookName: bookName,
          chapter: chapter,
          version: v,
        ),
      ),
    );
  }
}
