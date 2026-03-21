import 'package:latlong2/latlong.dart';

/// Modelos para mapas bíblicos interactivos.

class BibleMap {
  final String id;
  final String title;
  final String period;
  final String description;
  final String imageAsset;
  final bool placeholder;
  final List<int> relatedBooks;
  final Map<String, List<int>> relatedChapters; // bookNum -> chapters
  final List<MapPoint> points;
  final List<MapRoute> routes;

  const BibleMap({
    required this.id,
    required this.title,
    required this.period,
    required this.description,
    required this.imageAsset,
    this.placeholder = true,
    this.relatedBooks = const [],
    this.relatedChapters = const {},
    this.points = const [],
    this.routes = const [],
  });

  factory BibleMap.fromJson(Map<String, dynamic> json) {
    return BibleMap(
      id: json['id'] as String,
      title: json['title'] as String,
      period: json['period'] as String? ?? '',
      description: json['description'] as String? ?? '',
      imageAsset: json['imageAsset'] as String? ?? '',
      placeholder: json['placeholder'] as bool? ?? true,
      relatedBooks: (json['relatedBooks'] as List?)
              ?.map((e) => e as int)
              .toList() ??
          [],
      relatedChapters: _parseRelatedChapters(json['relatedChapters']),
      points: (json['points'] as List?)
              ?.map((e) => MapPoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      routes: (json['routes'] as List?)
              ?.map((e) => MapRoute.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  static Map<String, List<int>> _parseRelatedChapters(dynamic data) {
    if (data == null || data is! Map) return {};
    final result = <String, List<int>>{};
    for (final entry in data.entries) {
      result[entry.key.toString()] =
          (entry.value as List).map((e) => e as int).toList();
    }
    return result;
  }
}

class MapPoint {
  final String id;
  final String name;
  final String description;
  final double x; // 0.0-1.0 proporcional
  final double y;
  final String type; // city, event, region, battle, temple, routeStop
  final List<String> references;

  const MapPoint({
    required this.id,
    required this.name,
    this.description = '',
    required this.x,
    required this.y,
    this.type = 'city',
    this.references = const [],
  });

  factory MapPoint.fromJson(Map<String, dynamic> json) {
    return MapPoint(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      type: json['type'] as String? ?? 'city',
      references: (json['references'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class MapRoute {
  final String id;
  final String name;
  final String color;
  final double width;
  final bool animated;
  final List<RoutePoint> points;

  const MapRoute({
    required this.id,
    required this.name,
    this.color = '#D4A853',
    this.width = 2.0,
    this.animated = false,
    this.points = const [],
  });

  factory MapRoute.fromJson(Map<String, dynamic> json) {
    return MapRoute(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      color: json['color'] as String? ?? '#D4A853',
      width: (json['width'] as num?)?.toDouble() ?? 2.0,
      animated: json['animated'] as bool? ?? false,
      points: (json['points'] as List?)
              ?.map((e) {
                if (e is List) return RoutePoint(x: (e[0] as num).toDouble(), y: (e[1] as num).toDouble());
                return RoutePoint.fromJson(e as Map<String, dynamic>);
              })
              .toList() ??
          [],
    );
  }
}

class RoutePoint {
  final double x;
  final double y;

  const RoutePoint({required this.x, required this.y});

  factory RoutePoint.fromJson(Map<String, dynamic> json) {
    return RoutePoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}

/// ─── Modelos nuevos (mapas interactivos con coordenadas GPS reales) ───

/// Tipo de lugar bíblico.
enum BiblicalPlaceType { city, mountain, sea, river, temple, battlefield, region }

/// Un lugar bíblico con coordenadas GPS reales.
class BiblicalPlace {
  final String id;
  final String nameEs;
  final String nameEn;
  final double lat;
  final double lon;
  final BiblicalPlaceType type;
  final List<String> periods;
  final String description;
  final List<String> references;
  final int importance;

  const BiblicalPlace({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    required this.lat,
    required this.lon,
    required this.type,
    this.periods = const [],
    this.description = '',
    this.references = const [],
    this.importance = 3,
  });

  LatLng get position => LatLng(lat, lon);

  factory BiblicalPlace.fromJson(Map<String, dynamic> json) {
    return BiblicalPlace(
      id: json['id'] as String,
      nameEs: json['nameEs'] as String,
      nameEn: json['nameEn'] as String? ?? json['nameEs'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      type: _parseType(json['type'] as String? ?? 'city'),
      periods:
          (json['period'] as List?)?.map((e) => e.toString()).toList() ?? [],
      description: json['description'] as String? ?? '',
      references:
          (json['references'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      importance: json['importance'] as int? ?? 3,
    );
  }

  static BiblicalPlaceType _parseType(String t) {
    switch (t) {
      case 'city': return BiblicalPlaceType.city;
      case 'mountain': return BiblicalPlaceType.mountain;
      case 'sea': return BiblicalPlaceType.sea;
      case 'river': return BiblicalPlaceType.river;
      case 'temple': return BiblicalPlaceType.temple;
      case 'battlefield': return BiblicalPlaceType.battlefield;
      case 'region': return BiblicalPlaceType.region;
      default: return BiblicalPlaceType.city;
    }
  }
}

/// Ruta histórica con coordenadas GPS.
class HistoricalRoute {
  final String id;
  final String nameEs;
  final String nameEn;
  final String period;
  final String color;
  final double width;
  final bool dotted;
  final List<LatLng> points;

  const HistoricalRoute({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    this.period = '',
    this.color = '#D4AF37',
    this.width = 2.5,
    this.dotted = true,
    this.points = const [],
  });

  factory HistoricalRoute.fromJson(Map<String, dynamic> json) {
    return HistoricalRoute(
      id: json['id'] as String,
      nameEs: json['nameEs'] as String,
      nameEn: json['nameEn'] as String? ?? json['nameEs'] as String,
      period: json['period'] as String? ?? '',
      color: json['color'] as String? ?? '#D4AF37',
      width: (json['width'] as num?)?.toDouble() ?? 2.5,
      dotted: json['dotted'] as bool? ?? true,
      points: (json['points'] as List?)
              ?.map((e) {
                if (e is List) {
                  return LatLng(
                      (e[0] as num).toDouble(), (e[1] as num).toDouble());
                }
                final m = e as Map<String, dynamic>;
                return LatLng((m['lat'] as num).toDouble(),
                    (m['lon'] as num).toDouble());
              })
              .toList() ??
          [],
    );
  }
}

/// Región/frontera histórica (polígono).
class HistoricalRegion {
  final String id;
  final String nameEs;
  final String nameEn;
  final List<String> periods;
  final String color;
  final double opacity;
  final String borderColor;
  final List<LatLng> points;

  const HistoricalRegion({
    required this.id,
    required this.nameEs,
    required this.nameEn,
    this.periods = const [],
    this.color = '#90CAF9',
    this.opacity = 0.15,
    this.borderColor = '#64B5F6',
    this.points = const [],
  });

  factory HistoricalRegion.fromJson(Map<String, dynamic> json) {
    return HistoricalRegion(
      id: json['id'] as String,
      nameEs: json['nameEs'] as String,
      nameEn: json['nameEn'] as String? ?? json['nameEs'] as String,
      periods:
          (json['period'] as List?)?.map((e) => e.toString()).toList() ?? [],
      color: json['color'] as String? ?? '#90CAF9',
      opacity: (json['opacity'] as num?)?.toDouble() ?? 0.15,
      borderColor: json['borderColor'] as String? ?? '#64B5F6',
      points: (json['points'] as List?)
              ?.map((e) {
                if (e is List) {
                  return LatLng(
                      (e[0] as num).toDouble(), (e[1] as num).toDouble());
                }
                final m = e as Map<String, dynamic>;
                return LatLng((m['lat'] as num).toDouble(),
                    (m['lon'] as num).toDouble());
              })
              .toList() ??
          [],
    );
  }
}

/// Período bíblico para filtro.
class BiblicalPeriod {
  final String id;
  final String nameEs;
  final int order;
  const BiblicalPeriod(this.id, this.nameEs, this.order);
}

/// Períodos predefinidos.
const kBiblicalPeriods = [
  BiblicalPeriod('all', 'Todos los períodos', 0),
  BiblicalPeriod('patriarchs', 'Patriarcas', 1),
  BiblicalPeriod('exodus', 'Éxodo', 2),
  BiblicalPeriod('conquest', 'Conquista', 3),
  BiblicalPeriod('judges', 'Jueces', 4),
  BiblicalPeriod('united_kingdom', 'Reino Unido', 5),
  BiblicalPeriod('divided_kingdom', 'Reino Dividido', 6),
  BiblicalPeriod('exile', 'Exilio', 7),
  BiblicalPeriod('return', 'Regreso', 8),
  BiblicalPeriod('intertestamental', 'Intertestamentario', 9),
  BiblicalPeriod('jesus', 'Ministerio de Jesús', 10),
  BiblicalPeriod('apostolic', 'Era Apostólica', 11),
];

/// Mapeo de códigos OSIS a número de libro (1-66).
const kBookCodeToNumber = <String, int>{
  'GEN': 1, 'EXO': 2, 'LEV': 3, 'NUM': 4, 'DEU': 5,
  'JOS': 6, 'JDG': 7, 'RUT': 8, '1SA': 9, '2SA': 10,
  '1KI': 11, '2KI': 12, '1CH': 13, '2CH': 14, 'EZR': 15,
  'NEH': 16, 'EST': 17, 'JOB': 18, 'PSA': 19, 'PRO': 20,
  'ECC': 21, 'SOS': 22, 'ISA': 23, 'JER': 24, 'LAM': 25,
  'EZK': 26, 'DAN': 27, 'HOS': 28, 'JOL': 29, 'AMO': 30,
  'OBA': 31, 'JON': 32, 'MIC': 33, 'NAH': 34, 'HAB': 35,
  'ZEP': 36, 'HAG': 37, 'ZEC': 38, 'MAL': 39,
  'MAT': 40, 'MAR': 41, 'LUK': 42, 'JHN': 43, 'ACT': 44,
  'ROM': 45, '1CO': 46, '2CO': 47, 'GAL': 48, 'EPH': 49,
  'PHP': 50, 'COL': 51, '1TH': 52, '2TH': 53, '1TI': 54,
  '2TI': 55, 'TIT': 56, 'PHM': 57, 'HEB': 58, 'JAS': 59,
  '1PE': 60, '2PE': 61, '1JN': 62, '2JN': 63, '3JN': 64,
  'JUD': 65, 'REV': 66,
};

/// Mapeo de número de libro a nombre en español.
const kBookNumberToNameEs = <int, String>{
  1: 'Génesis', 2: 'Éxodo', 3: 'Levítico', 4: 'Números',
  5: 'Deuteronomio', 6: 'Josué', 7: 'Jueces', 8: 'Rut',
  9: '1 Samuel', 10: '2 Samuel', 11: '1 Reyes', 12: '2 Reyes',
  13: '1 Crónicas', 14: '2 Crónicas', 15: 'Esdras', 16: 'Nehemías',
  17: 'Ester', 18: 'Job', 19: 'Salmos', 20: 'Proverbios',
  21: 'Eclesiastés', 22: 'Cantares', 23: 'Isaías', 24: 'Jeremías',
  25: 'Lamentaciones', 26: 'Ezequiel', 27: 'Daniel', 28: 'Oseas',
  29: 'Joel', 30: 'Amós', 31: 'Abdías', 32: 'Jonás',
  33: 'Miqueas', 34: 'Nahúm', 35: 'Habacuc', 36: 'Sofonías',
  37: 'Hageo', 38: 'Zacarías', 39: 'Malaquías',
  40: 'Mateo', 41: 'Marcos', 42: 'Lucas', 43: 'Juan',
  44: 'Hechos', 45: 'Romanos', 46: '1 Corintios', 47: '2 Corintios',
  48: 'Gálatas', 49: 'Efesios', 50: 'Filipenses', 51: 'Colosenses',
  52: '1 Tesalonicenses', 53: '2 Tesalonicenses', 54: '1 Timoteo',
  55: '2 Timoteo', 56: 'Tito', 57: 'Filemón', 58: 'Hebreos',
  59: 'Santiago', 60: '1 Pedro', 61: '2 Pedro', 62: '1 Juan',
  63: '2 Juan', 64: '3 Juan', 65: 'Judas', 66: 'Apocalipsis',
};
