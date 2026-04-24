/// ═══════════════════════════════════════════════════════════════════════════
/// JourneyRepository — carga las estaciones de la Travesía bíblica
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning/journey_models.dart';

class JourneyRepository {
  JourneyRepository._();
  static final JourneyRepository I = JourneyRepository._();

  List<JourneyStation>? _stations;
  bool _loading = false;

  bool get isLoaded => _stations != null;
  List<JourneyStation> get all => _stations ?? const [];

  Future<void> load() async {
    if (_stations != null || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle
          .loadString('assets/content/journey_stations.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final parsed = list.map(JourneyStation.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _stations = parsed;
      debugPrint('🗺️ [JOURNEY] Loaded ${parsed.length} stations');
    } catch (e, st) {
      debugPrint('🗺️ [JOURNEY] Error loading stations: $e\n$st');
      _stations = const [];
    } finally {
      _loading = false;
    }
  }

  JourneyStation? byId(String id) {
    for (final s in all) {
      if (s.id == id) return s;
    }
    return null;
  }

  JourneyStation? byOrder(int order) {
    for (final s in all) {
      if (s.order == order) return s;
    }
    return null;
  }

  /// Agrupa estaciones por era, preservando el orden.
  Map<JourneyEra, List<JourneyStation>> groupedByEra() {
    final map = <JourneyEra, List<JourneyStation>>{};
    for (final s in all) {
      map.putIfAbsent(s.era, () => []).add(s);
    }
    return map;
  }
}
