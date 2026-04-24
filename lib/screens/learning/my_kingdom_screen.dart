/// ═══════════════════════════════════════════════════════════════════════════
/// MyKingdomScreen — "Mi Reino" (C5)
///
/// Sala de trofeos: muestra todo lo que el usuario ha conquistado en una sola
/// vista. Útil para reforzar la sensación de logro acumulado y para que pueda
/// repasar sin entrar a cada módulo.
///
/// Resumen mostrado:
///   • Nivel espiritual + XP
///   • Racha y escudo de gracia
///   • Versículos dominados / aprendiendo / total
///   • Travesía: estaciones completadas
///   • Héroes desbloqueados
///   • Parábolas / Línea del tiempo / Fruto / Mapas / Profecías
///   • Libros estudiados (66)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../models/learning/learning_models.dart';
import '../../services/learning/bible_map_progress_service.dart';
import '../../services/learning/bible_map_repository.dart';
import '../../services/learning/bible_order_progress_service.dart';
import '../../services/learning/book_progress_service.dart';
import '../../services/learning/book_repository.dart';
import '../../services/learning/collectibles_service.dart';
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
import '../../services/learning/talents_service.dart';
import '../../services/learning/timeline_progress_service.dart';
import '../../services/learning/timeline_repository.dart';
import '../../services/learning/verse_memory_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'talents_library_screen.dart';

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
        title: Text('Mi Reino',
            style: AppDesignSystem.headlineMedium(context, color: t.textPrimary)),
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
          TalentsService.I.stateNotifier,
          CollectiblesService.I.unlockedNotifier,
        ]),
        builder: (context, _) {
          final p = LearningProgressService.I.progressNotifier.value;
          final verses = VerseMemoryService.I.summary();
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              _LevelHeader(progress: p),
              const SizedBox(height: AppDesignSystem.spacingL),
              // ── Tarjeta especial Talentos ─────────────────────────────
              _TalentsCard(),
              const SizedBox(height: AppDesignSystem.spacingM),
              _trophyTile(
                context,
                icon: Icons.local_fire_department_rounded,
                color: AppDesignSystem.gold,
                title: 'Racha',
                value: '${p.studyStreak} día${p.studyStreak == 1 ? '' : 's'}',
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
                  final s = TimelineProgressService.I.stateNotifier.value;
                  final stars = s.completed.values.fold(0, (a, b) => a + b);
                  return '${s.completed.length} / ${TimelineRepository.I.all.length}  ·  $stars ★';
                }(),
                hint: 'Lecciones',
              ),
              _trophyTile(
                context,
                icon: Icons.eco_rounded,
                color: const Color(0xFF7FC99A),
                title: 'Fruto del Espíritu',
                value:
                    '${FruitProgressService.I.stateNotifier.value.badges.length} / ${FruitRepository.I.all.length}',
                hint: 'Insignias · Gálatas 5:22-23',
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
                  final s = BibleMapProgressService.I.stateNotifier.value;
                  final stars = s.completedMaps.values.fold(0, (a, b) => a + b);
                  return '${s.completedMaps.length} / ${BibleMapRepository.I.all.length}  ·  $stars ★';
                }(),
                hint: '',
              ),
              _trophyTile(
                context,
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFB59FE3),
                title: 'Profecías',
                value: () {
                  final s = ProphecyProgressService.I.stateNotifier.value;
                  final stars = s.bestStars.values.fold(0, (a, b) => a + b);
                  return '${s.bestStars.length} / ${ProphecyRepository.I.all.length}  ·  $stars ★';
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
                  Text(title,
                      style: AppDesignSystem.headlineSmall(
                        context,
                        color: t.textPrimary,
                      )),
                  if (hint.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(hint,
                        style: AppDesignSystem.bodyMedium(
                          context,
                          color: t.textSecondary,
                        )),
                  ],
                ],
              ),
            ),
            Text(value,
                style: AppDesignSystem.headlineSmall(
                  context,
                  color: AppDesignSystem.gold,
                )),
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
    final lvl = progress.level;
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
          Text(lvl.emoji, style: const TextStyle(fontSize: 56)),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lvl.displayName,
                    style: AppDesignSystem.displaySmall(
                      context,
                      color: t.textPrimary,
                    )),
                const SizedBox(height: 4),
                Text('${progress.totalXp} XP totales',
                    style: AppDesignSystem.bodyMedium(
                      context,
                      color: t.textSecondary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


/// Tarjeta destacada que muestra balance de Talentos + progreso global de
/// coleccionables. Tap ? abre la biblioteca.
class _TalentsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final balance = TalentsService.I.stateNotifier.value.balance;
    final unlocked = CollectiblesService.I.totalUnlocked;
    final total = CollectiblesService.I.totalAvailable;
    final pct = total == 0 ? 0.0 : (unlocked / total).clamp(0.0, 1.0);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TalentsLibraryScreen()),
      ),
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppDesignSystem.gold.withOpacity(0.25),
              AppDesignSystem.goldDark.withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(color: AppDesignSystem.gold.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppDesignSystem.gold,
                        AppDesignSystem.goldDark,
                      ],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    color: AppDesignSystem.midnightDeep,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppDesignSystem.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Talentos',
                          style: AppDesignSystem.headlineSmall(context,
                              color: t.textPrimary)),
                      Text('$balance disponibles',
                          style: AppDesignSystem.bodyMedium(context,
                              color: AppDesignSystem.gold)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textSecondary),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              'Biblioteca: $unlocked / $total piezas',
              style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: t.cardBg,
                valueColor:
                    const AlwaysStoppedAnimation(AppDesignSystem.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
