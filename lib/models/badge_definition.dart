/// Definiciones del sistema de insignias
library;

enum BadgeCategory {
  streak,      // Racha de victorias
  victories,   // Total de victorias
  reading,     // Planes completados
  bible,       // Capítulos leídos
  journal,     // Entradas de diario
  highlights,  // Textos resaltados
  favorites,   // Versículos guardados
  quiz,        // Sesiones Maná completadas
  memory,      // Versículos dominados
}

enum BadgeLevel {
  semilla,    // Nivel 1
  brote,      // Nivel 2
  planta,     // Nivel 3
  arbol,      // Nivel 4
  fruto,      // Nivel 5
  cosecha,    // Nivel 6
  corona,     // Nivel 7
}

extension BadgeLevelName on BadgeLevel {
  String get displayName {
    switch (this) {
      case BadgeLevel.semilla:  return 'Semilla';
      case BadgeLevel.brote:    return 'Brote';
      case BadgeLevel.planta:   return 'Planta';
      case BadgeLevel.arbol:    return 'Árbol';
      case BadgeLevel.fruto:    return 'Fruto';
      case BadgeLevel.cosecha:  return 'Cosecha';
      case BadgeLevel.corona:   return 'Corona';
    }
  }

  String get emoji {
    switch (this) {
      case BadgeLevel.semilla:  return '🌱';
      case BadgeLevel.brote:    return '🌿';
      case BadgeLevel.planta:   return '🌳';
      case BadgeLevel.arbol:    return '🏔️';
      case BadgeLevel.fruto:    return '🍇';
      case BadgeLevel.cosecha:  return '🌾';
      case BadgeLevel.corona:   return '👑';
    }
  }

  int get colorValue {
    switch (this) {
      case BadgeLevel.semilla:  return 0xFF8D6E63; // Tierra
      case BadgeLevel.brote:    return 0xFF66BB6A; // Verde
      case BadgeLevel.planta:   return 0xFF42A5F5; // Azul
      case BadgeLevel.arbol:    return 0xFFAB47BC; // Púrpura
      case BadgeLevel.fruto:    return 0xFFEF5350; // Rojo
      case BadgeLevel.cosecha:  return 0xFFFFB300; // Ámbar
      case BadgeLevel.corona:   return 0xFFD4A853; // Oro
    }
  }
}

extension BadgeCategoryInfo on BadgeCategory {
  String get displayName {
    switch (this) {
      case BadgeCategory.streak:     return 'Perseverancia';
      case BadgeCategory.victories:  return 'Victorias';
      case BadgeCategory.reading:    return 'Planes de Lectura';
      case BadgeCategory.bible:      return 'Lectura Bíblica';
      case BadgeCategory.journal:    return 'Reflexión';
      case BadgeCategory.highlights: return 'Resaltados';
      case BadgeCategory.favorites:  return 'Versículos Favoritos';
      case BadgeCategory.quiz:       return 'Maná Diario';
      case BadgeCategory.memory:     return 'Armadura Memorizada';
    }
  }

  String get emoji {
    switch (this) {
      case BadgeCategory.streak:     return '🔥';
      case BadgeCategory.victories:  return '⚔️';
      case BadgeCategory.reading:    return '📖';
      case BadgeCategory.bible:      return '📜';
      case BadgeCategory.journal:    return '📝';
      case BadgeCategory.highlights: return '🖍️';
      case BadgeCategory.favorites:  return '⭐';      case BadgeCategory.quiz:      return '🧠';
      case BadgeCategory.memory:    return '🛡️';    }
  }

  /// Umbrales para los 7 niveles
  List<int> get thresholds {
    switch (this) {
      case BadgeCategory.streak:     return [3, 7, 14, 30, 100, 200, 365];
      case BadgeCategory.victories:  return [7, 30, 100, 250, 500, 750, 1000];
      case BadgeCategory.reading:    return [1, 3, 5, 10, 20, 30, 50];
      case BadgeCategory.bible:      return [10, 50, 150, 300, 600, 900, 1189];
      case BadgeCategory.journal:    return [5, 25, 75, 150, 365, 700, 1000];
      case BadgeCategory.highlights: return [5, 20, 50, 100, 250, 500, 1000];
      case BadgeCategory.favorites:  return [5, 15, 40, 100, 200, 400, 750];
      case BadgeCategory.quiz:       return [1, 7, 30, 60, 120, 200, 365];
      case BadgeCategory.memory:     return [1, 3, 5, 10, 15, 20, 30];
    }
  }

  /// Mensaje de celebración al obtener cada nivel
  String celebrationMessage(BadgeLevel level) {
    final cat = displayName;
    switch (level) {
      case BadgeLevel.semilla:  return '¡Primera semilla de $cat plantada!';
      case BadgeLevel.brote:    return '¡Tu $cat está brotando!';
      case BadgeLevel.planta:   return '¡$cat crece con fuerza!';
      case BadgeLevel.arbol:    return '¡Tu $cat es un árbol firme!';
      case BadgeLevel.fruto:    return '¡$cat está dando fruto!';
      case BadgeLevel.cosecha:  return '¡Cosecha abundante en $cat!';
      case BadgeLevel.corona:   return '¡Corona de $cat! Eres un ejemplo.';
    }
  }
}

class BadgeProgress {
  final BadgeCategory category;
  final int currentValue;
  final BadgeLevel? unlockedLevel;  // Nivel más alto desbloqueado
  final BadgeLevel? nextLevel;      // Siguiente nivel por alcanzar

  const BadgeProgress({
    required this.category,
    required this.currentValue,
    this.unlockedLevel,
    this.nextLevel,
  });

  /// Progreso hacia el siguiente nivel (0.0 - 1.0)
  double get progressToNext {
    if (nextLevel == null) return 1.0; // Todos desbloqueados
    final thresholds = category.thresholds;
    final nextIdx = nextLevel!.index;
    final nextThreshold = thresholds[nextIdx];
    final prevThreshold = nextIdx > 0 ? thresholds[nextIdx - 1] : 0;
    final range = nextThreshold - prevThreshold;
    if (range <= 0) return 1.0;
    return ((currentValue - prevThreshold) / range).clamp(0.0, 1.0);
  }

  int? get nextThreshold {
    if (nextLevel == null) return null;
    return category.thresholds[nextLevel!.index];
  }
}
