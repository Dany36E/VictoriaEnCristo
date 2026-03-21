import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../models/bible/bible_timeline_models.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE TIMELINE SERVICE - Singleton
/// Carga y gestiona datos de la línea de tiempo bíblica desde JSON local.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleTimelineService {
  static final BibleTimelineService _instance =
      BibleTimelineService._internal();
  factory BibleTimelineService() => _instance;
  static BibleTimelineService get I => _instance;
  BibleTimelineService._internal();

  List<TimelinePeriod> _periods = [];
  List<TimelineEvent> _events = [];
  List<TimelineCharacter> _characters = [];
  bool _loaded = false;

  List<TimelinePeriod> get periods => _periods;
  List<TimelineEvent> get events => _events;
  List<TimelineCharacter> get characters => _characters;
  bool get isLoaded => _loaded;

  Future<void> init() async {
    if (_loaded) return;
    try {
      final jsonStr = await rootBundle
          .loadString('assets/bible/timeline/bible_timeline.json');
      final data = await compute(_parseJson, jsonStr);
      _periods = data['periods']!.cast<TimelinePeriod>();
      _events = data['events']!.cast<TimelineEvent>();
      _characters = data['characters']!.cast<TimelineCharacter>();
      _loaded = true;
      debugPrint('🕐 [TIMELINE] Loaded: ${_periods.length} periods, '
          '${_events.length} events, ${_characters.length} characters');
    } catch (e) {
      debugPrint('🕐 [TIMELINE] Error loading: $e');
    }
  }

  static Map<String, List<dynamic>> _parseJson(String jsonStr) {
    final data = json.decode(jsonStr) as Map<String, dynamic>;
    return {
      'periods': (data['periods'] as List)
          .map((e) => TimelinePeriod.fromJson(e as Map<String, dynamic>))
          .toList(),
      'events': (data['events'] as List)
          .map((e) => TimelineEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      'characters': (data['characters'] as List)
          .map((e) => TimelineCharacter.fromJson(e as Map<String, dynamic>))
          .toList(),
    };
  }

  /// Obtener período por id
  TimelinePeriod? getPeriod(String id) =>
      _periods.where((p) => p.id == id).firstOrNull;

  /// Eventos de un período
  List<TimelineEvent> eventsForPeriod(String periodId) =>
      _events.where((e) => e.periodId == periodId).toList();

  /// Personajes de un período
  List<TimelineCharacter> charactersForPeriod(String periodId) =>
      _characters.where((c) => c.periodId == periodId).toList();

  /// Eventos que referencian un libro/capítulo
  List<TimelineEvent> eventsForBook(int bookNumber) => _events
      .where(
          (e) => e.references.any((r) => r.bookNumber == bookNumber))
      .toList();

  /// Buscar eventos y personajes
  List<dynamic> search(String query) {
    if (query.trim().isEmpty) return [];
    final q = query.toLowerCase();
    final results = <dynamic>[
      ..._events.where((e) =>
          e.title.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q)),
      ..._characters.where((c) =>
          c.name.toLowerCase().contains(q) ||
          c.description.toLowerCase().contains(q)),
    ];
    return results;
  }
}
