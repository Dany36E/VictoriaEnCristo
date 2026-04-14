/// ═══════════════════════════════════════════════════════════════════════════
/// BADGE SERVICE - Evaluación y persistencia de insignias
/// Singleton · SharedPreferences + evaluación en tiempo real
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/badge_definition.dart';
import 'victory_scoring_service.dart';
import 'journal_service.dart';
import 'favorites_service.dart';
import 'plan_progress_service.dart';
import 'plan_repository.dart';
import 'bible/bible_reading_stats_service.dart';
import 'bible/bible_user_data_service.dart';

class BadgeService {
  // ── Singleton ──
  static final BadgeService _instance = BadgeService._internal();
  factory BadgeService() => _instance;
  BadgeService._internal();
  static BadgeService get I => _instance;

  static const String _storageKey = 'badge_unlocked_levels';

  /// Niveles previamente desbloqueados {categoryName: levelIndex}
  Map<String, int> _unlockedLevels = {};
  bool _isInitialized = false;

  /// Notifica cuando hay nuevas insignias desbloqueadas
  final ValueNotifier<BadgeUnlockEvent?> newBadgeNotifier = ValueNotifier(null);

  /// Callback para sincronización write-through (usado por BadgeSyncAdapter)
  void Function(Map<String, int> levels)? onBadgesChanged;

  /// Acceso de solo lectura a los niveles desbloqueados
  Map<String, int> get unlockedLevels => Map.unmodifiable(_unlockedLevels);

  Future<void> init() async {
    if (_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _unlockedLevels = decoded.map((k, v) => MapEntry(k, v as int));
    }
    _isInitialized = true;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_unlockedLevels));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LECTURA DE MÉTRICAS
  // ═══════════════════════════════════════════════════════════════════════════

  int _getMetric(BadgeCategory category) {
    switch (category) {
      case BadgeCategory.streak:
        return VictoryScoringService.I.getBestStreakAllTime();
      case BadgeCategory.victories:
        return VictoryScoringService.I.getTotalVictoriesForYear(DateTime.now().year);
      case BadgeCategory.reading:
        final durations = <String, int>{
          for (final p in PlanRepository.I.allPlans) p.id: p.durationDays,
        };
        return PlanProgressService.I.plansCompleted(durations);
      case BadgeCategory.bible:
        return BibleReadingStatsService.I.readChaptersNotifier.value.length;
      case BadgeCategory.journal:
        return JournalService().entries.length;
      case BadgeCategory.highlights:
        return BibleUserDataService.I.highlightsNotifier.value.length;
      case BadgeCategory.favorites:
        return FavoritesService().count;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // EVALUACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el nivel desbloqueado para una categoría
  BadgeLevel? _computeLevel(BadgeCategory category, int value) {
    final thresholds = category.thresholds;
    BadgeLevel? highest;
    for (int i = 0; i < thresholds.length; i++) {
      if (value >= thresholds[i]) {
        highest = BadgeLevel.values[i];
      } else {
        break;
      }
    }
    return highest;
  }

  /// Obtiene el progreso de todas las categorías
  List<BadgeProgress> getAllProgress() {
    return BadgeCategory.values.map((cat) {
      final value = _getMetric(cat);
      final level = _computeLevel(cat, value);
      final nextIdx = level != null ? level.index + 1 : 0;
      final nextLevel = nextIdx < BadgeLevel.values.length
          ? BadgeLevel.values[nextIdx]
          : null;
      return BadgeProgress(
        category: cat,
        currentValue: value,
        unlockedLevel: level,
        nextLevel: nextLevel,
      );
    }).toList();
  }

  /// Obtiene progreso de una categoría específica
  BadgeProgress getProgress(BadgeCategory category) {
    final value = _getMetric(category);
    final level = _computeLevel(category, value);
    final nextIdx = level != null ? level.index + 1 : 0;
    final nextLevel = nextIdx < BadgeLevel.values.length
        ? BadgeLevel.values[nextIdx]
        : null;
    return BadgeProgress(
      category: category,
      currentValue: value,
      unlockedLevel: level,
      nextLevel: nextLevel,
    );
  }

  /// Total de insignias desbloqueadas (suma de niveles de todas las categorías)
  int get totalUnlocked {
    int count = 0;
    for (final cat in BadgeCategory.values) {
      final value = _getMetric(cat);
      final level = _computeLevel(cat, value);
      if (level != null) count += level.index + 1;
    }
    return count;
  }

  /// Total posible (7 categorías × 7 niveles)
  int get totalPossible => BadgeCategory.values.length * BadgeLevel.values.length;

  // ═══════════════════════════════════════════════════════════════════════════
  // DETECCIÓN DE NUEVAS INSIGNIAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Evalúa todas las categorías y notifica si hay nuevas insignias.
  /// Retorna la lista de nuevos badges desbloqueados.
  Future<List<BadgeUnlockEvent>> checkForNewBadges() async {
    await init();
    final newBadges = <BadgeUnlockEvent>[];

    for (final cat in BadgeCategory.values) {
      final value = _getMetric(cat);
      final level = _computeLevel(cat, value);
      if (level == null) continue;

      final key = cat.name;
      final previousIdx = _unlockedLevels[key] ?? -1;

      if (level.index > previousIdx) {
        // Nuevo nivel desbloqueado (puede ser más de uno a la vez)
        for (int i = previousIdx + 1; i <= level.index; i++) {
          newBadges.add(BadgeUnlockEvent(
            category: cat,
            level: BadgeLevel.values[i],
            value: value,
          ));
        }
        _unlockedLevels[key] = level.index;
      }
    }

    if (newBadges.isNotEmpty) {
      await _save();
      // Notificar el badge más alto desbloqueado
      newBadgeNotifier.value = newBadges.last;
      onBadgesChanged?.call(Map.from(_unlockedLevels));
      debugPrint('🏅 [BADGE] ${newBadges.length} nuevas insignias desbloqueadas');
    }

    return newBadges;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HIDRATACIÓN DESDE CLOUD
  // ═══════════════════════════════════════════════════════════════════════════

  /// Restaurar niveles desde cloud (usado por DataBootstrapper)
  /// Merge: tomar nivel más alto entre local y cloud (badges nunca se des-desbloquean)
  Future<void> restoreFromCloud(Map<String, int> cloudLevels) async {
    if (cloudLevels.isEmpty) return;
    await init();

    bool changed = false;
    for (final entry in cloudLevels.entries) {
      final localLevel = _unlockedLevels[entry.key] ?? -1;
      if (entry.value > localLevel) {
        _unlockedLevels[entry.key] = entry.value;
        changed = true;
      }
    }

    if (changed) {
      await _save();
      debugPrint('🏅 [BADGE] Restored ${cloudLevels.length} badge levels from cloud');
    }
  }
}

class BadgeUnlockEvent {
  final BadgeCategory category;
  final BadgeLevel level;
  final int value;

  const BadgeUnlockEvent({
    required this.category,
    required this.level,
    required this.value,
  });
}
