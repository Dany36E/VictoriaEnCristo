/// ═══════════════════════════════════════════════════════════════════════════
/// FruitProgressService — avance por fruto (acciones marcadas + reflexión)
///
/// Un fruto se considera "ganado" (badge) cuando las 3 acciones están
/// marcadas hechas Y la reflexión fue escrita (≥ 20 caracteres).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class FruitProgress {
  final Set<String> doneActions; // action ids done
  final String reflection;

  const FruitProgress({this.doneActions = const {}, this.reflection = ''});

  FruitProgress copyWith({Set<String>? doneActions, String? reflection}) =>
      FruitProgress(
        doneActions: doneActions ?? this.doneActions,
        reflection: reflection ?? this.reflection,
      );

  Map<String, dynamic> toJson() => {
        'doneActions': doneActions.toList(),
        'reflection': reflection,
      };

  factory FruitProgress.fromJson(Map<String, dynamic> j) => FruitProgress(
        doneActions:
            (j['doneActions'] as List? ?? const []).cast<String>().toSet(),
        reflection: j['reflection'] as String? ?? '',
      );

  bool isComplete(int totalActions) =>
      doneActions.length >= totalActions && reflection.trim().length >= 20;
}

class FruitProgressState {
  final Map<String, FruitProgress> byFruit;
  final Set<String> badges; // fruits earned (awarded XP once)

  const FruitProgressState({
    this.byFruit = const {},
    this.badges = const {},
  });

  FruitProgressState copyWith({
    Map<String, FruitProgress>? byFruit,
    Set<String>? badges,
  }) =>
      FruitProgressState(
        byFruit: byFruit ?? this.byFruit,
        badges: badges ?? this.badges,
      );

  Map<String, dynamic> toJson() => {
        'byFruit':
            byFruit.map((k, v) => MapEntry(k, v.toJson())),
        'badges': badges.toList(),
      };

  factory FruitProgressState.fromJson(Map<String, dynamic> j) =>
      FruitProgressState(
        byFruit: (j['byFruit'] as Map? ?? const {}).map(
          (k, v) => MapEntry(
              k.toString(),
              FruitProgress.fromJson(
                  Map<String, dynamic>.from(v as Map))),
        ),
        badges:
            (j['badges'] as List? ?? const []).cast<String>().toSet(),
      );
}

class FruitProgressService {
  FruitProgressService._();
  static final FruitProgressService I = FruitProgressService._();

  static const String _kKey = 'fruit_progress_v1';

  SharedPreferences? _prefs;
  bool _init = false;

  final ValueNotifier<FruitProgressState> stateNotifier =
      ValueNotifier(const FruitProgressState());

  Future<void> init() async {
    if (_init) return;
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    final raw = _prefs?.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        stateNotifier.value = FruitProgressState.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _save(FruitProgressState s) async {
    await _prefs?.setString(_kKey, jsonEncode(s.toJson()));
    stateNotifier.value = s;
  }

  FruitProgress progressFor(String fruitId) =>
      stateNotifier.value.byFruit[fruitId] ?? const FruitProgress();

  bool hasBadge(String fruitId) =>
      stateNotifier.value.badges.contains(fruitId);

  Future<void> toggleAction(String fruitId, String actionId) async {
    await init();
    final s = stateNotifier.value;
    final fp = progressFor(fruitId);
    final next = {...fp.doneActions};
    if (next.contains(actionId)) {
      next.remove(actionId);
    } else {
      next.add(actionId);
    }
    final updatedFp = fp.copyWith(doneActions: next);
    await _save(s.copyWith(
      byFruit: {...s.byFruit, fruitId: updatedFp},
    ));
  }

  Future<void> setReflection(String fruitId, String text) async {
    await init();
    final s = stateNotifier.value;
    final fp = progressFor(fruitId).copyWith(reflection: text);
    await _save(s.copyWith(
      byFruit: {...s.byFruit, fruitId: fp},
    ));
  }

  /// Intenta otorgar la insignia. Devuelve XP ganado (0 si ya la tenía).
  Future<int> tryAwardBadge(
      String fruitId, int totalActions, int xpReward) async {
    await init();
    final s = stateNotifier.value;
    if (s.badges.contains(fruitId)) return 0;
    final fp = progressFor(fruitId);
    if (!fp.isComplete(totalActions)) return 0;
    await _save(s.copyWith(badges: {...s.badges, fruitId}));
    await LearningProgressService.I.addXp(xpReward);
    await LearningProgressService.I.recordStudyActivity();
    TalentsHooks.fruitBadge(fruitId);
    return xpReward;
  }

  int get badgeCount => stateNotifier.value.badges.length;
}
