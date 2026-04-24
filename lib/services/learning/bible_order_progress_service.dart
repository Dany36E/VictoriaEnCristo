import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class BibleOrderProgressState {
  /// categoryKey → best stars (1-3)
  final Map<String, int> bestStars;
  const BibleOrderProgressState({this.bestStars = const {}});
  BibleOrderProgressState copyWith({Map<String, int>? bestStars}) =>
      BibleOrderProgressState(bestStars: bestStars ?? this.bestStars);

  int get totalStars => bestStars.values.fold(0, (a, b) => a + b);
}

class BibleOrderProgressService {
  BibleOrderProgressService._();
  static final BibleOrderProgressService I = BibleOrderProgressService._();

  static const _kKey = 'bible_order.stars';

  final ValueNotifier<BibleOrderProgressState> stateNotifier =
      ValueNotifier(const BibleOrderProgressState());
  BibleOrderProgressState get state => stateNotifier.value;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kKey);
    Map<String, int> stars = {};
    if (raw != null) {
      try {
        final m = json.decode(raw) as Map<String, dynamic>;
        stars = m.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
    stateNotifier.value = BibleOrderProgressState(bestStars: stars);
  }

  Future<int> recordRound({
    required String categoryKey,
    required int stars,
    int xpReward = 15,
  }) async {
    final p = await SharedPreferences.getInstance();
    final cur = state;
    final prev = cur.bestStars[categoryKey] ?? 0;
    final newStars = Map<String, int>.from(cur.bestStars);
    if (stars > prev) newStars[categoryKey] = stars;
    await p.setString(_kKey, json.encode(newStars));
    stateNotifier.value = cur.copyWith(bestStars: newStars);
    var xp = 0;
    if (prev == 0) {
      xp = xpReward;
      await LearningProgressService.I.addXp(xp);
      await LearningProgressService.I.recordStudyActivity();
      TalentsHooks.bibleOrderStars(stars);
    }
    return xp;
  }
}
