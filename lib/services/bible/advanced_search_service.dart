import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/bible_version.dart';
import '../user_pref_cloud_sync_service.dart';
import 'bible_parser_service.dart';
import 'interlinear_service.dart';
import 'bible_timeline_service.dart';

/// Tipo de búsqueda avanzada
enum AdvancedSearchType {
  strong, // Búsqueda por número Strong (H/G)
  character, // Búsqueda por personaje bíblico
  theme, // Búsqueda por tema/tópico
}

/// Resultado de búsqueda avanzada
class AdvancedSearchResult {
  final String title;
  final String subtitle;
  final List<AdvancedSearchVerse> verses;
  final AdvancedSearchType type;

  const AdvancedSearchResult({
    required this.title,
    required this.subtitle,
    required this.verses,
    required this.type,
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
  static final AdvancedSearchService _instance = AdvancedSearchService._internal();
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
    'Salvación': ['salvación', 'salvar', 'salvó', 'salvador', 'redención', 'redentor'],
    'Perdón': ['perdón', 'perdonar', 'perdonó', 'perdonado'],
    'Oración': ['oración', 'orar', 'orad', 'oró', 'oremos', 'oraba', 'clamó'],
    'Paz': ['paz', 'pacífico', 'pacifica', 'reposo', 'descanso'],
    'Justicia': ['justicia', 'justo', 'justos', 'juzgar', 'juicio'],
    'Sabiduría': ['sabiduría', 'sabio', 'sabios', 'prudencia', 'entendimiento'],
    'Santidad': ['santo', 'santos', 'santidad', 'santificar', 'santificado'],
    'Gozo': ['gozo', 'gozoso', 'alegría', 'regocijo', 'gózate'],
    'Pecado': ['pecado', 'pecados', 'pecar', 'pecó', 'iniquidad', 'transgresión'],
    'Arrepentimiento': ['arrepentimiento', 'arrepentir', 'arrepentíos', 'arrepintió'],
    'Espíritu Santo': ['espíritu santo', 'espíritu de dios', 'consolador', 'paráclito'],
    'Resurrección': ['resurrección', 'resucitar', 'resucitó', 'levantó'],
    'Cielo': ['cielo', 'cielos', 'celestial', 'paraíso', 'morada'],
    'Tentación': ['tentación', 'tentar', 'tentado', 'prueba'],
    'Fortaleza': ['fortaleza', 'fuerte', 'fuerza', 'fortaleceos', 'esfuérzate'],
    'Adoración': ['adoración', 'adorar', 'adorad', 'adoró', 'alabanza', 'alabar'],
  };

  /// Lista de temas disponibles
  List<String> get availableThemes => _themes.keys.toList();

  /// Buscar por número Strong
  Future<AdvancedSearchResult> searchByStrong(String strongNumber, BibleVersion version) async {
    final isHebrew = strongNumber.startsWith('H');
    final results = <AdvancedSearchVerse>[];

    // Buscar en interlinear data
    try {
      final startBook = isHebrew ? 1 : 40;
      final endBook = isHebrew ? 39 : 66;

      for (int book = startBook; book <= endBook; book++) {
        // Get chapter count from book index
        final books = await BibleParserService.I.getBooks(version);
        final bookInfo = books.where((b) => b.number == book).firstOrNull;
        if (bookInfo == null) continue;

        for (int ch = 1; ch <= bookInfo.totalChapters; ch++) {
          final interlinearVerses = await InterlinearService.instance.getChapter(book, ch);
          for (final iv in interlinearVerses) {
            final hasStrong = iv.words.any(
              (w) =>
                  w.strongNumber != null &&
                  (w.strongNumber == strongNumber || w.strongNumber!.contains(strongNumber)),
            );

            if (hasStrong) {
              results.add(
                AdvancedSearchVerse(
                  bookNumber: book,
                  bookName: bookInfo.name,
                  chapter: ch,
                  verse: iv.verse,
                  text: '',
                  highlight: strongNumber,
                ),
              );
            }
          }
        }

        if (results.length >= 200) break;
      }
    } catch (e) {
      debugPrint('🔍 [ADV-SEARCH] Strong error: $e');
    }

    return AdvancedSearchResult(
      title: strongNumber,
      subtitle: '${results.length} apariciones',
      verses: results,
      type: AdvancedSearchType.strong,
    );
  }

  /// Buscar versículos relacionados con un personaje
  Future<AdvancedSearchResult> searchByCharacter(String characterName, BibleVersion version) async {
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
          final matchedKeyword = keywords.where((k) => lower.contains(k)).firstOrNull;
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
