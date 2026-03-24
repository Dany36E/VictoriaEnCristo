import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/typology.dart';

/// Servicio para tipologías AT → NT.
/// Carga lazy desde assets, cache en memoria.
class TypologyService {
  TypologyService._();
  static final instance = TypologyService._();

  List<Typology>? _typologies;
  Completer<void>? _loadCompleter;

  /// Todas las tipologías.
  Future<List<Typology>> getAll() async {
    await _ensureLoaded();
    return _typologies ?? [];
  }

  /// Tipologías que incluyen una referencia OSIS dada (parcial match).
  /// Ejemplo: "GEN.22" matchea "GEN.22.1-14".
  Future<List<Typology>> getForReference(String osisRef) async {
    await _ensureLoaded();
    return (_typologies ?? []).where((t) {
      return t.oldTestament.reference.startsWith(osisRef) ||
          t.newTestament.reference.startsWith(osisRef);
    }).toList();
  }

  /// Tipologías donde el AT o NT cae en book.chapter.
  Future<List<Typology>> getForBookChapter(int bookNumber, int chapter) async {
    await _ensureLoaded();
    final bookCode = _bookCode(bookNumber);
    if (bookCode == null) return [];
    final prefix = '$bookCode.$chapter';
    return (_typologies ?? []).where((t) {
      return t.oldTestament.reference.startsWith(prefix) ||
          t.newTestament.reference.startsWith(prefix);
    }).toList();
  }

  /// Buscar por título, descripción o tags.
  Future<List<Typology>> search(String query) async {
    await _ensureLoaded();
    final q = query.toLowerCase();
    return (_typologies ?? []).where((t) {
      return t.title.toLowerCase().contains(q) ||
          t.description.toLowerCase().contains(q) ||
          t.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
  }

  /// Obtener todos los tags únicos.
  Future<List<String>> getAllTags() async {
    await _ensureLoaded();
    final tags = <String>{};
    for (final t in _typologies ?? <Typology>[]) {
      tags.addAll(t.tags);
    }
    return tags.toList()..sort();
  }

  Future<void> _ensureLoaded() async {
    if (_loadCompleter != null) return _loadCompleter!.future;
    _loadCompleter = Completer<void>();

    try {
      final raw = await rootBundle.loadString(
        'assets/bible/typology/typologies.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = json['typologies'] as List<dynamic>;
      _typologies = list
          .map((e) => Typology.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('TypologyService: error loading: $e');
      _typologies = [];
    }
    _loadCompleter!.complete();
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
