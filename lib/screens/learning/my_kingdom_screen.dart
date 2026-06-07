library;

import 'package:flutter/material.dart';

import '../../models/learning/learning_models.dart';
import '../../services/learning/bible_map_progress_service.dart';
import '../../services/learning/bible_map_repository.dart';
import '../../services/learning/bible_order_progress_service.dart';
import '../../services/learning/book_progress_service.dart';
import '../../services/learning/book_repository.dart';
import '../../services/learning/fruit_progress_service.dart';
import '../../services/learning/fruit_repository.dart';
import '../../services/learning/heroes_progress_service.dart';
import '../../services/learning/heroes_repository.dart';
import '../../services/learning/journey_progress_service.dart';
import '../../services/learning/journey_repository.dart';
import '../../services/learning/learning_progress_service.dart';
import '../../services/learning/parable_progress_service.dart';
import '../../services/learning/parable_repository.dart';
import '../../services/learning/prophecy_progress_service.dart';
import '../../services/learning/prophecy_repository.dart';
import '../../services/learning/timeline_progress_service.dart';
import '../../services/learning/timeline_repository.dart';
import '../../services/learning/verse_memory_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class MyKingdomScreen extends StatelessWidget {
  const MyKingdomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Mi Reino',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          LearningProgressService.I.progressNotifier,
          VerseMemoryService.I.changeTickNotifier,
          JourneyProgressService.I.stateNotifier,
          HeroesProgressService.I.stateNotifier,
          ParableProgressService.I.stateNotifier,
          TimelineProgressService.I.stateNotifier,
          FruitProgressService.I.stateNotifier,
          BookProgressService.I.stateNotifier,
          BibleMapProgressService.I.stateNotifier,
          ProphecyProgressService.I.stateNotifier,
          BibleOrderProgressService.I.stateNotifier,
        ]),
        builder: (context, _) {
          final progress = LearningProgressService.I.progressNotifier.value;
          final verses = VerseMemoryService.I.summary();
          final fruitCompleted =
              FruitProgressService.I.stateNotifier.value.badges.length;
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              _LevelHeader(progress: progress),
              const SizedBox(height: AppDesignSystem.spacingL),
              _trophyTile(
                context,
                icon: Icons.local_fire_department_rounded,
                color: AppDesignSystem.gold,
                title: 'Racha',
                value:
                    '${progress.studyStreak} d${progress.studyStreak == 1 ? "ía" : "ías"}',
                hint: LearningProgressService.I.isGraceShieldAvailable
                    ? 'Escudo de gracia disponible esta semana'
                    : 'Escudo usado · vuelve la próxima semana',
              ),
              _trophyTile(
                context,
                icon: Icons.shield_moon_rounded,
                color: const Color(0xFF7CB8E8),
                title: 'Versículos',
                value: '${verses.mastered} / ${verses.total}',
                hint:
                    '${verses.mastered} dominados · ${verses.total - verses.mastered} aprendiendo',
              ),
              _trophyTile(
                context,
                icon: Icons.map_rounded,
                color: AppDesignSystem.gold,
                title: 'Travesía',
                value:
                    '${JourneyProgressService.I.stateNotifier.value.completedIds.length} / ${JourneyRepository.I.all.length}',
                hint: 'Estaciones completadas',
              ),
              _trophyTile(
                context,
                icon: Icons.workspace_premium_rounded,
                color: AppDesignSystem.gold,
                title: 'Héroes',
                value:
                    '${HeroesProgressService.I.stateNotifier.value.unlockedIds.length} / ${HeroesRepository.I.all.length}',
                hint: 'Hebreos 11',
              ),
              _trophyTile(
                context,
                icon: Icons.record_voice_over_rounded,
                color: const Color(0xFFF2B968),
                title: 'Parábolas',
                value:
                    '${ParableProgressService.I.stateNotifier.value.completedIds.length} / ${ParableRepository.I.all.length}',
                hint: 'Maestro de Galilea',
              ),
              _trophyTile(
                context,
                icon: Icons.history_edu_rounded,
                color: const Color(0xFF9FB8D8),
                title: 'Línea del tiempo',
                value: () {
                  final state = TimelineProgressService.I.stateNotifier.value;
                  final stars = state.completed.values.fold(0, (a, b) => a + b);
                  return '${state.completed.length} / ${TimelineRepository.I.all.length} · $stars ★';
                }(),
                hint: 'Lecciones',
              ),
              _trophyTile(
                context,
                icon: Icons.eco_rounded,
                color: const Color(0xFF7FC99A),
                title: 'Fruto del Espíritu',
                value: '$fruitCompleted / ${FruitRepository.I.all.length}',
                hint: 'Frutos cultivados · Gálatas 5:22-23',
              ),
              _trophyTile(
                context,
                icon: Icons.menu_book_rounded,
                color: const Color(0xFFD4A853),
                title: 'Los 66 libros',
                value:
                    '${BookProgressService.I.stateNotifier.value.studied.length} / ${BookRepository.I.all.length}',
                hint: 'Estudiados',
              ),
              _trophyTile(
                context,
                icon: Icons.format_list_numbered_rounded,
                color: const Color(0xFFE8B86D),
                title: 'Orden bíblico',
                value:
                    '${BibleOrderProgressService.I.stateNotifier.value.bestStars.length} secc. · ${BibleOrderProgressService.I.stateNotifier.value.totalStars} ★',
                hint: '',
              ),
              _trophyTile(
                context,
                icon: Icons.public_rounded,
                color: const Color(0xFF6BC5A0),
                title: 'Tierras bíblicas',
                value: () {
                  final state = BibleMapProgressService.I.stateNotifier.value;
                  final stars = state.completedMaps.values.fold(0, (a, b) => a + b);
                  return '${state.completedMaps.length} / ${BibleMapRepository.I.all.length} · $stars ★';
                }(),
                hint: '',
              ),
              _trophyTile(
                context,
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFB59FE3),
                title: 'Profecías',
                value: () {
                  final state = ProphecyProgressService.I.stateNotifier.value;
                  final stars = state.bestStars.values.fold(0, (a, b) => a + b);
                  return '${state.bestStars.length} / ${ProphecyRepository.I.all.length} · $stars ★';
                }(),
                hint: 'AT → NT',
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
              Center(
                child: Text(
                  '«Tuyo es el reino, y el poder, y la gloria, por todos los siglos.»',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: t.textSecondary,
                  ).copyWith(fontStyle: FontStyle.italic),
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
            ],
          );
        },
      ),
    );
  }

  Widget _trophyTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String hint,
  }) {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(color: t.cardBorder),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppDesignSystem.headlineSmall(
                      context,
                      color: t.textPrimary,
                    ),
                  ),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: AppDesignSystem.bodyMedium(
                        context,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              value,
              style: AppDesignSystem.headlineSmall(
                context,
                color: AppDesignSystem.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LevelHeader extends StatelessWidget {
  final LearningProgress progress;

  const _LevelHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final level = progress.level;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppDesignSystem.gold.withOpacity(0.18),
            AppDesignSystem.gold.withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Text(level.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  level.displayName,
                  style: AppDesignSystem.displaySmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${progress.totalXp} XP totales',
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
