library;

import '../../models/learning/kingdom_models.dart';
import 'kingdom_progress_service.dart';
import 'kingdom_review_service.dart';
import 'learning_progress_service.dart';
import 'verse_memory_service.dart';

class KingdomMissionService {
  KingdomMissionService._();
  static final KingdomMissionService I = KingdomMissionService._();

  List<DailyMission> dailyMissions() {
    final progress = KingdomProgressService.I;
    final dueReviews = KingdomReviewService.I.dueItems().length;
    final learning = LearningProgressService.I.progressNotifier.value;
    final didStudyToday = _isToday(learning.lastStudyDate);
    final hasVerseWork =
        VerseMemoryService.I.summary().inProgress > 0 ||
        VerseMemoryService.I.summary().mastered > 0;

    return [
      DailyMission(
        id: 'new_lesson',
        title: 'Completa una lección',
        subtitle: 'Avanza en tu ruta principal',
        completed: progress.missionDoneToday('new_lesson') || didStudyToday,
        xpReward: 10,
      ),
      DailyMission(
        id: 'review',
        title: 'Haz un repaso',
        subtitle: dueReviews > 0
            ? '$dueReviews pendiente${dueReviews == 1 ? '' : 's'}'
            : 'Mantente fresco',
        completed: progress.missionDoneToday('review') || dueReviews == 0,
        xpReward: 10,
      ),
      DailyMission(
        id: 'spiritual_action',
        title: 'Acción espiritual breve',
        subtitle: 'Práctica diaria, reflexión o memorización',
        completed:
            progress.missionDoneToday('spiritual_action') ||
            hasVerseWork ||
            didStudyToday,
        xpReward: 10,
      ),
    ];
  }

  int completedToday() => dailyMissions().where((m) => m.completed).length;

  bool _isToday(String isoDate) {
    if (isoDate.isEmpty) return false;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return isoDate.startsWith(today);
  }
}
