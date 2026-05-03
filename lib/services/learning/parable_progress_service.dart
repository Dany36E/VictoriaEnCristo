/// ═══════════════════════════════════════════════════════════════════════════
/// ParableProgressService — parábolas completadas + XP
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class ParableProgressState {
  final Set<String> completedIds;
  const ParableProgressState({this.completedIds = const {}});

  ParableProgressState copyWith({Set<String>? completedIds}) =>
      ParableProgressState(completedIds: completedIds ?? this.completedIds);

  Map<String, dynamic> toJson() => {'completedIds': completedIds.toList()};

  factory ParableProgressState.fromJson(Map<String, dynamic> j) => ParableProgressState(
    completedIds: (j['completedIds'] as List? ?? const []).cast<String>().toSet(),
  );
}

class ParableProgressService {
  ParableProgressService._();
  static final ParableProgressService I = ParableProgressService._();

  static const String _kKey = 'parable_progress_v1';

  SharedPreferences? _prefs;
  bool _init = false;

  final ValueNotifier<ParableProgressState> stateNotifier = ValueNotifier(
    const ParableProgressState(),
  );

  Future<void> init() async {
    if (_init) {
      _refreshFromStorage();
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    _refreshFromStorage();
  }

  void _refreshFromStorage() {
    final raw = _prefs?.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        stateNotifier.value = ParableProgressState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        stateNotifier.value = const ParableProgressState();
      }
    } else {
      stateNotifier.value = const ParableProgressState();
    }
  }

  Future<void> _save(ParableProgressState s) async {
    await _prefs?.setString(_kKey, jsonEncode(s.toJson()));
    stateNotifier.value = s;
  }

  bool isCompleted(String id) => stateNotifier.value.completedIds.contains(id);

  Future<int> markCompleted(String id, int xpReward) async {
    await init();
    if (isCompleted(id)) return 0;
    final s = stateNotifier.value;
    await _save(s.copyWith(completedIds: {...s.completedIds, id}));
    await LearningProgressService.I.addXp(xpReward);
    await LearningProgressService.I.recordStudyActivity();
    TalentsHooks.parableCompleted(id);
    return xpReward;
  }
}
