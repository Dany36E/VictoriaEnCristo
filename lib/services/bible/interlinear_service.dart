import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/interlinear_word.dart';
import '../../utils/morph_decoder.dart';

/// Servicio para datos interlineales griego/hebreo.
/// Carga lazy por libro – mantiene un solo libro en cache.
class InterlinearService {
  InterlinearService._();
  static final instance = InterlinearService._();

  String? _cachedBookCode;
  Map<String, InterlinearVerse>? _cachedVerses; // key: "c:v"

  /// Mapa bookNumber (1-66) → código de archivo interlineal.
  static const _bookNumberToFileCode = <int, String>{
    1: 'GEN', 2: 'EXO', 3: 'LEV', 4: 'NUM', 5: 'DEU',
    6: 'JOS', 7: 'JDG', 8: 'RUT', 9: '1SA', 10: '2SA',
    11: '1KI', 12: '2KI', 13: '1CH', 14: '2CH', 15: 'EZR',
    16: 'NEH', 17: 'EST', 18: 'JOB', 19: 'PSA', 20: 'PRO',
    21: 'ECC', 22: 'SNG', 23: 'ISA', 24: 'JER', 25: 'LAM',
    26: 'EZK', 27: 'DAN', 28: 'HOS', 29: 'JOL', 30: 'AMO',
    31: 'OBA', 32: 'JON', 33: 'MIC', 34: 'NAM', 35: 'HAB',
    36: 'ZEP', 37: 'HAG', 38: 'ZEC', 39: 'MAL',
    40: 'MAT', 41: 'MRK', 42: 'LUK', 43: 'JHN', 44: 'ACT',
    45: 'ROM', 46: '1CO', 47: '2CO', 48: 'GAL', 49: 'EPH',
    50: 'PHP', 51: 'COL', 52: '1TH', 53: '2TH', 54: '1TI',
    55: '2TI', 56: 'TIT', 57: 'PHM', 58: 'HEB', 59: 'JAS',
    60: '1PE', 61: '2PE', 62: '1JN', 63: '2JN', 64: '3JN',
    65: 'JUD', 66: 'REV',
  };

  /// Obtiene el código de archivo para un número de libro.
  static String? getFileCode(int bookNumber) =>
      _bookNumberToFileCode[bookNumber];

  /// True si el libro es del AT (hebreo), false si es NT (griego).
  static bool isOT(int bookNumber) => bookNumber <= 39;

  /// Obtiene datos interlineales para un versículo específico.
  /// Retorna null si no hay datos disponibles.
  Future<InterlinearVerse?> getVerse(
    int bookNumber,
    int chapter,
    int verse,
  ) async {
    final code = _bookNumberToFileCode[bookNumber];
    if (code == null) return null;

    await _ensureBookLoaded(bookNumber, code);
    return _cachedVerses?['$chapter:$verse'];
  }

  /// Obtiene datos interlineales para todos los versículos de un capítulo.
  Future<List<InterlinearVerse>> getChapter(
    int bookNumber,
    int chapter,
  ) async {
    final code = _bookNumberToFileCode[bookNumber];
    if (code == null) return [];

    await _ensureBookLoaded(bookNumber, code);
    if (_cachedVerses == null) return [];

    return _cachedVerses!.entries
        .where((e) => e.key.startsWith('$chapter:'))
        .map((e) => e.value)
        .toList()
      ..sort((a, b) => a.verse.compareTo(b.verse));
  }

  Future<void> _ensureBookLoaded(int bookNumber, String code) async {
    if (_cachedBookCode == code) return;

    final ot = isOT(bookNumber);
    final dir = ot ? 'hebrew' : 'greek';
    final path = 'assets/bible/interlinear/$dir/$code.json';

    try {
      final raw = await rootBundle.loadString(path);
      final parsed = await compute(_parseBookData, _ParseArgs(raw, code, ot));
      _cachedBookCode = code;
      _cachedVerses = parsed;
    } catch (e) {
      debugPrint('InterlinearService: Error cargando $path: $e');
      _cachedBookCode = code;
      _cachedVerses = {};
    }
  }

  /// Limpia la cache (para liberar memoria).
  void clearCache() {
    _cachedBookCode = null;
    _cachedVerses = null;
  }
}

class _ParseArgs {
  final String json;
  final String bookCode;
  final bool isOT;
  const _ParseArgs(this.json, this.bookCode, this.isOT);
}

/// Parsea JSON en un isolate para no bloquear el UI.
Map<String, InterlinearVerse> _parseBookData(_ParseArgs args) {
  final list = jsonDecode(args.json) as List;
  final result = <String, InterlinearVerse>{};

  for (final entry in list) {
    final map = entry as Map<String, dynamic>;
    final chapter = map['c'] as int;
    final verse = map['v'] as int;
    final rawWords = map['w'] as List;

    final words = rawWords.map((w) {
      final wm = w as Map<String, dynamic>;
      final morphCode = wm['m'] as String? ?? '';
      final strongRaw = wm['s'] as String?;
      final String? strongNumber;
      if (strongRaw != null && strongRaw.isNotEmpty) {
        strongNumber = args.isOT ? 'H$strongRaw' : 'G$strongRaw';
      } else {
        strongNumber = null;
      }

      return InterlinearWord(
        position: wm['p'] as int,
        originalWord: wm['o'] as String? ?? '',
        lemma: wm['l'] as String?,
        strongNumber: strongNumber,
        morphCode: morphCode,
        gloss: wm['g'] as String? ?? '',
        morphAnalysis: MorphDecoder.decode(morphCode),
      );
    }).toList();

    result['$chapter:$verse'] = InterlinearVerse(
      bookCode: args.bookCode,
      chapter: chapter,
      verse: verse,
      words: words,
    );
  }

  return result;
}
