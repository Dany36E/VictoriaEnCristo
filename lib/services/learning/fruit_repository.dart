/// ═══════════════════════════════════════════════════════════════════════════
/// FruitRepository — carga los 9 frutos del Espíritu
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning/fruit_models.dart';

class FruitRepository {
  FruitRepository._();
  static final FruitRepository I = FruitRepository._();

  List<SpiritFruit>? _items;
  bool _loading = false;

  bool get isLoaded => _items != null;
  List<SpiritFruit> get all => _items ?? const [];

  Future<void> load() async {
    if (_items != null || _loading) return;
    _loading = true;
    try {
      final raw =
          await rootBundle.loadString('assets/content/spirit_fruit.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final parsed = list.map(SpiritFruit.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _items = parsed;
      debugPrint('🌱 [FRUIT] Loaded ${parsed.length} fruits');
    } catch (e, st) {
      debugPrint('🌱 [FRUIT] Error: $e\n$st');
      _items = const [];
    } finally {
      _loading = false;
    }
  }

  SpiritFruit? byId(String id) {
    for (final f in all) {
      if (f.id == id) return f;
    }
    return null;
  }
}
