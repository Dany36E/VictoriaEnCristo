import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ENDURING WORD — TERMS OF USE
//
// Content from The Enduring Word Bible Commentary by David Guzik is used
// under the Enduring Word terms of use:
//   • Content is presented without alteration from the original text.
//   • Attribution is displayed at the end of each chapter in study mode:
//     "©1996–present The Enduring Word Bible Commentary by David Guzik
//      – enduringword.com. Used with permission."
//   • A disclaimer referencing Enduring Word is shown in Settings.
//   • The app does not claim authorship of commentary content.
//
// Spanish translation source: https://es.enduringword.com/
// ═══════════════════════════════════════════════════════════════════════════════

/// Sección de un comentario Enduring Word (David Guzik).
class EWSection {
  final String heading;
  final List<String> paragraphs;

  const EWSection({required this.heading, required this.paragraphs});

  factory EWSection.fromJson(Map<String, dynamic> json) => EWSection(
        heading: json['h'] as String? ?? '',
        paragraphs: (json['p'] as List?)?.cast<String>() ?? [],
      );
}

/// Comentario Enduring Word para un capítulo completo.
class EWChapterCommentary {
  final String title;
  final List<EWSection> sections;

  const EWChapterCommentary({
    required this.title,
    required this.sections,
  });

  bool get isEmpty => sections.isEmpty;

  factory EWChapterCommentary.fromJson(Map<String, dynamic> json) =>
      EWChapterCommentary(
        title: json['t'] as String? ?? '',
        sections: (json['s'] as List?)
                ?.map((s) => EWSection.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

/// Servicio para obtener comentarios de Enduring Word (David Guzik).
/// Lee desde assets locales pre-descargados (sin necesidad de internet).
class EnduringWordService {
  EnduringWordService._();
  static final instance = EnduringWordService._();

  /// Cache en memoria: bookNumber → { chapter → commentary }
  final Map<int, Map<String, EWChapterCommentary>> _cache = {};
  final Map<int, Completer<void>> _loadCompleters = {};

  /// Obtiene el comentario para un capítulo (desde assets locales).
  Future<EWChapterCommentary?> getChapterCommentary(
      int bookNumber, int chapter) async {
    // Check memory cache
    final bookCache = _cache[bookNumber];
    if (bookCache != null) {
      final chapterKey = chapter.toString();
      if (bookCache.containsKey(chapterKey)) {
        return bookCache[chapterKey];
      }
    }

    // Load the entire book JSON from assets
    await _loadBook(bookNumber);

    // Return from cache
    return _cache[bookNumber]?[chapter.toString()];
  }

  /// Carga el JSON del libro completo en memoria.
  Future<void> _loadBook(int bookNumber) async {
    if (_cache.containsKey(bookNumber)) return;
    if (_loadCompleters.containsKey(bookNumber)) {
      return _loadCompleters[bookNumber]!.future;
    }
    _loadCompleters[bookNumber] = Completer<void>();

    try {
      final jsonStr = await rootBundle.loadString(
        'assets/bible/commentaries/guzik/$bookNumber.json',
      );
      final data = await compute(_parseBookJson, jsonStr);
      _cache[bookNumber] = data;
    } catch (e) {
      debugPrint('EW: No se pudo cargar libro $bookNumber: $e');
      _cache[bookNumber] = {}; // mark as loaded (empty)
    }
    _loadCompleters[bookNumber]!.complete();
  }

  /// Parse JSON en isolate para no bloquear el UI.
  static Map<String, EWChapterCommentary> _parseBookJson(String jsonStr) {
    final result = <String, EWChapterCommentary>{};
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      for (final entry in map.entries) {
        final chapterData = entry.value as Map<String, dynamic>;
        result[entry.key] = EWChapterCommentary.fromJson(chapterData);
      }
    } catch (e) {
      debugPrint('EW: Error parsing JSON: $e');
    }
    return result;
  }

  /// Nombres en inglés para referencia / URLs externas.
  static const bookSlugs = <int, String>{
    1: 'genesis', 2: 'exodus', 3: 'leviticus', 4: 'numbers',
    5: 'deuteronomy', 6: 'joshua', 7: 'judges', 8: 'ruth',
    9: '1-samuel', 10: '2-samuel', 11: '1-kings', 12: '2-kings',
    13: '1-chronicles', 14: '2-chronicles', 15: 'ezra',
    16: 'nehemiah', 17: 'esther', 18: 'job', 19: 'psalm',
    20: 'proverbs', 21: 'ecclesiastes', 22: 'song-of-solomon',
    23: 'isaiah', 24: 'jeremiah', 25: 'lamentations',
    26: 'ezekiel', 27: 'daniel', 28: 'hosea', 29: 'joel',
    30: 'amos', 31: 'obadiah', 32: 'jonah', 33: 'micah',
    34: 'nahum', 35: 'habakkuk', 36: 'zephaniah', 37: 'haggai',
    38: 'zechariah', 39: 'malachi',
    40: 'matthew', 41: 'mark', 42: 'luke', 43: 'john', 44: 'acts',
    45: 'romans', 46: '1-corinthians', 47: '2-corinthians',
    48: 'galatians', 49: 'ephesians', 50: 'philippians',
    51: 'colossians', 52: '1-thessalonians', 53: '2-thessalonians',
    54: '1-timothy', 55: '2-timothy', 56: 'titus', 57: 'philemon',
    58: 'hebrews', 59: 'james', 60: '1-peter', 61: '2-peter',
    62: '1-john', 63: '2-john', 64: '3-john', 65: 'jude',
    66: 'revelation',
  };

  /// URL del comentario para un capítulo (referencia externa — sitio español).
  static String? getUrl(int bookNumber, int chapter) {
    final slug = bookSlugs[bookNumber];
    if (slug == null) return null;
    return 'https://es.enduringword.com/comentario-biblico/$slug-$chapter/';
  }
}
