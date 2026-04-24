/// ═══════════════════════════════════════════════════════════════════════════
/// BibleMapRepository — carga los mapas bíblicos desde assets/content
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning/bible_map_models.dart';

class BibleMapRepository {
  BibleMapRepository._();
  static final BibleMapRepository I = BibleMapRepository._();

  List<BibleMap>? _maps;
  bool _loading = false;

  bool get isLoaded => _maps != null;
  List<BibleMap> get all => _maps ?? const [];

  Future<void> load() async {
    if (_maps != null || _loading) return;
    _loading = true;
    try {
      final raw =
          await rootBundle.loadString('assets/content/bible_maps.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final parsed = list.map(BibleMap.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _maps = parsed;
      debugPrint('🌍 [MAPS] Loaded ${parsed.length} bible maps');
    } catch (e, st) {
      debugPrint('🌍 [MAPS] Error loading: $e\n$st');
      _maps = const [];
    } finally {
      _loading = false;
    }
  }

  BibleMap? byId(String id) {
    for (final m in all) {
      if (m.id == id) return m;
    }
    return null;
  }
}
