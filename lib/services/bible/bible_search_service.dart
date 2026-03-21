import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
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

  /// Mapa de abreviaturas comunes → nombre canónico normalizado
  static final Map<String, String> _abbreviations = {
    'gn': 'genesis', 'gen': 'genesis', 'genesis': 'genesis',
    'ex': 'exodo', 'exo': 'exodo', 'exodo': 'exodo',
    'lv': 'levitico', 'lev': 'levitico', 'levitico': 'levitico',
    'nm': 'numeros', 'num': 'numeros', 'numeros': 'numeros',
    'dt': 'deuteronomio', 'deut': 'deuteronomio', 'deuteronomio': 'deuteronomio',
    'jos': 'josue', 'josue': 'josue',
    'jue': 'jueces', 'jueces': 'jueces',
    'rt': 'rut', 'rut': 'rut',
    '1sa': '1 samuel', '1sam': '1 samuel', '1 samuel': '1 samuel',
    '2sa': '2 samuel', '2sam': '2 samuel', '2 samuel': '2 samuel',
    '1re': '1 reyes', '1rey': '1 reyes', '1 reyes': '1 reyes',
    '2re': '2 reyes', '2rey': '2 reyes', '2 reyes': '2 reyes',
    '1cr': '1 cronicas', '1cro': '1 cronicas', '1 cronicas': '1 cronicas',
    '2cr': '2 cronicas', '2cro': '2 cronicas', '2 cronicas': '2 cronicas',
    'esd': 'esdras', 'esdras': 'esdras',
    'neh': 'nehemias', 'nehemias': 'nehemias',
    'est': 'ester', 'ester': 'ester',
    'job': 'job',
    'sal': 'salmos', 'salmos': 'salmos', 'salmo': 'salmos',
    'pr': 'proverbios', 'pro': 'proverbios', 'prov': 'proverbios', 'proverbios': 'proverbios',
    'ec': 'eclesiastes', 'ecl': 'eclesiastes', 'eclesiastes': 'eclesiastes',
    'cnt': 'cantares', 'cant': 'cantares', 'cantares': 'cantares',
    'is': 'isaias', 'isa': 'isaias', 'isaias': 'isaias',
    'jr': 'jeremias', 'jer': 'jeremias', 'jeremias': 'jeremias',
    'lm': 'lamentaciones', 'lam': 'lamentaciones', 'lamentaciones': 'lamentaciones',
    'ez': 'ezequiel', 'eze': 'ezequiel', 'ezequiel': 'ezequiel',
    'dn': 'daniel', 'dan': 'daniel', 'daniel': 'daniel',
    'os': 'oseas', 'oseas': 'oseas',
    'jl': 'joel', 'joel': 'joel',
    'am': 'amos', 'amos': 'amos',
    'abd': 'abdias', 'abdias': 'abdias',
    'jon': 'jonas', 'jonas': 'jonas',
    'mi': 'miqueas', 'miq': 'miqueas', 'miqueas': 'miqueas',
    'nah': 'nahum', 'nahum': 'nahum',
    'hab': 'habacuc', 'habacuc': 'habacuc',
    'sof': 'sofonias', 'sofonias': 'sofonias',
    'hag': 'hageo', 'hageo': 'hageo',
    'zac': 'zacarias', 'zacarias': 'zacarias',
    'mal': 'malaquias', 'malaquias': 'malaquias',
    'mt': 'mateo', 'mat': 'mateo', 'mateo': 'mateo',
    'mr': 'marcos', 'mar': 'marcos', 'marcos': 'marcos',
    'lc': 'lucas', 'luc': 'lucas', 'lucas': 'lucas',
    'jn': 'juan', 'juan': 'juan',
    'hch': 'hechos', 'hec': 'hechos', 'hechos': 'hechos',
    'ro': 'romanos', 'rom': 'romanos', 'romanos': 'romanos',
    '1co': '1 corintios', '1cor': '1 corintios', '1 corintios': '1 corintios',
    '2co': '2 corintios', '2cor': '2 corintios', '2 corintios': '2 corintios',
    'ga': 'galatas', 'gal': 'galatas', 'galatas': 'galatas',
    'ef': 'efesios', 'efe': 'efesios', 'efesios': 'efesios',
    'fil': 'filipenses', 'flp': 'filipenses', 'filipenses': 'filipenses',
    'col': 'colosenses', 'colosenses': 'colosenses',
    '1ts': '1 tesalonicenses', '1tes': '1 tesalonicenses', '1 tesalonicenses': '1 tesalonicenses',
    '2ts': '2 tesalonicenses', '2tes': '2 tesalonicenses', '2 tesalonicenses': '2 tesalonicenses',
    '1ti': '1 timoteo', '1tim': '1 timoteo', '1 timoteo': '1 timoteo',
    '2ti': '2 timoteo', '2tim': '2 timoteo', '2 timoteo': '2 timoteo',
    'tit': 'tito', 'tito': 'tito',
    'flm': 'filemon', 'filemon': 'filemon',
    'he': 'hebreos', 'heb': 'hebreos', 'hebreos': 'hebreos',
    'stg': 'santiago', 'sant': 'santiago', 'santiago': 'santiago',
    '1pe': '1 pedro', '1ped': '1 pedro', '1 pedro': '1 pedro',
    '2pe': '2 pedro', '2ped': '2 pedro', '2 pedro': '2 pedro',
    '1jn': '1 juan', '1 juan': '1 juan',
    '2jn': '2 juan', '2 juan': '2 juan',
    '3jn': '3 juan', '3 juan': '3 juan',
    'jud': 'judas', 'judas': 'judas',
    'ap': 'apocalipsis', 'apo': 'apocalipsis', 'apoc': 'apocalipsis', 'apocalipsis': 'apocalipsis',
  };

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
    if (ref != null) return ref;

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
  /// Soporta: "Salmos", "Salmos 120", "Juan 3:16", "Gn 1:1"
  SearchResult? _parseReference(String query, List<BibleBook> books) {
    final normalized = normalize(query);

    // Regex: "[libro] [capítulo]:[versículo]" o "[libro] [capítulo]"
    // El libro puede tener un prefijo numérico como "1 juan" o "2 pedro"
    final refRegex = RegExp(r'^(\d?\s*[a-z]+)\s+(\d+)(?::(\d+))?$');
    final match = refRegex.firstMatch(normalized);

    if (match != null) {
      final bookPart = match.group(1)!.trim();
      final chapter = int.parse(match.group(2)!);
      final verse = match.group(3) != null ? int.parse(match.group(3)!) : null;

      final book = _resolveBook(bookPart, books);
      if (book != null) {
        if (verse != null) {
          return SearchResult(
            intent: SearchIntent.verseReference,
            bookNumber: book.number,
            bookName: book.name,
            totalChapters: book.totalChapters,
            chapter: chapter,
            verse: verse,
          );
        } else {
          return SearchResult(
            intent: SearchIntent.bookAndChapter,
            bookNumber: book.number,
            bookName: book.name,
            totalChapters: book.totalChapters,
            chapter: chapter,
          );
        }
      }
    }

    // Solo nombre de libro: "Salmos", "Gn", "Juan"
    final book = _resolveBook(normalized, books);
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

  /// Resolver un término a un libro bíblico.
  BibleBook? _resolveBook(String term, List<BibleBook> books) {
    // 1. Buscar en abreviaturas
    final canonical = _abbreviations[term];
    if (canonical != null) {
      return books.where((b) => normalize(b.name) == canonical).firstOrNull;
    }
    // 2. Buscar por nombre normalizado (exacto)
    final exact = books.where((b) => normalize(b.name) == term).firstOrNull;
    if (exact != null) return exact;
    // 3. Buscar por prefijo
    final prefix = books.where((b) => normalize(b.name).startsWith(term)).firstOrNull;
    return prefix;
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
        final bookName = book.getAttribute('name') ??
            (await BibleParserService.I.getBookName(version, bookNum));
        final chapters = book.findAllElements('chapter');
        for (final chapterEl in chapters) {
          final chapNum = int.parse(chapterEl.getAttribute('number')!);
          final verses = chapterEl.findAllElements('verse');
          for (final verseEl in verses) {
            final text = verseEl.innerText;
            if (text.trim().isEmpty) continue;
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
