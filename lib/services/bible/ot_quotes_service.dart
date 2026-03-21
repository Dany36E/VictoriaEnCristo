import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/ot_quote.dart';

/// Servicio para citas del Antiguo Testamento en el Nuevo.
/// Carga lazy desde assets, indexa por libro NT y OT.
class OTQuotesService {
  OTQuotesService._();
  static final instance = OTQuotesService._();

  List<OTQuote>? _quotes;
  bool _loaded = false;

  // Índices para búsqueda rápida
  Map<String, List<OTQuote>>? _byNTBook; // "MAT" → quotes
  Map<String, List<OTQuote>>? _byOTBook; // "ISA" → quotes

  /// Todas las citas.
  Future<List<OTQuote>> getAll() async {
    await _ensureLoaded();
    return _quotes ?? [];
  }

  /// Citas donde el versículo NT cae en book.chapter.
  Future<List<OTQuote>> getForNTReference(int bookNumber, int chapter) async {
    await _ensureLoaded();
    final code = _bookCode(bookNumber);
    if (code == null) return [];
    final prefix = '$code.$chapter';
    return (_byNTBook?[code] ?? [])
        .where((q) => q.ntReference.startsWith(prefix))
        .toList();
  }

  /// Citas donde el versículo OT cae en book.chapter.
  Future<List<OTQuote>> getForOTReference(int bookNumber, int chapter) async {
    await _ensureLoaded();
    final code = _bookCode(bookNumber);
    if (code == null) return [];
    final prefix = '$code.$chapter';
    return (_byOTBook?[code] ?? [])
        .where((q) => q.otReference.startsWith(prefix))
        .toList();
  }

  /// Citas para un libro NT completo.
  Future<List<OTQuote>> getForNTBook(int bookNumber) async {
    await _ensureLoaded();
    final code = _bookCode(bookNumber);
    if (code == null) return [];
    return _byNTBook?[code] ?? [];
  }

  /// Buscar por contexto o significado.
  Future<List<OTQuote>> search(String query) async {
    await _ensureLoaded();
    final q = query.toLowerCase();
    return (_quotes ?? []).where((qt) {
      return qt.context.toLowerCase().contains(q) ||
          qt.significance.toLowerCase().contains(q);
    }).toList();
  }

  /// Cuenta total de citas.
  Future<int> get totalCount async {
    await _ensureLoaded();
    return _quotes?.length ?? 0;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final raw = await rootBundle.loadString(
        'assets/bible/quotes/ot_quotes_in_nt.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = json['quotes'] as List<dynamic>;
      int idx = 0;
      _quotes = list.map((e) {
        final m = e as Map<String, dynamic>;
        // Generar id si no existe
        m.putIfAbsent('id', () => 'q_${idx++}');
        return OTQuote.fromJson(m);
      }).toList();

      // Construir índices
      _byNTBook = {};
      _byOTBook = {};
      for (final q in _quotes!) {
        final ntBook = q.ntReference.split('.').first;
        final otBook = q.otReference.split('.').first;
        _byNTBook!.putIfAbsent(ntBook, () => []).add(q);
        _byOTBook!.putIfAbsent(otBook, () => []).add(q);
      }
    } catch (e) {
      debugPrint('OTQuotesService: error loading: $e');
      _quotes = [];
    }
  }

  static String? _bookCode(int num) => const {
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
  }[num];
}
