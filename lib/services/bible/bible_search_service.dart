import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import 'bible_parser_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE SEARCH SERVICE
/// Búsqueda con normalización de acentos, historial reciente.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleSearchService {
  BibleSearchService._();
  static final I = BibleSearchService._();

  static const _recentKey = 'bible_recent_searches';
  static const _maxRecent = 8;

  /// Normalizar texto: quitar acentos, minúsculas
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  /// Búsqueda normalizada en una versión
  Future<List<BibleVerse>> search({
    required BibleVersion version,
    required String query,
    int maxResults = 80,
    String? testamentFilter, // 'old', 'new', or null for all
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final normalizedQuery = normalize(trimmed);

    // Use the parser's search but with normalization
    await BibleParserService.I.ensureVersionLoaded(version);
    final doc = BibleParserService.I.getParsedDoc(version);
    if (doc == null) return [];

    final results = <BibleVerse>[];
    final testaments = doc.rootElement.findAllElements('testament');

    for (final testament in testaments) {
      // Filter by testament if requested
      if (testamentFilter != null) {
        final name = testament.getAttribute('name') ?? '';
        final isOld = name == 'Old' || name == 'Antiguo';
        if (testamentFilter == 'old' && !isOld) continue;
        if (testamentFilter == 'new' && isOld) continue;
      }

      final books = testament.findAllElements('book');
      for (final book in books) {
        final bookNum = int.parse(book.getAttribute('number')!);
        final bookName = book.getAttribute('name')!;
        final chapters = book.findAllElements('chapter');
        for (final chapterEl in chapters) {
          final chapNum = int.parse(chapterEl.getAttribute('number')!);
          final verses = chapterEl.findAllElements('verse');
          for (final verseEl in verses) {
            final text = verseEl.innerText;
            if (normalize(text).contains(normalizedQuery)) {
              results.add(BibleVerse(
                bookName: bookName,
                bookNumber: bookNum,
                chapter: chapNum,
                verse: int.parse(verseEl.getAttribute('number')!),
                text: text,
                version: version.id,
              ));
              if (results.length >= maxResults) return results;
            }
          }
        }
      }
    }
    return results;
  }

  /// Búsquedas recientes
  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_recentKey) ?? [];
  }

  Future<void> addRecentSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey) ?? [];
    list.remove(q);
    list.insert(0, q);
    if (list.length > _maxRecent) list.removeLast();
    await prefs.setStringList(_recentKey, list);
  }

  Future<void> removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey) ?? [];
    list.remove(query);
    await prefs.setStringList(_recentKey, list);
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }
}
