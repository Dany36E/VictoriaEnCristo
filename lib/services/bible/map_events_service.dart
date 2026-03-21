import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Evento bíblico geoposicionado en el mapa.
class MapEvent {
  final String id;
  final String title;
  final String description;
  final double lat;
  final double lon;
  final String reference;
  final String period;
  final String type; // event, miracle, battle, teaching, crucifixion
  final String icon;
  final String? placeId;

  LatLng get position => LatLng(lat, lon);

  const MapEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.lat,
    required this.lon,
    required this.reference,
    required this.period,
    required this.type,
    required this.icon,
    this.placeId,
  });

  factory MapEvent.fromJson(Map<String, dynamic> json) => MapEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        lat: (json['lat'] as num).toDouble(),
        lon: (json['lon'] as num).toDouble(),
        reference: json['reference'] as String,
        period: json['period'] as String,
        type: json['type'] as String,
        icon: json['icon'] as String,
        placeId: json['placeId'] as String?,
      );
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MAP EVENTS SERVICE — Carga y filtra eventos bíblicos para el mapa.
/// ═══════════════════════════════════════════════════════════════════════════
class MapEventsService {
  static final MapEventsService I = MapEventsService._();
  MapEventsService._();

  List<MapEvent>? _events;
  bool _loading = false;

  Future<void> preload() async {
    if (_events != null || _loading) return;
    _loading = true;
    try {
      final bytes =
          await rootBundle.load('assets/bible/maps/map_events.json');
      final json = utf8.decode(bytes.buffer.asUint8List());
      final data = jsonDecode(json) as Map<String, dynamic>;
      _events = (data['events'] as List)
          .map((e) => MapEvent.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('[MapEvents] Loaded ${_events!.length} events');
    } catch (e) {
      debugPrint('[MapEvents] Error loading: $e');
      _events = [];
    }
    _loading = false;
  }

  List<MapEvent> getAllEvents() => _events ?? [];

  List<MapEvent> getEventsForPeriod(String period) =>
      _events?.where((e) => e.period == period).toList() ?? [];

  List<MapEvent> getEventsForReference(String osisRef) {
    final prefix = osisRef.split('.').take(2).join('.');
    return _events?.where((e) => e.reference.startsWith(prefix)).toList() ??
        [];
  }

  List<String> getPeriods() =>
      _events?.map((e) => e.period).toSet().toList() ?? [];
}
