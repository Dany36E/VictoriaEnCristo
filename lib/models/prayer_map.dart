import 'dart:convert';

/// Modelo para una entrada del "Mapa de Oración" (antes "Mi Diario").
///
/// Se persiste en el campo `content` de `JournalEntry` como un blob JSON con
/// un marcador inicial. Esto evita migrar el esquema del servicio existente y
/// mantiene compatibilidad con entradas antiguas (que se renderizarán como
/// texto libre en la sección "Esto es lo que está sucediendo").
class PrayerMapData {
  /// Prefijo único para detectar entradas estructuradas del Mapa de Oración.
  static const String marker = '__prayer_map_v1__';

  final String saludo;
  final String gracias;
  final String personas;
  final String preocupaciones;
  final String situacion;
  final String necesidades;
  final String corazon;
  final String verseReference;

  const PrayerMapData({
    this.saludo = '',
    this.gracias = '',
    this.personas = '',
    this.preocupaciones = '',
    this.situacion = '',
    this.necesidades = '',
    this.corazon = '',
    this.verseReference = '',
  });

  /// Secciones en orden de presentación, con sus etiquetas amigables.
  static const List<PrayerMapSection> sections = [
    PrayerMapSection(
      key: 'saludo',
      label: 'Amado Padre Celestial…',
      hint: 'Inicia tu oración hablándole a Dios.',
      minLines: 2,
    ),
    PrayerMapSection(
      key: 'gracias',
      label: 'Gracias por…',
      hint: 'Reconoce sus bendiciones y dones de hoy.',
      minLines: 3,
    ),
    PrayerMapSection(
      key: 'personas',
      label: 'Personas por las que estoy orando hoy…',
      hint: 'Nombres, familia, amigos, líderes…',
      minLines: 3,
    ),
    PrayerMapSection(
      key: 'preocupaciones',
      label: 'Estoy preocupado/a por…',
      hint: 'Entrega tus cargas al Señor.',
      minLines: 3,
    ),
    PrayerMapSection(
      key: 'situacion',
      label: 'Esto es lo que está sucediendo en mi vida…',
      hint: 'Cuéntale a Dios lo que vives hoy.',
      minLines: 3,
    ),
    PrayerMapSection(
      key: 'necesidades',
      label: 'Necesito…',
      hint: 'Pídele con confianza lo que necesitas.',
      minLines: 3,
    ),
    PrayerMapSection(
      key: 'corazon',
      label:
          'Otras cosas que hay en mi corazón y que tengo que compartir contigo, Señor…',
      hint: 'Comparte aquello que sólo Él puede entender.',
      minLines: 3,
    ),
  ];

  String getField(String key) {
    switch (key) {
      case 'saludo':
        return saludo;
      case 'gracias':
        return gracias;
      case 'personas':
        return personas;
      case 'preocupaciones':
        return preocupaciones;
      case 'situacion':
        return situacion;
      case 'necesidades':
        return necesidades;
      case 'corazon':
        return corazon;
      default:
        return '';
    }
  }

  PrayerMapData copyWith({
    String? saludo,
    String? gracias,
    String? personas,
    String? preocupaciones,
    String? situacion,
    String? necesidades,
    String? corazon,
    String? verseReference,
  }) {
    return PrayerMapData(
      saludo: saludo ?? this.saludo,
      gracias: gracias ?? this.gracias,
      personas: personas ?? this.personas,
      preocupaciones: preocupaciones ?? this.preocupaciones,
      situacion: situacion ?? this.situacion,
      necesidades: necesidades ?? this.necesidades,
      corazon: corazon ?? this.corazon,
      verseReference: verseReference ?? this.verseReference,
    );
  }

  Map<String, dynamic> toJson() => {
        'saludo': saludo,
        'gracias': gracias,
        'personas': personas,
        'preocupaciones': preocupaciones,
        'situacion': situacion,
        'necesidades': necesidades,
        'corazon': corazon,
        'verseRef': verseReference,
      };

  factory PrayerMapData.fromJson(Map<String, dynamic> json) {
    return PrayerMapData(
      saludo: (json['saludo'] ?? '').toString(),
      gracias: (json['gracias'] ?? '').toString(),
      personas: (json['personas'] ?? '').toString(),
      preocupaciones: (json['preocupaciones'] ?? '').toString(),
      situacion: (json['situacion'] ?? '').toString(),
      necesidades: (json['necesidades'] ?? '').toString(),
      corazon: (json['corazon'] ?? '').toString(),
      verseReference: (json['verseRef'] ?? '').toString(),
    );
  }

  /// Codifica esta data en el campo `content` de `JournalEntry`.
  String encode() => '$marker${jsonEncode(toJson())}';

  /// Devuelve `null` si `content` es texto libre (entrada antigua).
  static PrayerMapData? tryDecode(String content) {
    if (!content.startsWith(marker)) return null;
    try {
      final raw = content.substring(marker.length);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return PrayerMapData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Resumen corto para mostrar en la lista de entradas. Toma la primera
  /// sección con contenido.
  String summary() {
    for (final s in sections) {
      final v = getField(s.key).trim();
      if (v.isNotEmpty) {
        return '${s.label} $v';
      }
    }
    return 'Mapa de oración';
  }

  bool get isEmpty =>
      saludo.trim().isEmpty &&
      gracias.trim().isEmpty &&
      personas.trim().isEmpty &&
      preocupaciones.trim().isEmpty &&
      situacion.trim().isEmpty &&
      necesidades.trim().isEmpty &&
      corazon.trim().isEmpty;
}

class PrayerMapSection {
  final String key;
  final String label;
  final String hint;
  final int minLines;

  const PrayerMapSection({
    required this.key,
    required this.label,
    required this.hint,
    required this.minLines,
  });
}
