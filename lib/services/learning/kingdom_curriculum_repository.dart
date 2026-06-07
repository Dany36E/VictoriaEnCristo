library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/learning/kingdom_models.dart';

class KingdomCurriculumRepository {
  KingdomCurriculumRepository._();
  static final KingdomCurriculumRepository I = KingdomCurriculumRepository._();

  static const _assetPath = 'assets/content/kingdom_curriculum.json';

  bool _loading = false;
  List<LearningTrack>? _tracks;
  List<LearningUnit>? _units;
  List<LearningLesson>? _lessons;

  bool get isLoaded => _tracks != null;
  List<LearningTrack> get tracks => _tracks ?? const [];
  List<LearningUnit> get units => _units ?? const [];
  List<LearningLesson> get lessons => _lessons ?? const [];

  Future<void> load() async {
    if (_tracks != null || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle.loadString(_assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _tracks = (json['tracks'] as List? ?? const [])
          .map((e) => LearningTrack.fromJson(e as Map<String, dynamic>))
          .toList();
      _units = (json['units'] as List? ?? const [])
          .map((e) => LearningUnit.fromJson(e as Map<String, dynamic>))
          .toList();
      _lessons = (json['lessons'] as List? ?? const [])
          .map((e) => LearningLesson.fromJson(e as Map<String, dynamic>))
          .toList();
      debugPrint('Kingdom curriculum loaded: ${lessons.length} lessons');
    } catch (e, st) {
      debugPrint('Kingdom curriculum load failed: $e\n$st');
      _tracks = const [];
      _units = const [];
      _lessons = const [];
    } finally {
      _loading = false;
    }
  }

  LearningTrack? trackById(String id) {
    for (final track in tracks) {
      if (track.id == id) return track;
    }
    return null;
  }

  LearningUnit? unitById(String id) {
    for (final unit in units) {
      if (unit.id == id) return unit;
    }
    return null;
  }

  LearningLesson? lessonById(String id) {
    for (final lesson in lessons) {
      if (lesson.id == id) return lesson;
    }
    return null;
  }

  List<LearningUnit> unitsForTrack(String trackId) {
    final track = trackById(trackId);
    if (track == null) return const [];
    if (track.unitIds.isNotEmpty) {
      return track.unitIds
          .map(unitById)
          .whereType<LearningUnit>()
          .toList(growable: false);
    }
    final list = units.where((u) => u.trackId == trackId).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  List<LearningLesson> lessonsForUnit(String unitId) {
    final unit = unitById(unitId);
    if (unit == null) return const [];
    return unit.lessonIds
        .map(lessonById)
        .whereType<LearningLesson>()
        .toList(growable: false);
  }

  List<LearningLesson> lessonsForTrack(String trackId) {
    return unitsForTrack(trackId).expand((u) => lessonsForUnit(u.id)).toList();
  }

  List<String> validationIssuesForLesson(
    LearningLesson lesson, {
    bool requireStructuredContent = false,
    bool requireReviewTrail = false,
  }) {
    return lesson.validationIssues(
      requireStructuredContent: requireStructuredContent,
      requireReviewTrail: requireReviewTrail,
    );
  }

  int countLessonsReadyForPublication() {
    return lessons.where((lesson) {
      return lesson.hasStructuredBiblicalContent &&
          lesson.isReviewedForPublication &&
          lesson
              .validationIssues(
                requireStructuredContent: true,
                requireReviewTrail: true,
              )
              .isEmpty;
    }).length;
  }
}
