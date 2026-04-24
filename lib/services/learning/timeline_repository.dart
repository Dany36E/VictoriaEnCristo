/// ═══════════════════════════════════════════════════════════════════════════
/// TimelineRepository — carga las lecciones de línea del tiempo
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/learning/timeline_models.dart';

class TimelineRepository {
  TimelineRepository._();
  static final TimelineRepository I = TimelineRepository._();

  List<TimelineLesson>? _items;
  bool _loading = false;

  bool get isLoaded => _items != null;
  List<TimelineLesson> get all => _items ?? const [];

  Future<void> load() async {
    if (_items != null || _loading) return;
    _loading = true;
    try {
      final raw =
          await rootBundle.loadString('assets/content/timeline_lessons.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final parsed = list.map(TimelineLesson.fromJson).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      _items = parsed;
      debugPrint('🕰️ [TIMELINE] Loaded ${parsed.length} lessons');
    } catch (e, st) {
      debugPrint('🕰️ [TIMELINE] Error: $e\n$st');
      _items = const [];
    } finally {
      _loading = false;
    }
  }

  TimelineLesson? byId(String id) {
    for (final l in all) {
      if (l.id == id) return l;
    }
    return null;
  }
}
