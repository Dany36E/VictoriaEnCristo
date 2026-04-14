import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bible_map_models.dart';

/// Servicio para mapas bíblicos interactivos.
class BibleMapsService {
  BibleMapsService._();
  static final instance = BibleMapsService._();

  // ─── Legacy data (coordenadas 0-1) ───
  List<BibleMap>? _maps;
  Completer<void>? _loadCompleter;

  // ─── New GPS data ───
  List<BiblicalPlace>? _places;
  List<HistoricalRoute>? _routes;
  List<HistoricalRegion>? _regions;
  Completer<void>? _gpsCompleter;

  /// Todos los mapas disponibles (legacy).
  Future<List<BibleMap>> getMaps() async {
    await _ensureLoaded();
    return _maps ?? [];
  }

  /// Mapas relacionados con un libro específico (legacy).
  Future<List<BibleMap>> getMapsForBook(int bookNumber) async {
    await _ensureLoaded();
    if (_maps == null) return [];
    return _maps!
        .where((m) => m.relatedBooks.contains(bookNumber))
        .toList();
  }

  /// Mapas relacionados con un capítulo específico (legacy).
  Future<List<BibleMap>> getMapsForChapter(
    int bookNumber,
    int chapter,
  ) async {
    await _ensureLoaded();
    if (_maps == null) return [];
    return _maps!.where((m) {
      if (!m.relatedBooks.contains(bookNumber)) return false;
      final chapters = m.relatedChapters[bookNumber.toString()];
      if (chapters == null) return true;
      return chapters.contains(chapter);
    }).toList();
  }

  /// Busca un mapa por id (legacy).
  Future<BibleMap?> getMapById(String mapId) async {
    await _ensureLoaded();
    try {
      return _maps?.firstWhere((m) => m.id == mapId);
    } catch (e) {
      debugPrint('📍 [MAPS] getMapById($mapId): $e');
      return null;
    }
  }

  // ─── GPS-based data access ───

  /// Todos los lugares bíblicos con GPS.
  Future<List<BiblicalPlace>> getPlaces() async {
    await _ensureGpsLoaded();
    return _places ?? [];
  }

  /// Lugares filtrados por período.
  Future<List<BiblicalPlace>> getPlacesForPeriod(String period) async {
    await _ensureGpsLoaded();
    if (period == 'all') return _places ?? [];
    return _places?.where((p) => p.periods.contains(period)).toList() ?? [];
  }

  /// Todas las rutas históricas.
  Future<List<HistoricalRoute>> getRoutes() async {
    await _ensureGpsLoaded();
    return _routes ?? [];
  }

  /// Rutas filtradas por período.
  Future<List<HistoricalRoute>> getRoutesForPeriod(String period) async {
    await _ensureGpsLoaded();
    if (period == 'all') return _routes ?? [];
    return _routes?.where((r) => r.period == period).toList() ?? [];
  }

  /// Todas las regiones históricas.
  Future<List<HistoricalRegion>> getRegions() async {
    await _ensureGpsLoaded();
    return _regions ?? [];
  }

  /// Regiones filtradas por período.
  Future<List<HistoricalRegion>> getRegionsForPeriod(String period) async {
    await _ensureGpsLoaded();
    if (period == 'all') return _regions ?? [];
    return _regions?.where((r) => r.periods.contains(period)).toList() ?? [];
  }

  // ─── Loaders ───

  Future<void> _ensureLoaded() async {
    if (_loadCompleter != null) return _loadCompleter!.future;
    _loadCompleter = Completer<void>();

    try {
      final raw =
          await rootBundle.loadString('assets/bible/maps/bible_maps.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = data['maps'] as List;
      _maps = list
          .map((e) => BibleMap.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('BibleMapsService: Error cargando mapas: $e');
      _maps = [];
    }
    _loadCompleter!.complete();
  }

  Future<void> _ensureGpsLoaded() async {
    if (_gpsCompleter != null) return _gpsCompleter!.future;
    _gpsCompleter = Completer<void>();

    try {
      // Places
      final placesRaw = await rootBundle
          .loadString('assets/bible/maps/biblical_places.json');
      final placesData = jsonDecode(placesRaw) as Map<String, dynamic>;
      _places = (placesData['places'] as List)
          .map((e) => BiblicalPlace.fromJson(e as Map<String, dynamic>))
          .toList();

      // Routes
      final routesRaw = await rootBundle
          .loadString('assets/bible/maps/historical_routes.json');
      final routesData = jsonDecode(routesRaw) as Map<String, dynamic>;
      _routes = (routesData['routes'] as List)
          .map((e) => HistoricalRoute.fromJson(e as Map<String, dynamic>))
          .toList();

      // Regions
      final regionsRaw = await rootBundle
          .loadString('assets/bible/maps/historical_borders.json');
      final regionsData = jsonDecode(regionsRaw) as Map<String, dynamic>;
      _regions = (regionsData['regions'] as List)
          .map((e) => HistoricalRegion.fromJson(e as Map<String, dynamic>))
          .toList();

      debugPrint('BibleMapsService: GPS data loaded — '
          '${_places!.length} places, ${_routes!.length} routes, '
          '${_regions!.length} regions');
    } catch (e) {
      debugPrint('BibleMapsService: Error cargando GPS data: $e');
      _places ??= [];
      _routes ??= [];
      _regions ??= [];
    }
    _gpsCompleter!.complete();
  }
}
