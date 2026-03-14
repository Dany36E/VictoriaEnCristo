/// Modelo para un Plan de Crecimiento Espiritual
/// Parte del sistema "Biblioteca de Victoria"
library;

/// Estado de un día dentro del plan
enum DayStatus {
  locked,    // 🔒 Día futuro, bloqueado
  current,   // ▶️ Día actual disponible para leer
  completed, // ✅ Día completado
}

/// Nivel de dificultad del plan
enum PlanDifficulty {
  beginner,     // Principiante
  intermediate, // Intermedio
  advanced,     // Avanzado
}

/// Categoría temática del plan
enum PlanCategory {
  mentalBattles,      // Batallas Mentales
  relationshipsPurity, // Relaciones y Pureza
  faithFoundations,   // Fundamentos de Fe
}

/// Representa un día individual dentro de un plan
class PlanDay {
  final int dayNumber;
  final String title;
  final String verse;
  final String verseReference;
  final String reflection;
  final String prayer;
  final String challenge;

  const PlanDay({
    required this.dayNumber,
    required this.title,
    required this.verse,
    required this.verseReference,
    required this.reflection,
    required this.prayer,
    this.challenge = '',
  });
}

/// Modelo principal para un Plan Espiritual
class SpiritualPlan {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final PlanCategory category;
  final PlanDifficulty difficulty;
  final int totalDays;
  final String coverImageUrl;
  final String heroImageUrl;
  final List<PlanDay> days;
  final int completedByUsers; // Cantidad de usuarios que lo han completado
  
  // Estado del usuario (se actualizará con datos reales)
  final int currentDay;      // Día actual del usuario (0 = no iniciado)
  final bool isStarted;
  final bool isCompleted;

  const SpiritualPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.totalDays,
    required this.coverImageUrl,
    required this.heroImageUrl,
    required this.days,
    this.completedByUsers = 0,
    this.currentDay = 0,
    this.isStarted = false,
    this.isCompleted = false,
  });

  /// Progreso del usuario (0.0 - 1.0)
  double get progress {
    if (!isStarted || totalDays == 0) return 0.0;
    return (currentDay - 1) / totalDays;
  }

  /// Nombre legible de la categoría
  String get categoryName {
    switch (category) {
      case PlanCategory.mentalBattles:
        return 'Batallas Mentales';
      case PlanCategory.relationshipsPurity:
        return 'Relaciones y Pureza';
      case PlanCategory.faithFoundations:
        return 'Fundamentos de Fe';
    }
  }

  /// Nombre legible de la dificultad
  String get difficultyName {
    switch (difficulty) {
      case PlanDifficulty.beginner:
        return 'Principiante';
      case PlanDifficulty.intermediate:
        return 'Intermedio';
      case PlanDifficulty.advanced:
        return 'Avanzado';
    }
  }

  /// Obtener el estado de un día específico
  DayStatus getDayStatus(int dayNumber) {
    if (dayNumber < currentDay) return DayStatus.completed;
    if (dayNumber == currentDay) return DayStatus.current;
    return DayStatus.locked;
  }

  /// Copia del plan con progreso actualizado
  SpiritualPlan copyWithProgress({
    int? currentDay,
    bool? isStarted,
    bool? isCompleted,
  }) {
    return SpiritualPlan(
      id: id,
      title: title,
      subtitle: subtitle,
      description: description,
      category: category,
      difficulty: difficulty,
      totalDays: totalDays,
      coverImageUrl: coverImageUrl,
      heroImageUrl: heroImageUrl,
      days: days,
      completedByUsers: completedByUsers,
      currentDay: currentDay ?? this.currentDay,
      isStarted: isStarted ?? this.isStarted,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
