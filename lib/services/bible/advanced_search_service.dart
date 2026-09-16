import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/strong_lexicon_entry.dart';
import '../user_pref_cloud_sync_service.dart';
import 'bible_parser_service.dart';
import 'bible_timeline_service.dart';
import 'strong_lexicon_service.dart';

/// Tipo de búsqueda avanzada
enum AdvancedSearchType {
  strong, // Búsqueda por número Strong (H/G)
  originalWord, // Forma original o lema en hebreo/griego
  character, // Búsqueda por personaje bíblico
  theme, // Búsqueda por tema/tópico
}

/// Resultado de búsqueda avanzada
class AdvancedSearchResult {
  final String title;
  final String subtitle;
  final List<AdvancedSearchVerse> verses;
  final AdvancedSearchType type;
  final String? description;

  const AdvancedSearchResult({
    required this.title,
    required this.subtitle,
    required this.verses,
    required this.type,
    this.description,
  });
}

/// Versículo encontrado en búsqueda avanzada
class AdvancedSearchVerse {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int verse;
  final String text;
  final String? highlight; // Fragmento resaltado

  const AdvancedSearchVerse({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.text,
    this.highlight,
  });

  String get reference => '$bookName $chapter:$verse';
}

/// ═══════════════════════════════════════════════════════════════════════════
/// ADVANCED SEARCH SERVICE - Singleton
/// Búsqueda por números Strong, personajes y temas.
/// ═══════════════════════════════════════════════════════════════════════════
class AdvancedSearchService {
  static final AdvancedSearchService _instance =
      AdvancedSearchService._internal();
  factory AdvancedSearchService() => _instance;
  static AdvancedSearchService get I => _instance;
  AdvancedSearchService._internal();

  static const _historyKey = 'advanced_search_history';
  static const int _maxHistory = 20;

  /// Historial de búsquedas avanzadas
  Future<List<String>> getSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_historyKey) ?? [];
  }

  Future<void> addToHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? [];
    list.remove(query);
    list.insert(0, query);
    if (list.length > _maxHistory) list.removeLast();
    await prefs.setStringList(_historyKey, list);
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_historyKey) ?? [];
    list.remove(query);
    await prefs.setStringList(_historyKey, list);
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    UserPrefCloudSyncService.I.markDirty();
  }

  // Temas predefinidos con palabras clave en español
  static const Map<String, List<String>> _themes = {
    'Amor': ['amor', 'amó', 'ama', 'amado', 'amar', 'amados'],
    'Fe': ['fe', 'creer', 'creyó', 'creyeron', 'fiel', 'fieles', 'confianza'],
    'Esperanza': ['esperanza', 'esperar', 'espera', 'esperamos'],
    'Gracia': ['gracia', 'misericordia', 'compasión', 'favor'],
    'Salvación': [
      'salvación',
      'salvar',
      'salvó',
      'salvador',
      'redención',
      'redentor',
    ],
    'Perdón': ['perdón', 'perdonar', 'perdonó', 'perdonado'],
    'Oración': ['oración', 'orar', 'orad', 'oró', 'oremos', 'oraba', 'clamó'],
    'Paz': ['paz', 'pacífico', 'pacifica', 'reposo', 'descanso'],
    'Justicia': ['justicia', 'justo', 'justos', 'juzgar', 'juicio'],
    'Sabiduría': ['sabiduría', 'sabio', 'sabios', 'prudencia', 'entendimiento'],
    'Santidad': ['santo', 'santos', 'santidad', 'santificar', 'santificado'],
    'Gozo': ['gozo', 'gozoso', 'alegría', 'regocijo', 'gózate'],
    'Pecado': [
      'pecado',
      'pecados',
      'pecar',
      'pecó',
      'iniquidad',
      'transgresión',
    ],
    'Arrepentimiento': [
      'arrepentimiento',
      'arrepentir',
      'arrepentíos',
      'arrepintió',
    ],
    'Espíritu Santo': [
      'espíritu santo',
      'espíritu de dios',
      'consolador',
      'paráclito',
    ],
    'Resurrección': ['resurrección', 'resucitar', 'resucitó', 'levantó'],
    'Cielo': ['cielo', 'cielos', 'celestial', 'paraíso', 'morada'],
    'Tentación': ['tentación', 'tentar', 'tentado', 'prueba'],
    'Fortaleza': ['fortaleza', 'fuerte', 'fuerza', 'fortaleceos', 'esfuérzate'],
    'Adoración': [
      'adoración',
      'adorar',
      'adorad',
      'adoró',
      'alabanza',
      'alabar',
    ],
  };

  /// Lista de temas disponibles
  List<String> get availableThemes => _themes.keys.toList();

  /// Buscar por número Strong
  Future<AdvancedSearchResult> searchByStrong(
    String strongNumber,
    BibleVersion version,
  ) async {
    final result = await StrongLexiconService.I.search(strongNumber);
    return _buildOriginalLanguageResult(
      result,
      version,
      AdvancedSearchType.strong,
    );
  }

  /// Busca una forma escrita o lema en todos los versículos del interlineal.
  Future<AdvancedSearchResult> searchByOriginalWord(
    String query,
    BibleVersion version,
  ) async {
    final result = await StrongLexiconService.I.search(query);
    return _buildOriginalLanguageResult(
      result,
      version,
      AdvancedSearchType.originalWord,
    );
  }

  Future<AdvancedSearchResult> _buildOriginalLanguageResult(
    OriginalWordSearchResult result,
    BibleVersion version,
    AdvancedSearchType type,
  ) async {
    const visibleLimit = 500;
    final books = await BibleParserService.I.getBooks(version);
    final bookNames = <int, String>{
      for (final book in books) book.number: book.name,
    };
    final verses = <AdvancedSearchVerse>[];
    final chapterCache = <String, Map<int, String>>{};

    for (final reference in result.references.take(visibleLimit)) {
      final chapterKey = '${reference.bookNumber}:${reference.chapter}';
      var verseTexts = chapterCache[chapterKey];
      if (verseTexts == null) {
        final chapter = await BibleParserService.I.getChapter(
          version: version,
          bookNumber: reference.bookNumber,
          chapter: reference.chapter,
        );
        verseTexts = <int, String>{
          for (final verse in chapter) verse.verse: verse.text,
        };
        chapterCache[chapterKey] = verseTexts;
      }
      verses.add(
        AdvancedSearchVerse(
          bookNumber: reference.bookNumber,
          bookName:
              bookNames[reference.bookNumber] ??
              'Libro ${reference.bookNumber}',
          chapter: reference.chapter,
          verse: reference.verse,
          text: verseTexts[reference.verse] ?? '',
          highlight: '',
        ),
      );
    }

    final total = result.occurrenceCount;
    final shown = verses.length;
    final strongLabel = result.strongNumbers.isEmpty
        ? ''
        : ' · ${result.strongNumbers.join(', ')}';
    final lexical = result.lexiconEntries.firstOrNull;
    final details = <String>[
      if (lexical?.transliteration.isNotEmpty == true)
        'Transliteración: ${lexical!.transliteration}',
      if (lexical?.definition.isNotEmpty == true)
        'Definición histórica Strong (inglés): ${lexical!.definition}',
    ];

    return AdvancedSearchResult(
      title: '${result.displayWord}$strongLabel',
      subtitle: total > shown
          ? '$total versículos · mostrando los primeros $shown'
          : '$total versículo${total == 1 ? '' : 's'}',
      description: details.isEmpty ? null : details.join('\n'),
      verses: verses,
      type: type,
    );
  }

  /// Buscar versículos relacionados con un personaje
  Future<AdvancedSearchResult> searchByCharacter(
    String characterName,
    BibleVersion version,
  ) async {
    await BibleTimelineService.I.init();
    final results = <AdvancedSearchVerse>[];

    final q = characterName.toLowerCase();
    final books = await BibleParserService.I.getBooks(version);

    for (final book in books) {
      for (int ch = 1; ch <= book.totalChapters; ch++) {
        final verses = await BibleParserService.I.getChapter(
          version: version,
          bookNumber: book.number,
          chapter: ch,
        );
        for (final v in verses) {
          if (v.text.toLowerCase().contains(q)) {
            results.add(
              AdvancedSearchVerse(
                bookNumber: v.bookNumber,
                bookName: v.bookName,
                chapter: v.chapter,
                verse: v.verse,
                text: v.text,
                highlight: characterName,
              ),
            );
          }
        }
        if (results.length >= 200) break;
      }
      if (results.length >= 200) break;
    }

    return AdvancedSearchResult(
      title: characterName,
      subtitle: '${results.length} versículos relacionados',
      verses: results,
      type: AdvancedSearchType.character,
    );
  }

  /// Buscar por tema predefinido
  Future<AdvancedSearchResult> searchByTheme(
    String themeName,
    BibleVersion version, {
    String? testamentFilter,
    int? startBook,
    int? endBook,
  }) async {
    final keywords = _themes[themeName];
    if (keywords == null) {
      return AdvancedSearchResult(
        title: themeName,
        subtitle: 'Tema no encontrado',
        verses: [],
        type: AdvancedSearchType.theme,
      );
    }

    final results = <AdvancedSearchVerse>[];
    final books = await BibleParserService.I.getBooks(version);

    final filteredBooks = books.where((b) {
      if (startBook != null && b.number < startBook) return false;
      if (endBook != null && b.number > endBook) return false;
      if (testamentFilter == 'AT') return b.number < 40;
      if (testamentFilter == 'NT') return b.number >= 40;
      return true;
    });

    for (final book in filteredBooks) {
      for (int ch = 1; ch <= book.totalChapters; ch++) {
        final verses = await BibleParserService.I.getChapter(
          version: version,
          bookNumber: book.number,
          chapter: ch,
        );
        for (final v in verses) {
          final lower = v.text.toLowerCase();
          final matchedKeyword = keywords
              .where((k) => lower.contains(k))
              .firstOrNull;
          if (matchedKeyword != null) {
            results.add(
              AdvancedSearchVerse(
                bookNumber: v.bookNumber,
                bookName: v.bookName,
                chapter: v.chapter,
                verse: v.verse,
                text: v.text,
                highlight: matchedKeyword,
              ),
            );
          }
        }
        if (results.length >= 300) break;
      }
      if (results.length >= 300) break;
    }

    return AdvancedSearchResult(
      title: themeName,
      subtitle: '${results.length} versículos sobre $themeName',
      verses: results,
      type: AdvancedSearchType.theme,
    );
  }
}
