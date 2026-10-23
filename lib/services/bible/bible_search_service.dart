import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../utils/bible_reference_parser.dart';
import '../user_pref_cloud_sync_service.dart';
import 'bible_parser_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE SEARCH SERVICE
/// Búsqueda con normalización de acentos, historial reciente,
/// detección inteligente de intención (libro, capítulo, versículo, texto libre).
/// ═══════════════════════════════════════════════════════════════════════════

enum SearchIntent { bookOnly, bookAndChapter, verseReference, freeText }

class SearchResult {
  final SearchIntent intent;
  final int? bookNumber;
  final String? bookName;
  final int? totalChapters;
  final int? chapter;
  final int? verse;
  final List<BibleVerse> verses;

  const SearchResult({
    required this.intent,
    this.bookNumber,
    this.bookName,
    this.totalChapters,
    this.chapter,
    this.verse,
    this.verses = const [],
  });
}

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

  /// Detectar la intención del query y resolver a libro/capítulo/versículo
  Future<SearchResult> detectAndSearch({
    required BibleVersion version,
    required String query,
    int maxResults = 80,
    String? testamentFilter,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const SearchResult(intent: SearchIntent.freeText);

    final books = await BibleParserService.I.getBooks(version);

    // Intentar parsear como referencia bíblica
    final ref = _parseReference(trimmed, books);
    if (ref != null && ref.intent != SearchIntent.bookOnly) return ref;
    if (ref != null) {
      // «Job», «Amós», «Rut»… también son palabras: se sugiere el libro y
      // además se muestran los versículos que la contienen.
      final verses = await search(
        version: version,
        query: trimmed,
        maxResults: maxResults,
        testamentFilter: testamentFilter,
      );
      return SearchResult(
        intent: SearchIntent.bookOnly,
        bookNumber: ref.bookNumber,
        bookName: ref.bookName,
        totalChapters: ref.totalChapters,
        verses: verses,
      );
    }

    // Texto libre: búsqueda fuzzy de versículos
    final verses = await search(
      version: version,
      query: trimmed,
      maxResults: maxResults,
      testamentFilter: testamentFilter,
    );
    return SearchResult(intent: SearchIntent.freeText, verses: verses);
  }

  /// Parsear una cadena como referencia bíblica.
  /// Soporta: «Salmos», «Salmo 120», «Juan 3:16», «Gn 1:1», «1 Co 13»,
  /// nombres sin acentos y códigos OSIS (ver [BibleReferenceParser]).
  SearchResult? _parseReference(String query, List<BibleBook> books) {
    BibleBook? bookFor(int number) =>
        books.where((b) => b.number == number).firstOrNull;

    final ref = BibleReferenceParser.parse(query);
    if (ref != null) {
      final book = bookFor(ref.bookNumber);
      if (book != null && ref.chapter <= book.totalChapters) {
        final maxVerse = book.versesPerChapter[ref.chapter];
        final verse = ref.verse;
        if (verse != null && (maxVerse == null || verse <= maxVerse)) {
          return SearchResult(
            intent: SearchIntent.verseReference,
            bookNumber: book.number,
            bookName: book.name,
            totalChapters: book.totalChapters,
            chapter: ref.chapter,
            verse: verse,
          );
        }
        return SearchResult(
          intent: SearchIntent.bookAndChapter,
          bookNumber: book.number,
          bookName: book.name,
          totalChapters: book.totalChapters,
          chapter: ref.chapter,
        );
      }
    }

    // Solo nombre de libro: «Salmos», «Gn», «Juan», «filip».
    final number = BibleReferenceParser.resolveBook(query);
    final book = number == null ? null : bookFor(number);
    if (book != null) {
      return SearchResult(
        intent: SearchIntent.bookOnly,
        bookNumber: book.number,
        bookName: book.name,
        totalChapters: book.totalChapters,
      );
    }
    return null;
  }

  /// Búsqueda normalizada en una versión
  Future<List<BibleVerse>> search({
    required BibleVersion version,
    required String query,
    int maxResults = 80,
    String? testamentFilter,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return [];

    final normalizedQuery = normalize(trimmed);

    await BibleParserService.I.ensureVersionLoaded(version);
    final doc = BibleParserService.I.getParsedDoc(version);
    if (doc == null) return [];

    final results = <BibleVerse>[];
    final testaments = doc.rootElement.findAllElements('testament');

    for (final testament in testaments) {
      if (testamentFilter != null) {
        final name = testament.getAttribute('name') ?? '';
        final isOld = name == 'Old' || name == 'Antiguo';
        if (testamentFilter == 'old' && !isOld) continue;
        if (testamentFilter == 'new' && isOld) continue;
      }

      final xmlBooks = testament.findAllElements('book');
      for (final book in xmlBooks) {
        final bookNum = int.parse(book.getAttribute('number')!);
        final bookName =
            book.getAttribute('name') ?? (await BibleParserService.I.getBookName(version, bookNum));
        final chapters = book.findAllElements('chapter');
        for (final chapterEl in chapters) {
          final chapNum = int.parse(chapterEl.getAttribute('number')!);
          final verses = chapterEl.findAllElements('verse');
          for (final verseEl in verses) {
            final text = verseEl.innerText;
            if (text.trim().isEmpty) continue;
            if (normalize(text).contains(normalizedQuery)) {
              results.add(
                BibleVerse(
                  bookName: bookName,
                  bookNumber: bookNum,
                  chapter: chapNum,
                  verse: int.parse(verseEl.getAttribute('number')!),
                  text: text,
                  version: version.id,
                ),
              );
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
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_recentKey) ?? [];
    list.remove(query);
    await prefs.setStringList(_recentKey, list);
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
    UserPrefCloudSyncService.I.markDirty();
  }
}
