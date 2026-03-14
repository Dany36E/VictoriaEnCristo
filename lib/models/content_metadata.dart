import 'content_enums.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CONTENT METADATA
/// Metadatos completos para clasificación y personalización de contenido
/// ═══════════════════════════════════════════════════════════════════════════

class ContentMetadata {
  /// Gigantes a los que aplica este contenido
  final List<GiantId> giants;
  
  /// Etapa del usuario para la cual es más útil
  final ContentStage stage;
  
  /// Intensidad del contenido (para matching con frecuencia)
  final IntensityFit? intensityFit;
  
  /// Técnicas psicológicas/espirituales aplicadas
  final List<TechniqueId> techniques;
  
  /// Gatillos que aborda este contenido
  final List<TriggerId> triggers;
  
  /// Resultados esperados
  final List<OutcomeId> outcomes;
  
  /// Contraindicaciones o advertencias
  final List<String>? contraindications;
  
  /// Fuente metodológica
  final ContentSource source;
  
  /// Nivel de revisión editorial
  final ReviewLevel reviewLevel;
  
  /// Última actualización
  final DateTime? lastUpdated;

  const ContentMetadata({
    required this.giants,
    required this.stage,
    this.intensityFit,
    this.techniques = const [],
    this.triggers = const [],
    this.outcomes = const [],
    this.contraindications,
    this.source = ContentSource.mixed,
    this.reviewLevel = ReviewLevel.approved,
    this.lastUpdated,
  });

  /// Crear desde JSON
  factory ContentMetadata.fromJson(Map<String, dynamic> json) {
    return ContentMetadata(
      giants: (json['giants'] as List<dynamic>?)
          ?.map((e) => GiantIdExtension.fromId(e as String))
          .whereType<GiantId>()
          .toList() ?? [],
      stage: ContentStageExtension.fromId(json['stage'] as String?) 
          ?? ContentStage.habit,
      intensityFit: IntensityFitExtension.fromId(json['intensityFit'] as String?),
      techniques: (json['techniques'] as List<dynamic>?)
          ?.map((e) => TechniqueIdExtension.fromId(e as String))
          .whereType<TechniqueId>()
          .toList() ?? [],
      triggers: (json['triggers'] as List<dynamic>?)
          ?.map((e) => TriggerIdExtension.fromId(e as String))
          .whereType<TriggerId>()
          .toList() ?? [],
      outcomes: (json['outcomes'] as List<dynamic>?)
          ?.map((e) => OutcomeIdExtension.fromId(e as String))
          .whereType<OutcomeId>()
          .toList() ?? [],
      contraindications: (json['contraindications'] as List<dynamic>?)
          ?.cast<String>(),
      source: ContentSourceExtension.fromId(json['source'] as String?) 
          ?? ContentSource.mixed,
      reviewLevel: ReviewLevelExtension.fromId(json['reviewLevel'] as String?) 
          ?? ReviewLevel.approved,
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.tryParse(json['lastUpdated'] as String)
          : null,
    );
  }

  /// Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'giants': giants.map((g) => g.id).toList(),
      'stage': stage.id,
      if (intensityFit != null) 'intensityFit': intensityFit!.id,
      'techniques': techniques.map((t) => t.id).toList(),
      'triggers': triggers.map((t) => t.id).toList(),
      'outcomes': outcomes.map((o) => o.id).toList(),
      if (contraindications != null) 'contraindications': contraindications,
      'source': source.id,
      'reviewLevel': reviewLevel.id,
      if (lastUpdated != null) 'lastUpdated': lastUpdated!.toIso8601String(),
    };
  }

  /// Metadata vacía para fallback
  static const ContentMetadata empty = ContentMetadata(
    giants: [],
    stage: ContentStage.habit,
  );

  /// Verificar si aplica a un gigante específico
  bool appliesToGiant(GiantId giant) => giants.contains(giant);

  /// Verificar si aplica a cualquiera de los gigantes dados
  bool appliesToAnyGiant(List<GiantId> userGiants) {
    if (giants.isEmpty) return false;
    return giants.any((g) => userGiants.contains(g));
  }

  /// Obtener texto explicativo de por qué se recomienda
  String getRecommendationReason(GiantId? primaryGiant, ContentStage userStage) {
    final parts = <String>[];
    
    // Por gigante
    if (primaryGiant != null && giants.contains(primaryGiant)) {
      parts.add(primaryGiant.displayName);
    } else if (giants.isNotEmpty) {
      parts.add(giants.first.displayName);
    }
    
    // Por etapa
    if (stage == userStage) {
      parts.add('etapa de ${stage.displayName.toLowerCase()}');
    }
    
    // Por técnica (solo la primera)
    if (techniques.isNotEmpty) {
      parts.add(techniques.first.displayName.toLowerCase());
    }
    
    if (parts.isEmpty) return 'Contenido general';
    return 'Recomendado por: ${parts.join(' + ')}';
  }

  @override
  String toString() {
    return 'ContentMetadata(giants: ${giants.map((g) => g.id).join(", ")}, '
           'stage: ${stage.id}, reviewLevel: ${reviewLevel.id})';
  }
}
