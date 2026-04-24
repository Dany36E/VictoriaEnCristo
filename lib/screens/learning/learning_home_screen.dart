/// ═══════════════════════════════════════════════════════════════════════════
/// LearningHomeScreen — Escuela del Reino (hub)
///
/// Reorganización (vs versión anterior):
///   • La inicialización pesada se delega a [LearningRegistry] (ya invocado
///     desde main.dart FASE 3). Aquí solo esperamos a `readyNotifier`. Con eso
///     evitamos el doble Future.wait.
///   • El hero (XP / hearts / racha) está aislado en su propio
///     ValueListenableBuilder<LearningProgress>: cambios en XP no rebuildean
///     las 11 tarjetas.
///   • Cada tarjeta de módulo conserva su propio ValueListenableBuilder local
///     sobre su servicio, así que un avance en, p. ej., Travesía no toca la
///     tarjeta de Héroes.
///   • Los módulos se agrupan en 3 secciones colapsables:
///         · Diario          (Maná, Armadura)
///         · Recorridos      (Travesía, Héroes, Parábolas, Línea, Fruto)
///         · Biblioteca      (Libros, Orden, Mapas, Profecías, Juegos)
///   • Tarjeta "Hoy te toca" en la cabecera con la mejor acción del día.
///   • Botón a "Mi Reino" (trofeos) en la AppBar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/learning_models.dart';
import '../../services/feedback_engine.dart';
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
import '../../services/learning/learning_registry.dart';
import '../../services/learning/parable_progress_service.dart';
import '../../services/learning/parable_repository.dart';
import '../../services/learning/prophecy_progress_service.dart';
import '../../services/learning/prophecy_repository.dart';
import '../../services/learning/question_repository.dart';
import '../../services/learning/timeline_progress_service.dart';
import '../../services/learning/timeline_repository.dart';
import '../../services/learning/verse_memory_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../widgets/learning/talents_badge.dart';
import '../../widgets/learning/xp_bar.dart';
import 'armory_deck_screen.dart';
import 'bible_maps_screen.dart';
import 'bible_order_screen.dart';
import 'bookshelf_screen.dart';
import 'fruit_garden_screen.dart';
import 'games_home_screen.dart';
import 'heroes_gallery_screen.dart';
import 'journey_map_screen.dart';
import 'mana_session_screen.dart';
import 'my_kingdom_screen.dart';
import 'parables_gallery_screen.dart';
import 'prophecies_home_screen.dart';
import 'timeline_lessons_screen.dart';

class LearningHomeScreen extends StatefulWidget {
  const LearningHomeScreen({super.key});

  @override
  State<LearningHomeScreen> createState() => _LearningHomeScreenState();
}

class _LearningHomeScreenState extends State<LearningHomeScreen> {
  // Secciones colapsables (default: todas abiertas).
  bool _expDiario = true;
  bool _expRecorridos = true;
  bool _expBiblioteca = true;

  @override
  void initState() {
    super.initState();
    // Idempotente: si ya estaba listo, vuelve inmediato.
    LearningRegistry.I.initAll();
    _logEvent('learning_home_open');
  }

  void _logEvent(String name, {Map<String, Object>? params}) {
    try {
      FirebaseAnalytics.instance
          .logEvent(name: name, parameters: params);
    } catch (_) {/* analytics no debería bloquear UX */}
  }

  Future<void> _openModule(
    String moduleKey,
    Widget Function() build,
  ) async {
    FeedbackEngine.I.tap();
    _logEvent('learning_module_open', params: {'module': moduleKey});
    await Navigator.push(context, MaterialPageRoute(builder: (_) => build()));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Text(
          'Escuela del Reino',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: [
          const TalentsBadge(),
          IconButton(
            tooltip: 'Mi Reino',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () {
              FeedbackEngine.I.tap();
              _logEvent('learning_my_kingdom_open');
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyKingdomScreen()),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: LearningRegistry.I.readyNotifier,
        builder: (context, ready, _) {
          if (!ready) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              // Hero aislado: solo se reconstruye al cambiar XP/hearts/streak.
              ValueListenableBuilder<LearningProgress>(
                valueListenable: LearningProgressService.I.progressNotifier,
                builder: (context, p, _) => _Hero(progress: p),
              ),
              const SizedBox(height: AppDesignSystem.spacingM),

              // C1 — "Hoy te toca" recomendación
              const _TodayRecommendationCard(),

              const SizedBox(height: AppDesignSystem.spacingL),

              _SectionHeader(
                title: 'Diario',
                subtitle: 'Tu práctica de cada día',
                expanded: _expDiario,
                onToggle: () => setState(() => _expDiario = !_expDiario),
              ),
              if (_expDiario) ...[
                const SizedBox(height: AppDesignSystem.spacingS),
                _ManaCard(onOpen: () => _openModule(
                    'mana', () => const ManaSessionScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _ArmoryCard(onOpen: () => _openModule(
                    'armory', () => const ArmoryDeckScreen())),
              ],

              const SizedBox(height: AppDesignSystem.spacingL),

              _SectionHeader(
                title: 'Recorridos',
                subtitle: 'Camina la historia paso a paso',
                expanded: _expRecorridos,
                onToggle: () =>
                    setState(() => _expRecorridos = !_expRecorridos),
              ),
              if (_expRecorridos) ...[
                const SizedBox(height: AppDesignSystem.spacingS),
                _JourneyCard(onOpen: () => _openModule(
                    'journey', () => const JourneyMapScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _HeroesCard(onOpen: () => _openModule(
                    'heroes', () => const HeroesGalleryScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _ParablesCard(onOpen: () => _openModule(
                    'parables', () => const ParablesGalleryScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _TimelineCard(onOpen: () => _openModule(
                    'timeline', () => const TimelineLessonsScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _FruitCard(onOpen: () => _openModule(
                    'fruit', () => const FruitGardenScreen())),
              ],

              const SizedBox(height: AppDesignSystem.spacingL),

              _SectionHeader(
                title: 'Biblioteca',
                subtitle: 'Explora libros, mapas y profecías',
                expanded: _expBiblioteca,
                onToggle: () =>
                    setState(() => _expBiblioteca = !_expBiblioteca),
              ),
              if (_expBiblioteca) ...[
                const SizedBox(height: AppDesignSystem.spacingS),
                _BooksCard(onOpen: () => _openModule(
                    'books', () => const BookshelfScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _BibleOrderCard(onOpen: () => _openModule(
                    'bible_order', () => const BibleOrderScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _MapsCard(onOpen: () => _openModule(
                    'maps', () => const BibleMapsScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _ProphecyCard(onOpen: () => _openModule(
                    'prophecy', () => const PropheciesHomeScreen())),
                const SizedBox(height: AppDesignSystem.spacingM),
                _GamesCard(onOpen: () => _openModule(
                    'games', () => const GamesHomeScreen())),
              ],

              const SizedBox(height: AppDesignSystem.spacingL),
              ValueListenableBuilder<LearningProgress>(
                valueListenable: LearningProgressService.I.progressNotifier,
                builder: (_, p, _) => _StatsRow(progress: p),
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// HERO  ·  STATS  ·  SECTION HEADER
// ══════════════════════════════════════════════════════════════════════════

class _Hero extends StatelessWidget {
  final LearningProgress progress;
  const _Hero({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, t.cardBg],
        ),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.2)),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Crece cada día en la Palabra',
                  style: AppDesignSystem.headlineSmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
              ),
              HeartsDisplay(hearts: progress.hearts),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          XpBar(progress: progress),
          const SizedBox(height: AppDesignSystem.spacingS),
          Row(
            children: [
              const Icon(Icons.local_fire_department_rounded,
                  size: 16, color: AppDesignSystem.gold),
              const SizedBox(width: 4),
              Text(
                '${progress.studyStreak} día${progress.studyStreak == 1 ? '' : 's'} estudiando',
                style: AppDesignSystem.labelMedium(
                  context,
                  color: t.textSecondary,
                ),
              ),
              if (LearningProgressService.I.isGraceShieldAvailable) ...[
                const SizedBox(width: AppDesignSystem.spacingS),
                const Tooltip(
                  message: 'Escudo de gracia disponible esta semana',
                  child: Icon(Icons.shield_outlined,
                      size: 16, color: AppDesignSystem.gold),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final LearningProgress progress;
  const _StatsRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'Sesiones', value: '${progress.sessionsCompleted}'),
        const SizedBox(width: AppDesignSystem.spacingM),
        _Stat(label: 'Dominados', value: '${progress.versesMastered}'),
        const SizedBox(width: AppDesignSystem.spacingM),
        _Stat(label: 'Racha', value: '${progress.studyStreak}'),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool expanded;
  final VoidCallback onToggle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      onTap: () {
        FeedbackEngine.I.tap();
        onToggle();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingS,
          vertical: AppDesignSystem.spacingS,
        ),
        child: Row(
          children: [
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
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppDesignSystem.bodyMedium(
                      context,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedRotation(
              turns: expanded ? 0 : -0.25,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.keyboard_arrow_down_rounded,
                  color: t.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// "HOY TE TOCA" — recomendación
// ══════════════════════════════════════════════════════════════════════════

class _TodayRecommendationCard extends StatelessWidget {
  const _TodayRecommendationCard();

  /// Calcula la mejor acción del día. Prioridad:
  ///   1. Versículos vencidos (Armadura)
  ///   2. Sesión Maná no hecha hoy
  ///   3. Próxima estación de Travesía
  ///   4. Próximo héroe sin desbloquear
  /// Si todo está al día, devuelve un mensaje de descanso.
  _Recommendation _compute() {
    final due = VerseMemoryService.I.summary().due;
    if (due > 0) {
      return _Recommendation(
        title: 'Repasa tus versículos',
        subtitle:
            '$due versículo${due == 1 ? '' : 's'} listo${due == 1 ? '' : 's'} hoy',
        cta: 'Empezar',
        icon: Icons.shield_moon_rounded,
        onTap: (ctx) => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const ArmoryDeckScreen())),
      );
    }
    final today = DateTime.now();
    final last = LearningProgressService.I.progressNotifier.value.lastStudyDate;
    final lastIsToday = last.isNotEmpty &&
        last.startsWith(
            '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}');
    if (!lastIsToday && QuestionRepository.I.all.isNotEmpty) {
      return _Recommendation(
        title: 'Sesión de Maná',
        subtitle: '7 preguntas · ~5 min',
        cta: 'Jugar',
        icon: Icons.wb_sunny_rounded,
        onTap: (ctx) => Navigator.push(
            ctx, MaterialPageRoute(builder: (_) => const ManaSessionScreen())),
      );
    }
    final nextStation = JourneyProgressService.I.currentStation();
    if (nextStation != null) {
      return _Recommendation(
        title: 'Continúa la Travesía',
        subtitle: 'Siguiente: ${nextStation.title}',
        cta: 'Avanzar',
        icon: Icons.map_rounded,
        onTap: (ctx) => Navigator.push(ctx,
            MaterialPageRoute(builder: (_) => const JourneyMapScreen())),
      );
    }
    return const _Recommendation(
      title: 'Día completo',
      subtitle: 'Hoy no hay tareas pendientes. Descansa en Su presencia.',
      cta: '',
      icon: Icons.spa_rounded,
      onTap: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        VerseMemoryService.I.changeTickNotifier,
        LearningProgressService.I.progressNotifier,
        JourneyProgressService.I.stateNotifier,
      ]),
      builder: (context, _) {
        final r = _compute();
        final t = AppThemeData.of(context);
        return InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          onTap: r.onTap == null
              ? null
              : () {
                  FeedbackEngine.I.tap();
                  r.onTap!(context);
                },
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppDesignSystem.gold.withOpacity(0.15),
                  AppDesignSystem.gold.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              border: Border.all(
                color: AppDesignSystem.gold.withOpacity(0.4),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gold.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(r.icon,
                      color: AppDesignSystem.gold, size: 24),
                ),
                const SizedBox(width: AppDesignSystem.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HOY TE TOCA',
                          style: AppDesignSystem.labelSmall(
                            context,
                            color: AppDesignSystem.gold,
                          ).copyWith(letterSpacing: 1.2)),
                      const SizedBox(height: 2),
                      Text(
                        r.title,
                        style: AppDesignSystem.headlineSmall(
                          context,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        r.subtitle,
                        style: AppDesignSystem.bodyMedium(
                          context,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (r.cta.isNotEmpty)
                  Text(r.cta,
                      style: AppDesignSystem.labelLarge(
                        context,
                        color: AppDesignSystem.gold,
                      )),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 350.ms);
      },
    );
  }
}

class _Recommendation {
  final String title;
  final String subtitle;
  final String cta;
  final IconData icon;
  final void Function(BuildContext)? onTap;
  const _Recommendation({
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.icon,
    required this.onTap,
  });
}

// ══════════════════════════════════════════════════════════════════════════
// MODULE CARDS — uno por módulo, con su propio ValueListenableBuilder
// ══════════════════════════════════════════════════════════════════════════

class _ManaCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ManaCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<LearningProgress>(
      valueListenable: LearningProgressService.I.progressNotifier,
      builder: (context, p, _) {
        final canPlay = QuestionRepository.I.all.isNotEmpty;
        return _ActionCard(
          icon: Icons.wb_sunny_rounded,
          iconColor: AppDesignSystem.gold,
          title: 'Maná del día',
          subtitle: 'Sesión rápida · ~5 min · 7 preguntas',
          cta: 'Empezar',
          enabled: canPlay,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _ArmoryCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ArmoryCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: VerseMemoryService.I.changeTickNotifier,
      builder: (context, _, _) {
        final s = VerseMemoryService.I.summary();
        final due = s.due;
        final subtitle = due > 0
            ? '$due versículo${due == 1 ? '' : 's'} listos para repasar'
            : '${s.mastered} dominados · ${s.total} en total';
        return _ActionCard(
          icon: Icons.shield_moon_rounded,
          iconColor: const Color(0xFF7CB8E8),
          title: 'Armadura',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: true,
          badge: due > 0 ? due.toString() : null,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 80.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _JourneyCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<JourneyProgressState>(
      valueListenable: JourneyProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = JourneyRepository.I.all.length;
        final done = state.completedIds.length;
        final current = JourneyProgressService.I.currentStation();
        final subtitle = total == 0
            ? 'Preparando ruta…'
            : done >= total
                ? 'Travesía completada. ¡Gloria a Dios!'
                : current != null
                    ? 'Siguiente: ${current.title}  ·  $done/$total'
                    : '$done/$total estaciones';
        return _ActionCard(
          icon: Icons.map_rounded,
          iconColor: AppDesignSystem.gold,
          title: 'Travesía Bíblica',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 60.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _HeroesCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _HeroesCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HeroesProgressState>(
      valueListenable: HeroesProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = HeroesRepository.I.all.length;
        final unlocked = state.unlockedIds.length;
        final subtitle = total == 0
            ? 'Preparando galería…'
            : unlocked >= total
                ? 'Conoces a todos los héroes. ¡Bien hecho!'
                : '$unlocked/$total héroes  ·  Hebreos 11';
        return _ActionCard(
          icon: Icons.workspace_premium_rounded,
          iconColor: AppDesignSystem.gold,
          title: 'Héroes de la Fe',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _ParablesCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ParablesCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ParableProgressState>(
      valueListenable: ParableProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = ParableRepository.I.all.length;
        final done = state.completedIds.length;
        final subtitle = total == 0
            ? 'Preparando parábolas…'
            : done >= total
                ? '¡Todas las parábolas exploradas!'
                : '$done/$total parábolas  ·  Maestro de Galilea';
        return _ActionCard(
          icon: Icons.record_voice_over_rounded,
          iconColor: const Color(0xFFF2B968),
          title: 'Parábolas de Jesús',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 140.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _TimelineCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TimelineProgressState>(
      valueListenable: TimelineProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = TimelineRepository.I.all.length;
        final done = state.completed.length;
        final stars = state.completed.values.fold(0, (a, b) => a + b);
        final subtitle = total == 0
            ? 'Preparando línea del tiempo…'
            : done >= total
                ? '¡Línea del tiempo dominada! $stars ★'
                : '$done/$total lecciones · $stars ★';
        return _ActionCard(
          icon: Icons.history_edu_rounded,
          iconColor: const Color(0xFF9FB8D8),
          title: 'Línea del Tiempo',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 180.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _FruitCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _FruitCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<FruitProgressState>(
      valueListenable: FruitProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = FruitRepository.I.all.length;
        final badges = state.badges.length;
        final subtitle = total == 0
            ? 'Preparando huerto…'
            : badges >= total
                ? '👑 Corona de los 9 frutos completa'
                : '$badges/$total insignias  ·  Gálatas 5:22-23';
        return _ActionCard(
          icon: Icons.eco_rounded,
          iconColor: const Color(0xFF7FC99A),
          title: 'Fruto del Espíritu',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 220.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _BooksCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _BooksCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BookProgressState>(
      valueListenable: BookProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = BookRepository.I.all.length;
        final done = state.studied.length;
        final subtitle = total == 0
            ? 'Preparando biblioteca…'
            : done >= total
                ? '¡66 libros estudiados!'
                : '$done/$total libros  ·  AT + NT';
        return _ActionCard(
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFFD4A853),
          title: 'Los 66 Libros',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 260.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _BibleOrderCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _BibleOrderCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BibleOrderProgressState>(
      valueListenable: BibleOrderProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final stars = state.totalStars;
        final done = state.bestStars.length;
        final subtitle = done == 0
            ? 'Aprende el orden de los 66 libros'
            : '$done secciones · $stars ★';
        return _ActionCard(
          icon: Icons.format_list_numbered_rounded,
          iconColor: const Color(0xFFE8B86D),
          title: 'Orden de la Biblia',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: BookRepository.I.all.isNotEmpty,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 300.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _MapsCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _MapsCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BibleMapProgressState>(
      valueListenable: BibleMapProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = BibleMapRepository.I.all.length;
        final done = state.completedMaps.length;
        final totalStars = state.completedMaps.values.fold(0, (a, b) => a + b);
        final subtitle = total == 0
            ? 'Preparando mapas…'
            : done >= total
                ? '¡Todas las tierras exploradas! $totalStars ★'
                : '$done/$total mapas · $totalStars ★';
        return _ActionCard(
          icon: Icons.public_rounded,
          iconColor: const Color(0xFF6BC5A0),
          title: 'Tierras Bíblicas',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 340.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _ProphecyCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ProphecyCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ProphecyProgressState>(
      valueListenable: ProphecyProgressService.I.stateNotifier,
      builder: (context, state, _) {
        final total = ProphecyRepository.I.all.length;
        final stars = state.bestStars.values.fold(0, (a, b) => a + b);
        final subtitle = total == 0
            ? 'Preparando profecías…'
            : 'Profecías AT → NT  ·  $stars ★';
        return _ActionCard(
          icon: Icons.auto_awesome_rounded,
          iconColor: const Color(0xFFB59FE3),
          title: 'Profecías Mesiánicas',
          subtitle: subtitle,
          cta: 'Abrir',
          enabled: total > 0,
          onTap: onOpen,
        ).animate().fadeIn(duration: 300.ms, delay: 380.ms).slideY(begin: 0.05, end: 0);
      },
    );
  }
}

class _GamesCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _GamesCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _ActionCard(
      icon: Icons.sports_esports_rounded,
      iconColor: const Color(0xFF7FC99A),
      title: 'Juegos Bíblicos',
      subtitle: 'Reta a alguien · 1 vs 1 local · 3 juegos',
      cta: 'Jugar',
      enabled: true,
      onTap: onOpen,
    ).animate().fadeIn(duration: 300.ms, delay: 420.ms).slideY(begin: 0.05, end: 0);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// PRIVATE WIDGETS BASE
// ══════════════════════════════════════════════════════════════════════════

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String cta;
  final bool enabled;
  final String? badge;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.enabled,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        onTap: enabled ? onTap : null,
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
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 28),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.gold,
                          borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusFull),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
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
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppDesignSystem.bodyMedium(
                        context,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingS),
              Text(
                cta,
                style: AppDesignSystem.labelLarge(
                  context,
                  color: AppDesignSystem.gold,
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;

  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingM,
        ),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(color: t.cardBorder),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppDesignSystem.headlineMedium(
                context,
                color: AppDesignSystem.gold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppDesignSystem.labelSmall(
                context,
                color: t.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
