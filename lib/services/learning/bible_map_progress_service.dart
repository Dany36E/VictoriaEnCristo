/// ═══════════════════════════════════════════════════════════════════════════
/// BibleMapProgressService — estado de avance en Tierras Bíblicas
///
/// Persiste mapas completados y estrellas obtenidas en SharedPreferences.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'bible_map_repository.dart';
import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class BibleMapProgressState {
  /// mapId → estrellas obtenidas (1-3)
  final Map<String, int> completedMaps;

  const BibleMapProgressState({this.completedMaps = const {}});

  BibleMapProgressState copyWith({Map<String, int>? completedMaps}) =>
      BibleMapProgressState(completedMaps: completedMaps ?? this.completedMaps);

  Map<String, dynamic> toJson() => {'completedMaps': completedMaps};

  factory BibleMapProgressState.fromJson(Map<String, dynamic> j) {
    final raw = j['completedMaps'] as Map<String, dynamic>? ?? {};
    return BibleMapProgressState(completedMaps: raw.map((k, v) => MapEntry(k, v as int)));
  }
}

class BibleMapProgressService {
  BibleMapProgressService._();
  static final BibleMapProgressService I = BibleMapProgressService._();

  static const String _kKey = 'bible_map_progress_v1';

  SharedPreferences? _prefs;
  bool _init = false;

  final ValueNotifier<BibleMapProgressState> stateNotifier = ValueNotifier(
    const BibleMapProgressState(),
  );

  Future<void> init() async {
    if (_init) {
      _refreshFromStorage();
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    _refreshFromStorage();
    debugPrint('🌍 [MAPS] Progress init completed=${stateNotifier.value.completedMaps.length}');
  }

  void _refreshFromStorage() {
    final raw = _prefs?.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        stateNotifier.value = BibleMapProgressState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        stateNotifier.value = const BibleMapProgressState();
      }
    } else {
      stateNotifier.value = const BibleMapProgressState();
    }
  }

  Future<void> _save(BibleMapProgressState s) async {
    await _prefs?.setString(_kKey, jsonEncode(s.toJson()));
    stateNotifier.value = s;
  }

  bool isCompleted(String mapId) => stateNotifier.value.completedMaps.containsKey(mapId);

  int starsFor(String mapId) => stateNotifier.value.completedMaps[mapId] ?? 0;

  /// ¿Está desbloqueado? El primer mapa siempre; los demás requieren
  /// que el anterior (por orden) esté completado.
  bool isUnlocked(String mapId) {
    final all = BibleMapRepository.I.all;
    final idx = all.indexWhere((m) => m.id == mapId);
    if (idx <= 0) return true;
    return isCompleted(all[idx - 1].id);
  }

  /// Marca un mapa como completado con estrellas, otorga XP.
  /// Solo actualiza si mejora la puntuación previa.
  Future<int> markCompleted(String mapId, int stars, int xpReward) async {
    await init();
    final s = stateNotifier.value;
    final prev = s.completedMaps[mapId] ?? 0;
    if (stars <= prev) return 0; // No mejoró
    final updated = s.copyWith(completedMaps: {...s.completedMaps, mapId: stars});
    await _save(updated);
    await LearningProgressService.I.addXp(xpReward);
    await LearningProgressService.I.recordStudyActivity();
    TalentsHooks.mapStars(mapId, stars);
    return xpReward;
  }

  int get completedCount => stateNotifier.value.completedMaps.length;

  int get totalStars => stateNotifier.value.completedMaps.values.fold(0, (a, b) => a + b);
}
