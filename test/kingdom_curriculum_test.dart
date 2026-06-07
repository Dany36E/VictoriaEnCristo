import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _knownModules = {
  'mana',
  'kingdom_lesson',
  'armory',
  'books',
  'bible_order',
  'journey',
  'heroes',
  'parables',
  'timeline',
  'fruit',
  'maps',
  'prophecies',
  'games',
};

const _knownPracticeModes = {
  'learn',
  'quiz',
  'review',
  'case',
  'memory',
  'checkpoint',
  'deepStudy',
};

const _knownTheologyStatuses = {'draft', 'needsReview', 'reviewed', 'approved'};

void main() {
  test('kingdom curriculum references valid units, lessons, and modules', () {
    final raw = File(
      'assets/content/kingdom_curriculum.json',
    ).readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final auditRaw = File(
      'docs/kingdom_fundamentals_audit.json',
    ).readAsStringSync();
    final auditJson = jsonDecode(auditRaw) as Map<String, dynamic>;

    final tracks = (json['tracks'] as List).cast<Map<String, dynamic>>();
    final units = (json['units'] as List).cast<Map<String, dynamic>>();
    final lessons = (json['lessons'] as List).cast<Map<String, dynamic>>();

    final unitIds = units.map((u) => u['id'] as String).toSet();
    final lessonIds = lessons.map((l) => l['id'] as String).toSet();
    final trackIds = tracks.map((t) => t['id'] as String).toSet();
    final visibleUnitIds = tracks
        .expand((t) => (t['unitIds'] as List).map((id) => '$id'))
        .toSet();

    expect(tracks, isNotEmpty);
    expect(units, isNotEmpty);
    expect(lessons.length, greaterThanOrEqualTo(180));
    expect(unitIds.length, units.length);
    expect(lessonIds.length, lessons.length);
    expect(trackIds.length, tracks.length);

    for (final track in tracks) {
      expect(track['title'], isNotEmpty);
      for (final unitId in (track['unitIds'] as List)) {
        expect(unitIds, contains(unitId));
      }
      for (final prerequisite
          in (track['prerequisiteTrackIds'] as List? ?? const [])) {
        expect(trackIds, contains(prerequisite));
      }
    }

    for (final unit in units) {
      expect(trackIds, contains(unit['trackId']));
      for (final lessonId in (unit['lessonIds'] as List)) {
        expect(lessonIds, contains(lessonId));
      }
      for (final prerequisite
          in (unit['prerequisiteUnitIds'] as List? ?? const [])) {
        expect(unitIds, contains(prerequisite));
      }
    }

    for (final lesson in lessons) {
      expect(unitIds, contains(lesson['unitId']));
      expect(_knownModules, contains(lesson['moduleKey']));
      expect(lesson['title'], isNotEmpty);
      expect(lesson['objective'], isNotEmpty);
      expect((lesson['estimatedMinutes'] as num).toInt(), greaterThan(0));
      expect((lesson['difficulty'] as num).toInt(), inInclusiveRange(1, 3));
      expect(lesson['lessonGoal'], isNotEmpty);
      expect(_knownPracticeModes, contains(lesson['practiceMode']));
      expect(
        _knownTheologyStatuses,
        contains(lesson['theologyReviewStatus'] as String? ?? 'needsReview'),
      );
      expect((lesson['competencyIds'] as List), isNotEmpty);
      for (final prerequisite
          in (lesson['prerequisiteLessonIds'] as List? ?? const [])) {
        expect(lessonIds, contains(prerequisite));
      }
      for (final review
          in (lesson['reviewAfterLessonIds'] as List? ?? const [])) {
        expect(lessonIds, contains(review));
      }
      if (lesson['moduleKey'] == 'bible_order' &&
          (lesson['targetKey'] as String? ?? '').isNotEmpty) {
        expect(lesson['targetKey'], matches(RegExp(r'^[A-Za-z0-9_]+$')));
      }
    }

    expect(visibleUnitIds, isNot(contains('practice_daily_hub')));
    final practiceLessons = lessons.where(
      (lesson) => lesson['unitId'] == 'practice_daily_hub',
    );
    expect(practiceLessons, isNotEmpty);
    expect(
      practiceLessons.every((lesson) => lesson['isCorePath'] == false),
      isTrue,
    );

    final fundamentals = tracks.firstWhere((t) => t['id'] == 'fundamentals');
    expect(
      fundamentals['unitIds'],
      orderedEquals([
        'fund_bible_orientation',
        'fund_reading_basics',
        'fund_order_ot',
        'fund_order_nt',
        'fund_order_mastery',
        'fund_gospel_basics',
      ]),
    );

    final fundamentalUnitIds = (fundamentals['unitIds'] as List)
        .map((id) => '$id')
        .toSet();
    final fundamentalLessons = lessons.where(
      (lesson) => fundamentalUnitIds.contains(lesson['unitId']),
    );
    final auditLessonIds =
        ((auditJson['lessons'] as List).cast<Map<String, dynamic>>().map(
          (entry) => entry['lessonId'] as String,
        )).toSet();
    expect(fundamentalLessons.length, greaterThanOrEqualTo(40));
    for (final lesson in fundamentalLessons) {
      expect(auditLessonIds, contains(lesson['id']));
      expect(lesson['baseTextRefs'], isA<List>());
      expect((lesson['baseTextRefs'] as List), isNotEmpty);
      expect(lesson['keyVerseRef'], isA<String>());
      expect(lesson['keyVerseRef'], isNotEmpty);
      expect(lesson['contextNote'], isA<String>());
      expect(lesson['contextNote'], isNotEmpty);
      expect(lesson['doctrinePoint'], isA<String>());
      expect(lesson['doctrinePoint'], isNotEmpty);
      expect(lesson['doctrinalCategory'], isA<String>());
      expect(lesson['doctrinalCategory'], isNotEmpty);
      expect(lesson['applicationPrompt'], isA<String>());
      expect(lesson['applicationPrompt'], isNotEmpty);
      expect((lesson['commonErrors'] as List), isNotEmpty);
      expect(lesson['masteryCriteria'], isA<String>());
      expect(lesson['masteryCriteria'], isNotEmpty);
      expect((lesson['questions'] as List), isNotEmpty);
      expect((lesson['quizItems'] as List), isNotEmpty);
      expect(lesson['theologyReviewStatus'], 'reviewed');
      expect(lesson['reviewedBy'], isA<String>());
      expect(lesson['reviewedBy'], isNotEmpty);
      expect(lesson['reviewedAt'], isA<String>());
      expect(lesson['reviewedAt'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(lesson['reviewNotes'], isA<String>());
      expect(lesson['reviewNotes'], isNotEmpty);

      for (final ref in lesson['baseTextRefs'] as List) {
        expect('$ref', matches(RegExp(r'^[1-3]? ?\S+ \d+:\d+')));
        expect('$ref'.length, lessThan(40));
      }
      expect((lesson['keyVerseRef'] as String).length, lessThan(40));
    }

    final comprehension = tracks.firstWhere((t) => t['id'] == 'comprehension');
    expect(
      comprehension['unitIds'],
      orderedEquals([
        'comp_interpretation_basics',
        'comp_maps_context',
        'comp_themes',
        'comp_prophecy_connections',
        'comp_deep_study',
      ]),
    );
  });
}
