import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/commentary_entry.dart';

/// Fuentes de comentario disponibles.
enum CommentarySource {
  matthewHenry('matthew_henry', 'Matthew Henry'),
  jfb('jfb', 'Jamieson, Fausset & Brown'),
  gill('gill', 'John Gill'),
  clarke('clarke', 'Adam Clarke');

  final String folder;
  final String displayName;
  const CommentarySource(this.folder, this.displayName);
}

/// Servicio para comentarios bíblicos — 4 fuentes.
/// Carga lazy por libro+fuente – mantiene un solo libro por fuente en cache.
class CommentaryService {
  CommentaryService._();
  static final instance = CommentaryService._();

  // Cache por fuente: {source: {bookCode, entries}}
  final _cache = <CommentarySource, _BookCache>{};

  /// Libros que tienen comentario disponible.
  static const _availableBooks = <int, String>{
    1: 'GEN', 19: 'PSA', 40: 'MAT', 43: 'JHN', 45: 'ROM',
  };

  /// Todas las fuentes disponibles.
  static List<CommentarySource> get availableSources =>
      CommentarySource.values.toList();

  /// True si el libro tiene comentarios disponibles.
  static bool hasCommentary(int bookNumber) =>
      _availableBooks.containsKey(bookNumber);

  /// Obtiene comentarios para un versículo de una fuente específica.
  Future<List<CommentaryEntry>> getVerseCommentary(
    int bookNumber,
    int chapter,
    int verse, {
    CommentarySource source = CommentarySource.matthewHenry,
  }) async {
    final code = _availableBooks[bookNumber];
    if (code == null) return [];

    await _ensureBookLoaded(code, source);
    final entries = <CommentaryEntry>[];
    final cached = _cache[source]?.entries;

    final byVerse = cached?['$chapter:$verse'];
    if (byVerse != null) entries.addAll(byVerse);

    final byChapter = cached?['$chapter'];
    if (byChapter != null) entries.addAll(byChapter);

    return entries;
  }

  /// Obtiene comentarios de TODAS las fuentes para un versículo.
  Future<Map<CommentarySource, List<CommentaryEntry>>>
      getVerseCommentaryAllSources(
    int bookNumber,
    int chapter,
    int verse,
  ) async {
    final result = <CommentarySource, List<CommentaryEntry>>{};
    for (final source in CommentarySource.values) {
      final entries =
          await getVerseCommentary(bookNumber, chapter, verse, source: source);
      if (entries.isNotEmpty) {
        result[source] = entries;
      }
    }
    return result;
  }

  /// Obtiene todos los comentarios de un capítulo.
  Future<List<CommentaryEntry>> getChapterCommentary(
    int bookNumber,
    int chapter, {
    CommentarySource source = CommentarySource.matthewHenry,
  }) async {
    final code = _availableBooks[bookNumber];
    if (code == null) return [];

    await _ensureBookLoaded(code, source);
    final cached = _cache[source]?.entries;
    if (cached == null) return [];

    return cached.entries
        .where((e) => e.key.startsWith('$chapter:') || e.key == '$chapter')
        .expand((e) => e.value)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
  }

  Future<void> _ensureBookLoaded(String code, CommentarySource source) async {
    if (_cache[source]?.bookCode == code) return;

    final path = 'assets/bible/commentaries/${source.folder}/$code.json';
    try {
      final raw = await rootBundle.loadString(path);
      final list = jsonDecode(raw) as List;
      final entries = <String, List<CommentaryEntry>>{};

      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final chapter = m['chapter'] as int;
        final verse = m['verse'] as int? ?? 0;
        final entry = CommentaryEntry(
          bookCode: code,
          chapter: chapter,
          verse: verse,
          text: m['text'] as String? ?? '',
          source: source.displayName,
        );

        final key = verse > 0 ? '$chapter:$verse' : '$chapter';
        entries.putIfAbsent(key, () => []).add(entry);
      }

      _cache[source] = _BookCache(code, entries);
    } catch (e) {
      debugPrint('CommentaryService: Error cargando $path: $e');
      _cache[source] = _BookCache(code, {});
    }
  }

  void clearCache() {
    _cache.clear();
  }
}

class _BookCache {
  final String bookCode;
  final Map<String, List<CommentaryEntry>> entries;
  _BookCache(this.bookCode, this.entries);
}
