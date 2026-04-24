/// ═══════════════════════════════════════════════════════════════════════════
/// ParableRepository — carga las parábolas desde JSON
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning/parable_models.dart';

class ParableRepository {
  ParableRepository._();
  static final ParableRepository I = ParableRepository._();

  List<Parable>? _items;
  bool _loading = false;

  bool get isLoaded => _items != null;
  List<Parable> get all => _items ?? const [];

  Future<void> load() async {
    if (_items != null || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle.loadString('assets/content/parables.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final parsed = list.map(Parable.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _items = parsed;
      debugPrint('📖 [PARABLES] Loaded ${parsed.length} parables');
    } catch (e, st) {
      debugPrint('📖 [PARABLES] Error: $e\n$st');
      _items = const [];
    } finally {
      _loading = false;
    }
  }

  Parable? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
