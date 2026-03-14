/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN METADATA - Metadatos para personalización y filtrado de planes
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'content_enums.dart';

// ═══════════════════════════════════════════════════════════════════════════
// ENUMS ESPECÍFICOS DE PLANES
// ═══════════════════════════════════════════════════════════════════════════

/// Tipo de plan según enfoque
enum PlanType {
  newInFaith,         // Para nuevos en la fe
  giantFocused,       // Enfocado en un gigante específico
  scriptureDepth,     // Profundización en la Palabra
  emotionalRegulation,// Regulación emocional
  relapseRecovery,    // Recuperación post-recaída
  discipleship,       // Discipulado general
}

extension PlanTypeExtension on PlanType {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case PlanType.newInFaith: return 'Nuevos en la Fe';
      case PlanType.giantFocused: return 'Enfocado en Batalla';
      case PlanType.scriptureDepth: return 'Profundizar en la Palabra';
      case PlanType.emotionalRegulation: return 'Regulación Emocional';
      case PlanType.relapseRecovery: return 'Recuperación';
      case PlanType.discipleship: return 'Discipulado';
    }
  }
  
  String get emoji {
    switch (this) {
      case PlanType.newInFaith: return '🌱';
      case PlanType.giantFocused: return '⚔️';
      case PlanType.scriptureDepth: return '📖';
      case PlanType.emotionalRegulation: return '🧘';
      case PlanType.relapseRecovery: return '🔄';
      case PlanType.discipleship: return '✝️';
    }
  }
  
  static PlanType? fromId(String? id) {
    if (id == null) return null;
    // Normalize: trim, lowercase, convert snake_case to camelCase
    final normalized = id.trim().toLowerCase();
    switch (normalized) {
      // camelCase
      case 'newinfaith': return PlanType.newInFaith;
      case 'giantfocused': return PlanType.giantFocused;
      case 'scripturedepth': return PlanType.scriptureDepth;
      case 'emotionalregulation': return PlanType.emotionalRegulation;
      case 'relapserecovery': return PlanType.relapseRecovery;
      case 'discipleship': return PlanType.discipleship;
      // snake_case (from JSON)
      case 'new_in_faith': return PlanType.newInFaith;
      case 'giant_focused': return PlanType.giantFocused;
      case 'scripture_depth': return PlanType.scriptureDepth;
      case 'emotional_regulation': return PlanType.emotionalRegulation;
      case 'relapse_recovery': return PlanType.relapseRecovery;
      // aliases en español
      case 'batalla': return PlanType.giantFocused;
      case 'emocional': return PlanType.emotionalRegulation;
      case 'recuperacion': return PlanType.relapseRecovery;
      case 'escritura': return PlanType.scriptureDepth;
      case 'nuevo': return PlanType.newInFaith;
      case 'nuevos': return PlanType.newInFaith;
      default:
        debugPrint('[PLANS-DBG] Unknown planType: $id');
        return null;
    }
  }
}

/// Dificultad del plan
enum PlanDifficulty {
  easy,
  medium,
  hard,
}

extension PlanDifficultyExtension on PlanDifficulty {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case PlanDifficulty.easy: return 'Fácil';
      case PlanDifficulty.medium: return 'Moderado';
      case PlanDifficulty.hard: return 'Intensivo';
    }
  }
  
  String get emoji {
    switch (this) {
      case PlanDifficulty.easy: return '🟢';
      case PlanDifficulty.medium: return '🟡';
      case PlanDifficulty.hard: return '🔴';
    }
  }
  
  static PlanDifficulty? fromId(String? id) {
    if (id == null) return null;
    switch (id) {
      case 'easy': return PlanDifficulty.easy;
      case 'medium': return PlanDifficulty.medium;
      case 'hard': return PlanDifficulty.hard;
      default: return null;
    }
  }
}

/// Nivel de revisión del contenido (solo niveles publicados)
enum PlanReviewLevel {
  reviewed, // Revisado por editor
  approved, // Aprobado por equipo pastoral
}

extension PlanReviewLevelExtension on PlanReviewLevel {
  String get id => name;
  
  static PlanReviewLevel? fromId(String? id) {
    if (id == null) return null;
    switch (id) {
      case 'reviewed': return PlanReviewLevel.reviewed;
      case 'approved': return PlanReviewLevel.approved;
      default: return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAN METADATA
// ═══════════════════════════════════════════════════════════════════════════

/// Criterios de recomendación
class RecommendedFor {
  final bool newBeliever;
  final bool highFrequencyGiant;
  final bool crisis;
  
  const RecommendedFor({
    this.newBeliever = false,
    this.highFrequencyGiant = false,
    this.crisis = false,
  });
  
  factory RecommendedFor.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const RecommendedFor();
    return RecommendedFor(
      newBeliever: json['newBeliever'] ?? false,
      highFrequencyGiant: json['highFrequencyGiant'] ?? false,
      crisis: json['crisis'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'newBeliever': newBeliever,
    'highFrequencyGiant': highFrequencyGiant,
    'crisis': crisis,
  };
}

/// Metadatos completos de un plan para filtrado y personalización
class PlanMetadata {
  /// Gigantes a los que aplica este plan
  final List<GiantId> giants;
  
  /// Etapa del usuario para la cual es apropiado
  final ContentStage stage;
  
  /// Tipo de plan según enfoque
  final PlanType planType;
  
  /// Dificultad
  final PlanDifficulty difficulty;
  
  /// Tags para búsqueda y categorización
  final List<String> tags;
  
  /// Técnicas psicológicas/espirituales usadas
  final List<TechniqueId> techniques;
  
  /// Criterios de recomendación
  final RecommendedFor recommendedFor;
  
  /// Nivel de revisión
  final PlanReviewLevel reviewLevel;
  
  const PlanMetadata({
    required this.giants,
    required this.stage,
    required this.planType,
    this.difficulty = PlanDifficulty.medium,
    this.tags = const [],
    this.techniques = const [],
    this.recommendedFor = const RecommendedFor(),
    this.reviewLevel = PlanReviewLevel.approved,
  });
  
  factory PlanMetadata.fromJson(Map<String, dynamic> json) {
    return PlanMetadata(
      giants: (json['giants'] as List<dynamic>?)
          ?.map((e) => GiantIdExtension.fromId(e as String))
          .whereType<GiantId>()
          .toList() ?? [],
      stage: ContentStageExtension.fromId(json['stage'] as String?) 
          ?? ContentStage.habit,
      planType: PlanTypeExtension.fromId(json['planType'] as String?) 
          ?? PlanType.giantFocused,
      difficulty: PlanDifficultyExtension.fromId(json['difficulty'] as String?) 
          ?? PlanDifficulty.medium,
      tags: (json['tags'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
        techniques: (json['techniques'] as List<dynamic>?)
          ?.map((e) => TechniqueIdExtension.fromId(e as String))
          .whereType<TechniqueId>()
          .toList() ?? [],
      recommendedFor: RecommendedFor.fromJson(
          json['recommendedFor'] as Map<String, dynamic>?),
      reviewLevel: PlanReviewLevelExtension.fromId(json['reviewLevel'] as String?) 
          ?? PlanReviewLevel.approved,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'giants': giants.map((e) => e.id).toList(),
    'stage': stage.id,
    'planType': planType.id,
    'difficulty': difficulty.id,
    'tags': tags,
    'techniques': techniques.map((e) => e.id).toList(),
    'recommendedFor': recommendedFor.toJson(),
    'reviewLevel': reviewLevel.id,
  };
  
  /// Verifica si el plan aplica para un gigante específico
  bool appliesToGiant(GiantId giant) => giants.contains(giant);
  
  /// Verifica si alguno de los gigantes coincide
  bool appliesToAnyGiant(List<GiantId> userGiants) {
    return giants.any((g) => userGiants.contains(g));
  }
}
