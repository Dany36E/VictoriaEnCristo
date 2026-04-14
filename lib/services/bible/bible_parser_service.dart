import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import 'bible_download_service.dart';

/// Top-level function para parsear XML en un Isolate
XmlDocument _parseXmlInIsolate(String xmlContent) {
  return XmlDocument.parse(xmlContent);
}

/// Nombres canónicos de los 66 libros de la Biblia, indexados por número (1-based).
const Map<int, String> _canonicalBookNames = {
  1: 'Génesis', 2: 'Éxodo', 3: 'Levítico', 4: 'Números', 5: 'Deuteronomio',
  6: 'Josué', 7: 'Jueces', 8: 'Rut', 9: '1 Samuel', 10: '2 Samuel',
  11: '1 Reyes', 12: '2 Reyes', 13: '1 Crónicas', 14: '2 Crónicas',
  15: 'Esdras', 16: 'Nehemías', 17: 'Ester', 18: 'Job', 19: 'Salmos',
  20: 'Proverbios', 21: 'Eclesiastés', 22: 'Cantares', 23: 'Isaías',
  24: 'Jeremías', 25: 'Lamentaciones', 26: 'Ezequiel', 27: 'Daniel',
  28: 'Oseas', 29: 'Joel', 30: 'Amós', 31: 'Abdías', 32: 'Jonás',
  33: 'Miqueas', 34: 'Nahúm', 35: 'Habacuc', 36: 'Sofonías', 37: 'Hageo',
  38: 'Zacarías', 39: 'Malaquías',
  40: 'Mateo', 41: 'Marcos', 42: 'Lucas', 43: 'Juan', 44: 'Hechos',
  45: 'Romanos', 46: '1 Corintios', 47: '2 Corintios', 48: 'Gálatas',
  49: 'Efesios', 50: 'Filipenses', 51: 'Colosenses',
  52: '1 Tesalonicenses', 53: '2 Tesalonicenses',
  54: '1 Timoteo', 55: '2 Timoteo', 56: 'Tito', 57: 'Filemón',
  58: 'Hebreos', 59: 'Santiago', 60: '1 Pedro', 61: '2 Pedro',
  62: '1 Juan', 63: '2 Juan', 64: '3 Juan', 65: 'Judas', 66: 'Apocalipsis',
};

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE PARSER SERVICE - Singleton
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// Estructura XML detectada (confirmada en los 5 archivos):
///   <bible translation="...">
///     <testament name="Old|Antiguo">
///       <book number="1" name="Génesis">
///         <chapter number="1">
///           <verse number="1">En el principio creó Dios...</verse>
///         </chapter>
///       </book>
///     </testament>
///     <testament name="New|Nuevo">
///       ...
///     </testament>
///   </bible>
///
/// Notas sobre los archivos:
/// - RVR1960 y TLA usan testament name="Old"/"New"
/// - NVI, LBLA, NTV usan testament name="Antiguo"/"Nuevo"
/// - Todos usan book number (1-based), chapter number, verse number
/// ═══════════════════════════════════════════════════════════════════════════
class BibleParserService {
  // ── Singleton ──
  static final BibleParserService _instance = BibleParserService._internal();
  factory BibleParserService() => _instance;
  static BibleParserService get I => _instance;
  BibleParserService._internal();

  // ── Estado ──
  bool _initialized = false;

  /// Metadata de libros por versión (cargado en init)
  final Map<BibleVersion, List<BibleBook>> _booksIndex = {};

  /// LRU Cache: "VERSION:bookNum:chapter" → List<BibleVerse>
  /// Mantiene máximo 20 capítulos en memoria
  static const int _maxCacheSize = 20;
  final LinkedHashMap<String, List<BibleVerse>> _chapterCache =
      LinkedHashMap<String, List<BibleVerse>>();

  /// Documentos XML parseados (lazy loaded, se mantienen en memoria por versión activa)
  final Map<BibleVersion, XmlDocument> _parsedDocs = {};

  // ══════════════════════════════════════════════════════════════════════════
  // INIT - Cargar índice de libros de la versión por defecto
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_initialized) return;
    // Pre-cargar el índice de RVR1960 (versión por defecto)
    await _ensureVersionLoaded(BibleVersion.rvr1960);
    _initialized = true;
    debugPrint('📖 [BIBLE] BibleParserService initialized (RVR1960 index ready)');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA
  // ══════════════════════════════════════════════════════════════════════════

  /// Obtener lista de libros de una versión
  Future<List<BibleBook>> getBooks(BibleVersion version) async {
    await _ensureVersionLoaded(version);
    return _booksIndex[version] ?? [];
  }

  /// Obtener los libros del AT
  Future<List<BibleBook>> getOldTestament(BibleVersion version) async {
    final books = await getBooks(version);
    return books.where((b) => b.testament == 'AT').toList();
  }

  /// Obtener los libros del NT
  Future<List<BibleBook>> getNewTestament(BibleVersion version) async {
    final books = await getBooks(version);
    return books.where((b) => b.testament == 'NT').toList();
  }

  /// Obtener versículos de un capítulo
  Future<List<BibleVerse>> getChapter({
    required BibleVersion version,
    required int bookNumber,
    required int chapter,
  }) async {
    final cacheKey = '${version.id}:$bookNumber:$chapter';

    // Check LRU cache
    if (_chapterCache.containsKey(cacheKey)) {
      // Move to end (most recently used)
      final data = _chapterCache.remove(cacheKey)!;
      _chapterCache[cacheKey] = data;
      return data;
    }

    // Parse from XML
    await _ensureVersionLoaded(version);
    final doc = _parsedDocs[version];
    if (doc == null) return [];

    final verses = _parseChapterFromDoc(doc, version, bookNumber, chapter);

    // Add to LRU cache
    _chapterCache[cacheKey] = verses;
    if (_chapterCache.length > _maxCacheSize) {
      _chapterCache.remove(_chapterCache.keys.first);
    }

    return verses;
  }

  /// Obtener un versículo específico
  Future<BibleVerse?> getVerse({
    required BibleVersion version,
    required int bookNumber,
    required int chapter,
    required int verse,
  }) async {
    final verses = await getChapter(
      version: version,
      bookNumber: bookNumber,
      chapter: chapter,
    );
    try {
      return verses.firstWhere((v) => v.verse == verse);
    } catch (e) {
      debugPrint('📖 [PARSER] getVerse not found: $e');
      return null;
    }
  }

  /// Obtener un versículo en múltiples versiones (para comparar).
  /// Carga TODAS las versiones en paralelo con timeout individual.
  Future<Map<BibleVersion, BibleVerse?>> getVerseInAllVersions({
    required int bookNumber,
    required int chapter,
    required int verse,
  }) async {
    final futures = BibleVersion.values.map((version) async {
      try {
        final result = await getVerse(
          version: version,
          bookNumber: bookNumber,
          chapter: chapter,
          verse: verse,
        ).timeout(const Duration(seconds: 8));
        return MapEntry(version, result);
      } catch (e) {
        debugPrint('📖 [BIBLE] getVerseInAllVersions: ${version.id} failed: $e');
        return MapEntry(version, null);
      }
    });
    final entries = await Future.wait(futures);
    return Map.fromEntries(entries);
  }

  /// Buscar versículos que contengan texto (búsqueda simple)
  Future<List<BibleVerse>> search({
    required BibleVersion version,
    required String query,
    int maxResults = 50,
  }) async {
    if (query.trim().length < 3) return [];
    await _ensureVersionLoaded(version);
    final doc = _parsedDocs[version];
    if (doc == null) return [];

    final results = <BibleVerse>[];
    final queryLower = query.toLowerCase();

    final testaments = doc.rootElement.findAllElements('testament');
    for (final testament in testaments) {
      final books = testament.findAllElements('book');
      for (final book in books) {
        final bookNum = int.parse(book.getAttribute('number')!);
        final bookName = book.getAttribute('name') ??
            _canonicalBookNames[bookNum] ??
            'Libro $bookNum';
        final chapters = book.findAllElements('chapter');
        for (final chapterEl in chapters) {
          final chapNum = int.parse(chapterEl.getAttribute('number')!);
          final verses = chapterEl.findAllElements('verse');
          for (final verseEl in verses) {
            final text = verseEl.innerText;
            if (text.toLowerCase().contains(queryLower)) {
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

  /// Obtener nombre de libro por número
  Future<String> getBookName(BibleVersion version, int bookNumber) async {
    final books = await getBooks(version);
    try {
      return books.firstWhere((b) => b.number == bookNumber).name;
    } catch (e) {
      debugPrint('📖 [PARSER] getBookName($bookNumber): $e');
      return 'Libro $bookNumber';
    }
  }

  /// Limpiar cache y documentos parseados
  void clearCache() {
    _chapterCache.clear();
    _parsedDocs.clear();
    debugPrint('📖 [BIBLE] Cache cleared');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PUBLIC ACCESSORS (para BibleSearchService)
  // ══════════════════════════════════════════════════════════════════════════

  /// Asegurar que una versión esté cargada y parseada.
  Future<void> ensureVersionLoaded(BibleVersion version) =>
      _ensureVersionLoaded(version);

  /// Obtener documento XML parseado (null si no está cargado).
  XmlDocument? getParsedDoc(BibleVersion version) => _parsedDocs[version];

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNOS
  // ══════════════════════════════════════════════════════════════════════════

  /// Decodificar bytes de XML con detección de encoding.
  /// Intenta UTF-8 primero, luego Latin-1, y finalmente UTF-8 tolerante.
  static String _decodeBytes(List<int> bytes, String label) {
    try {
      return utf8.decode(bytes);
    } catch (e) {
      debugPrint('📖 [PARSER] UTF-8 decode failed for $label: $e');
      try {
        debugPrint('📖 [BIBLE] $label: fallback to Latin-1 encoding');
        return latin1.decode(bytes);
      } catch (e) {
        debugPrint('📖 [BIBLE] $label: encoding error, using allowMalformed: $e');
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
  }

  /// Cargar y parsear un XML de versión si no está ya en memoria.
  /// Prioridad: archivo local descargado > asset bundle.
  /// Parseo en Isolate para no bloquear el UI thread.
  Future<void> _ensureVersionLoaded(BibleVersion version) async {
    if (_parsedDocs.containsKey(version)) return;

    final sw = Stopwatch()..start();
    debugPrint('📖 [BIBLE] Loading ${version.id}...');

    String xmlString;
    final localPath = BibleDownloadService.I.getLocalPath(version);
    if (localPath != null) {
      final file = File(localPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        xmlString = _decodeBytes(bytes, version.id);
        debugPrint('📖 [BIBLE] ${version.id} loaded from local storage');
      } else {
        final byteData = await rootBundle.load('assets/bible/${version.fileName}');
        xmlString = _decodeBytes(byteData.buffer.asUint8List(), version.id);
        debugPrint('📖 [BIBLE] ${version.id} loaded from assets (local file missing)');
      }
    } else {
      final byteData = await rootBundle.load('assets/bible/${version.fileName}');
      xmlString = _decodeBytes(byteData.buffer.asUint8List(), version.id);
      debugPrint('📖 [BIBLE] ${version.id} loaded from assets');
    }

    // Parsear XML en un Isolate para no bloquear UI
    final doc = await compute(_parseXmlInIsolate, xmlString);
    _parsedDocs[version] = doc;
    sw.stop();
    debugPrint('📖 [BIBLE] ${version.id} parsed in ${sw.elapsedMilliseconds}ms');

    // Build books index
    _booksIndex[version] = _buildBooksIndex(doc);
    debugPrint('📖 [BIBLE] ${version.id} loaded: ${_booksIndex[version]!.length} books');
  }

  /// Construir índice de libros desde el documento XML.
  /// Maneja XMLs con o sin atributo name en <book>.
  List<BibleBook> _buildBooksIndex(XmlDocument doc) {
    final books = <BibleBook>[];
    final testaments = doc.rootElement.findAllElements('testament');

    for (final testament in testaments) {
      final testName = testament.getAttribute('name') ?? '';
      // Manejar ambas convenciones: "Old"/"Antiguo" => AT, "New"/"Nuevo" => NT
      final isOT = testName == 'Old' || testName == 'Antiguo';
      final testCode = isOT ? 'AT' : 'NT';

      final bookElements = testament.findAllElements('book');
      for (final bookEl in bookElements) {
        final bookNum = int.parse(bookEl.getAttribute('number')!);
        // Usar atributo name si existe, sino usar nombre canónico por número
        final bookName = bookEl.getAttribute('name') ??
            _canonicalBookNames[bookNum] ??
            'Libro $bookNum';
        final chapters = bookEl.findAllElements('chapter');

        final versesPerChapter = <int, int>{};
        int totalChaps = 0;
        for (final chapterEl in chapters) {
          totalChaps++;
          final chapNum = int.parse(chapterEl.getAttribute('number')!);
          final verseCount = chapterEl.findAllElements('verse').length;
          versesPerChapter[chapNum] = verseCount;
        }

        books.add(BibleBook(
          number: bookNum,
          name: bookName,
          testament: testCode,
          totalChapters: totalChaps,
          versesPerChapter: versesPerChapter,
        ));
      }
    }
    return books;
  }

  /// Parsear versículos de un capítulo específico
  List<BibleVerse> _parseChapterFromDoc(
    XmlDocument doc,
    BibleVersion version,
    int bookNumber,
    int chapter,
  ) {
    final verses = <BibleVerse>[];
    final testaments = doc.rootElement.findAllElements('testament');

    for (final testament in testaments) {
      final bookElements = testament.findAllElements('book');
      for (final bookEl in bookElements) {
        if (int.parse(bookEl.getAttribute('number')!) != bookNumber) continue;

        final bookName = bookEl.getAttribute('name') ??
            _canonicalBookNames[bookNumber] ??
            'Libro $bookNumber';
        final chapters = bookEl.findAllElements('chapter');
        for (final chapterEl in chapters) {
          if (int.parse(chapterEl.getAttribute('number')!) != chapter) continue;

          final verseElements = chapterEl.findAllElements('verse');
          for (final verseEl in verseElements) {
            final text = verseEl.innerText;
            if (text.trim().isEmpty) continue; // Saltar versículos vacíos
            verses.add(BibleVerse(
              bookName: bookName,
              bookNumber: bookNumber,
              chapter: chapter,
              verse: int.parse(verseEl.getAttribute('number')!),
              text: text,
              version: version.id,
            ));
          }
          return verses;
        }
        return verses; // Book found but chapter not
      }
    }
    return verses;
  }
}
