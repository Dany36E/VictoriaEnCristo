import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/content_enums.dart';
import '../models/content_item.dart';
import '../models/giant_frequency.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'content_repository.dart';
import 'onboarding_service.dart';
import 'user_pref_cloud_sync_service.dart';
import 'victory_scoring_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PERSONALIZATION ENGINE
/// Motor de recomendaciones explicables basado en reglas determinísticas
/// ═══════════════════════════════════════════════════════════════════════════

class PersonalizationEngine {
  // Singleton
  static final PersonalizationEngine _instance = PersonalizationEngine._internal();
  factory PersonalizationEngine() => _instance;
  PersonalizationEngine._internal();

  static PersonalizationEngine get I => _instance;

  // Dependencias
  final ContentRepository _repo = ContentRepository.I;
  final OnboardingService _onboarding = OnboardingService();

  // ═══════════════════════════════════════════════════════════════════════════
  // HISTORIAL DE RECOMENDACIONES (diario, reset cada día)
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _historyKey = 'recommendation_history_v1';
  Set<String> _shownToday = {};
  String _historyDate = '';

  /// Cargar IDs mostrados hoy desde SharedPreferences
  Future<void> _loadHistory() async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (_historyDate == today && _shownToday.isNotEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final savedDate = data['date'] as String? ?? '';
        if (savedDate == today) {
          _shownToday = Set<String>.from(data['ids'] as List<dynamic>? ?? []);
        } else {
          _shownToday = {};
        }
      }
    } catch (e) {
      debugPrint('⚠️ [PERSONALIZATION] _loadHistory error: $e');
      _shownToday = {};
    }
    _historyDate = today;
  }

  /// Persistir IDs mostrados hoy
  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _historyKey,
        jsonEncode({'date': _historyDate, 'ids': _shownToday.toList()}),
      );
      UserPrefCloudSyncService.I.markDirty();
    } catch (e) {
      debugPrint('⚠️ [PERSONALIZATION] _saveHistory error: $e');
    }
  }

  /// Registrar IDs como mostrados y obtener historial actual
  Set<String> _getRecentIds() => Set<String>.from(_shownToday);

  void _recordShownIds(Set<String> ids) {
    _shownToday.addAll(ids);
    _saveHistory(); // fire-and-forget
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTEXTO DEL USUARIO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener gigantes seleccionados del usuario
  List<GiantId> get userGiants {
    final legacyIds = _onboarding.selectedGiants;
    return legacyIds.map((id) => GiantIdExtension.fromLegacyId(id)).whereType<GiantId>().toList();
  }

  /// Obtener frecuencias por gigante
  Map<GiantId, BattleFrequency> get giantFrequencies {
    final raw = _onboarding.loadGiantFrequencies();
    final result = <GiantId, BattleFrequency>{};

    for (final entry in raw.entries) {
      final giant = GiantIdExtension.fromLegacyId(entry.key);
      final freq = BattleFrequencyExtension.fromId(entry.value);
      if (giant != null && freq != null) {
        result[giant] = freq;
      }
    }

    return result;
  }

  /// Determinar el gigante primario (el de mayor frecuencia)
  GiantId? get primaryGiant {
    final frequencies = giantFrequencies;
    if (frequencies.isEmpty) {
      // Fallback: primer gigante seleccionado
      return userGiants.isNotEmpty ? userGiants.first : null;
    }

    // Ordenar por frecuencia (daily > severalPerWeek > weekly > occasional)
    final sorted = frequencies.entries.toList()
      ..sort((a, b) {
        final freqCompare = a.value.index.compareTo(b.value.index);
        if (freqCompare != 0) return freqCompare;
        // Empate: usar prioridad del gigante
        return a.key.priority.compareTo(b.key.priority);
      });

    return sorted.first.key;
  }

  /// Determinar la etapa actual del usuario basada en contexto
  ContentStage getUserStage({bool isCrisisMode = false, bool recentRelapse = false}) {
    if (isCrisisMode) return ContentStage.crisis;
    if (recentRelapse) return ContentStage.restoration;

    final streak = VictoryScoringService.I.currentStreakNotifier.value;
    if (streak >= 66) return ContentStage.maintenance;
    return ContentStage.habit;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SCORING SYSTEM
  // ═══════════════════════════════════════════════════════════════════════════

  /// Calcula el score de un item para el usuario actual
  ScoredItem<T> scoreItem<T extends ContentItem>(
    T item, {
    ContentStage? userStage,
    Set<String>? recentlyShownIds,
    bool isCrisisMode = false,
  }) {
    int score = 0;
    final reasons = <String>[];
    final stage = userStage ?? getUserStage(isCrisisMode: isCrisisMode);
    final primary = primaryGiant;

    // ─────────────────────────────────────────────────────────────────────────
    // A) MATCH POR GIGANTE
    // ─────────────────────────────────────────────────────────────────────────

    if (item.metadata.giants.isEmpty) {
      // Contenido general: score bajo pero no excluido
      score += 10;
    } else if (primary != null && item.metadata.giants.contains(primary)) {
      // Match con gigante primario: máximo bonus
      score += 100;
      reasons.add(primary.displayName);
    } else if (item.metadata.appliesToAnyGiant(userGiants)) {
      // Match con algún gigante seleccionado
      score += 50;
      final matchedGiant = item.metadata.giants.firstWhere(
        (g) => userGiants.contains(g),
        orElse: () =>
            item.metadata.giants.isNotEmpty ? item.metadata.giants.first : userGiants.first,
      );
      reasons.add(matchedGiant.displayName);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // B) MATCH POR ETAPA
    // ─────────────────────────────────────────────────────────────────────────

    if (item.metadata.stage == stage) {
      score += 40;
      reasons.add('etapa de ${stage.displayName.toLowerCase()}');
    } else if (isCrisisMode && item.metadata.stage == ContentStage.crisis) {
      // Bonus extra para crisis cuando está en modo crisis
      score += 60;
      reasons.add('contenido de crisis');
    }

    // ─────────────────────────────────────────────────────────────────────────
    // C) CALIDAD EDITORIAL
    // ─────────────────────────────────────────────────────────────────────────

    switch (item.metadata.reviewLevel) {
      case ReviewLevel.approved:
        score += 20;
        break;
      case ReviewLevel.reviewed:
        score += 10;
        break;
      case ReviewLevel.draft:
        // Penalización severa - no mostrar en producción
        score -= 999;
        break;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // D) DIVERSIDAD (PENALIZAR REPETICIÓN)
    // ─────────────────────────────────────────────────────────────────────────

    if (recentlyShownIds != null && recentlyShownIds.contains(item.id)) {
      score -= 30;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // E) MATCH POR INTENSIDAD
    // ─────────────────────────────────────────────────────────────────────────

    final frequencies = giantFrequencies;
    if (item.metadata.intensityFit != null && primary != null) {
      final userFreq = frequencies[primary];
      if (userFreq != null) {
        final expectedIntensity = _frequencyToIntensity(userFreq);
        if (item.metadata.intensityFit == expectedIntensity) {
          score += 15;
        }
      }
    }

    // Construir razón explicable
    final reason = reasons.isNotEmpty
        ? 'Recomendado por: ${reasons.join(' + ')}'
        : 'Contenido general';

    return ScoredItem(item: item, score: score, reason: reason);
  }

  /// Convertir frecuencia a intensidad esperada
  IntensityFit _frequencyToIntensity(BattleFrequency freq) {
    switch (freq) {
      case BattleFrequency.daily:
        return IntensityFit.strong;
      case BattleFrequency.severalPerWeek:
        return IntensityFit.strong;
      case BattleFrequency.weekly:
        return IntensityFit.medium;
      case BattleFrequency.occasional:
        return IntensityFit.light;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECOMENDACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Ordenar items por score (mayor primero)
  List<ScoredItem<T>> rankItems<T extends ContentItem>(
    List<T> items, {
    ContentStage? userStage,
    Set<String>? recentlyShownIds,
    bool isCrisisMode = false,
  }) {
    final scored = items
        .map(
          (item) => scoreItem(
            item,
            userStage: userStage,
            recentlyShownIds: recentlyShownIds,
            isCrisisMode: isCrisisMode,
          ),
        )
        .toList();

    // Filtrar drafts y ordenar por score
    scored.removeWhere((s) => s.score < -500);
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored;
  }

  /// Obtener versículos recomendados
  List<ScoredItem<VerseItem>> getRecommendedVerses({
    int limit = 5,
    bool isCrisisMode = false,
    Set<String>? recentlyShownIds,
  }) {
    final ranked = rankItems(
      _repo.verses,
      isCrisisMode: isCrisisMode,
      recentlyShownIds: recentlyShownIds,
    );
    return ranked.take(limit).toList();
  }

  /// Obtener versículo ancla del día
  ScoredItem<VerseItem>? getAnchorVerse({bool isCrisisMode = false}) {
    final ranked = getRecommendedVerses(limit: 1, isCrisisMode: isCrisisMode);
    return ranked.isNotEmpty ? ranked.first : null;
  }

  /// Obtener oraciones recomendadas
  List<ScoredItem<PrayerItem>> getRecommendedPrayers({
    int limit = 3,
    bool isCrisisMode = false,
    Set<String>? recentlyShownIds,
  }) {
    final ranked = rankItems(
      _repo.prayers,
      isCrisisMode: isCrisisMode,
      recentlyShownIds: recentlyShownIds,
    );
    return ranked.take(limit).toList();
  }

  /// Obtener prompt de diario recomendado
  ScoredItem<JournalPromptItem>? getRecommendedJournalPrompt() {
    final ranked = rankItems(_repo.journalPrompts);
    return ranked.isNotEmpty ? ranked.first : null;
  }

  /// Obtener ejercicios recomendados (para crisis)
  List<ScoredItem<ExerciseItem>> getRecommendedExercises({
    int limit = 3,
    bool isCrisisMode = true,
  }) {
    final ranked = rankItems(_repo.exercises, isCrisisMode: isCrisisMode);
    return ranked.take(limit).toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // "PARA TI HOY" - MEZCLA DIVERSA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener recomendaciones mixtas para "Para ti hoy"
  ForYouTodayBundle getForYouToday({bool isCrisisMode = false}) {
    // Cargar historial (async pero no bloqueante — usa cache en memoria)
    _loadHistory(); // fire-and-forget, próxima vez tendrá datos
    final recentIds = _getRecentIds();

    // 1 versículo ancla
    final anchor = getAnchorVerse(isCrisisMode: isCrisisMode);
    if (anchor != null) recentIds.add(anchor.item.id);

    // 3-5 versículos de batalla
    final battleVerses = getRecommendedVerses(
      limit: 5,
      isCrisisMode: isCrisisMode,
      recentlyShownIds: recentIds,
    );
    for (final v in battleVerses) {
      recentIds.add(v.item.id);
    }

    // 1-3 oraciones
    final prayers = getRecommendedPrayers(
      limit: 3,
      isCrisisMode: isCrisisMode,
      recentlyShownIds: recentIds,
    );

    // 1 prompt de diario
    final journalPrompt = getRecommendedJournalPrompt();

    // Ejercicios (solo si crisis)
    final exercises = isCrisisMode
        ? getRecommendedExercises(limit: 2)
        : <ScoredItem<ExerciseItem>>[];

    // Registrar todos los IDs mostrados para no repetir hoy
    _recordShownIds(recentIds);

    return ForYouTodayBundle(
      primaryGiant: primaryGiant,
      anchorVerse: anchor,
      battleVerses: battleVerses,
      prayers: prayers,
      journalPrompt: journalPrompt,
      exercises: exercises,
      isCrisisMode: isCrisisMode,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CATEGORÍAS ORDENADAS POR USUARIO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtener categorías de versículos ordenadas (gigantes del usuario primero)
  List<VerseCategory> getOrderedVerseCategories() {
    final categories = <VerseCategory>[];

    // Primero: categorías de los gigantes del usuario
    for (final giant in userGiants) {
      final verses = _repo.getVersesForGiants([giant]);
      if (verses.isNotEmpty) {
        categories.add(
          VerseCategory(
            id: giant.id,
            name: giant.displayName,
            emoji: giant.emoji,
            verses: verses,
            isUserGiant: true,
          ),
        );
      }
    }

    // Después: categorías generales

    // Añadir categorías por etapa si hay contenido
    final crisisVerses = _repo.getCrisisVerses();
    if (crisisVerses.isNotEmpty) {
      categories.add(
        VerseCategory(
          id: 'crisis',
          name: 'Emergencia',
          emoji: '🆘',
          verses: crisisVerses,
          isUserGiant: false,
        ),
      );
    }

    // Añadir "Todos" al final
    categories.add(
      VerseCategory(
        id: 'all',
        name: 'Todos',
        emoji: '📚',
        verses: _repo.verses,
        isUserGiant: false,
      ),
    );

    return categories;
  }

  /// Obtener categorías de oraciones ordenadas
  List<PrayerCategory> getOrderedPrayerCategories() {
    final categories = <PrayerCategory>[];

    // Emergencia primero si el usuario lo necesita
    final emergencyPrayers = _repo.getEmergencyPrayers();
    if (emergencyPrayers.isNotEmpty) {
      categories.add(
        PrayerCategory(id: 'emergency', name: 'Emergencia', emoji: '🆘', prayers: emergencyPrayers),
      );
    }

    // Restauración
    final restorationPrayers = _repo.getRestorationPrayers();
    if (restorationPrayers.isNotEmpty) {
      categories.add(
        PrayerCategory(
          id: 'restoration',
          name: 'Restauración',
          emoji: '🩹',
          prayers: restorationPrayers,
        ),
      );
    }

    // Por gigantes del usuario
    for (final giant in userGiants) {
      final prayers = _repo.getPrayersForGiants([giant]);
      if (prayers.isNotEmpty) {
        categories.add(
          PrayerCategory(
            id: giant.id,
            name: giant.displayName,
            emoji: giant.emoji,
            prayers: prayers,
          ),
        );
      }
    }

    // Todos
    categories.add(PrayerCategory(id: 'all', name: 'Todas', emoji: '🙏', prayers: _repo.prayers));

    return categories;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// MODELOS DE RESULTADO
// ═══════════════════════════════════════════════════════════════════════════

/// Item con score y razón de recomendación
class ScoredItem<T> {
  final T item;
  final int score;
  final String reason;

  const ScoredItem({required this.item, required this.score, required this.reason});

  @override
  String toString() => 'ScoredItem(score: $score, reason: $reason)';
}

/// Bundle de recomendaciones para "Para ti hoy"
class ForYouTodayBundle {
  final GiantId? primaryGiant;
  final ScoredItem<VerseItem>? anchorVerse;
  final List<ScoredItem<VerseItem>> battleVerses;
  final List<ScoredItem<PrayerItem>> prayers;
  final ScoredItem<JournalPromptItem>? journalPrompt;
  final List<ScoredItem<ExerciseItem>> exercises;
  final bool isCrisisMode;

  const ForYouTodayBundle({
    this.primaryGiant,
    this.anchorVerse,
    this.battleVerses = const [],
    this.prayers = const [],
    this.journalPrompt,
    this.exercises = const [],
    this.isCrisisMode = false,
  });

  /// Total de items recomendados
  int get totalItems {
    return (anchorVerse != null ? 1 : 0) +
        battleVerses.length +
        prayers.length +
        (journalPrompt != null ? 1 : 0) +
        exercises.length;
  }
}

/// Categoría de versículos para UI
class VerseCategory {
  final String id;
  final String name;
  final String emoji;
  final List<VerseItem> verses;
  final bool isUserGiant;

  const VerseCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.verses,
    this.isUserGiant = false,
  });
}

/// Categoría de oraciones para UI
class PrayerCategory {
  final String id;
  final String name;
  final String emoji;
  final List<PrayerItem> prayers;

  const PrayerCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.prayers,
  });
}
