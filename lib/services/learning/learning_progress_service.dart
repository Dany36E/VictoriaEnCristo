/// ═══════════════════════════════════════════════════════════════════════════
/// LearningProgressService — XP, nivel espiritual, hearts, racha de estudio.
///
/// Persiste en SharedPreferences bajo `learning.progress.v2` (migra el legado
/// `learning_progress_v1` la primera vez).
///
/// Cambios v2 vs v1:
///   • Hearts: pasan de "3 por día y se acaban" a sistema regenerativo
///     (1 cada 4 h, máximo 5). NO bloquean sesiones — solo amortiguan errores.
///   • Escudo de gracia (1/semana ISO): si el usuario perdió un día, el primer
///     hueco semanal se perdona y la racha NO se resetea.
///   • Bonus de fin de sesión: ya no se premia perfeccionismo (100%). Se
///     premia terminar (+5) y la honestidad (+3 si marcó "no la sabía").
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/learning/learning_models.dart';
import '../../utils/time_utils.dart';
import 'talents_hooks.dart';

/// Política de hearts (centralizada para evitar magic numbers).
class HeartsPolicy {
  static const int maxHearts = 5;
  static const int regenIntervalHours = 4;
  static int get regenIntervalMs =>
      regenIntervalHours * 60 * 60 * 1000;
}

class LearningProgressService {
  LearningProgressService._();
  static final LearningProgressService I = LearningProgressService._();

  static const String _kProgressV2 = 'learning.progress.v2';
  static const String _kProgressV1Legacy = 'learning_progress_v1';

  SharedPreferences? _prefs;
  bool _init = false;

  final ValueNotifier<LearningProgress> progressNotifier =
      ValueNotifier(const LearningProgress.initial());

  Future<void> init() async {
    if (_init) {
      _refreshFromStorage();
      _maybeRegenHearts();
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    await _migrateLegacyIfNeeded();
    _refreshFromStorage();
    _maybeRegenHearts();
    debugPrint(
        '🎓 [PROGRESS] Init XP=${progressNotifier.value.totalXp} '
        'hearts=${progressNotifier.value.hearts}/${HeartsPolicy.maxHearts} '
        'streak=${progressNotifier.value.studyStreak}');
  }

  /// Migración no destructiva v1 → v2.
  Future<void> _migrateLegacyIfNeeded() async {
    final hasV2 = _prefs?.containsKey(_kProgressV2) ?? false;
    if (hasV2) return;
    final raw = _prefs?.getString(_kProgressV1Legacy);
    if (raw == null || raw.isEmpty) return;
    try {
      jsonDecode(raw); // valida
      await _prefs?.setString(_kProgressV2, raw);
      await _prefs?.remove(_kProgressV1Legacy);
      debugPrint('🎓 [PROGRESS] Migrado v1 → v2');
    } catch (_) {/* no tocar v1 si está corrupto */}
  }

  void _refreshFromStorage() {
    final raw = _prefs?.getString(_kProgressV2);
    if (raw == null || raw.isEmpty) {
      progressNotifier.value = const LearningProgress.initial();
      return;
    }
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      progressNotifier.value = LearningProgress.fromJson(j);
    } catch (_) {
      progressNotifier.value = const LearningProgress.initial();
    }
  }

  Future<void> _save(LearningProgress p) async {
    await _prefs?.setString(_kProgressV2, jsonEncode(p.toJson()));
    progressNotifier.value = p;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HEARTS — regeneración gradual (no bloqueante)
  // ══════════════════════════════════════════════════════════════════════════

  /// Recalcula hearts según tiempo transcurrido. Idempotente.
  void _maybeRegenHearts() {
    final p = progressNotifier.value;
    if (p.hearts >= HeartsPolicy.maxHearts) {
      if (p.heartsLastRefillMs == 0) {
        _save(p.copyWith(
            heartsLastRefillMs: DateTime.now().millisecondsSinceEpoch));
      }
      return;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final baseMs = p.heartsLastRefillMs;
    if (baseMs == 0) {
      _save(p.copyWith(heartsLastRefillMs: nowMs));
      return;
    }
    final elapsed = nowMs - baseMs;
    if (elapsed < HeartsPolicy.regenIntervalMs) return;
    final ticks = elapsed ~/ HeartsPolicy.regenIntervalMs;
    final newHearts = (p.hearts + ticks).clamp(0, HeartsPolicy.maxHearts);
    if (newHearts == p.hearts) return;
    final consumed = (newHearts - p.hearts) * HeartsPolicy.regenIntervalMs;
    _save(p.copyWith(
      hearts: newHearts,
      heartsLastRefillMs: baseMs + consumed,
    ));
  }

  /// Milisegundos hasta el próximo heart (0 si ya está al máximo).
  int msUntilNextHeart() {
    final p = progressNotifier.value;
    if (p.hearts >= HeartsPolicy.maxHearts) return 0;
    if (p.heartsLastRefillMs == 0) return HeartsPolicy.regenIntervalMs;
    final elapsed =
        DateTime.now().millisecondsSinceEpoch - p.heartsLastRefillMs;
    final remaining = HeartsPolicy.regenIntervalMs - elapsed;
    return remaining < 0 ? 0 : remaining;
  }

  /// Consume un heart si tiene. Devuelve true si descontó.
  /// Importante: el llamador NO debe bloquear la sesión cuando devuelve false.
  Future<bool> spendHeart() async {
    await init();
    _maybeRegenHearts();
    final p = progressNotifier.value;
    if (p.hearts <= 0) return false;
    final newHearts = p.hearts - 1;
    final newRefillMs = (p.hearts == HeartsPolicy.maxHearts)
        ? DateTime.now().millisecondsSinceEpoch
        : p.heartsLastRefillMs;
    await _save(p.copyWith(
      hearts: newHearts,
      heartsLastRefillMs: newRefillMs,
    ));
    return true;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // XP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> addXp(int amount) async {
    if (amount <= 0) return;
    await init();
    final p = progressNotifier.value;
    await _save(p.copyWith(totalXp: p.totalXp + amount));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SESIONES + STREAK + ESCUDO DE GRACIA
  // ══════════════════════════════════════════════════════════════════════════

  /// Registra una sesión Maná completada.
  ///
  /// Política XP (D3 — sin perfeccionismo):
  ///   • +5 por respuesta correcta
  ///   • +5 bonus por terminar (independiente de aciertos)
  ///   • +3 bonus por honestidad si marcó "no la sabía" alguna vez
  Future<SessionXpReward> recordSessionCompleted({
    required int correctAnswers,
    required int totalAnswers,
    bool usedHonestyOption = false,
  }) async {
    await init();
    final p = progressNotifier.value;
    final today = TimeUtils.dateToISO(DateTime.now());

    final base = correctAnswers * 5;
    const bonusFinish = 5;
    final bonusHonesty = usedHonestyOption ? 3 : 0;
    final xp = base + bonusFinish + bonusHonesty;

    final next = _computeNextStreak(
      previousLastStudy: p.lastStudyDate,
      previousStreak: p.studyStreak,
      previousGraceDate: p.lastGraceShieldDate,
      today: today,
    );

    await _save(p.copyWith(
      totalXp: p.totalXp + xp,
      sessionsCompleted: p.sessionsCompleted + 1,
      lastStudyDate: today,
      studyStreak: next.streak,
      lastGraceShieldDate:
          next.usedGraceShield ? today : p.lastGraceShieldDate,
    ));

    // Talentos: sesión completa + bonus si fue 7/7. Streak milestones se
    // recompensan al cruzar 7 o 30.
    TalentsHooks.manaSession(
      correctas: correctAnswers,
      perfecta: correctAnswers == totalAnswers && totalAnswers > 0,
    );
    if (next.streak != p.studyStreak) {
      TalentsHooks.streakMilestone(next.streak);
    }

    return SessionXpReward(
      total: xp,
      base: base,
      bonusFinish: bonusFinish,
      bonusHonesty: bonusHonesty,
      usedGraceShield: next.usedGraceShield,
      newStreak: next.streak,
    );
  }

  /// Registra estudio puntual (review de versículo, etc) — actualiza streak
  /// con escudo de gracia si aplica.
  Future<void> recordStudyActivity() async {
    await init();
    final p = progressNotifier.value;
    final today = TimeUtils.dateToISO(DateTime.now());
    if (p.lastStudyDate == today) return;
    final next = _computeNextStreak(
      previousLastStudy: p.lastStudyDate,
      previousStreak: p.studyStreak,
      previousGraceDate: p.lastGraceShieldDate,
      today: today,
    );
    await _save(p.copyWith(
      lastStudyDate: today,
      studyStreak: next.streak,
      lastGraceShieldDate:
          next.usedGraceShield ? today : p.lastGraceShieldDate,
    ));
  }

  Future<void> setVersesMastered(int count) async {
    await init();
    final p = progressNotifier.value;
    if (p.versesMastered == count) return;
    await _save(p.copyWith(versesMastered: count));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // STREAK GRACE — política
  //   • Mismo día           → mantener
  //   • Ayer                → +1
  //   • Antes de ayer + escudo disponible esta semana → +1 + consume escudo
  //   • Resto               → reset a 1
  // ══════════════════════════════════════════════════════════════════════════

  _StreakResult _computeNextStreak({
    required String previousLastStudy,
    required int previousStreak,
    required String previousGraceDate,
    required String today,
  }) {
    if (previousLastStudy == today) {
      return _StreakResult(streak: previousStreak, usedGraceShield: false);
    }
    if (_isYesterday(previousLastStudy, today)) {
      return _StreakResult(
          streak: previousStreak + 1, usedGraceShield: false);
    }
    if (_daysBetween(previousLastStudy, today) == 2 &&
        _canUseGraceShield(previousGraceDate, today)) {
      return _StreakResult(streak: previousStreak + 1, usedGraceShield: true);
    }
    return const _StreakResult(streak: 1, usedGraceShield: false);
  }

  bool _canUseGraceShield(String previousGraceDate, String today) {
    if (previousGraceDate.isEmpty) return true;
    try {
      final prev = DateTime.parse(previousGraceDate);
      final now = DateTime.parse(today);
      return _isoWeekKey(prev) != _isoWeekKey(now);
    } catch (_) {
      return true;
    }
  }

  /// ¿Está disponible el escudo de gracia esta semana?
  bool get isGraceShieldAvailable {
    final p = progressNotifier.value;
    final today = TimeUtils.dateToISO(DateTime.now());
    return _canUseGraceShield(p.lastGraceShieldDate, today);
  }

  String _isoWeekKey(DateTime d) {
    final dayOfYear = d.difference(DateTime(d.year, 1, 1)).inDays + 1;
    return '${d.year}-${dayOfYear ~/ 7}';
  }

  bool _isYesterday(String prevIso, String todayIso) {
    return _daysBetween(prevIso, todayIso) == 1;
  }

  int _daysBetween(String prevIso, String todayIso) {
    if (prevIso.isEmpty) return -1;
    try {
      final prev = DateTime.parse(prevIso);
      final today = DateTime.parse(todayIso);
      return today.difference(prev).inDays;
    } catch (_) {
      return -1;
    }
  }
}

class _StreakResult {
  final int streak;
  final bool usedGraceShield;
  const _StreakResult({required this.streak, required this.usedGraceShield});
}

/// Desglose detallado del XP otorgado al cerrar una sesión.
class SessionXpReward {
  final int total;
  final int base;
  final int bonusFinish;
  final int bonusHonesty;
  final bool usedGraceShield;
  final int newStreak;
  const SessionXpReward({
    required this.total,
    required this.base,
    required this.bonusFinish,
    required this.bonusHonesty,
    required this.usedGraceShield,
    required this.newStreak,
  });
}
