/// ═══════════════════════════════════════════════════════════════════════════
/// GameDifficulty — modo de dificultad compartido por los juegos bíblicos.
///
/// Mapea directamente al campo `difficulty` (1..3) de [LearningQuestion]:
///   • fácil   → 1
///   • medio   → 2
///   • difícil → 3
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

enum GameDifficulty { facil, medio, dificil }

extension GameDifficultyInfo on GameDifficulty {
  /// Nivel numérico equivalente al campo `difficulty` de las preguntas (1..3).
  int get level => index + 1;

  String get label {
    switch (this) {
      case GameDifficulty.facil:
        return 'Fácil';
      case GameDifficulty.medio:
        return 'Medio';
      case GameDifficulty.dificil:
        return 'Difícil';
    }
  }

  String get description {
    switch (this) {
      case GameDifficulty.facil:
        return 'Las más conocidas';
      case GameDifficulty.medio:
        return 'Un poco más de reto';
      case GameDifficulty.dificil:
        return 'Para quienes conocen bien la Biblia';
    }
  }

  IconData get icon {
    switch (this) {
      case GameDifficulty.facil:
        return Icons.sentiment_satisfied_alt_rounded;
      case GameDifficulty.medio:
        return Icons.psychology_alt_rounded;
      case GameDifficulty.dificil:
        return Icons.local_fire_department_rounded;
    }
  }

  Color get color {
    switch (this) {
      case GameDifficulty.facil:
        return AppDesignSystem.victory;
      case GameDifficulty.medio:
        return AppDesignSystem.gold;
      case GameDifficulty.dificil:
        return AppDesignSystem.struggle;
    }
  }
}
