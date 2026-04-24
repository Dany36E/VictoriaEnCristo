import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class ProphecyProgressState {
  final Map<String, int> bestStars; // roundId -> stars (1..3)
  const ProphecyProgressState({this.bestStars = const {}});
  ProphecyProgressState copyWith({Map<String, int>? bestStars}) =>
      ProphecyProgressState(bestStars: bestStars ?? this.bestStars);
}

class ProphecyProgressService {
  ProphecyProgressService._();
  static final ProphecyProgressService I = ProphecyProgressService._();

  static const _kStars = 'prophecy.stars';

  final ValueNotifier<ProphecyProgressState> stateNotifier =
      ValueNotifier(const ProphecyProgressState());
  ProphecyProgressState get state => stateNotifier.value;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kStars);
    Map<String, int> stars = {};
    if (raw != null) {
      try {
        final m = json.decode(raw) as Map<String, dynamic>;
        stars = m.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
    stateNotifier.value = ProphecyProgressState(bestStars: stars);
  }

  /// Registra el resultado. Devuelve el XP otorgado (0 si no mejora).
  Future<int> recordRound({
    required String roundId,
    required int stars,
    required int xpReward,
  }) async {
    final p = await SharedPreferences.getInstance();
    final cur = state;
    final prev = cur.bestStars[roundId] ?? 0;
    final award = stars > prev;
    if (award) {
      final newStars = Map<String, int>.from(cur.bestStars);
      newStars[roundId] = stars;
      await p.setString(_kStars, json.encode(newStars));
      stateNotifier.value = cur.copyWith(bestStars: newStars);
      final xp = (xpReward * (stars / 3)).round();
      await LearningProgressService.I.addXp(xp);
      await LearningProgressService.I.recordStudyActivity();
      TalentsHooks.prophecyStars(roundId, stars);
      return xp;
    }
    return 0;
  }
}
