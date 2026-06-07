import 'dart:convert';
import 'dart:io';

import 'package:app_quitar/models/learning/kingdom_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('structured reviewed lesson has no validation issues', () {
    const lesson = LearningLesson(
      id: 'sample',
      unitId: 'fund_bible_orientation',
      title: 'Lección de ejemplo',
      objective: 'Comprender una verdad bíblica central.',
      moduleKey: 'kingdom_lesson',
      competencyIds: ['bible_foundation'],
      lessonGoal: 'Comprensión bíblica',
      practiceMode: 'learn',
      type: KingdomLessonType.guidedStudy,
      difficulty: 1,
      estimatedMinutes: 5,
      xpReward: 10,
      baseTextRefs: ['Juan 3:16'],
      keyVerseRef: 'Juan 3:16',
      contextNote: 'Jesús habla con Nicodemo acerca del nuevo nacimiento.',
      doctrinePoint: 'La salvación es por gracia mediante la fe en Cristo.',
      doctrinalCategory: 'Evangelio y salvación',
      christConnection: 'Cristo es el centro del mensaje de salvación.',
      applicationPrompt: 'Responde con fe y gratitud al evangelio.',
      commonErrors: ['Reducir la salvación a mérito humano.'],
      masteryCriteria: 'Puede explicar el evangelio en sus propias palabras.',
      questions: [
        KingdomLessonQuestion(
          id: 'q1',
          prompt: '¿Qué enseña este pasaje acerca del amor de Dios?',
          expectedIdea: 'Que Dios dio a su Hijo para salvar.',
        ),
      ],
      quizItems: [
        KingdomQuizItem(
          id: 'quiz1',
          prompt: '¿Quién tomó la iniciativa en la salvación?',
          options: ['Dios', 'El hombre', 'La iglesia', 'La ley'],
          correctIndex: 0,
          explanation: 'Dios amó y dio a su Hijo.',
          ref: 'Juan 3:16',
        ),
      ],
      theologyReviewStatus: 'reviewed',
      reviewedBy: 'Equipo curricular',
      reviewedAt: '2026-05-24',
      reviewNotes: 'Lista para aprobación pastoral.',
    );

    expect(lesson.hasStructuredBiblicalContent, isTrue);
    expect(lesson.hasReviewTrail, isTrue);
    expect(
      lesson.validationIssues(
        requireStructuredContent: true,
        requireReviewTrail: true,
      ),
      isEmpty,
    );
  });

  test('draft lesson reports missing structured content', () {
    const lesson = LearningLesson(
      id: 'draft',
      unitId: 'growth_daily_practice',
      title: 'Borrador',
      objective: 'Pendiente',
      moduleKey: 'kingdom_lesson',
      competencyIds: ['habit'],
      lessonGoal: 'Pendiente',
      practiceMode: 'learn',
      type: KingdomLessonType.guidedStudy,
      difficulty: 1,
      estimatedMinutes: 5,
      xpReward: 10,
    );

    final issues = lesson.validationIssues(requireStructuredContent: true);
    expect(issues, contains('missing_base_text_refs'));
    expect(issues, contains('missing_context_note'));
    expect(issues, contains('missing_quiz_items'));
    expect(lesson.hasStructuredBiblicalContent, isFalse);
  });

  test('fundamentals lessons satisfy the structured lesson contract', () {
    final raw = File(
      'assets/content/kingdom_curriculum.json',
    ).readAsStringSync();
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final tracks = (json['tracks'] as List).cast<Map<String, dynamic>>();
    final lessons = (json['lessons'] as List).cast<Map<String, dynamic>>();
    final fundamentals = tracks.firstWhere((t) => t['id'] == 'fundamentals');
    final fundamentalUnitIds = (fundamentals['unitIds'] as List)
        .map((id) => '$id')
        .toSet();

    final fundamentalLessons = lessons
        .where((lesson) => fundamentalUnitIds.contains(lesson['unitId']))
        .map(LearningLesson.fromJson)
        .toList(growable: false);

    expect(fundamentalLessons, isNotEmpty);
    for (final lesson in fundamentalLessons) {
      expect(lesson.hasStructuredBiblicalContent, isTrue, reason: lesson.id);
      expect(lesson.hasReviewTrail, isTrue, reason: lesson.id);
      expect(
        lesson.validationIssues(
          requireStructuredContent: true,
          requireReviewTrail: true,
        ),
        isEmpty,
        reason: lesson.id,
      );
    }
  });
}
