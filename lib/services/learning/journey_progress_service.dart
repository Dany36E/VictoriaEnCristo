/// ═══════════════════════════════════════════════════════════════════════════
/// JourneyProgressService — estado de avance en la Travesía bíblica
///
/// Persiste el conjunto de estaciones completadas en SharedPreferences.
/// Expone un ValueNotifier para reaccionar en la UI.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/learning/journey_models.dart';
import 'journey_repository.dart';
import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class JourneyProgressState {
  final Set<String> completedIds;

  const JourneyProgressState({this.completedIds = const {}});

  JourneyProgressState copyWith({Set<String>? completedIds}) =>
      JourneyProgressState(
        completedIds: completedIds ?? this.completedIds,
      );

  Map<String, dynamic> toJson() => {
        'completedIds': completedIds.toList(),
      };

  factory JourneyProgressState.fromJson(Map<String, dynamic> j) =>
      JourneyProgressState(
        completedIds:
            (j['completedIds'] as List? ?? const []).cast<String>().toSet(),
      );
}

class JourneyProgressService {
  JourneyProgressService._();
  static final JourneyProgressService I = JourneyProgressService._();

  static const String _kKey = 'journey_progress_v1';

  SharedPreferences? _prefs;
  bool _init = false;

  final ValueNotifier<JourneyProgressState> stateNotifier =
      ValueNotifier(const JourneyProgressState());

  Future<void> init() async {
    if (_init) return;
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    final raw = _prefs?.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        stateNotifier.value =
            JourneyProgressState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        stateNotifier.value = const JourneyProgressState();
      }
    }
    debugPrint(
        '🗺️ [JOURNEY] Progress init completed=${stateNotifier.value.completedIds.length}');
  }

  Future<void> _save(JourneyProgressState s) async {
    await _prefs?.setString(_kKey, jsonEncode(s.toJson()));
    stateNotifier.value = s;
  }

  bool isCompleted(String id) => stateNotifier.value.completedIds.contains(id);

  /// Devuelve la estación actual (la más temprana no completada).
  JourneyStation? currentStation() {
    final all = JourneyRepository.I.all;
    for (final s in all) {
      if (!isCompleted(s.id)) return s;
    }
    return null; // todas completadas
  }

  /// ¿Está desbloqueada? Una estación está desbloqueada si es la #1 o si la
  /// estación anterior (order - 1) está completada.
  bool isUnlocked(JourneyStation s) {
    if (s.order <= 1) return true;
    final prev = JourneyRepository.I.byOrder(s.order - 1);
    if (prev == null) return true;
    return isCompleted(prev.id);
  }

  /// Marca una estación como completada, otorga XP y registra actividad.
  /// Devuelve el XP otorgado (0 si ya estaba completada).
  Future<int> markCompleted(JourneyStation station) async {
    await init();
    final s = stateNotifier.value;
    if (s.completedIds.contains(station.id)) return 0;
    final updated = s.copyWith(
      completedIds: {...s.completedIds, station.id},
    );
    await _save(updated);
    // Otorgar XP y registrar actividad de estudio.
    await LearningProgressService.I.addXp(station.xpReward);
    await LearningProgressService.I.recordStudyActivity();
    TalentsHooks.journeyStation(station.id);
    return station.xpReward;
  }

  int get completedCount => stateNotifier.value.completedIds.length;
}
