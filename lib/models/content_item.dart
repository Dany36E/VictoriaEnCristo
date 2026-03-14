import 'content_enums.dart';
import 'content_metadata.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CONTENT ITEM - Modelo Base Unificado
/// Representa cualquier pieza de contenido con metadata completa
/// ═══════════════════════════════════════════════════════════════════════════

class ContentItem {
  /// Identificador único
  final String id;
  
  /// Tipo de contenido
  final ContentType type;
  
  /// Título principal
  final String title;
  
  /// Subtítulo o descripción corta
  final String? subtitle;
  
  /// Cuerpo del contenido (texto, pasos, etc.)
  final String body;
  
  /// Duración estimada en minutos (para planes/ejercicios)
  final int? durationMinutes;
  
  /// Metadata completa para personalización
  final ContentMetadata metadata;
  
  /// Datos adicionales específicos del tipo
  final Map<String, dynamic>? extra;

  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    required this.body,
    this.durationMinutes,
    required this.metadata,
    this.extra,
  });

  /// Crear desde JSON
  factory ContentItem.fromJson(Map<String, dynamic> json) {
    return ContentItem(
      id: json['id'] as String,
      type: ContentTypeExtension.fromId(json['type'] as String?) 
          ?? ContentType.verse,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      body: json['body'] as String? ?? json['content'] as String? ?? '',
      durationMinutes: json['durationMinutes'] as int?,
      metadata: json['metadata'] != null
          ? ContentMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : ContentMetadata.empty,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      'body': body,
      if (durationMinutes != null) 'durationMinutes': durationMinutes,
      'metadata': metadata.toJson(),
      if (extra != null) 'extra': extra,
    };
  }

  /// Copia con modificaciones
  ContentItem copyWith({
    String? id,
    ContentType? type,
    String? title,
    String? subtitle,
    String? body,
    int? durationMinutes,
    ContentMetadata? metadata,
    Map<String, dynamic>? extra,
  }) {
    return ContentItem(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      body: body ?? this.body,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      metadata: metadata ?? this.metadata,
      extra: extra ?? this.extra,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ContentItem && other.id == id && other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode;

  @override
  String toString() {
    return 'ContentItem($type: $id - $title)';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELOS ESPECÍFICOS (extienden ContentItem para tipos con estructura propia)
// ═══════════════════════════════════════════════════════════════════════════

/// Versículo bíblico con referencia
class VerseItem extends ContentItem {
  final String reference;
  final String? howToUse; // "Cómo usarlo en 30s"
  final String? whyItApplies; // "Por qué aplica"

  VerseItem({
    required super.id,
    required super.title, // El texto del versículo
    required this.reference,
    this.howToUse,
    this.whyItApplies,
    required super.metadata,
  }) : super(
    type: ContentType.verse,
    body: title, // El versículo es el body
    extra: {
      'reference': reference,
      if (howToUse != null) 'howToUse': howToUse,
      if (whyItApplies != null) 'whyItApplies': whyItApplies,
    },
  );

  factory VerseItem.fromJson(Map<String, dynamic> json) {
    return VerseItem(
      id: json['id'] as String,
      title: json['verse'] as String? ?? json['title'] as String? ?? '',
      reference: json['reference'] as String,
      howToUse: json['howToUse'] as String?,
      whyItApplies: json['whyItApplies'] as String?,
      metadata: json['metadata'] != null
          ? ContentMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : ContentMetadata.empty,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.id,
      'verse': title,
      'reference': reference,
      if (howToUse != null) 'howToUse': howToUse,
      if (whyItApplies != null) 'whyItApplies': whyItApplies,
      'metadata': metadata.toJson(),
    };
  }
}

/// Oración guiada
class PrayerItem extends ContentItem {
  final String category;

  PrayerItem({
    required super.id,
    required super.title,
    required String content,
    required this.category,
    super.durationMinutes,
    required super.metadata,
  }) : super(
    type: ContentType.prayer,
    body: content,
    extra: {'category': category},
  );

  factory PrayerItem.fromJson(Map<String, dynamic> json) {
    return PrayerItem(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String? ?? json['body'] as String? ?? '',
      category: json['category'] as String? ?? 'general',
      durationMinutes: json['durationMinutes'] as int?,
      metadata: json['metadata'] != null
          ? ContentMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : ContentMetadata.empty,
    );
  }

  String get content => body;
}

/// Prompt para el diario
class JournalPromptItem extends ContentItem {
  final String? followUp; // Pregunta de seguimiento opcional

  JournalPromptItem({
    required super.id,
    required String prompt,
    this.followUp,
    required super.metadata,
  }) : super(
    type: ContentType.journalPrompt,
    title: prompt,
    body: prompt,
    extra: {if (followUp != null) 'followUp': followUp},
  );

  factory JournalPromptItem.fromJson(Map<String, dynamic> json) {
    return JournalPromptItem(
      id: json['id'] as String,
      prompt: json['prompt'] as String? ?? json['title'] as String? ?? '',
      followUp: json['followUp'] as String?,
      metadata: json['metadata'] != null
          ? ContentMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : ContentMetadata.empty,
    );
  }

  String get prompt => title;
}

/// Ejercicio práctico
class ExerciseItem extends ContentItem {
  final List<String> steps;

  ExerciseItem({
    required super.id,
    required super.title,
    super.subtitle,
    required this.steps,
    required super.durationMinutes,
    required super.metadata,
  }) : super(
    type: ContentType.exercise,
    body: steps.join('\n'),
    extra: {'steps': steps},
  );

  factory ExerciseItem.fromJson(Map<String, dynamic> json) {
    return ExerciseItem(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      steps: (json['steps'] as List<dynamic>?)?.cast<String>() ?? [],
      durationMinutes: json['durationMinutes'] as int? ?? 5,
      metadata: json['metadata'] != null
          ? ContentMetadata.fromJson(json['metadata'] as Map<String, dynamic>)
          : ContentMetadata.empty,
    );
  }
}
