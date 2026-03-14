/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN - Modelo principal de un plan devocional/terapéutico
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'plan_day.dart';
import 'plan_metadata.dart';

/// Un plan completo con días, metadatos y contenido
class Plan {
  /// ID único del plan (slug estable, ej: "calma-en-la-tormenta")
  final String id;
  
  /// Título del plan
  final String title;
  
  /// Subtítulo descriptivo
  final String subtitle;
  
  /// Descripción detallada del plan
  final String description;
  
  /// Duración total en días
  final int durationDays;
  
  /// Minutos estimados por día
  final int minutesPerDay;
  
  /// Ruta al asset de imagen de portada
  final String coverImage;

  /// Referencia opcional a archivo externo de días (assets/content/plan_days/<id>.json)
  final String? daysRef;
  
  /// Metadatos para filtrado y personalización
  final PlanMetadata metadata;
  
  /// Días del plan
  final List<PlanDay> days;
  
  const Plan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.durationDays,
    required this.minutesPerDay,
    required this.coverImage,
    this.daysRef,
    required this.metadata,
    required this.days,
  });
  
  factory Plan.fromJson(Map<String, dynamic> json) {
    final daysJson = json['days'] as List<dynamic>? ?? [];
    return Plan(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      durationDays: json['durationDays'] as int? ?? daysJson.length,
      minutesPerDay: json['minutesPerDay'] as int? ?? 10,
      coverImage: json['coverImage'] as String? ?? '',
        daysRef: json['daysRef'] as String?,
      metadata: PlanMetadata.fromJson(
          json['metadata'] as Map<String, dynamic>? ?? {}),
      days: daysJson
          .map((d) => PlanDay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
  
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'durationDays': durationDays,
    'minutesPerDay': minutesPerDay,
    'coverImage': coverImage,
    if (daysRef != null) 'daysRef': daysRef,
    'metadata': metadata.toJson(),
    'days': days.map((d) => d.toJson()).toList(),
  };
  
  /// Obtener un día específico (1-indexed)
  PlanDay? getDay(int dayIndex) {
    if (dayIndex < 1 || dayIndex > days.length) return null;
    return days.firstWhere(
      (d) => d.dayIndex == dayIndex,
      orElse: () => days[dayIndex - 1], // Fallback por índice
    );
  }
  
  /// Verifica si el plan está completo (tiene todos los días)
  bool get isComplete => days.length >= durationDays;
  
  /// Porcentaje de días disponibles
  double get completionPercentage => 
      durationDays > 0 ? (days.length / durationDays) * 100 : 0;
  
  /// Etiqueta de duración para UI
  String get durationLabel {
    if (durationDays <= 3) return '$durationDays días · Crisis';
    if (durationDays <= 7) return '$durationDays días · Reinicio';
    if (durationDays <= 21) return '$durationDays días · Formación';
    return '$durationDays días · Profundización';
  }
  
  /// Etiqueta de tiempo diario
  String get timeLabel => '$minutesPerDay min/día';
  
  /// Ruta de imagen con fallback
  String get coverImagePath {
    if (coverImage.isEmpty) {
      return 'assets/images/plan_covers/default.jpg';
    }
    return coverImage;
  }
  
  /// Verifica si debe mostrarse (no es draft)
  bool get isPublished => 
      metadata.reviewLevel == PlanReviewLevel.approved || 
      metadata.reviewLevel == PlanReviewLevel.reviewed;
  
  /// Ancla del día 1 (para preview)
  String? get previewAnchor => days.isNotEmpty ? days.first.anchorVerse : null;
  
  /// Primer versículo del plan
  String? get previewVerse => 
      days.isNotEmpty ? days.first.scripture.reference : null;
  
  /// Descripción corta (primeras 100 caracteres)
  String get shortDescription {
    if (description.length <= 100) return description;
    return '${description.substring(0, 97)}...';
  }
  
  @override
  String toString() => 'Plan($id: $title, $durationDays días)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Plan && runtimeType == other.runtimeType && id == other.id;
  
  @override
  int get hashCode => id.hashCode;
}

// ═══════════════════════════════════════════════════════════════════════════
// PLAN PROGRESS - Progreso del usuario en un plan
// ═══════════════════════════════════════════════════════════════════════════

/// Estado de progreso de un usuario en un plan
class PlanProgress {
  /// ID del plan
  final String planId;
  
  /// Días completados (set de índices, 1-indexed)
  final Set<int> completedDays;
  
  /// Último día completado (timestamp)
  final DateTime? lastCompletedAt;
  
  /// Racha actual de días consecutivos
  final int currentStreak;
  
  /// Última vez que abrió el plan
  final DateTime? lastOpenedAt;
  
  /// Día actual en progreso (1-indexed)
  final int currentDay;
  
  /// ¿Tiene recordatorio activo?
  final bool hasReminder;
  
  /// Hora del recordatorio (HH:mm)
  final String? reminderTime;
  
  const PlanProgress({
    required this.planId,
    this.completedDays = const {},
    this.lastCompletedAt,
    this.currentStreak = 0,
    this.lastOpenedAt,
    this.currentDay = 1,
    this.hasReminder = false,
    this.reminderTime,
  });
  
  factory PlanProgress.fromJson(Map<String, dynamic> json) {
    return PlanProgress(
      planId: json['planId'] as String? ?? '',
      completedDays: (json['completedDays'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toSet() ?? {},
      lastCompletedAt: json['lastCompletedAt'] != null
          ? DateTime.tryParse(json['lastCompletedAt'] as String)
          : null,
      currentStreak: json['currentStreak'] as int? ?? 0,
      lastOpenedAt: json['lastOpenedAt'] != null
          ? DateTime.tryParse(json['lastOpenedAt'] as String)
          : null,
      currentDay: json['currentDay'] as int? ?? 1,
      hasReminder: json['hasReminder'] as bool? ?? false,
      reminderTime: json['reminderTime'] as String?,
    );
  }
  
  Map<String, dynamic> toJson() => {
    'planId': planId,
    'completedDays': completedDays.toList(),
    if (lastCompletedAt != null) 'lastCompletedAt': lastCompletedAt!.toIso8601String(),
    'currentStreak': currentStreak,
    if (lastOpenedAt != null) 'lastOpenedAt': lastOpenedAt!.toIso8601String(),
    'currentDay': currentDay,
    'hasReminder': hasReminder,
    if (reminderTime != null) 'reminderTime': reminderTime,
  };
  
  /// Verifica si un día específico está completado
  bool isDayCompleted(int dayIndex) => completedDays.contains(dayIndex);
  
  /// Porcentaje de progreso
  double progressPercentage(int totalDays) {
    if (totalDays <= 0) return 0;
    return (completedDays.length / totalDays) * 100;
  }
  
  /// Próximo día a completar
  int get nextDay {
    for (int i = 1; i <= currentDay + 1; i++) {
      if (!completedDays.contains(i)) return i;
    }
    return currentDay + 1;
  }
  
  /// ¿Completó hoy?
  bool get completedToday {
    if (lastCompletedAt == null) return false;
    final now = DateTime.now();
    return lastCompletedAt!.year == now.year &&
           lastCompletedAt!.month == now.month &&
           lastCompletedAt!.day == now.day;
  }
  
  /// ¿Tiene días perdidos (no consecutivos)?
  bool get hasMissedDays {
    if (completedDays.isEmpty) return false;
    final max = completedDays.reduce((a, b) => a > b ? a : b);
    return completedDays.length < max;
  }
  
  /// Crear copia con modificaciones
  PlanProgress copyWith({
    String? planId,
    Set<int>? completedDays,
    DateTime? lastCompletedAt,
    int? currentStreak,
    DateTime? lastOpenedAt,
    int? currentDay,
    bool? hasReminder,
    String? reminderTime,
  }) {
    return PlanProgress(
      planId: planId ?? this.planId,
      completedDays: completedDays ?? this.completedDays,
      lastCompletedAt: lastCompletedAt ?? this.lastCompletedAt,
      currentStreak: currentStreak ?? this.currentStreak,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      currentDay: currentDay ?? this.currentDay,
      hasReminder: hasReminder ?? this.hasReminder,
      reminderTime: reminderTime ?? this.reminderTime,
    );
  }
}
