library;

import 'package:flutter/foundation.dart';

enum KingdomTrackLevel {
  fundamentals,
  growth,
  panorama,
  comprehension,
  leadership,
  teacher,
}

enum KingdomLessonType {
  guidedStudy,
  readingQuestions,
  memory,
  reflection,
  quiz,
  caseStudy,
  devotional,
  doctrine,
  leadership,
  assessment,
}

enum KingdomLessonStatus { notStarted, inProgress, completed, mastered }

enum KingdomRecommendationKind {
  review,
  nextLesson,
  dailyPractice,
  deepSession,
  rest,
}

@immutable
class KingdomLessonQuestion {
  final String id;
  final String prompt;
  final String expectedIdea;

  const KingdomLessonQuestion({
    required this.id,
    required this.prompt,
    required this.expectedIdea,
  });

  factory KingdomLessonQuestion.fromJson(Map<String, dynamic> json) =>
      KingdomLessonQuestion(
        id: json['id'] as String? ?? '',
        prompt: json['prompt'] as String? ?? '',
        expectedIdea: json['expectedIdea'] as String? ?? '',
      );
}

@immutable
class KingdomQuizItem {
  final String id;
  final String type;
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;
  final String ref;

  const KingdomQuizItem({
    required this.id,
    this.type = 'multipleChoice',
    required this.prompt,
    this.options = const [],
    this.correctIndex = 0,
    this.explanation = '',
    this.ref = '',
  });

  factory KingdomQuizItem.fromJson(Map<String, dynamic> json) =>
      KingdomQuizItem(
        id: json['id'] as String? ?? '',
        type: json['type'] as String? ?? 'multipleChoice',
        prompt: json['prompt'] as String? ?? '',
        options: (json['options'] as List? ?? const [])
            .map((e) => '$e')
            .toList(),
        correctIndex: (json['correctIndex'] as num?)?.toInt() ?? 0,
        explanation: json['explanation'] as String? ?? '',
        ref: json['ref'] as String? ?? '',
      );
}

@immutable
class LearningTrack {
  final String id;
  final KingdomTrackLevel level;
  final String title;
  final String subtitle;
  final List<String> unitIds;
  final List<String> prerequisiteTrackIds;
  final bool lockedByDefault;

  const LearningTrack({
    required this.id,
    required this.level,
    required this.title,
    required this.subtitle,
    required this.unitIds,
    this.prerequisiteTrackIds = const [],
    this.lockedByDefault = false,
  });

  factory LearningTrack.fromJson(Map<String, dynamic> json) => LearningTrack(
    id: json['id'] as String,
    level: _trackLevelFromId(json['level'] as String? ?? ''),
    title: json['title'] as String,
    subtitle: json['subtitle'] as String? ?? '',
    unitIds: (json['unitIds'] as List? ?? const []).map((e) => '$e').toList(),
    prerequisiteTrackIds: (json['prerequisiteTrackIds'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    lockedByDefault: json['lockedByDefault'] as bool? ?? false,
  );
}

@immutable
class LearningUnit {
  final String id;
  final String trackId;
  final String title;
  final String subtitle;
  final int order;
  final List<String> lessonIds;
  final List<String> prerequisiteUnitIds;

  const LearningUnit({
    required this.id,
    required this.trackId,
    required this.title,
    required this.subtitle,
    required this.order,
    required this.lessonIds,
    this.prerequisiteUnitIds = const [],
  });

  factory LearningUnit.fromJson(Map<String, dynamic> json) => LearningUnit(
    id: json['id'] as String,
    trackId: json['trackId'] as String,
    title: json['title'] as String,
    subtitle: json['subtitle'] as String? ?? '',
    order: (json['order'] as num?)?.toInt() ?? 0,
    lessonIds: (json['lessonIds'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    prerequisiteUnitIds: (json['prerequisiteUnitIds'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
  );
}

@immutable
class LearningLesson {
  final String id;
  final String unitId;
  final String title;
  final String objective;
  final String moduleKey;
  final String targetKey;
  final List<String> competencyIds;
  final List<String> reviewAfterLessonIds;
  final String lessonGoal;
  final String practiceMode;
  final bool isCorePath;
  final String unlockReason;
  final KingdomLessonType type;
  final int difficulty;
  final int estimatedMinutes;
  final int xpReward;
  final List<String> prerequisiteLessonIds;
  final List<String> giantTags;
  final bool deepSession;
  final bool leadershipLocked;
  final List<String> baseTextRefs;
  final String keyVerseRef;
  final String contextNote;
  final String doctrinePoint;
  final String doctrinalCategory;
  final String christConnection;
  final String applicationPrompt;
  final List<String> commonErrors;
  final String masteryCriteria;
  final List<KingdomLessonQuestion> questions;
  final List<KingdomQuizItem> quizItems;
  final String theologyReviewStatus;
  final String reviewedBy;
  final String reviewedAt;
  final String reviewNotes;

  const LearningLesson({
    required this.id,
    required this.unitId,
    required this.title,
    required this.objective,
    required this.moduleKey,
    this.targetKey = '',
    this.competencyIds = const [],
    this.reviewAfterLessonIds = const [],
    this.lessonGoal = '',
    this.practiceMode = 'learn',
    this.isCorePath = true,
    this.unlockReason = '',
    required this.type,
    required this.difficulty,
    required this.estimatedMinutes,
    required this.xpReward,
    this.prerequisiteLessonIds = const [],
    this.giantTags = const [],
    this.deepSession = false,
    this.leadershipLocked = false,
    this.baseTextRefs = const [],
    this.keyVerseRef = '',
    this.contextNote = '',
    this.doctrinePoint = '',
    this.doctrinalCategory = '',
    this.christConnection = '',
    this.applicationPrompt = '',
    this.commonErrors = const [],
    this.masteryCriteria = '',
    this.questions = const [],
    this.quizItems = const [],
    this.theologyReviewStatus = 'draft',
    this.reviewedBy = '',
    this.reviewedAt = '',
    this.reviewNotes = '',
  });

  factory LearningLesson.fromJson(Map<String, dynamic> json) => LearningLesson(
    id: json['id'] as String,
    unitId: json['unitId'] as String,
    title: json['title'] as String,
    objective: json['objective'] as String? ?? '',
    moduleKey: json['moduleKey'] as String? ?? '',
    targetKey: json['targetKey'] as String? ?? '',
    competencyIds: (json['competencyIds'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    reviewAfterLessonIds: (json['reviewAfterLessonIds'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    lessonGoal: json['lessonGoal'] as String? ?? '',
    practiceMode: json['practiceMode'] as String? ?? 'learn',
    isCorePath: json['isCorePath'] as bool? ?? true,
    unlockReason: json['unlockReason'] as String? ?? '',
    type: _lessonTypeFromId(json['type'] as String? ?? ''),
    difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
    estimatedMinutes: (json['estimatedMinutes'] as num?)?.toInt() ?? 5,
    xpReward: (json['xpReward'] as num?)?.toInt() ?? 10,
    prerequisiteLessonIds: (json['prerequisiteLessonIds'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    giantTags: (json['giantTags'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    deepSession: json['deepSession'] as bool? ?? false,
    leadershipLocked: json['leadershipLocked'] as bool? ?? false,
    baseTextRefs: (json['baseTextRefs'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    keyVerseRef: json['keyVerseRef'] as String? ?? '',
    contextNote: json['contextNote'] as String? ?? '',
    doctrinePoint: json['doctrinePoint'] as String? ?? '',
    doctrinalCategory: json['doctrinalCategory'] as String? ?? '',
    christConnection: json['christConnection'] as String? ?? '',
    applicationPrompt: json['applicationPrompt'] as String? ?? '',
    commonErrors: (json['commonErrors'] as List? ?? const [])
        .map((e) => '$e')
        .toList(),
    masteryCriteria: json['masteryCriteria'] as String? ?? '',
    questions: (json['questions'] as List? ?? const [])
        .map((e) => KingdomLessonQuestion.fromJson(e as Map<String, dynamic>))
        .toList(),
    quizItems: (json['quizItems'] as List? ?? const [])
        .map((e) => KingdomQuizItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    theologyReviewStatus: json['theologyReviewStatus'] as String? ?? 'draft',
    reviewedBy: json['reviewedBy'] as String? ?? '',
    reviewedAt: json['reviewedAt'] as String? ?? '',
    reviewNotes: json['reviewNotes'] as String? ?? '',
  );

  bool get hasBiblicalContent =>
      baseTextRefs.isNotEmpty ||
      keyVerseRef.isNotEmpty ||
      doctrinePoint.isNotEmpty ||
      questions.isNotEmpty ||
      quizItems.isNotEmpty;

  bool get hasStructuredBiblicalContent =>
      baseTextRefs.isNotEmpty &&
      keyVerseRef.isNotEmpty &&
      contextNote.isNotEmpty &&
      doctrinePoint.isNotEmpty &&
      doctrinalCategory.isNotEmpty &&
      applicationPrompt.isNotEmpty &&
      commonErrors.isNotEmpty &&
      masteryCriteria.isNotEmpty &&
      questions.isNotEmpty &&
      quizItems.isNotEmpty;

  bool get hasReviewTrail =>
      reviewedBy.isNotEmpty && reviewedAt.isNotEmpty && reviewNotes.isNotEmpty;

  bool get isReviewedForPublication =>
      theologyReviewStatus == 'reviewed' || theologyReviewStatus == 'approved';

  List<String> validationIssues({
    bool requireStructuredContent = false,
    bool requireReviewTrail = false,
  }) {
    final issues = <String>[];
    if (title.trim().isEmpty) issues.add('missing_title');
    if (objective.trim().isEmpty) issues.add('missing_objective');
    if (lessonGoal.trim().isEmpty) issues.add('missing_lesson_goal');
    if (competencyIds.isEmpty) issues.add('missing_competencies');
    if (requireStructuredContent || hasBiblicalContent) {
      if (baseTextRefs.isEmpty) issues.add('missing_base_text_refs');
      if (keyVerseRef.trim().isEmpty) issues.add('missing_key_verse_ref');
      if (contextNote.trim().isEmpty) issues.add('missing_context_note');
      if (doctrinePoint.trim().isEmpty) issues.add('missing_doctrine_point');
      if (doctrinalCategory.trim().isEmpty) {
        issues.add('missing_doctrinal_category');
      }
      if (applicationPrompt.trim().isEmpty) {
        issues.add('missing_application_prompt');
      }
      if (questions.isEmpty) issues.add('missing_questions');
      if (quizItems.isEmpty) issues.add('missing_quiz_items');
      if (commonErrors.isEmpty) issues.add('missing_common_errors');
      if (masteryCriteria.trim().isEmpty) {
        issues.add('missing_mastery_criteria');
      }
    }
    if (requireReviewTrail || isReviewedForPublication) {
      if (!hasReviewTrail) issues.add('missing_review_trail');
    }
    return issues;
  }
}

@immutable
class LessonResult {
  final String lessonId;
  final KingdomLessonStatus status;
  final int stars;
  final int attempts;
  final int bestScore;
  final int lastCompletedAtMs;
  final int lastReviewedAtMs;
  final int dueAtMs;

  const LessonResult({
    required this.lessonId,
    this.status = KingdomLessonStatus.notStarted,
    this.stars = 0,
    this.attempts = 0,
    this.bestScore = 0,
    this.lastCompletedAtMs = 0,
    this.lastReviewedAtMs = 0,
    this.dueAtMs = 0,
  });

  LessonResult copyWith({
    KingdomLessonStatus? status,
    int? stars,
    int? attempts,
    int? bestScore,
    int? lastCompletedAtMs,
    int? lastReviewedAtMs,
    int? dueAtMs,
  }) {
    return LessonResult(
      lessonId: lessonId,
      status: status ?? this.status,
      stars: stars ?? this.stars,
      attempts: attempts ?? this.attempts,
      bestScore: bestScore ?? this.bestScore,
      lastCompletedAtMs: lastCompletedAtMs ?? this.lastCompletedAtMs,
      lastReviewedAtMs: lastReviewedAtMs ?? this.lastReviewedAtMs,
      dueAtMs: dueAtMs ?? this.dueAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'lessonId': lessonId,
    'status': status.name,
    'stars': stars,
    'attempts': attempts,
    'bestScore': bestScore,
    'lastCompletedAtMs': lastCompletedAtMs,
    'lastReviewedAtMs': lastReviewedAtMs,
    'dueAtMs': dueAtMs,
  };

  factory LessonResult.fromJson(Map<String, dynamic> json) => LessonResult(
    lessonId: json['lessonId'] as String? ?? '',
    status: _lessonStatusFromId(json['status'] as String? ?? ''),
    stars: (json['stars'] as num?)?.toInt() ?? 0,
    attempts: (json['attempts'] as num?)?.toInt() ?? 0,
    bestScore: (json['bestScore'] as num?)?.toInt() ?? 0,
    lastCompletedAtMs: (json['lastCompletedAtMs'] as num?)?.toInt() ?? 0,
    lastReviewedAtMs: (json['lastReviewedAtMs'] as num?)?.toInt() ?? 0,
    dueAtMs: (json['dueAtMs'] as num?)?.toInt() ?? 0,
  );
}

@immutable
class ReviewItem {
  final String id;
  final String title;
  final String reason;
  final String moduleKey;
  final String? lessonId;
  final List<String> competencyIds;
  final int priority;

  const ReviewItem({
    required this.id,
    required this.title,
    required this.reason,
    required this.moduleKey,
    this.lessonId,
    this.competencyIds = const [],
    required this.priority,
  });
}

@immutable
class DailyMission {
  final String id;
  final String title;
  final String subtitle;
  final bool completed;
  final int xpReward;

  const DailyMission({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.completed,
    required this.xpReward,
  });
}

@immutable
class KingdomRecommendation {
  final KingdomRecommendationKind kind;
  final String title;
  final String subtitle;
  final String cta;
  final String moduleKey;
  final String? lessonId;

  const KingdomRecommendation({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.moduleKey,
    this.lessonId,
  });
}

@immutable
class KingdomProgressSummary {
  final int totalLessons;
  final int completedLessons;
  final int masteredLessons;
  final int dueReviews;
  final int dailyMissionsCompleted;
  final int dailyMissionsTotal;
  final String activeTrackId;
  final String? nextLessonId;
  final bool fundamentalsComplete;

  const KingdomProgressSummary({
    required this.totalLessons,
    required this.completedLessons,
    required this.masteredLessons,
    required this.dueReviews,
    required this.dailyMissionsCompleted,
    required this.dailyMissionsTotal,
    required this.activeTrackId,
    required this.nextLessonId,
    required this.fundamentalsComplete,
  });

  double get progress {
    if (totalLessons <= 0) return 0;
    return completedLessons / totalLessons;
  }
}

KingdomTrackLevel _trackLevelFromId(String id) {
  return KingdomTrackLevel.values.firstWhere(
    (value) => value.name == id,
    orElse: () => KingdomTrackLevel.fundamentals,
  );
}

KingdomLessonType _lessonTypeFromId(String id) {
  return KingdomLessonType.values.firstWhere(
    (value) => value.name == id,
    orElse: () => KingdomLessonType.guidedStudy,
  );
}

KingdomLessonStatus _lessonStatusFromId(String id) {
  return KingdomLessonStatus.values.firstWhere(
    (value) => value.name == id,
    orElse: () => KingdomLessonStatus.notStarted,
  );
}
