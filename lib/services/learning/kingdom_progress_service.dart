library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/learning/kingdom_models.dart';
import 'bible_order_progress_service.dart';
import 'book_progress_service.dart';
import 'kingdom_curriculum_repository.dart';
import 'learning_progress_service.dart';
import 'verse_memory_service.dart';

@immutable
class KingdomProgressState {
  final String activeTrackId;
  final String focusId;
  final Map<String, LessonResult> lessons;
  final Map<String, String> missionDates;
  final int updatedAtMs;

  const KingdomProgressState({
    this.activeTrackId = 'fundamentals',
    this.focusId = 'bible_basics',
    this.lessons = const {},
    this.missionDates = const {},
    this.updatedAtMs = 0,
  });

  KingdomProgressState copyWith({
    String? activeTrackId,
    String? focusId,
    Map<String, LessonResult>? lessons,
    Map<String, String>? missionDates,
    int? updatedAtMs,
  }) {
    return KingdomProgressState(
      activeTrackId: activeTrackId ?? this.activeTrackId,
      focusId: focusId ?? this.focusId,
      lessons: lessons ?? this.lessons,
      missionDates: missionDates ?? this.missionDates,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'activeTrackId': activeTrackId,
    'focusId': focusId,
    'lessons': lessons.map((k, v) => MapEntry(k, v.toJson())),
    'missionDates': missionDates,
    'updatedAtMs': updatedAtMs,
  };

  factory KingdomProgressState.fromJson(Map<String, dynamic> json) {
    final rawLessons = json['lessons'] as Map? ?? const {};
    return KingdomProgressState(
      activeTrackId: json['activeTrackId'] as String? ?? 'fundamentals',
      focusId: json['focusId'] as String? ?? 'bible_basics',
      lessons: rawLessons.map(
        (k, v) =>
            MapEntry('$k', LessonResult.fromJson(v as Map<String, dynamic>)),
      ),
      missionDates: (json['missionDates'] as Map? ?? const {}).map(
        (k, v) => MapEntry('$k', '$v'),
      ),
      updatedAtMs: (json['updatedAtMs'] as num?)?.toInt() ?? 0,
    );
  }
}

class KingdomProgressService {
  KingdomProgressService._();
  static final KingdomProgressService I = KingdomProgressService._();

  static const _prefsKey = 'kingdom.progress.v1';
  final ValueNotifier<KingdomProgressState> stateNotifier = ValueNotifier(
    const KingdomProgressState(),
  );

  SharedPreferences? _prefs;
  bool _initialized = false;

  KingdomProgressState get state => stateNotifier.value;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _prefs = await SharedPreferences.getInstance();
    await _pullCloud();
    final raw = _prefs!.getString(_prefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        stateNotifier.value = KingdomProgressState.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        stateNotifier.value = const KingdomProgressState();
      }
    }
  }

  LessonResult resultFor(String lessonId) {
    return state.lessons[lessonId] ?? LessonResult(lessonId: lessonId);
  }

  bool isTrackUnlocked(String trackId) {
    final repo = KingdomCurriculumRepository.I;
    final track = repo.trackById(trackId);
    if (track == null) return false;
    if (!track.lockedByDefault && track.prerequisiteTrackIds.isEmpty) {
      return true;
    }
    return track.prerequisiteTrackIds.every(_trackComplete);
  }

  bool _trackComplete(String trackId) {
    final lessons = KingdomCurriculumRepository.I
        .lessonsForTrack(trackId)
        .where((lesson) => lesson.isCorePath)
        .toList(growable: false);
    if (lessons.isEmpty) return false;
    return lessons.every(
      (lesson) => _effectiveStatus(lesson) != KingdomLessonStatus.notStarted,
    );
  }

  KingdomLessonStatus effectiveStatus(LearningLesson lesson) =>
      _effectiveStatus(lesson);

  KingdomLessonStatus _effectiveStatus(LearningLesson lesson) {
    final explicit = resultFor(lesson.id).status;
    if (explicit != KingdomLessonStatus.notStarted) return explicit;
    if (lesson.hasBiblicalContent) return explicit;

    switch (lesson.moduleKey) {
      case 'books':
        return BookProgressService.I.state.studied.isNotEmpty
            ? KingdomLessonStatus.completed
            : KingdomLessonStatus.notStarted;
      case 'bible_order':
        return _bibleOrderTargetCompleted(lesson)
            ? KingdomLessonStatus.completed
            : KingdomLessonStatus.notStarted;
      case 'armory':
        return VerseMemoryService.I.summary().inProgress > 0 ||
                VerseMemoryService.I.summary().mastered > 0
            ? KingdomLessonStatus.completed
            : KingdomLessonStatus.notStarted;
      case 'mana':
        return LearningProgressService
                    .I
                    .progressNotifier
                    .value
                    .sessionsCompleted >
                0
            ? KingdomLessonStatus.completed
            : KingdomLessonStatus.notStarted;
      default:
        return explicit;
    }
  }

  bool _bibleOrderTargetCompleted(LearningLesson lesson) {
    final targetKey = lesson.targetKey.trim();
    final stars = BibleOrderProgressService.I.state.bestStars;
    if (targetKey.isEmpty) return stars.isNotEmpty;
    final normalizedTarget = _normalizeProgressKey(targetKey);
    return stars.keys.any((key) {
      final normalizedKey = _normalizeProgressKey(key);
      return normalizedKey == normalizedTarget ||
          normalizedKey.startsWith('${normalizedTarget}_chunk');
    });
  }

  LearningLesson? nextLesson() {
    final repo = KingdomCurriculumRepository.I;
    final unlockedTracks = repo.tracks.where((t) => isTrackUnlocked(t.id));
    for (final track in unlockedTracks) {
      for (final lesson in repo.lessonsForTrack(track.id)) {
        if (!lesson.isCorePath) continue;
        if (lesson.leadershipLocked && !fundamentalsComplete) continue;
        if (_effectiveStatus(lesson) == KingdomLessonStatus.notStarted) {
          return lesson;
        }
      }
    }
    for (final lesson in repo.lessons) {
      if (lesson.isCorePath) return lesson;
    }
    return null;
  }

  bool get fundamentalsComplete => _trackComplete('fundamentals');

  KingdomProgressSummary summary({
    int dueReviews = 0,
    int missionsDone = 0,
    int missionsTotal = 3,
  }) {
    final repo = KingdomCurriculumRepository.I;
    var completed = 0;
    var mastered = 0;
    final lessons = repo.lessons.where((lesson) => lesson.isCorePath);
    for (final lesson in lessons) {
      final status = _effectiveStatus(lesson);
      if (status == KingdomLessonStatus.completed ||
          status == KingdomLessonStatus.mastered) {
        completed++;
      }
      if (status == KingdomLessonStatus.mastered) mastered++;
    }
    return KingdomProgressSummary(
      totalLessons: lessons.length,
      completedLessons: completed,
      masteredLessons: mastered,
      dueReviews: dueReviews,
      dailyMissionsCompleted: missionsDone,
      dailyMissionsTotal: missionsTotal,
      activeTrackId: state.activeTrackId,
      nextLessonId: nextLesson()?.id,
      fundamentalsComplete: fundamentalsComplete,
    );
  }

  Future<void> markLessonCompleted(
    String lessonId, {
    int score = 100,
    bool review = false,
  }) async {
    final previous = resultFor(lessonId);
    final stars = _starsForScore(score);
    final status = review && previous.stars >= 2
        ? KingdomLessonStatus.mastered
        : KingdomLessonStatus.completed;
    final now = DateTime.now().millisecondsSinceEpoch;
    final next = previous.copyWith(
      status: status,
      stars: stars > previous.stars ? stars : previous.stars,
      bestScore: score > previous.bestScore ? score : previous.bestScore,
      attempts: previous.attempts + 1,
      lastCompletedAtMs: now,
      lastReviewedAtMs: review ? now : previous.lastReviewedAtMs,
      dueAtMs: now + const Duration(days: 3).inMilliseconds,
    );
    await _save(
      state.copyWith(
        lessons: {...state.lessons, lessonId: next},
        updatedAtMs: now,
      ),
    );
  }

  Future<void> markMissionDone(String missionId) async {
    await _save(
      state.copyWith(
        missionDates: {...state.missionDates, missionId: _todayKey()},
        updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  bool missionDoneToday(String missionId) =>
      state.missionDates[missionId] == _todayKey();

  int _starsForScore(int score) {
    if (score >= 90) return 3;
    if (score >= 80) return 2;
    if (score >= 60) return 1;
    return 0;
  }

  Future<void> _save(KingdomProgressState next) async {
    stateNotifier.value = next;
    final encoded = jsonEncode(next.toJson());
    await _prefs?.setString(_prefsKey, encoded);
    await _pushCloud(next);
  }

  Future<void> _pullCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learning')
          .doc('kingdom')
          .get();
      final remote = snap.data();
      if (remote == null) return;
      final remoteMs = (remote['updatedAtMs'] as num?)?.toInt() ?? 0;
      final local = _prefs?.getString(_prefsKey);
      final localMs = local == null
          ? 0
          : (jsonDecode(local) as Map<String, dynamic>)['updatedAtMs']
                    as int? ??
                0;
      if (remoteMs > localMs) {
        await _prefs?.setString(_prefsKey, jsonEncode(remote));
      }
    } catch (e) {
      debugPrint('Kingdom cloud pull skipped: $e');
    }
  }

  Future<void> _pushCloud(KingdomProgressState next) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('learning')
          .doc('kingdom')
          .set({
            ...next.toJson(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Kingdom cloud push skipped: $e');
    }
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

String _normalizeProgressKey(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  text = text.replaceAll(RegExp(r'_+'), '_');
  return text.replaceAll(RegExp(r'^_|_$'), '');
}
