import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/series.dart';

/// Carga y cachea el catálogo de series desde `assets/content/series.json`.
class SeriesService {
  SeriesService._();
  static final SeriesService I = SeriesService._();

  List<VideoSeries>? _cache;

  Future<List<VideoSeries>> loadSeries() async {
    if (_cache != null) return _cache!;
    try {
      final raw = await rootBundle.loadString('assets/content/series.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final list = (data['series'] as List<dynamic>? ?? [])
          .map((e) => VideoSeries.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache = list;
      return list;
    } catch (e) {
      debugPrint('[SeriesService] Error cargando series.json: $e');
      return const [];
    }
  }
}
