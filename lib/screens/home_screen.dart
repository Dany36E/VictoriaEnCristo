import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/image_urls.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/home/daily_verse_section.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/sos_button.dart';
import '../widgets/home/bible_reading_streak.dart';
import '../widgets/daily_checklist_card.dart';
import 'learning/learning_home_screen.dart';
import '../widgets/milestone_banner.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../data/bible_verses.dart';
import '../services/daily_verse_service.dart';
import '../services/victory_scoring_service.dart';
import '../services/feedback_engine.dart';
import '../services/content_repository.dart';
import '../widgets/jesus_streak_widget.dart';
import 'verses_screen.dart';
import 'prayers_screen.dart';
import 'plan_library_screen.dart';
import 'progress_screen.dart';
import 'journal_screen.dart';
import 'devotional_screen.dart';

import 'battle_partner/battle_partner_screen.dart';
import 'wall/wall_screen.dart';
import 'admin/admin_wall_screen.dart';
import 'bible/bible_home_screen.dart';
import 'exercises_screen.dart';
import 'relapse_recovery_screen.dart';
import '../utils/bible_navigation_helper.dart';
import '../services/battle_partner_service.dart';
import '../services/audio_engine.dart';
import '../services/badge_service.dart';
import '../widgets/badge_celebration.dart';
import '../repositories/profile_repository.dart';
import '../widgets/morning_checkin_sheet.dart';
import '../widgets/offline_banner.dart';
import '../main.dart' show routeObserver;
import '../utils/daily_outcome_registration.dart';

// Enum para tipos de animación de iconos
enum IconAnimationType {
  shimmer, // Versículos - destello
  heartbeat, // Oraciones - latido
  rotate, // Devocional - rotación
  drawUp, // Progreso - dibujado
  pulse, // Diario - pulso suave
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;

  const HomeScreen({super.key, this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, RouteAware {
  late BibleVerse dailyVerse;

  // Victoria del día
  int _currentStreak = 0;
  bool _loggedToday = false;
  bool _victoryLoading = true;
  bool _celebrationShownToday = false;
  bool _checkinDoneToday = false;

  @override
  void initState() {
    super.initState();
    // Versículo del día determinístico (no aleatorio)
    dailyVerse = DailyVerseService.I.getForTodaySync();

    // Cargar contenido personalizado
    _loadPersonalizedContent();

    // Cargar datos de victoria
    _loadVictoryData();

    // Escuchar cambios en VictoryScoringService (se actualiza cuando
    // DataBootstrapper/AccountSessionManager hidratan desde cloud)
    VictoryScoringService.I.currentStreakNotifier.addListener(_onScoringChanged);
    VictoryScoringService.I.loggedTodayNotifier.addListener(_onScoringChanged);
    VictoryScoringService.I.relapseEventNotifier.addListener(_onRelapseEvent);

    // Si al entrar ya hay una recaída pendiente, mostrar tras el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onRelapseEvent();
    });
  }

  bool _relapseScreenShown = false;

  void _onRelapseEvent() {
    if (!mounted || _relapseScreenShown) return;
    final scoring = VictoryScoringService.I;
    if (!scoring.hasPendingRelapseAck) return;
    _relapseScreenShown = true;
    final broken = scoring.lastBrokenStreak;
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => RelapseRecoveryScreen(brokenStreak: broken),
            fullscreenDialog: true,
          ),
        )
        .then((_) {
          _relapseScreenShown = false;
        });
  }

  void _onScoringChanged() {
    if (!mounted) return;
    setState(() {
      _currentStreak = VictoryScoringService.I.getCurrentStreak();
      _loggedToday = VictoryScoringService.I.isLoggedToday();
    });
  }

  Future<void> _loadVictoryData() async {
    try {
      await VictoryScoringService.I.init();

      // También inicializar DailyVerseService async
      await DailyVerseService.I.init();
      final verse = await DailyVerseService.I.getForToday();

      if (mounted) {
        setState(() {
          dailyVerse = verse;
          _currentStreak = VictoryScoringService.I.getCurrentStreak();
          _loggedToday = VictoryScoringService.I.isLoggedToday();
          _victoryLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _victoryLoading = false;
        });
      }
    }

    // Verificar insignias después de cargar datos
    _checkBadgesAndNotify();

    // Mostrar check-in matutino (una vez al día)
    _showMorningCheckinIfNeeded();
  }

  Future<void> _showMorningCheckinIfNeeded() async {
    try {
      if (!mounted) return;
      final shouldShow = await MorningCheckinSheet.shouldShow();
      if (!shouldShow) {
        // Ya hizo el check-in hoy
        if (mounted) setState(() => _checkinDoneToday = true);
        return;
      }
      if (mounted) {
        // Pequeño delay para que la UI se estabilice
        await Future.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const MorningCheckinSheet(),
        );
        // Verificar si realmente completó (markShown pudo no haberse llamado si descartó el sheet)
        final wasCompleted = !(await MorningCheckinSheet.shouldShow());
        if (mounted && wasCompleted) setState(() => _checkinDoneToday = true);
      }
    } catch (e) {
      debugPrint('[HOME] Error showing morning check-in: $e');
    }
  }

  Future<void> _registerVictory() async {
    debugPrint(
      '🎉 _registerVictory called: _loggedToday=$_loggedToday, isTodayVictory=${VictoryScoringService.I.isTodayVictory()}, _celebrationShown=$_celebrationShownToday',
    );

    final shouldShowAlreadyVictoryCelebration = !_celebrationShownToday;
    final result = await promptAndRegisterDailyOutcome(
      context,
      showVictoryCelebration: true,
      showAlreadyVictoryCelebration: shouldShowAlreadyVictoryCelebration,
    );

    if (!mounted) return;

    if (result.status == DailyOutcomeStatus.alreadyVictory) {
      if (shouldShowAlreadyVictoryCelebration) {
        _celebrationShownToday = true;
      } else {
        _navigateToProgress();
      }
      return;
    }

    if (result.status == DailyOutcomeStatus.tooEarly) {
      _navigateToProgress();
      return;
    }

    if (result.changed) {
      setState(() {
        _currentStreak = result.streak;
        _loggedToday = VictoryScoringService.I.hasDataForToday();
      });

      if (result.status == DailyOutcomeStatus.victoryLogged) {
        _celebrationShownToday = true;
      }
    }
  }

  void _navigateToProgress() {
    // Feedback táctil suave para navegación
    FeedbackEngine.I.tap();

    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProgressScreen()))
        .then((_) {
          // Recargar datos de victoria al volver (por si editó días)
          _refreshVictoryData();
        })
        .catchError((e) {
          debugPrint('⚠️ [HOME] Nav progress error: $e');
        });
  }

  /// Refresca los datos de victoria sin recargar todo
  void _refreshVictoryData() {
    if (!mounted) return;
    setState(() {
      _currentStreak = VictoryScoringService.I.getCurrentStreak();
      _loggedToday = VictoryScoringService.I.hasDataForToday();
    });
  }

  Future<void> _loadPersonalizedContent() async {
    try {
      await ContentRepository.I.init();
    } catch (e) {
      debugPrint('⚠️ [HOME] Error loading home content: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    VictoryScoringService.I.currentStreakNotifier.removeListener(_onScoringChanged);
    VictoryScoringService.I.loggedTodayNotifier.removeListener(_onScoringChanged);
    VictoryScoringService.I.relapseEventNotifier.removeListener(_onRelapseEvent);
    super.dispose();
  }

  // RouteAware: BGM solo suena en HomeScreen
  @override
  void didPush() => AudioEngine.I.unmuteForScreen();

  @override
  void didPopNext() {
    AudioEngine.I.unmuteForScreen();
    _checkBadgesAndNotify();
  }

  @override
  void didPushNext() => AudioEngine.I.muteForScreen();

  /// Verifica insignias y muestra snackbar si hay nuevas
  Future<void> _checkBadgesAndNotify() async {
    final newBadges = await BadgeService.I.checkForNewBadges();
    if (!mounted || newBadges.isEmpty) return;
    for (final badge in newBadges) {
      BadgeCelebration.showSnackbar(context, badge);
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    // Forzar íconos claros en status bar: el fondo hero siempre es oscuro arriba
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS
      ),
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // CAPA 1: Imagen de fondo épica (cacheada)
            Positioned.fill(
              child: CachedNetworkImage(
                imageUrl: ImageUrls.heroMountain,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                placeholder: (context, url) => Container(color: t.scaffoldBg),
                errorWidget: (context, url, error) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.surface, t.scaffoldBg, t.scaffoldBg],
                    ),
                  ),
                ),
              ),
            ),

            // CAPA 2: Overlay gradiente (adapta opacidad según tema)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      t.scaffoldBg.withOpacity(0.95),
                      t.scaffoldBg.withOpacity(0.7),
                      t.scaffoldBg.withOpacity(0.3),
                      t.scaffoldBg.withOpacity(0.1),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.15, 0.35, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            // CAPA 3: Contenido principal
            SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // Banner de conectividad
                  const SliverToBoxAdapter(child: OfflineBanner()),
                  // Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                      child: HomeHeader(
                        onThemeChanged: () {
                          widget.onThemeChanged?.call();
                          // FIX (crash: setState() called after dispose):
                          // El callback puede disparar desde SettingsScreen
                          // tras un pop rápido, cuando este State ya no está
                          // en el árbol. Verificamos `mounted` antes de
                          // invocar setState para evitar el FlutterError.
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════════════
                  // HERO: VICTORIAS (Primer elemento de impacto)
                  // ═══════════════════════════════════════════════════════════════
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: JesusStreakWidget(
                        streakDays: _currentStreak,
                        completedToday: _loggedToday,
                        victoryToday: VictoryScoringService.I.isTodayVictory(),
                        isNewUser:
                            _currentStreak == 0 &&
                            !_loggedToday &&
                            VictoryScoringService.I.getBestStreakAllTime() == 0,
                        isLoading: _victoryLoading,
                        checkinDone: _checkinDoneToday,
                        onRegisterVictory: _registerVictory,
                        onTapCard: _navigateToProgress,
                      ),
                    ),
                  ),

                  // Daily Verse Section (después de Victorias)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        0,
                      ),
                      child: DailyVerseSection(
                        dailyVerse: dailyVerse,
                        onTapVerse: (ref) =>
                            BibleNavigationHelper.navigateToSpanishRef(context, ref),
                      ),
                    ),
                  ),

                  // Bible Reading Streak (mini-card)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                        0,
                      ),
                      child: BibleReadingStreak(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const BibleHomeScreen()),
                        ),
                      ),
                    ),
                  ),

                  // Milestone Banner (hito alcanzado / progreso / normalización)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                        0,
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: VictoryScoringService.I.currentStreakNotifier,
                        builder: (_, streak, _) => MilestoneBanner(streak: streak),
                      ),
                    ),
                  ),

                  // Daily Checklist (4/4 prácticas del día)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                        0,
                      ),
                      child: DailyChecklistCard(
                        onTapDevotional: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DevotionalScreen()),
                        ),
                        onTapPrayer: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrayersScreen()),
                        ),
                        onTapJournal: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const JournalScreen()),
                        ),
                        onTapVictory: _registerVictory,
                        onTapStudy: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LearningHomeScreen()),
                        ),
                      ),
                    ),
                  ),

                  // ═══════════════════════════════════════════════════════════
                  // QUICK GLANCE - Compañero + Insignias + Etapa
                  // ═══════════════════════════════════════════════════════════
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        0,
                      ),
                      child: _buildQuickGlance(),
                    ),
                  ),

                  // Tools Section Header — PRÁCTICA DIARIA
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                      ),
                      child: _buildSectionHeader(
                        label: 'PRÁCTICA DIARIA',
                        icon: Icons.wb_sunny_outlined,
                        accent: const Color(0xFFFF80AB),
                        animationDelayMs: 250,
                      ),
                    ),
                  ),

                  // Grid: Práctica diaria (Oraciones, Ejercicios, Mi Diario, Versículos)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.favorite,
                                title: 'Oraciones',
                                subtitle: 'Conexión con Dios',
                                accentColor: const Color(0xFFFF80AB),
                                animationType: IconAnimationType.heartbeat,
                                index: 0,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PrayersScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.fitness_center,
                                title: 'Ejercicios',
                                subtitle: 'Respira y ancla',
                                accentColor: const Color(0xFF80CBC4),
                                animationType: IconAnimationType.pulse,
                                index: 1,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ExercisesScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.auto_stories,
                                title: 'Mi Diario',
                                subtitle: 'Reflexiones',
                                accentColor: const Color(0xFFCE93D8),
                                animationType: IconAnimationType.pulse,
                                index: 2,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const JournalScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.menu_book_outlined,
                                title: 'Versículos',
                                subtitle: 'Armadura espiritual',
                                accentColor: const Color(0xFF64B5F6),
                                animationType: IconAnimationType.shimmer,
                                index: 3,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const VersesScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.school_rounded,
                                title: 'Escuela del Reino',
                                subtitle: 'Aprende y memoriza',
                                accentColor: AppDesignSystem.gold,
                                animationType: IconAnimationType.shimmer,
                                index: 4,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LearningHomeScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            const Expanded(child: SizedBox.shrink()),
                          ],
                        ),
                      ]),
                    ),
                  ),

                  // Tools Section Header — CRECIMIENTO
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                      ),
                      child: _buildSectionHeader(
                        label: 'CRECIMIENTO',
                        icon: Icons.trending_up_rounded,
                        accent: const Color(0xFFE8C97A),
                        animationDelayMs: 300,
                      ),
                    ),
                  ),

                  // Grid: Crecimiento (Planes, La Biblia, Mi Progreso)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.wb_sunny,
                                title: 'Planes',
                                subtitle: 'Crecimiento espiritual',
                                accentColor: const Color(0xFFFFD740),
                                animationType: IconAnimationType.rotate,
                                index: 4,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PlanLibraryScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.menu_book,
                                title: 'La Biblia',
                                subtitle: 'Palabra de Dios',
                                accentColor: const Color(0xFFE8C97A),
                                animationType: IconAnimationType.shimmer,
                                index: 5,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const BibleHomeScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        Row(
                          children: [
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.show_chart,
                                title: 'Mi Progreso',
                                subtitle: 'Días de victoria',
                                accentColor: const Color(0xFF69F0AE),
                                animationType: IconAnimationType.drawUp,
                                index: 6,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const ProgressScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.auto_stories_rounded,
                                title: 'Devocional',
                                subtitle: '30 días de fe',
                                accentColor: const Color(0xFFCE93D8),
                                animationType: IconAnimationType.pulse,
                                index: 7,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const DevotionalScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ]),
                    ),
                  ),

                  // Tools Section Header — COMUNIDAD
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                      ),
                      child: _buildSectionHeader(
                        label: 'COMUNIDAD',
                        icon: Icons.groups_rounded,
                        accent: const Color(0xFFFFAB40),
                        animationDelayMs: 350,
                      ),
                    ),
                  ),

                  // Grid: Comunidad (Compañero, Muro de Batalla)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        Row(
                          children: [
                            Expanded(
                              child: ValueListenableBuilder<List<dynamic>>(
                                valueListenable: BattlePartnerService.I.pendingInvitesNotifier,
                                builder: (context, invites, _) {
                                  return Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      _GlassmorphicMenuButton(
                                        icon: Icons.shield,
                                        title: 'Compañero',
                                        subtitle: 'De Batalla',
                                        accentColor: const Color(0xFFFFAB40),
                                        animationType: IconAnimationType.pulse,
                                        index: 7,
                                        onTap: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const BattlePartnerScreen(),
                                          ),
                                        ),
                                      ),
                                      if (invites.isNotEmpty)
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(5),
                                            decoration: const BoxDecoration(
                                              color: AppDesignSystem.struggle,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Text(
                                              '${invites.length}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: AppDesignSystem.spacingM),
                            Expanded(
                              child: _GlassmorphicMenuButton(
                                icon: Icons.forum_rounded,
                                title: 'Muro de',
                                subtitle: 'Batalla',
                                accentColor: const Color(0xFF64B5F6),
                                animationType: IconAnimationType.shimmer,
                                index: 8,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const WallScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        // ── Admin row (hidden, solo si isAdmin) ──
                        if (ProfileRepository.I.currentProfile?.isAdmin == true)
                          Padding(
                            padding: const EdgeInsets.only(top: AppDesignSystem.spacingM),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _GlassmorphicMenuButton(
                                    icon: Icons.admin_panel_settings_rounded,
                                    title: 'Moderación',
                                    subtitle: 'Admin',
                                    accentColor: AppDesignSystem.struggle,
                                    animationType: IconAnimationType.pulse,
                                    index: 9,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const AdminWallScreen()),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppDesignSystem.spacingM),
                                const Expanded(child: SizedBox()),
                              ],
                            ),
                          ),
                      ]),
                    ),
                  ),

                  // Bottom spacing for FAB + Safe Area
                  SliverToBoxAdapter(
                    child: SizedBox(height: MediaQuery.of(context).padding.bottom + 120),
                  ),
                ],
              ),
            ),

            // Floating SOS Button with breathing glow
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 24,
              child: const Center(child: BreathingSosButton()),
            ),
          ],
        ),
      ), // Scaffold
    ); // AnnotatedRegion
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN DE PLANES RECOMENDADOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuickGlance() {
    final partners = BattlePartnerService.I.partnersNotifier.value;

    // Solo mostramos compañeros para no saturar la home.
    // Insignias y etapa viven en ProgressScreen donde hay espacio para
    // mostrarlas con el detalle que merecen.
    if (partners.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _QuickGlanceChip(
          emoji: '🛡️',
          label: '${partners.length} compañero${partners.length > 1 ? 's' : ''}',
          color: const Color(0xFFFFAB40),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BattlePartnerScreen()),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildSectionHeader({
    String label = 'HERRAMIENTAS DE VICTORIA',
    IconData icon = Icons.shield_outlined,
    Color? accent,
    int animationDelayMs = 300,
  }) {
    final color = accent ?? Colors.white;
    return Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingS),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                border: Border.all(color: color.withOpacity(0.25), width: 0.5),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.white70,
              ),
            ),
          ],
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: animationDelayMs),
          duration: 400.ms,
        )
        .slideX(begin: -0.1, end: 0);
  }
}

// ============================================================================
// GLASSMORPHIC MENU BUTTON - Premium Dark UI Component
// ============================================================================

class _GlassmorphicMenuButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final IconAnimationType animationType;
  final int index;
  final VoidCallback onTap;

  const _GlassmorphicMenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.animationType,
    required this.index,
    required this.onTap,
  });

  @override
  State<_GlassmorphicMenuButton> createState() => _GlassmorphicMenuButtonState();
}

class _GlassmorphicMenuButtonState extends State<_GlassmorphicMenuButton>
    with TickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  late AnimationController _iconAnimationController;
  late AnimationController _shimmerController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    // Animación principal del icono según tipo
    switch (widget.animationType) {
      case IconAnimationType.shimmer:
        _shimmerController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        );
        // Repetir cada 5 segundos
        Future.delayed(Duration(milliseconds: widget.index * 200), () {
          if (mounted) {
            _shimmerController.forward().then((_) {
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) {
                  _shimmerController.reset();
                  _shimmerController.forward();
                }
              });
            });
          }
        });
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 1),
        );
        _iconAnimation = Tween<double>(begin: 1.0, end: 1.0).animate(_iconAnimationController);
        break;

      case IconAnimationType.heartbeat:
        _shimmerController = AnimationController(vsync: this, duration: Duration.zero);
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..repeat(reverse: true);
        _iconAnimation = Tween<double>(
          begin: 1.0,
          end: 1.15,
        ).animate(CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeInOutSine));
        break;

      case IconAnimationType.rotate:
        _shimmerController = AnimationController(vsync: this, duration: Duration.zero);
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 10),
        )..repeat();
        _iconAnimation = Tween<double>(
          begin: 0,
          end: 2 * math.pi,
        ).animate(_iconAnimationController);
        break;

      case IconAnimationType.drawUp:
        _shimmerController = AnimationController(vsync: this, duration: Duration.zero);
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        );
        _iconAnimation = Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeOutCubic));
        Future.delayed(Duration(milliseconds: 400 + widget.index * 100), () {
          if (mounted) _iconAnimationController.forward();
        });
        break;

      case IconAnimationType.pulse:
        _shimmerController = AnimationController(vsync: this, duration: Duration.zero);
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        )..repeat(reverse: true);
        _iconAnimation = Tween<double>(
          begin: 0.7,
          end: 1.0,
        ).animate(CurvedAnimation(parent: _iconAnimationController, curve: Curves.easeInOut));
        break;
    }
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: Container(
                height: 115,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        // Cristal puro - gradiente lineal sutil
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: _isPressed || _isHovered
                              ? [
                                  widget.accentColor.withOpacity(0.15),
                                  widget.accentColor.withOpacity(0.05),
                                ]
                              : [Colors.white.withOpacity(0.10), Colors.white.withOpacity(0.02)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      // CustomPaint para borde gradiente mágico
                      child: CustomPaint(
                        painter: _NeonGradientBorderPainter(
                          accentColor: widget.accentColor,
                          isHovered: _isHovered,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Icono con NEÓN y micro-glow
                              _buildAnimatedIcon(),

                              // Texto
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.subtitle,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(0.6),
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 11,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 300 + (widget.index * 100)),
          duration: const Duration(milliseconds: 500),
        )
        .slideY(
          begin: 0.2,
          end: 0,
          curve: Curves.easeOutCubic,
          delay: Duration(milliseconds: 300 + (widget.index * 100)),
        );
  }

  Widget _buildAnimatedIcon() {
    // Icono con color NEÓN pastel y micro-glow LED
    const double iconSize = 28;

    // Widget base del icono con glow
    Widget iconWidget = Container(
      decoration: BoxDecoration(
        boxShadow: [
          // Micro-glow LED detrás del icono
          BoxShadow(color: widget.accentColor.withOpacity(0.6), blurRadius: 12, spreadRadius: 1),
          BoxShadow(color: widget.accentColor.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
        ],
      ),
      child: Icon(widget.icon, color: widget.accentColor, size: iconSize),
    );

    switch (widget.animationType) {
      case IconAnimationType.shimmer:
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [widget.accentColor, Colors.white, widget.accentColor],
                    stops: [
                      (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                      _shimmerController.value,
                      (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: Icon(widget.icon, color: Colors.white, size: iconSize),
              ),
            );
          },
        );

      case IconAnimationType.heartbeat:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Transform.scale(scale: _iconAnimation.value, child: iconWidget);
          },
        );

      case IconAnimationType.rotate:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Transform.rotate(angle: _iconAnimation.value, child: iconWidget);
          },
        );

      case IconAnimationType.drawUp:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _iconAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - _iconAnimation.value)),
                child: iconWidget,
              ),
            );
          },
        );

      case IconAnimationType.pulse:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Opacity(opacity: 0.7 + (_iconAnimation.value * 0.3), child: iconWidget);
          },
        );
    }
  }
}

// ============================================================================
// NEON GRADIENT BORDER PAINTER - Borde mágico que se desvanece
// ============================================================================

class _NeonGradientBorderPainter extends CustomPainter {
  final Color accentColor;
  final bool isHovered;

  _NeonGradientBorderPainter({required this.accentColor, required this.isHovered});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));

    // Gradiente que va del color neón (esquina superior izquierda) a transparente,
    // usando SOLO el accentColor. Antes había paradas de blanco que hacían que
    // el borde inferior se viera «blancoso» sobre fondos claros.
    final gradient = SweepGradient(
      center: Alignment.topLeft,
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        accentColor.withOpacity(isHovered ? 0.9 : 0.65),
        accentColor.withOpacity(isHovered ? 0.55 : 0.35),
        accentColor.withOpacity(isHovered ? 0.30 : 0.18),
        accentColor.withOpacity(isHovered ? 0.22 : 0.12),
        accentColor.withOpacity(isHovered ? 0.30 : 0.18),
        accentColor.withOpacity(isHovered ? 0.45 : 0.28),
      ],
      stops: const [0.0, 0.12, 0.28, 0.5, 0.78, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHovered ? 1.2 : 0.8;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(_NeonGradientBorderPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor || oldDelegate.isHovered != isHovered;
  }
}

// Ya no necesitamos el CustomPainter - usamos borde simple

// ============================================================================
// QUICK GLANCE CHIP
// ============================================================================

class _QuickGlanceChip extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickGlanceChip({
    required this.emoji,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          FeedbackEngine.I.tap();
          onTap!();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.25), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
