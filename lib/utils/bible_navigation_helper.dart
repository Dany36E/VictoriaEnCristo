import 'package:flutter/material.dart';
import '../models/bible/bible_version.dart';
import '../services/bible/bible_parser_service.dart';
import '../services/bible/bible_user_data_service.dart';
import '../screens/bible/bible_reader_screen.dart';
import 'bible_reference_parser.dart';

/// Helper estático para abrir el lector en un versículo desde cualquier
/// contexto. Todas las entradas pasan el versículo para que el lector llegue
/// EXACTAMENTE a él y lo resalte un instante.
class BibleNavigationHelper {
  BibleNavigationHelper._();

  /// Abre la referencia en español («Filipenses 4:13», «Salmo 103:12»,
  /// «1 Co 13:4», «Jn 3:16»…). Devuelve false si no se pudo interpretar.
  static bool navigateToSpanishRef(BuildContext context, String ref) {
    final parsed = BibleReferenceParser.parse(ref);
    if (parsed == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text('No se reconoció la referencia «$ref».')),
      );
      return false;
    }
    navigateTo(
      context,
      bookNumber: parsed.bookNumber,
      bookName: parsed.bookName,
      chapter: parsed.chapter,
      verse: parsed.verse,
    );
    return true;
  }

  /// Parsea una referencia en español. Devuelve null si no se puede parsear.
  /// Se conserva por compatibilidad: usa [BibleReferenceParser].
  static ({int bookNumber, String bookName, int chapter, int? verse})?
  parseSpanishRef(String ref) {
    final r = BibleReferenceParser.parse(ref);
    if (r == null) return null;
    return (
      bookNumber: r.bookNumber,
      bookName: r.bookName,
      chapter: r.chapter,
      verse: r.verse,
    );
  }

  /// Abre una referencia OSIS («ROM.5.8»).
  static void navigateToOsis(BuildContext context, String osisRef) {
    final parsed = BibleReferenceParser.parseOsis(osisRef);
    if (parsed == null) return;
    navigateTo(
      context,
      bookNumber: parsed.bookNumber,
      bookName: parsed.bookName,
      chapter: parsed.chapter,
      verse: parsed.verse,
    );
  }

  /// Abre el lector en libro/capítulo/versículo.
  static Future<void> navigateTo(
    BuildContext context, {
    required int bookNumber,
    required String bookName,
    required int chapter,
    int? verse,
    BibleVersion? version,
    bool replace = false,
  }) async {
    final v = version ?? BibleUserDataService.I.preferredVersionNotifier.value;
    var name = bookName;
    if (v.isEnglish) {
      // Los libros en inglés tienen su propio nombre en el XML.
      try {
        name = await BibleParserService.I.getBookName(v, bookNumber);
      } catch (_) {}
      if (!context.mounted) return;
    }
    final route = MaterialPageRoute<void>(
      builder: (_) => BibleReaderScreen(
        bookNumber: bookNumber,
        bookName: name,
        chapter: chapter,
        version: v,
        initialVerse: verse,
      ),
    );
    final nav = Navigator.of(context);
    if (replace) {
      await nav.pushReplacement(route);
    } else {
      await nav.push(route);
    }
  }
}
