/// ═══════════════════════════════════════════════════════════════════════════
/// TimelineProgressService — lecciones completadas con estrellas
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class TimelineProgressState {
  final Map<String, int> completed; // lessonId -> stars (1-3)
  const TimelineProgressState({this.completed = const {}});

  TimelineProgressState copyWith({Map<String, int>? completed}) =>
      TimelineProgressState(completed: completed ?? this.completed);

  Map<String, dynamic> toJson() => {'completed': completed};

  factory TimelineProgressState.fromJson(Map<String, dynamic> j) =>
      TimelineProgressState(
        completed: Map<String, int>.from(
            (j['completed'] as Map?)?.map(
                  (k, v) => MapEntry(k.toString(), (v as num).toInt()),
                ) ??
                const {}),
      );
}

class TimelineProgressService {
  TimelineProgressService._();
  static final TimelineProgressService I = TimelineProgressService._();

  static const String _kKey = 'timeline_progress_v1';

  SharedPreferences? _prefs;
  bool _init = false;

  final ValueNotifier<TimelineProgressState> stateNotifier =
      ValueNotifier(const TimelineProgressState());

  Future<void> init() async {
    if (_init) return;
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    final raw = _prefs?.getString(_kKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        stateNotifier.value = TimelineProgressState.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  Future<void> _save(TimelineProgressState s) async {
    await _prefs?.setString(_kKey, jsonEncode(s.toJson()));
    stateNotifier.value = s;
  }

  bool isCompleted(String id) => stateNotifier.value.completed.containsKey(id);
  int starsFor(String id) => stateNotifier.value.completed[id] ?? 0;

  Future<int> markCompleted(String id, int stars, int xpReward) async {
    await init();
    final s = stateNotifier.value;
    final prev = s.completed[id] ?? 0;
    if (stars <= prev) return 0;
    await _save(s.copyWith(completed: {...s.completed, id: stars}));
    await LearningProgressService.I.addXp(xpReward);
    await LearningProgressService.I.recordStudyActivity();
    TalentsHooks.timelineLessonStars(id, stars);
    return xpReward;
  }

  int get totalStars =>
      stateNotifier.value.completed.values.fold(0, (a, b) => a + b);
}
