library;

import '../../models/learning/kingdom_models.dart';
import 'kingdom_curriculum_repository.dart';
import 'kingdom_progress_service.dart';
import 'verse_memory_service.dart';

class KingdomReviewService {
  KingdomReviewService._();
  static final KingdomReviewService I = KingdomReviewService._();

  List<ReviewItem> dueItems() {
    final items = <ReviewItem>[];
    final seen = <String>{};
    final dueVerses = VerseMemoryService.I.dueToday().length;
    if (dueVerses > 0) {
      items.add(
        ReviewItem(
          id: 'armory_due',
          title: 'Armadura',
          reason:
              '$dueVerses versiculo${dueVerses == 1 ? '' : 's'} por repasar',
          moduleKey: 'armory',
          competencyIds: const ['memory'],
          priority: 100,
        ),
      );
      seen.add('armory_due');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final curriculum = KingdomCurriculumRepository.I;
    final progress = KingdomProgressService.I;
    for (final lesson in curriculum.lessons) {
      if (!lesson.isCorePath) continue;
      final result = KingdomProgressService.I.resultFor(lesson.id);
      if (result.stars == 1) {
        final id = 'weak_${lesson.id}';
        if (!seen.add(id)) continue;
        items.add(
          ReviewItem(
            id: id,
            title: lesson.title,
            reason: 'Conviene reforzar esta lección',
            moduleKey: lesson.moduleKey,
            lessonId: lesson.id,
            competencyIds: lesson.competencyIds,
            priority: 80,
          ),
        );
      } else if (result.dueAtMs > 0 && result.dueAtMs <= now) {
        final id = 'due_${lesson.id}';
        if (!seen.add(id)) continue;
        items.add(
          ReviewItem(
            id: id,
            title: lesson.title,
            reason: 'Ya toca repaso',
            moduleKey: lesson.moduleKey,
            lessonId: lesson.id,
            competencyIds: lesson.competencyIds,
            priority: 70,
          ),
        );
      }

      final lessonReady =
          result.status == KingdomLessonStatus.notStarted &&
          lesson.reviewAfterLessonIds.isNotEmpty &&
          _prerequisitesCompleted(lesson);
      if (lessonReady) {
        for (final reviewId in lesson.reviewAfterLessonIds) {
          final reviewLesson = curriculum.lessonById(reviewId);
          if (reviewLesson == null) continue;
          final reviewStatus = progress.effectiveStatus(reviewLesson);
          if (reviewStatus == KingdomLessonStatus.notStarted) continue;
          final id = 'bridge_${lesson.id}_$reviewId';
          if (!seen.add(id)) continue;
          items.add(
            ReviewItem(
              id: id,
              title: reviewLesson.title,
              reason: 'Repaso antes de avanzar: ${lesson.title}',
              moduleKey: reviewLesson.moduleKey,
              lessonId: reviewLesson.id,
              competencyIds: reviewLesson.competencyIds,
              priority: 60,
            ),
          );
        }
      }
    }

    items.sort((a, b) => b.priority.compareTo(a.priority));
    return items;
  }

  bool _prerequisitesCompleted(LearningLesson lesson) {
    if (lesson.prerequisiteLessonIds.isEmpty) return false;
    final progress = KingdomProgressService.I;
    final repo = KingdomCurriculumRepository.I;
    return lesson.prerequisiteLessonIds.every((id) {
      final prerequisite = repo.lessonById(id);
      if (prerequisite == null) return false;
      final status = progress.effectiveStatus(prerequisite);
      return status == KingdomLessonStatus.completed ||
          status == KingdomLessonStatus.mastered;
    });
  }
}
