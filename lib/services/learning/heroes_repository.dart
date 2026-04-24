/// ═══════════════════════════════════════════════════════════════════════════
/// HeroesRepository — carga los héroes de la fe desde assets/content
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning/hero_models.dart';

class HeroesRepository {
  HeroesRepository._();
  static final HeroesRepository I = HeroesRepository._();

  List<HeroOfFaith>? _heroes;
  bool _loading = false;

  bool get isLoaded => _heroes != null;
  List<HeroOfFaith> get all => _heroes ?? const [];

  Future<void> load() async {
    if (_heroes != null || _loading) return;
    _loading = true;
    try {
      final raw =
          await rootBundle.loadString('assets/content/heroes_of_faith.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final parsed = list.map(HeroOfFaith.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _heroes = parsed;
      debugPrint('⚔️ [HEROES] Loaded ${parsed.length} heroes of faith');
    } catch (e, st) {
      debugPrint('⚔️ [HEROES] Error loading: $e\n$st');
      _heroes = const [];
    } finally {
      _loading = false;
    }
  }

  HeroOfFaith? byId(String id) {
    for (final h in all) {
      if (h.id == id) return h;
    }
    return null;
  }

  Map<HeroEra, List<HeroOfFaith>> groupedByEra() {
    final map = <HeroEra, List<HeroOfFaith>>{};
    for (final h in all) {
      map.putIfAbsent(h.era, () => []).add(h);
    }
    return map;
  }
}
