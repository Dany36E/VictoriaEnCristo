/// ═══════════════════════════════════════════════════════════════════════════
/// HeroesProgressService — héroes desbloqueados por el usuario
///
/// A diferencia de la Travesía (lineal), los héroes se pueden desbloquear en
/// cualquier orden. Completar el reto de un héroe lo marca como conocido y
/// otorga XP al LearningProgressService.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/learning/hero_models.dart';
import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class HeroesProgressState {
  final Set<String> unlockedIds;

  const HeroesProgressState({this.unlockedIds = const {}});

  HeroesProgressState copyWith({Set<String>? unlockedIds}) =>
      HeroesProgressState(unlockedIds: unlockedIds ?? this.unlockedIds);

  Map<String, dynamic> toJson() => {
        'unlockedIds': unlockedIds.toList(),
      };

  factory HeroesProgressState.fromJson(Map<String, dynamic> j) =>
      HeroesProgressState(
        unlockedIds:
            (j['unlockedIds'] as List? ?? const []).cast<String>().toSet(),
      );
}

class HeroesProgressService {
  HeroesProgressService._();
  static final HeroesProgressService I = HeroesProgressService._();

  static const String _kKey = 'heroes_progress_v1';

  SharedPreferences? _prefs;
  bool _init = false;

  final ValueNotifier<HeroesProgressState> stateNotifier =
      ValueNotifier(const HeroesProgressState());

  Future<void> init() async {
    if (_init) return;
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    final raw = _prefs?.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        stateNotifier.value = HeroesProgressState.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        stateNotifier.value = const HeroesProgressState();
      }
    }
    debugPrint(
        '⚔️ [HEROES] Progress init unlocked=${stateNotifier.value.unlockedIds.length}');
  }

  Future<void> _save(HeroesProgressState s) async {
    await _prefs?.setString(_kKey, jsonEncode(s.toJson()));
    stateNotifier.value = s;
  }

  bool isUnlocked(String id) => stateNotifier.value.unlockedIds.contains(id);

  int get unlockedCount => stateNotifier.value.unlockedIds.length;

  /// Desbloquea un héroe, otorga XP y registra actividad.
  /// Devuelve el XP otorgado (0 si ya estaba desbloqueado).
  Future<int> unlock(HeroOfFaith hero) async {
    await init();
    final s = stateNotifier.value;
    if (s.unlockedIds.contains(hero.id)) return 0;
    final updated = s.copyWith(unlockedIds: {...s.unlockedIds, hero.id});
    await _save(updated);
    await LearningProgressService.I.addXp(hero.xpReward);
    await LearningProgressService.I.recordStudyActivity();
    TalentsHooks.heroUnlocked(hero.id);
    return hero.xpReward;
  }
}
