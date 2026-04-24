/// ═══════════════════════════════════════════════════════════════════════════
/// Tierras Bíblicas — modelos de datos
///
/// Cada "BibleMap" es un mapa interactivo de una región bíblica.
/// El usuario arrastra las etiquetas de lugares a su posición correcta.
/// ═══════════════════════════════════════════════════════════════════════════
library;

enum MapRegion { tierraPrometida, viajeExodo, imperioRomano, mesopotamia, egipto, viajesPablo }

extension MapRegionX on MapRegion {
  String get label {
    switch (this) {
      case MapRegion.tierraPrometida:
        return 'Tierra Prometida';
      case MapRegion.viajeExodo:
        return 'Viaje del Éxodo';
      case MapRegion.imperioRomano:
        return 'Mundo del Nuevo Testamento';
      case MapRegion.mesopotamia:
        return 'Mesopotamia';
      case MapRegion.egipto:
        return 'Egipto y Sinaí';
      case MapRegion.viajesPablo:
        return 'Viajes de Pablo';
    }
  }

  static MapRegion fromString(String s) {
    switch (s) {
      case 'tierra_prometida':
        return MapRegion.tierraPrometida;
      case 'viaje_exodo':
        return MapRegion.viajeExodo;
      case 'imperio_romano':
        return MapRegion.imperioRomano;
      case 'mesopotamia':
        return MapRegion.mesopotamia;
      case 'egipto':
        return MapRegion.egipto;
      case 'viajes_pablo':
        return MapRegion.viajesPablo;
      default:
        return MapRegion.tierraPrometida;
    }
  }
}

/// Un lugar marcado en el mapa con coordenadas normalizadas (0.0 - 1.0).
class MapPlace {
  final String id;
  final String name;
  final double x; // 0.0 = izquierda, 1.0 = derecha
  final double y; // 0.0 = arriba, 1.0 = abajo
  final String? hint;

  const MapPlace({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    this.hint,
  });

  factory MapPlace.fromJson(Map<String, dynamic> j) => MapPlace(
        id: j['id'] as String,
        name: j['name'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        hint: j['hint'] as String?,
      );
}

/// Landmark decorativo en el mapa (montañas, ríos, mares).
class MapLandmark {
  final String type; // 'sea', 'river', 'mountain', 'desert', 'label'
  final String label;
  final double x;
  final double y;
  final double? width;
  final double? height;

  const MapLandmark({
    required this.type,
    required this.label,
    required this.x,
    required this.y,
    this.width,
    this.height,
  });

  factory MapLandmark.fromJson(Map<String, dynamic> j) => MapLandmark(
        type: j['type'] as String,
        label: j['label'] as String,
        x: (j['x'] as num).toDouble(),
        y: (j['y'] as num).toDouble(),
        width: (j['width'] as num?)?.toDouble(),
        height: (j['height'] as num?)?.toDouble(),
      );
}

/// Un mapa completo con sus lugares y landmarks.
class BibleMap {
  final String id;
  final int order;
  final MapRegion region;
  final String title;
  final String subtitle;
  final String icon;
  final String description;
  final List<MapPlace> places;
  final List<MapLandmark> landmarks;
  final int xpReward;

  const BibleMap({
    required this.id,
    required this.order,
    required this.region,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.description,
    required this.places,
    required this.landmarks,
    required this.xpReward,
  });

  factory BibleMap.fromJson(Map<String, dynamic> j) => BibleMap(
        id: j['id'] as String,
        order: j['order'] as int,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        icon: j['icon'] as String,
        region: MapRegionX.fromString(j['region'] as String),
        description: j['description'] as String,
        places: (j['places'] as List)
            .map((e) => MapPlace.fromJson(e as Map<String, dynamic>))
            .toList(),
        landmarks: (j['landmarks'] as List? ?? const [])
            .map((e) => MapLandmark.fromJson(e as Map<String, dynamic>))
            .toList(),
        xpReward: j['xpReward'] as int? ?? 30,
      );
}
