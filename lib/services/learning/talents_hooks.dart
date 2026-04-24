/// ═══════════════════════════════════════════════════════════════════════════
/// TalentsHooks — punto único donde el resto de servicios disparan
/// recompensas. Centraliza las reglas (qué evento da cuántos talentos),
/// loguea analytics y delega en TalentsService.
///
/// Diseñado para ser fire-and-forget: ningún caller debe esperar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import 'talents_service.dart';

class TalentsHooks {
  TalentsHooks._();

  static void _award(int amount, String reason) {
    if (amount <= 0) return;
    unawaited(TalentsService.I.earn(amount, reason: reason));
    unawaited(_logAnalytics(amount, reason));
  }

  static Future<void> _logAnalytics(int amount, String reason) async {
    try {
      await FirebaseAnalytics.instance.logEvent(
        name: 'talents_earned',
        parameters: {
          'amount': amount,
          'reason': reason,
        },
      );
    } catch (e) {
      debugPrint('⭐ [TALENTS_HOOKS] analytics error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // EVENTOS DE GANANCIA
  // ──────────────────────────────────────────────────────────────────────

  /// Maná: se dispara una sola vez al final de la sesión, no por respuesta.
  /// [correctas] = preguntas acertadas, [perfecta] = sesión 7/7.
  static void manaSession({required int correctas, required bool perfecta}) {
    final total = correctas * TalentRewards.perCorrectAnswer +
        (perfecta ? TalentRewards.sessionPerfectBonus : 0);
    _award(total, 'mana_session');
  }

  static void verseMastered(String verseRef) =>
      _award(TalentRewards.verseMastered, 'verse:$verseRef');

  static void journeyStation(String stationId) =>
      _award(TalentRewards.journeyStation, 'station:$stationId');

  static void heroUnlocked(String heroId) =>
      _award(TalentRewards.heroUnlocked, 'hero:$heroId');

  static void parableCompleted(String parableId) =>
      _award(TalentRewards.parableCompleted, 'parable:$parableId');

  static void timelineLessonStars(String lessonId, int stars) =>
      _award(stars * TalentRewards.timelineLessonStar, 'timeline:$lessonId');

  static void fruitBadge(String fruitId) =>
      _award(TalentRewards.fruitBadge, 'fruit:$fruitId');

  static void mapStars(String mapId, int stars) =>
      _award(stars * TalentRewards.mapPerStar, 'map:$mapId');

  static void prophecyStars(String prophecyId, int stars) =>
      _award(stars * TalentRewards.prophecyPerStar, 'prophecy:$prophecyId');

  static void bookStudied(String bookId) =>
      _award(TalentRewards.bookStudied, 'book:$bookId');

  static void bibleOrderStars(int stars) =>
      _award(stars * TalentRewards.bibleOrderPerStar, 'order_round');

  /// Streak diario. Solo otorga si cruza 7 o 30 (lo verifica el caller).
  static void streakMilestone(int days) {
    if (days == 7) {
      _award(TalentRewards.streak7, 'streak_7');
    } else if (days == 30) {
      _award(TalentRewards.streak30, 'streak_30');
    }
  }
}
