import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Treasury of Scripture Knowledge — 340,000+ referencias cruzadas.
/// Carga lazy por libro, una sola cache.
class TreasuryService {
  TreasuryService._();
  static final instance = TreasuryService._();

  String? _cachedBookCode;
  Map<String, List<String>>? _cachedRefs; // key: "chapter:verse"
  Completer<void>? _loadCompleter;

  static const _bookCodes = <int, String>{
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

  static const _codeToNumber = <String, int>{
    'GEN': 1, 'EXO': 2, 'LEV': 3, 'NUM': 4, 'DEU': 5,
    'JOS': 6, 'JDG': 7, 'RUT': 8, '1SA': 9, '2SA': 10,
    '1KI': 11, '2KI': 12, '1CH': 13, '2CH': 14, 'EZR': 15,
    'NEH': 16, 'EST': 17, 'JOB': 18, 'PSA': 19, 'PRO': 20,
    'ECC': 21, 'SNG': 22, 'ISA': 23, 'JER': 24, 'LAM': 25,
    'EZK': 26, 'DAN': 27, 'HOS': 28, 'JOL': 29, 'AMO': 30,
    'OBA': 31, 'JON': 32, 'MIC': 33, 'NAM': 34, 'HAB': 35,
    'ZEP': 36, 'HAG': 37, 'ZEC': 38, 'MAL': 39,
    'MAT': 40, 'MRK': 41, 'LUK': 42, 'JHN': 43, 'ACT': 44,
    'ROM': 45, '1CO': 46, '2CO': 47, 'GAL': 48, 'EPH': 49,
    'PHP': 50, 'COL': 51, '1TH': 52, '2TH': 53, '1TI': 54,
    '2TI': 55, 'TIT': 56, 'PHM': 57, 'HEB': 58, 'JAS': 59,
    '1PE': 60, '2PE': 61, '1JN': 62, '2JN': 63, '3JN': 64,
    'JUD': 65, 'REV': 66,
  };

  /// Nombres en español para mostrar.
  static const _bookNames = <String, String>{
    'GEN': 'Génesis', 'EXO': 'Éxodo', 'LEV': 'Levítico',
    'NUM': 'Números', 'DEU': 'Deuteronomio', 'JOS': 'Josué',
    'JDG': 'Jueces', 'RUT': 'Rut', '1SA': '1 Samuel',
    '2SA': '2 Samuel', '1KI': '1 Reyes', '2KI': '2 Reyes',
    '1CH': '1 Crónicas', '2CH': '2 Crónicas', 'EZR': 'Esdras',
    'NEH': 'Nehemías', 'EST': 'Ester', 'JOB': 'Job',
    'PSA': 'Salmos', 'PRO': 'Proverbios', 'ECC': 'Eclesiastés',
    'SNG': 'Cantares', 'ISA': 'Isaías', 'JER': 'Jeremías',
    'LAM': 'Lamentaciones', 'EZK': 'Ezequiel', 'DAN': 'Daniel',
    'HOS': 'Oseas', 'JOL': 'Joel', 'AMO': 'Amós',
    'OBA': 'Abdías', 'JON': 'Jonás', 'MIC': 'Miqueas',
    'NAM': 'Nahúm', 'HAB': 'Habacuc', 'ZEP': 'Sofonías',
    'HAG': 'Hageo', 'ZEC': 'Zacarías', 'MAL': 'Malaquías',
    'MAT': 'Mateo', 'MRK': 'Marcos', 'LUK': 'Lucas',
    'JHN': 'Juan', 'ACT': 'Hechos', 'ROM': 'Romanos',
    '1CO': '1 Corintios', '2CO': '2 Corintios', 'GAL': 'Gálatas',
    'EPH': 'Efesios', 'PHP': 'Filipenses', 'COL': 'Colosenses',
    '1TH': '1 Tesalonicenses', '2TH': '2 Tesalonicenses',
    '1TI': '1 Timoteo', '2TI': '2 Timoteo', 'TIT': 'Tito',
    'PHM': 'Filemón', 'HEB': 'Hebreos', 'JAS': 'Santiago',
    '1PE': '1 Pedro', '2PE': '2 Pedro', '1JN': '1 Juan',
    '2JN': '2 Juan', '3JN': '3 Juan', 'JUD': 'Judas',
    'REV': 'Apocalipsis',
  };

  /// Obtiene texto legible de una referencia TSK (ej: "ROM.8.28" → "Romanos 8:28")
  static String formatReference(String ref) {
    final parts = ref.split('.');
    if (parts.length < 3) return ref;
    final bookName = _bookNames[parts[0]] ?? parts[0];
    return '$bookName ${parts[1]}:${parts[2]}';
  }

  /// Parsea referencia TSK a (bookNumber, chapter, verse).
  static ({int bookNumber, int chapter, int verse})? parseReference(
      String ref) {
    final parts = ref.split('.');
    if (parts.length < 3) return null;
    final bookNum = _codeToNumber[parts[0]];
    if (bookNum == null) return null;
    final chapter = int.tryParse(parts[1]);
    final verse = int.tryParse(parts[2]);
    if (chapter == null || verse == null) return null;
    return (bookNumber: bookNum, chapter: chapter, verse: verse);
  }

  /// Obtiene referencias cruzadas para un versículo.
  Future<List<String>> getCrossReferences(
    int bookNumber,
    int chapter,
    int verse,
  ) async {
    final code = _bookCodes[bookNumber];
    if (code == null) return [];

    await _ensureBookLoaded(code);
    return _cachedRefs?['$chapter:$verse'] ?? [];
  }

  /// Cuenta de referencias disponibles para un versículo (sin cargar todo).
  Future<int> getReferenceCount(
    int bookNumber,
    int chapter,
    int verse,
  ) async {
    final refs = await getCrossReferences(bookNumber, chapter, verse);
    return refs.length;
  }

  Future<void> _ensureBookLoaded(String code) async {
    if (_cachedBookCode == code) return;

    // Si ya hay una carga en vuelo, esperar
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      await _loadCompleter!.future;
      if (_cachedBookCode == code) return;
    }
    _loadCompleter = Completer<void>();

    final path = 'assets/bible/cross_refs/tsk_$code.json';
    try {
      final raw = await rootBundle.loadString(path);
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final refs = <String, List<String>>{};

      for (final entry in data.entries) {
        refs[entry.key] =
            (entry.value as List).map((e) => e.toString()).toList();
      }

      _cachedBookCode = code;
      _cachedRefs = refs;
    } catch (e) {
      debugPrint('TreasuryService: Error cargando $path: $e');
      _cachedBookCode = code;
      _cachedRefs = {};
    }
    _loadCompleter!.complete();
  }
}
