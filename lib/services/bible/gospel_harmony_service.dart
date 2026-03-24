import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/harmony_section.dart';

/// Servicio para la Armonía de los Evangelios.
/// Carga lazy desde assets, cache en memoria.
class GospelHarmonyService {
  GospelHarmonyService._();
  static final instance = GospelHarmonyService._();

  List<HarmonySection>? _sections;
  Completer<void>? _loadCompleter;

  /// Todas las secciones.
  Future<List<HarmonySection>> getAllSections() async {
    await _ensureLoaded();
    return _sections ?? [];
  }

  /// Secciones agrupadas por categoría.
  Future<Map<String, List<HarmonySection>>> getByCategory() async {
    await _ensureLoaded();
    final map = <String, List<HarmonySection>>{};
    for (final s in _sections ?? <HarmonySection>[]) {
      map.putIfAbsent(s.category, () => []).add(s);
    }
    return map;
  }

  /// Categorías en orden de aparición.
  Future<List<String>> getCategories() async {
    await _ensureLoaded();
    final seen = <String>{};
    final list = <String>[];
    for (final s in _sections ?? <HarmonySection>[]) {
      if (seen.add(s.category)) list.add(s.category);
    }
    return list;
  }

  /// Secciones que cubren un libro+capítulo específico (MAT=40..JHN=43).
  Future<List<HarmonySection>> getSectionsForReference(
      int bookNumber, int chapter) async {
    await _ensureLoaded();
    if (bookNumber < 40 || bookNumber > 43) return [];
    final gospelKey = const {40: 'matthew', 41: 'mark', 42: 'luke', 43: 'john'}[bookNumber]!;
    return (_sections ?? []).where((s) {
      final ref = s.references[gospelKey];
      if (ref == null) return false;
      // ref format: "MAT.5.1-7.29" or "MAT.5.1-12"
      final parts = ref.split('.');
      if (parts.length < 2) return false;
      final startCh = int.tryParse(parts[1].split('-').first) ?? 0;
      // Check end chapter for ranges like "MAT.5.1-7.29"
      int endCh = startCh;
      if (parts.length >= 3) {
        final lastPart = parts.last;
        if (lastPart.contains('-')) {
          // e.g. "1-7.29" → check if range crosses chapters
          final rangeParts = ref.split('-');
          if (rangeParts.length == 2 && rangeParts[1].contains('.')) {
            endCh = int.tryParse(rangeParts[1].split('.').first) ?? startCh;
          }
        }
      }
      return chapter >= startCh && chapter <= endCh;
    }).toList();
  }

  /// Busca secciones por título.
  Future<List<HarmonySection>> search(String query) async {
    await _ensureLoaded();
    final q = query.toLowerCase();
    return (_sections ?? [])
        .where((s) => s.title.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _ensureLoaded() async {
    if (_loadCompleter != null) return _loadCompleter!.future;
    _loadCompleter = Completer<void>();

    try {
      final raw = await rootBundle.loadString(
        'assets/bible/harmony/gospel_harmony.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final list = json['sections'] as List<dynamic>;
      _sections = list
          .map((e) => HarmonySection.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('GospelHarmonyService: error loading: $e');
      _sections = [];
    }
    _loadCompleter!.complete();
  }
}
