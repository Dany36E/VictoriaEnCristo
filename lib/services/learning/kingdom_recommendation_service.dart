library;

import '../../models/learning/kingdom_models.dart';
import 'kingdom_mission_service.dart';
import 'kingdom_progress_service.dart';
import 'kingdom_review_service.dart';

class KingdomRecommendationService {
  KingdomRecommendationService._();
  static final KingdomRecommendationService I =
      KingdomRecommendationService._();

  KingdomRecommendation today() {
    final reviews = KingdomReviewService.I.dueItems();
    if (reviews.isNotEmpty) {
      final first = reviews.first;
      return KingdomRecommendation(
        kind: KingdomRecommendationKind.review,
        title: first.title,
        subtitle: first.reason,
        cta: 'Repasar',
        moduleKey: first.moduleKey,
        lessonId: first.lessonId,
      );
    }

    final next = KingdomProgressService.I.nextLesson();
    if (next != null) {
      return KingdomRecommendation(
        kind: KingdomRecommendationKind.nextLesson,
        title: next.title,
        subtitle: '${next.estimatedMinutes} min · ${next.objective}',
        cta: 'Continuar',
        moduleKey: next.moduleKey,
        lessonId: next.id,
      );
    }

    final missions = KingdomMissionService.I.dailyMissions();
    final pending = missions.where((m) => !m.completed).toList();
    if (pending.isNotEmpty) {
      final mission = pending.first;
      return KingdomRecommendation(
        kind: KingdomRecommendationKind.dailyPractice,
        title: mission.title,
        subtitle: mission.subtitle,
        cta: 'Empezar',
        moduleKey: 'mana',
      );
    }

    return const KingdomRecommendation(
      kind: KingdomRecommendationKind.rest,
      title: 'Dia completo',
      subtitle: 'Tu practica principal esta al dia.',
      cta: '',
      moduleKey: '',
    );
  }
}
