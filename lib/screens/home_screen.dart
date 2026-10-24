import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/home/atajos_inicio.dart';
import '../widgets/home/daily_verse_section.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/sos_button.dart';
import '../widgets/home/bible_reading_streak.dart';
import '../widgets/daily_checklist_card.dart';
import 'learning/learning_home_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../data/bible_verses.dart';
import '../services/daily_verse_service.dart';
import '../services/day_change_service.dart';
import '../services/daily_practice_service.dart';
import '../services/bible/bible_user_data_service.dart';
import '../models/bible/bible_version.dart';
import '../utils/time_utils.dart';
import '../services/victory_scoring_service.dart';
import '../services/feedback_engine.dart';
import '../services/content_repository.dart';
import '../widgets/jesus_streak_widget.dart';
import 'progress_screen.dart';
import 'journal_screen.dart';
import 'devotional_screen.dart';

import 'battle_partner/battle_partner_screen.dart';
import 'bible/bible_home_screen.dart';
import 'relapse_recovery_screen.dart';
import 'categories/vida_espiritual_screen.dart';
import 'categories/crecimiento_espiritual_screen.dart';
import 'categories/hermanos_en_cristo_screen.dart';
import '../widgets/home/glassmorphic_menu_button.dart' as gmb;
import '../utils/bible_navigation_helper.dart';
import '../services/battle_partner_service.dart';
import '../services/audio_engine.dart';
import '../widgets/morning_checkin_sheet.dart';
import '../widgets/offline_banner.dart';
import '../main.dart' show routeObserver;
import '../utils/daily_outcome_registration.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;

  const HomeScreen({super.key, this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin, RouteAware {
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

    // Cambio de día con la app abierta o al volver del fondo: refrescar
    // versículo, check-in y racha (lo demás escucha sus propios servicios).
    DayChangeService.I.hoy.addListener(_onDayChanged);
    // Si el usuario cambia de versión de la Biblia, el versículo del día se
    // muestra en la nueva versión.
    _versionBiblia = _notifierVersionBiblia();
    _versionBiblia?.addListener(_recargarVersiculo);

    // Cargar contenido personalizado
    _loadPersonalizedContent();

    // Cargar datos de victoria
    _loadVictoryData();

    // Escuchar cambios en VictoryScoringService (se actualiza cuando
    // DataBootstrapper/AccountSessionManager hidratan desde cloud)
    VictoryScoringService.I.currentStreakNotifier.addListener(
      _onScoringChanged,
    );
    VictoryScoringService.I.loggedTodayNotifier.addListener(_onScoringChanged);
    VictoryScoringService.I.relapseEventNotifier.addListener(_onRelapseEvent);

    // Si al entrar ya hay una recaída pendiente, mostrar tras el primer frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onRelapseEvent();
    });
  }

  bool _relapseScreenShown = false;
  ValueNotifier<BibleVersion>? _versionBiblia;

  /// Hora a partir de la cual, si cambia el día con Inicio a la vista, se
  /// ofrece el check-in matutino (no a medianoche con la app abierta).
  static const int _horaMinimaCheckin = 5;

  static ValueNotifier<BibleVersion>? _notifierVersionBiblia() {
    try {
      return BibleUserDataService.I.preferredVersionNotifier;
    } catch (_) {
      // Sin Firebase (pruebas): el versículo usa RVR1960.
      return null;
    }
  }

  /// Cambió el día local: todo lo «de hoy» de Inicio vuelve a calcularse.
  void _onDayChanged() {
    if (!mounted) return;
    _celebrationShownToday = false;
    DailyPracticeService.I.refresh();
    setState(() {
      dailyVerse = DailyVerseService.I.getForTodaySync();
      _currentStreak = VictoryScoringService.I.getCurrentStreak();
      _loggedToday = VictoryScoringService.I.hasDataForToday();
      _checkinDoneToday = false;
    });
    _recargarVersiculo();
    final enPantalla = ModalRoute.of(context)?.isCurrent ?? false;
    if (enPantalla && TimeUtils.now().hour >= _horaMinimaCheckin) {
      _showMorningCheckinIfNeeded();
    }
  }

  /// Vuelve a pedir el versículo del día en la versión activa.
  Future<void> _recargarVersiculo() async {
    try {
      final verse = await DailyVerseService.I.getForToday();
      if (mounted) setState(() => dailyVerse = verse);
    } catch (e) {
      debugPrint('⚠️ [HOME] Error recargando versículo: $e');
    }
  }

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

    Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProgressScreen()),
        )
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
    DayChangeService.I.hoy.removeListener(_onDayChanged);
    _versionBiblia?.removeListener(_recargarVersiculo);
    VictoryScoringService.I.currentStreakNotifier.removeListener(
      _onScoringChanged,
    );
    VictoryScoringService.I.loggedTodayNotifier.removeListener(
      _onScoringChanged,
    );
    VictoryScoringService.I.relapseEventNotifier.removeListener(
      _onRelapseEvent,
    );
    super.dispose();
  }

  // RouteAware: BGM solo suena en HomeScreen
  @override
  void didPush() => AudioEngine.I.unmuteForScreen();

  @override
  void didPopNext() {
    AudioEngine.I.unmuteForScreen();
  }

  @override
  void didPushNext() => AudioEngine.I.muteForScreen();

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    // Íconos de la barra de estado según el papel: oscuros sobre el claro,
    // claros sobre kraft y noche.
    final hojaClara = !t.oscuro;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: hojaClara ? Brightness.dark : Brightness.light,
        statusBarBrightness: hojaClara ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: t.pageBg,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // La portada es la propia hoja con textura (FondoPapel detrás).
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
                            BibleNavigationHelper.navigateToSpanishRef(
                              context,
                              ref,
                            ),
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
                          MaterialPageRoute(
                            builder: (_) => const BibleHomeScreen(),
                          ),
                        ),
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
                          MaterialPageRoute(
                            builder: (_) => const DevotionalScreen(),
                          ),
                        ),
                        onTapJournal: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const JournalScreen(),
                          ),
                        ),
                        onTapVictory: _registerVictory,
                        onTapStudy: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LearningHomeScreen(),
                          ),
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

                  // ATAJOS — accesos directos que elige el usuario
                  // (por defecto Biblia, Estudio bíblico y Apuntes)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingS,
                      ),
                      child: _buildSectionHeader(
                        label: 'ATAJOS',
                        animationDelayMs: 200,
                        trailing: const BotonEditarAtajos(),
                      ),
                    ),
                  ),
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.spacingM,
                    ),
                    sliver: SliverToBoxAdapter(child: AtajosInicio()),
                  ),

                  // Tools Section Header — MENÚ PRINCIPAL (3 botones simplificados)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingM,
                      ),
                      child: _buildSectionHeader(
                        label: 'EXPLORA',
                        animationDelayMs: 250,
                      ),
                    ),
                  ),

                  // 3 grandes botones principales: Vida Espiritual /
                  // Crecimiento Espiritual / Hermanos en Cristo.
                  // Cada uno abre un sub-hub con las herramientas de esa área.
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDesignSystem.spacingM,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        gmb.GlassmorphicMenuButton(
                          icon: Icons.wb_sunny_outlined,
                          title: 'Vida Espiritual',
                          subtitle: 'Oración, palabra y reflexión diaria',
                          index: 0,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const VidaEspiritualScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        gmb.GlassmorphicMenuButton(
                          icon: Icons.trending_up_rounded,
                          title: 'Crecimiento Espiritual',
                          subtitle: 'Biblia y escuela del Reino',
                          index: 1,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  const CrecimientoEspiritualScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        ValueListenableBuilder<List<dynamic>>(
                          valueListenable:
                              BattlePartnerService.I.pendingInvitesNotifier,
                          builder: (context, invites, _) {
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                gmb.GlassmorphicMenuButton(
                                  icon: Icons.groups_rounded,
                                  title: 'Hermanos en Cristo',
                                  subtitle:
                                      'Compañero, muro y comunidad de batalla',
                                  index: 2,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const HermanosEnCristoScreen(),
                                    ),
                                  ),
                                ),
                                if (invites.isNotEmpty)
                                  Positioned(
                                    top: -4,
                                    right: -4,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppDesignSystem.struggle,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        invites.length == 1
                                            ? '1 invitación'
                                            : '${invites.length} invitaciones',
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
                      ]),
                    ),
                  ),

                  // Bottom spacing for FAB + Safe Area
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 120,
                    ),
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
          label:
              '${partners.length} compañero${partners.length > 1 ? 's' : ''}',
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
    int animationDelayMs = 300,
    Widget? trailing,
  }) {
    final etiqueta = PopIn(
      retraso: Duration(milliseconds: animationDelayMs),
      child: EtiquetaSeccion(label),
    );
    // Aire abajo para la cinta de la primera tarjeta.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: trailing == null
          ? etiqueta
          : Row(children: [Expanded(child: etiqueta), trailing]),
    );
  }
}

// ============================================================================
// QUICK GLANCE CHIP
// ============================================================================

class _QuickGlanceChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickGlanceChip({
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ChipVec(
        texto: label,
        color: VecColores.mostaza,
        iconoWidget: const IconoVec('escudo'),
      ),
    );
  }
}
