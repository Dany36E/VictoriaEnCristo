/// ═══════════════════════════════════════════════════════════════════════════
/// CONTENT ENUMS - Taxonomía de Contenido Personalizado
/// Sistema de clasificación para personalización basada en evidencia
/// ═══════════════════════════════════════════════════════════════════════════
library;

// ═══════════════════════════════════════════════════════════════════════════
// TIPOS DE CONTENIDO
// ═══════════════════════════════════════════════════════════════════════════

/// Tipos de contenido disponibles en la app
enum ContentType {
  plan,         // Plan de varios días
  verse,        // Versículo bíblico
  prayer,       // Oración guiada
  journalPrompt,// Prompt para diario
  exercise,     // Ejercicio práctico
  devotion,     // Devocional
}

extension ContentTypeExtension on ContentType {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case ContentType.plan: return 'Plan';
      case ContentType.verse: return 'Versículo';
      case ContentType.prayer: return 'Oración';
      case ContentType.journalPrompt: return 'Reflexión';
      case ContentType.exercise: return 'Ejercicio';
      case ContentType.devotion: return 'Devocional';
    }
  }
  
  String get emoji {
    switch (this) {
      case ContentType.plan: return '📅';
      case ContentType.verse: return '📖';
      case ContentType.prayer: return '🙏';
      case ContentType.journalPrompt: return '✍️';
      case ContentType.exercise: return '💪';
      case ContentType.devotion: return '🕯️';
    }
  }
  
  static ContentType? fromId(String? id) {
    if (id == null) return null;
    return ContentType.values.cast<ContentType?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GIGANTES (ÁREAS DE BATALLA)
// ═══════════════════════════════════════════════════════════════════════════

/// Los 6 gigantes principales - áreas de lucha
enum GiantId {
  digital,     // 📱 Mundo Digital (redes, videojuegos, doom scrolling)
  sexual,      // 🔞 Pureza Sexual (pornografía, lujuria)
  health,      // 🍬 Cuerpo & Salud (glotonería, sedentarismo)
  substances,  // 🥃 Sustancias (alcohol, tabaco, drogas)
  mental,      // 🤯 Batallas Mentales (ansiedad, depresión)
  emotions,    // 💔 Emociones Tóxicas (ira, resentimiento, envidia)
}

extension GiantIdExtension on GiantId {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case GiantId.digital: return 'Mundo Digital';
      case GiantId.sexual: return 'Pureza Sexual';
      case GiantId.health: return 'Cuerpo & Salud';
      case GiantId.substances: return 'Sustancias';
      case GiantId.mental: return 'Batallas Mentales';
      case GiantId.emotions: return 'Emociones Tóxicas';
    }
  }
  
  String get emoji {
    switch (this) {
      case GiantId.digital: return '📱';
      case GiantId.sexual: return '🔞';
      case GiantId.health: return '🍬';
      case GiantId.substances: return '🥃';
      case GiantId.mental: return '🤯';
      case GiantId.emotions: return '💔';
    }
  }
  
  String get description {
    switch (this) {
      case GiantId.digital: return 'Redes sociales, videojuegos, doom scrolling';
      case GiantId.sexual: return 'Pornografía, lujuria, pensamientos impuros';
      case GiantId.health: return 'Glotonería, desorden alimenticio, sedentarismo';
      case GiantId.substances: return 'Alcohol, tabaco, drogas, dependencias';
      case GiantId.mental: return 'Ansiedad, depresión, pensamientos negativos';
      case GiantId.emotions: return 'Ira, resentimiento, falta de perdón, envidia';
    }
  }
  
  /// Prioridad numérica (para ordenamiento cuando hay empate de frecuencia)
  int get priority {
    switch (this) {
      case GiantId.sexual: return 1;    // Mayor urgencia típica
      case GiantId.substances: return 2;
      case GiantId.mental: return 3;
      case GiantId.emotions: return 4;
      case GiantId.digital: return 5;
      case GiantId.health: return 6;
    }
  }
  
  static GiantId? fromId(String? id) {
    if (id == null) return null;
    return GiantId.values.cast<GiantId?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
  
  static GiantId? fromLegacyId(String? id) {
    if (id == null) return null;
    // Mapeo de IDs legacy a nuevos
    switch (id.toLowerCase()) {
      case 'digital': return GiantId.digital;
      case 'sexual': return GiantId.sexual;
      case 'health': return GiantId.health;
      case 'substances': return GiantId.substances;
      case 'mental': return GiantId.mental;
      case 'emotions': return GiantId.emotions;
      // Aliases
      case 'pureza': return GiantId.sexual;
      case 'ansiedad': return GiantId.mental;
      case 'ira': return GiantId.emotions;
      default: return null;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ETAPAS DEL USUARIO
// ═══════════════════════════════════════════════════════════════════════════

/// Etapa en la que se encuentra el usuario respecto a su batalla
enum ContentStage {
  crisis,       // 🆘 Momento de crisis/tentación aguda
  habit,        // 🔄 Formando nuevos hábitos (primeros 21-66 días)
  maintenance,  // 🛡️ Mantenimiento (racha establecida)
  restoration,  // 🩹 Restauración (después de una caída)
}

extension ContentStageExtension on ContentStage {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case ContentStage.crisis: return 'Crisis';
      case ContentStage.habit: return 'Formación de hábito';
      case ContentStage.maintenance: return 'Mantenimiento';
      case ContentStage.restoration: return 'Restauración';
    }
  }
  
  String get emoji {
    switch (this) {
      case ContentStage.crisis: return '🆘';
      case ContentStage.habit: return '🔄';
      case ContentStage.maintenance: return '🛡️';
      case ContentStage.restoration: return '🩹';
    }
  }
  
  String get description {
    switch (this) {
      case ContentStage.crisis: 
        return 'Contenido para momentos de tentación aguda';
      case ContentStage.habit: 
        return 'Contenido para formar nuevos patrones';
      case ContentStage.maintenance: 
        return 'Contenido para mantener la victoria';
      case ContentStage.restoration: 
        return 'Contenido para levantarse después de caer';
    }
  }
  
  static ContentStage? fromId(String? id) {
    if (id == null) return null;
    return ContentStage.values.cast<ContentStage?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TÉCNICAS APLICADAS
// ═══════════════════════════════════════════════════════════════════════════

/// Técnicas psicológicas/espirituales aplicadas en el contenido
enum TechniqueId {
  // Técnicas cognitivo-conductuales
  cbtReframe,       // Reestructuración cognitiva
  urgeDelay,        // Retraso del impulso (5-10 min)
  cravingSurfing,   // Surfear el antojo (observar sin actuar)
  triggerAwareness, // Identificación de gatillos
  
  // Técnicas de regulación emocional
  breathingExercise, // Respiración consciente
  grounding,         // Técnicas de anclaje (5-4-3-2-1)
  journaling,        // Escritura terapéutica
  
  // Disciplinas espirituales
  scriptureMeditation, // Meditación en la Escritura
  declarativeprayer,   // Oración declarativa
  worship,             // Adoración intencional
  fasting,             // Ayuno (mención, no instrucción médica)
  accountability,      // Rendición de cuentas
  
  // Estrategias preventivas
  environmentDesign, // Diseño del entorno (quitar acceso)
  replacementHabit,  // Hábito de reemplazo
  microCommitment,   // Micro-compromisos (solo hoy)
}

extension TechniqueIdExtension on TechniqueId {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case TechniqueId.cbtReframe: return 'Reestructuración cognitiva';
      case TechniqueId.urgeDelay: return 'Retraso del impulso';
      case TechniqueId.cravingSurfing: return 'Surfear el antojo';
      case TechniqueId.triggerAwareness: return 'Identificar gatillos';
      case TechniqueId.breathingExercise: return 'Respiración consciente';
      case TechniqueId.grounding: return 'Técnica de anclaje';
      case TechniqueId.journaling: return 'Escritura reflexiva';
      case TechniqueId.scriptureMeditation: return 'Meditación bíblica';
      case TechniqueId.declarativeprayer: return 'Oración declarativa';
      case TechniqueId.worship: return 'Adoración intencional';
      case TechniqueId.fasting: return 'Ayuno';
      case TechniqueId.accountability: return 'Rendición de cuentas';
      case TechniqueId.environmentDesign: return 'Diseño del entorno';
      case TechniqueId.replacementHabit: return 'Hábito de reemplazo';
      case TechniqueId.microCommitment: return 'Micro-compromiso';
    }
  }
  
  String get source {
    switch (this) {
      case TechniqueId.cbtReframe:
      case TechniqueId.urgeDelay:
      case TechniqueId.cravingSurfing:
      case TechniqueId.triggerAwareness:
      case TechniqueId.breathingExercise:
      case TechniqueId.grounding:
      case TechniqueId.journaling:
      case TechniqueId.environmentDesign:
      case TechniqueId.replacementHabit:
      case TechniqueId.microCommitment:
        return 'psychology';
      case TechniqueId.scriptureMeditation:
      case TechniqueId.declarativeprayer:
      case TechniqueId.worship:
      case TechniqueId.fasting:
      case TechniqueId.accountability:
        return 'pastoral';
    }
  }
  
  static TechniqueId? fromId(String? id) {
    if (id == null) return null;
    return TechniqueId.values.cast<TechniqueId?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GATILLOS (TRIGGERS)
// ═══════════════════════════════════════════════════════════════════════════

/// Gatillos comunes que disparan la tentación
enum TriggerId {
  night,        // 🌙 Noche / hora de dormir
  loneliness,   // 😔 Soledad
  boredom,      // 😐 Aburrimiento
  stress,       // 😰 Estrés
  socialMedia,  // 📱 Redes sociales
  conflict,     // 💢 Conflicto interpersonal
  celebration,  // 🎉 Celebración (alcohol, excesos)
  fatigue,      // 😴 Cansancio
  rejection,    // 💔 Rechazo
  anxiety,      // 😟 Ansiedad
}

extension TriggerIdExtension on TriggerId {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case TriggerId.night: return 'Noche';
      case TriggerId.loneliness: return 'Soledad';
      case TriggerId.boredom: return 'Aburrimiento';
      case TriggerId.stress: return 'Estrés';
      case TriggerId.socialMedia: return 'Redes sociales';
      case TriggerId.conflict: return 'Conflicto';
      case TriggerId.celebration: return 'Celebración';
      case TriggerId.fatigue: return 'Cansancio';
      case TriggerId.rejection: return 'Rechazo';
      case TriggerId.anxiety: return 'Ansiedad';
    }
  }
  
  String get emoji {
    switch (this) {
      case TriggerId.night: return '🌙';
      case TriggerId.loneliness: return '😔';
      case TriggerId.boredom: return '😐';
      case TriggerId.stress: return '😰';
      case TriggerId.socialMedia: return '📱';
      case TriggerId.conflict: return '💢';
      case TriggerId.celebration: return '🎉';
      case TriggerId.fatigue: return '😴';
      case TriggerId.rejection: return '💔';
      case TriggerId.anxiety: return '😟';
    }
  }
  
  static TriggerId? fromId(String? id) {
    if (id == null) return null;
    return TriggerId.values.cast<TriggerId?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULTADOS ESPERADOS
// ═══════════════════════════════════════════════════════════════════════════

/// Resultados que busca lograr el contenido
enum OutcomeId {
  calm,            // Calmar ansiedad/impulso
  focus,           // Recuperar enfoque
  purityGuard,     // Proteger pureza
  relapseRecovery, // Recuperar después de caída
  hopeRestoration, // Restaurar esperanza
  angerRelease,    // Liberar ira sanamente
  connectionWithGod, // Conexión espiritual
  selfAwareness,   // Autoconocimiento
  gratitude,       // Cultivar gratitud
  resilience,      // Fortalecer resiliencia
}

extension OutcomeIdExtension on OutcomeId {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case OutcomeId.calm: return 'Calma';
      case OutcomeId.focus: return 'Enfoque';
      case OutcomeId.purityGuard: return 'Guardar pureza';
      case OutcomeId.relapseRecovery: return 'Recuperación';
      case OutcomeId.hopeRestoration: return 'Restaurar esperanza';
      case OutcomeId.angerRelease: return 'Liberar ira';
      case OutcomeId.connectionWithGod: return 'Conexión con Dios';
      case OutcomeId.selfAwareness: return 'Autoconocimiento';
      case OutcomeId.gratitude: return 'Gratitud';
      case OutcomeId.resilience: return 'Resiliencia';
    }
  }
  
  static OutcomeId? fromId(String? id) {
    if (id == null) return null;
    return OutcomeId.values.cast<OutcomeId?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// NIVEL DE REVISIÓN EDITORIAL
// ═══════════════════════════════════════════════════════════════════════════

/// Nivel de revisión del contenido
enum ReviewLevel {
  draft,    // Borrador (no mostrar en producción)
  reviewed, // Revisado por 1 persona
  approved, // Aprobado por comité
}

extension ReviewLevelExtension on ReviewLevel {
  String get id => name;
  
  static ReviewLevel? fromId(String? id) {
    if (id == null) return null;
    return ReviewLevel.values.cast<ReviewLevel?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FUENTE DEL CONTENIDO
// ═══════════════════════════════════════════════════════════════════════════

/// Origen metodológico del contenido
enum ContentSource {
  pastoral,   // Basado en disciplinas espirituales
  psychology, // Basado en psicología (CBT, etc.)
  mixed,      // Combinación de ambos
}

extension ContentSourceExtension on ContentSource {
  String get id => name;
  
  String get displayName {
    switch (this) {
      case ContentSource.pastoral: return 'Pastoral';
      case ContentSource.psychology: return 'Psicología';
      case ContentSource.mixed: return 'Mixto';
    }
  }
  
  static ContentSource? fromId(String? id) {
    if (id == null) return null;
    return ContentSource.values.cast<ContentSource?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// INTENSIDAD
// ═══════════════════════════════════════════════════════════════════════════

/// Intensidad del contenido (para matching con frecuencia del usuario)
enum IntensityFit {
  light,   // Suave - para frecuencia ocasional
  medium,  // Moderado - para frecuencia semanal
  strong,  // Intenso - para frecuencia diaria
}

extension IntensityFitExtension on IntensityFit {
  String get id => name;
  
  static IntensityFit? fromId(String? id) {
    if (id == null) return null;
    return IntensityFit.values.cast<IntensityFit?>().firstWhere(
      (e) => e?.name == id,
      orElse: () => null,
    );
  }
}
