/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN DAY - Estructura de un día dentro de un plan
/// Cada día sigue: Escritura → Reflexión → Acción → Oración → Check-in
/// ═══════════════════════════════════════════════════════════════════════════
library;

// ═══════════════════════════════════════════════════════════════════════════
// SCRIPTURE (Escritura del día)
// ═══════════════════════════════════════════════════════════════════════════

/// Versículo o pasaje del día
class Scripture {
  /// Referencia bíblica (ej: "1 Corintios 10:13")
  final String reference;
  
  /// Texto completo del versículo (offline, sin depender de red)
  final String text;
  
  const Scripture({
    required this.reference,
    required this.text,
  });
  
  factory Scripture.fromJson(Map<String, dynamic> json) {
    return Scripture(
      reference: json['ref'] as String? ?? json['reference'] as String? ?? '',
      text: json['text'] as String? ?? '',
    );
  }
  
  Map<String, dynamic> toJson() => {
    'ref': reference,
    'text': text,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// CRISIS TOOL (Herramienta de crisis - opcional)
// ═══════════════════════════════════════════════════════════════════════════

/// Herramienta de crisis para planes de emergencia
class CrisisTool {
  /// Nombre de la herramienta
  final String name;
  
  /// Pasos a seguir
  final List<String> steps;
  
  const CrisisTool({
    required this.name,
    required this.steps,
  });
  
  factory CrisisTool.fromJson(Map<String, dynamic> json) {
    return CrisisTool(
      name: json['name'] as String? ?? '',
      steps: (json['steps'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
    );
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'steps': steps,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAN DAY
// ═══════════════════════════════════════════════════════════════════════════

/// Un día completo dentro de un plan
class PlanDay {
  /// Índice del día (1..durationDays)
  final int dayIndex;
  
  /// Título del día
  final String title;
  
  /// Escritura del día (versículo + texto completo)
  final Scripture scripture;
  
  /// Reflexión pastoral/terapéutica
  final String reflection;
  
  /// Oración guiada para el día
  final String prayer;
  
  /// Pasos de acción concretos (micro-hábitos)
  final List<String> actionSteps;
  
  /// Preguntas de check-in (1-3 preguntas de reflexión personal)
  final List<String> checkInQuestions;
  
  /// Herramienta de crisis (opcional, para planes de emergencia)
  final CrisisTool? crisisTool;
  
  /// Versículo corto para "ancla del día" (resumen memorable)
  final String? anchorVerse;
  
  const PlanDay({
    required this.dayIndex,
    required this.title,
    required this.scripture,
    required this.reflection,
    required this.prayer,
    this.actionSteps = const [],
    this.checkInQuestions = const [],
    this.crisisTool,
    this.anchorVerse,
  });
  
  factory PlanDay.fromJson(Map<String, dynamic> json) {
    return PlanDay(
      dayIndex: json['dayIndex'] as int? ?? 1,
      title: json['title'] as String? ?? 'Día ${json['dayIndex'] ?? 1}',
      scripture: Scripture.fromJson(
          json['scripture'] as Map<String, dynamic>? ?? {}),
      reflection: json['reflection'] as String? ?? '',
      prayer: json['prayer'] as String? ?? '',
      actionSteps: (json['actionSteps'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      checkInQuestions: (json['checkInQuestions'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList() ?? [],
      crisisTool: json['crisisTool'] != null
          ? CrisisTool.fromJson(json['crisisTool'] as Map<String, dynamic>)
          : null,
      anchorVerse: json['anchorVerse'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'dayIndex': dayIndex,
    'title': title,
    'scripture': scripture.toJson(),
    'reflection': reflection,
    'prayer': prayer,
    'actionSteps': actionSteps,
    'checkInQuestions': checkInQuestions,
    if (crisisTool != null) 'crisisTool': crisisTool!.toJson(),
    if (anchorVerse != null) 'anchorVerse': anchorVerse,
  };
  
  /// Versión corta del día (solo Escritura + Oración + 1 acción)
  /// Para "Modo 2 minutos" cuando el usuario tiene poco tiempo
  PlanDay get quickVersion => PlanDay(
    dayIndex: dayIndex,
    title: '$title (Rápido)',
    scripture: scripture,
    reflection: '', // Omitir reflexión larga
    prayer: prayer,
    actionSteps: actionSteps.take(1).toList(), // Solo 1 acción
    checkInQuestions: [], // Sin check-in
    crisisTool: crisisTool,
    anchorVerse: anchorVerse,
  );
  
  /// Duración estimada en minutos
  int get estimatedMinutes {
    int minutes = 2; // Base: leer escritura
    if (reflection.isNotEmpty) minutes += 3;
    if (prayer.isNotEmpty) minutes += 2;
    minutes += actionSteps.length; // 1 min por acción
    if (checkInQuestions.isNotEmpty) minutes += 2;
    if (crisisTool != null) minutes += 3;
    return minutes;
  }
}
