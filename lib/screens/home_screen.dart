import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../data/bible_verses.dart';
import '../models/content_enums.dart';
import '../services/daily_verse_service.dart';
import '../services/victory_scoring_service.dart';
import '../services/feedback_engine.dart';
import '../services/widget_sync_service.dart';
import '../models/content_item.dart';
import '../models/plan.dart';
import '../services/personalization_engine.dart';
import '../services/content_repository.dart';
import '../services/plan_repository.dart';
import '../services/plan_progress_service.dart';
import '../widgets/plan_card.dart';
import '../widgets/victory_hero_card.dart';
import 'emergency_screen.dart';
import 'verses_screen.dart';
import 'prayers_screen.dart';
import 'plan_library_screen.dart';
import 'plan_detail_screen_v2.dart';
import 'progress_screen.dart';
import 'settings_screen.dart';
import 'journal_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';
import 'battle_partner/battle_partner_screen.dart';
import 'wall/wall_screen.dart';
import 'admin/admin_wall_screen.dart';
import 'bible/bible_home_screen.dart';
import '../services/favorites_service.dart';
import '../services/battle_partner_service.dart';
import '../repositories/profile_repository.dart';

// Enum para tipos de animación de iconos
enum IconAnimationType {
  shimmer,    // Versículos - destello
  heartbeat,  // Oraciones - latido
  rotate,     // Devocional - rotación
  drawUp,     // Progreso - dibujado
  pulse,      // Diario - pulso suave
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? onThemeChanged;
  
  const HomeScreen({super.key, this.onThemeChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late BibleVerse dailyVerse;
  late AnimationController _breatheController;
  late AnimationController _glowController;
  
  // Personalización
  ForYouTodayBundle? _forYouBundle;
  bool _contentLoading = true;
  
  // Planes recomendados
  List<Plan> _recommendedPlans = [];
  Map<String, PlanProgress> _planProgressMap = {};
  Plan? _activePlan;
  PlanProgress? _activeProgress;
  
  // Victoria del día
  int _currentStreak = 0;
  bool _loggedToday = false;
  bool _victoryLoading = true;

  @override
  void initState() {
    super.initState();
    // Versículo del día determinístico (no aleatorio)
    dailyVerse = DailyVerseService.I.getForTodaySync();
    
    // Breathing animation for SOS button (heartbeat effect)
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Glow animation for SOS button
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    // Cargar contenido personalizado
    _loadPersonalizedContent();
    
    // Cargar datos de victoria
    _loadVictoryData();
    
    // Escuchar cambios en VictoryScoringService (se actualiza cuando
    // DataBootstrapper/AccountSessionManager hidratan desde cloud)
    VictoryScoringService.I.currentStreakNotifier.addListener(_onScoringChanged);
    VictoryScoringService.I.loggedTodayNotifier.addListener(_onScoringChanged);
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
  }
  
  Future<void> _registerVictory() async {
    // Si ya tiene victoria completa hoy, navegar a progreso para ajustar
    if (_loggedToday && VictoryScoringService.I.isTodayVictory()) {
      _navigateToProgress();
      return;
    }
    
    // Feedback táctil y sonoro
    FeedbackEngine.I.confirm();
    
    // Registrar victoria en todos los gigantes
    await VictoryScoringService.I.logVictoryForToday();
    
    if (mounted) {
      setState(() {
        _currentStreak = VictoryScoringService.I.getCurrentStreak();
        _loggedToday = true;
      });
      
      // Sincronizar widget de inicio con nuevo streak
      WidgetSyncService.I.syncWidget();
      
      // Mostrar snackbar de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emoji_events, color: Color(0xFFD4AF37)),
              const SizedBox(width: 12),
              Text(
                '¡Victoria registrada! Racha: $_currentStreak días',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
  
  void _navigateToProgress() {
    // Feedback táctil suave para navegación
    FeedbackEngine.I.tap();
    
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProgressScreen()),
    ).then((_) {
      // Recargar datos de victoria al volver (por si editó días)
      _refreshVictoryData();
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
      
      // Cargar planes
      final planRepo = PlanRepository();
      await planRepo.init();
      
      final progressService = PlanProgressService();
      await progressService.init();
      
      // Obtener plan activo
      final activePlanId = progressService.activePlanId;
      Plan? activePlan;
      PlanProgress? activeProgress;
      
      if (activePlanId != null) {
        activePlan = planRepo.getPlan(activePlanId);
        activeProgress = progressService.getProgress(activePlanId);
      }
      
      // Obtener planes recomendados (crisis + reinicio para empezar)
      final recommendedPlans = planRepo.plans
          .where((p) => p.isPublished)
          .take(6)
          .toList();
      
      // Mapear progreso
      final progressMap = <String, PlanProgress>{};
      for (final progress in progressService.allProgress) {
        progressMap[progress.planId] = progress;
      }
      
      if (mounted) {
        setState(() {
          _forYouBundle = PersonalizationEngine.I.getForYouToday();
          _recommendedPlans = recommendedPlans;
          _planProgressMap = progressMap;
          _activePlan = activePlan;
          _activeProgress = activeProgress;
          _contentLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _contentLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    VictoryScoringService.I.currentStreakNotifier.removeListener(_onScoringChanged);
    VictoryScoringService.I.loggedTodayNotifier.removeListener(_onScoringChanged);
    _breatheController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // CAPA 1: Imagen de fondo épica
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1519681393784-d120267933ba?w=1920&q=80',
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: const Color(0xFF0D1B2A),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1B2838),
                        Color(0xFF0D1B2A),
                        Color(0xFF051015),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // CAPA 2: Overlay gradiente oscuro (de abajo hacia arriba)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    Color(0xCC000000), // 80%
                    Color(0x80000000), // 50%
                    Color(0x40000000), // 25%
                    Colors.transparent,
                  ],
                  stops: [0.0, 0.2, 0.4, 0.6, 1.0],
                ),
              ),
            ),
          ),
          
          // CAPA 3: Contenido principal
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                    child: _buildHeader(context),
                  ),
                ),
                
                // ═══════════════════════════════════════════════════════════════
                // HERO: VICTORIAS (Primer elemento de impacto)
                // ═══════════════════════════════════════════════════════════════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignSystem.spacingM,
                      AppDesignSystem.spacingM,
                      AppDesignSystem.spacingM,
                      0,
                    ),
                    child: VictoryHeroCard(
                      streakDays: _currentStreak,
                      loggedToday: _loggedToday,
                      isLoading: _victoryLoading,
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
                    child: _buildDailyVerseSection(),
                  ),
                ),
                
                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN: PARA TI HOY (Personalizada)
                // ═══════════════════════════════════════════════════════════════
                if (!_contentLoading && _forYouBundle != null && _forYouBundle!.primaryGiant != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDesignSystem.spacingM,
                        AppDesignSystem.spacingL,
                        AppDesignSystem.spacingM,
                        0,
                      ),
                      child: _buildForYouTodaySection(),
                    ),
                  ),
                
                // Tools Section Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppDesignSystem.spacingM,
                      AppDesignSystem.spacingL,
                      AppDesignSystem.spacingM,
                      AppDesignSystem.spacingM,
                    ),
                    child: _buildSectionHeader(),
                  ),
                ),
                
                // Tools Grid - Diseño compacto tipo lista de tarjetas
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spacingM,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Primera fila
                      Row(
                        children: [
                          Expanded(
                            child: _GlassmorphicMenuButton(
                              icon: Icons.menu_book_outlined,
                              title: 'Versículos',
                              subtitle: 'Armadura espiritual',
                              accentColor: const Color(0xFF64B5F6), // Cyan brillante
                              animationType: IconAnimationType.shimmer,
                              index: 0,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const VersesScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDesignSystem.spacingM),
                          Expanded(
                            child: _GlassmorphicMenuButton(
                              icon: Icons.favorite,
                              title: 'Oraciones',
                              subtitle: 'Conexión con Dios',
                              accentColor: const Color(0xFFFF80AB), // Rosa neón suave
                              animationType: IconAnimationType.heartbeat,
                              index: 1,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PrayersScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesignSystem.spacingM),
                      // Segunda fila
                      Row(
                        children: [
                          Expanded(
                            child: _GlassmorphicMenuButton(
                              icon: Icons.wb_sunny,
                              title: 'Planes',
                              subtitle: 'Crecimiento espiritual',
                              accentColor: const Color(0xFFFFD740), // Ámbar/Dorado
                              animationType: IconAnimationType.rotate,
                              index: 2,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const PlanLibraryScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDesignSystem.spacingM),
                          Expanded(
                            child: _GlassmorphicMenuButton(
                              icon: Icons.show_chart,
                              title: 'Mi Progreso',
                              subtitle: 'Días de victoria',
                              accentColor: const Color(0xFF69F0AE), // Verde menta eléctrico
                              animationType: IconAnimationType.drawUp,
                              index: 3,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const ProgressScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesignSystem.spacingM),
                      // Tercera fila - Mi Diario + Widget
                      Row(
                        children: [
                          Expanded(
                            child: _GlassmorphicMenuButton(
                              icon: Icons.auto_stories,
                              title: 'Mi Diario',
                              subtitle: 'Reflexiones',
                              accentColor: const Color(0xFFCE93D8), // Lavanda neón
                              animationType: IconAnimationType.pulse,
                              index: 4,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const JournalScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDesignSystem.spacingM),
                          Expanded(
                            child: _GlassmorphicMenuButton(
                              icon: Icons.widgets_outlined,
                              title: 'Widget',
                              subtitle: 'Pantalla inicio',
                              accentColor: const Color(0xFF81D4FA), // Azul claro
                              animationType: IconAnimationType.pulse,
                              index: 5,
                              onTap: () => Navigator.pushNamed(context, '/widget-settings'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesignSystem.spacingM),
                      // Cuarta fila - Compañero de Batalla
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
                                      index: 6,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const BattlePartnerScreen()),
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
                              index: 7,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const WallScreen()),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDesignSystem.spacingM),
                      // Quinta fila - La Biblia
                      Row(
                        children: [
                          Expanded(
                            child: _GlassmorphicMenuButton(
                              icon: Icons.menu_book,
                              title: 'La Biblia',
                              subtitle: 'Palabra de Dios',
                              accentColor: const Color(0xFFE8C97A), // Gold Light
                              animationType: IconAnimationType.shimmer,
                              index: 8,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const BibleHomeScreen()),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppDesignSystem.spacingM),
                          const Expanded(child: SizedBox()),
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
                
                // ═══════════════════════════════════════════════════════════════
                // SECCIÓN DE PLANES
                // ═══════════════════════════════════════════════════════════════
                if (_recommendedPlans.isNotEmpty || _activePlan != null)
                  SliverToBoxAdapter(child: _buildPlansSection(context)),
                
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
            child: Center(
              child: _buildBreathingSosButton(context),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN DE PLANES RECOMENDADOS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPlansSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingL),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.gold.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: AppDesignSystem.gold,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PLANES PARA TI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PlanLibraryScreen()),
                ),
                child: Row(
                  children: [
                    Text(
                      'Ver todos',
                      style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppDesignSystem.gold),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Plan activo destacado
        if (_activePlan != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingL),
            child: _buildActivePlanCard(context),
          ),

        if (_activePlan != null) const SizedBox(height: 16),

        // Carousel de planes recomendados
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingL),
            itemCount: _recommendedPlans.length,
            itemBuilder: (context, index) {
              final plan = _recommendedPlans[index];
              final progress = _planProgressMap[plan.id];
              
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _recommendedPlans.length - 1 ? 12 : 0,
                ),
                child: PlanCard.poster(
                  plan: plan,
                  progress: progress,
                  width: 145,
                  height: 215,
                  onTap: () => _openPlanDetail(plan),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivePlanCard(BuildContext context) {
    final plan = _activePlan!;
    final progress = _activeProgress;
    final progressPercent = progress?.progressPercentage(plan.durationDays) ?? 0.0;
    final currentDay = progress?.currentDay ?? 0;

    return GestureDetector(
      onTap: () => _openPlanDetail(plan),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppDesignSystem.gold.withOpacity(0.2),
              AppDesignSystem.gold.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            // Progress ring
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progressPercent,
                    strokeWidth: 4,
                    backgroundColor: AppDesignSystem.midnight.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${currentDay + 1}',
                        style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.gold).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'de ${plan.durationDays}',
                        style: TextStyle(
                          fontSize: 9,
                          color: AppDesignSystem.coolGray.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Continúa tu plan',
                    style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    plan.title,
                    style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.pureWhite).copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Día ${currentDay + 1}: ${plan.days.length > currentDay ? plan.days[currentDay].title : ""}',
                    style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Arrow
            const Icon(
              Icons.play_circle_fill,
              color: AppDesignSystem.gold,
              size: 32,
            ),
          ],
        ),
      ),
    );
  }

  void _openPlanDetail(Plan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanDetailScreenV2(plan: plan),
      ),
    ).then((_) => _loadPersonalizedContent()); // Refresh on return
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingS),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: const Icon(
            Icons.shield_outlined,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: AppDesignSystem.spacingS),
        const Text(
          'HERRAMIENTAS DE VICTORIA',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 300.ms, duration: 400.ms)
        .slideX(begin: -0.1, end: 0);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SECCIÓN: PARA TI HOY - Contenido personalizado
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildForYouTodaySection() {
    final bundle = _forYouBundle!;
    final primary = bundle.primaryGiant!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con gigante primario
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingS),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                primary.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PARA TI HOY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  Text(
                    'Enfoque: ${primary.displayName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
        
        const SizedBox(height: AppDesignSystem.spacingM),
        
        // Versículo ancla del día
        if (bundle.anchorVerse != null)
          _buildAnchorVerseCard(bundle.anchorVerse!),
        
        const SizedBox(height: AppDesignSystem.spacingS),
        
        // Quick actions row
        Row(
          children: [
            // Versículos recomendados
            Expanded(
              child: _buildQuickActionChip(
                emoji: '📖',
                label: '${bundle.battleVerses.length} Versículos',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VersesScreen()),
                ),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            // Oraciones recomendadas
            Expanded(
              child: _buildQuickActionChip(
                emoji: '🙏',
                label: '${bundle.prayers.length} Oraciones',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrayersScreen()),
                ),
              ),
            ),
          ],
        ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
      ],
    );
  }
  
  Widget _buildAnchorVerseCard(ScoredItem<VerseItem> scoredVerse) {
    final verse = scoredVerse.item;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VersesScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.anchor,
                  color: Color(0xFFD4AF37),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Versículo ancla',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: const Color(0xFFD4AF37).withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              '"${verse.title}"',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              verse.reference,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 6),
            // Razón de recomendación
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                scoredVerse.reason,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildQuickActionChip({
    required String emoji,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    User? user;
    try {
      user = FirebaseAuth.instance.currentUser;
    } catch (e) {
      user = null;
    }
    final isLoggedIn = user != null;
    
    return Row(
      children: [
        // Avatar con borde cristal
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isLoggedIn) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(
                    // NO pasar onLogout con navegación manual.
                    // ProfileScreen.handleLogout hace signOut + popUntil(isFirst)
                    // y el StreamBuilder en main.dart maneja la transición a Login.
                  ),
                ),
              );
            } else {
              // Si no está logueado, volver a la raíz para que
              // el StreamBuilder muestre LoginScreen
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
              child: Icon(
                isLoggedIn ? Icons.person : Icons.shield_outlined,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
        
        const SizedBox(width: AppDesignSystem.spacingM),
        
        // Welcome text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLoggedIn ? '¡Bienvenido!' : 'Victoria en Cristo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isLoggedIn 
                    ? (user.displayName?.split(' ').first ?? 'Guerrero')
                    : 'Tu camino a la libertad',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          )
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideX(begin: 0.1, end: 0),
        ),
        
        // Favorites button
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const FavoritesScreen(),
              ),
            );
          },
          icon: Stack(
            children: [
              Icon(
                Icons.bookmark_rounded,
                color: Colors.white.withOpacity(0.7),
              ),
              if (FavoritesService().count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFD4A853),
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${FavoritesService().count}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        // Settings button
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  onThemeChanged: () {
                    widget.onThemeChanged?.call();
                    setState(() {});
                  },
                ),
              ),
            );
          },
          icon: Icon(
            Icons.tune_rounded,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // Breathing SOS Button - RED GLASS INFERNO STYLE
  // Looks like a burning ember or power gem floating over the mountain
  Widget _buildBreathingSosButton(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breatheController, _glowController]),
      builder: (context, child) {
        final breatheCurve = Curves.easeInOutSine.transform(_breatheController.value);
        final glowCurve = Curves.easeInOut.transform(_glowController.value);
        
        final scale = 1.0 + (breatheCurve * 0.05);
        final glowOpacity = 0.5 + (glowCurve * 0.3);
        
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              // Neon glow shadow - more diffuse for light emission effect
              boxShadow: [
                // Primary outer glow - large and diffuse
                BoxShadow(
                  color: Colors.redAccent.withOpacity(glowOpacity * 0.6),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
                // Secondary inner glow - warm orange tint
                BoxShadow(
                  color: Colors.deepOrange.withOpacity(glowOpacity * 0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
                // Core intense glow
                BoxShadow(
                  color: const Color(0xFFFF5722).withOpacity(glowOpacity * 0.3),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.heavyImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmergencyScreen()),
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppDesignSystem.spacingM,
              horizontal: AppDesignSystem.spacingXL,
            ),
            decoration: BoxDecoration(
              // Crystal glass texture - vertical gradient for depth
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.redAccent.withOpacity(0.95),
                  Colors.deepOrange.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              // Highlight border for glass effect
              border: Border.all(
                color: Colors.white.withOpacity(0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                // Pure white icon for maximum contrast
                Icon(
                  Icons.emergency_outlined,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: AppDesignSystem.spacingS),
                // Pure white text
                Text(
                  '¡NECESITO AYUDA!',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: 500.ms, duration: 600.ms)
        .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack);
  }

  Widget _buildDailyVerseSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header - SIN botón de refresh (versículo fijo del día)
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingS),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: const Icon(
                Icons.auto_stories_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            Text(
              'VERSÍCULO DEL DÍA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: AppDesignSystem.spacingM),
        
        // Scripture Card - CRISTAL
        _buildScriptureCard(),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }

  Widget _buildScriptureCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.white.withOpacity(0.12),
                Colors.white.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 0.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quote icon
              Icon(
                Icons.format_quote_rounded,
                size: 32,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(height: AppDesignSystem.spacingM),
              
              // Verse text
              Text(
                dailyVerse.verse,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                  height: 1.6,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingM),
              
              // Reference
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: AppDesignSystem.spacingS),
                  Text(
                    dailyVerse.reference,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        _iconAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
          CurvedAnimation(
            parent: _iconAnimationController,
            curve: Curves.easeInOutSine,
          ),
        );
        break;
        
      case IconAnimationType.rotate:
        _shimmerController = AnimationController(vsync: this, duration: Duration.zero);
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 10),
        )..repeat();
        _iconAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(_iconAnimationController);
        break;
        
      case IconAnimationType.drawUp:
        _shimmerController = AnimationController(vsync: this, duration: Duration.zero);
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        );
        _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _iconAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
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
        _iconAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(
            parent: _iconAnimationController,
            curve: Curves.easeInOut,
          ),
        );
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
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
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
                          : [
                              Colors.white.withOpacity(0.10),
                              Colors.white.withOpacity(0.02),
                            ],
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
      child: Icon(
        widget.icon,
        color: widget.accentColor,
        size: iconSize,
      ),
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
                    colors: [
                      widget.accentColor,
                      Colors.white,
                      widget.accentColor,
                    ],
                    stops: [
                      (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                      _shimmerController.value,
                      (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: Icon(
                  widget.icon,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
            );
          },
        );

      case IconAnimationType.heartbeat:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _iconAnimation.value,
              child: iconWidget,
            );
          },
        );

      case IconAnimationType.rotate:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _iconAnimation.value,
              child: iconWidget,
            );
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
            return Opacity(
              opacity: 0.7 + (_iconAnimation.value * 0.3),
              child: iconWidget,
            );
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

  _NeonGradientBorderPainter({
    required this.accentColor,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    
    // Gradiente que va del color neón (esquina superior izquierda) a transparente
    final gradient = SweepGradient(
      center: Alignment.topLeft,
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        accentColor.withOpacity(isHovered ? 0.9 : 0.6),
        accentColor.withOpacity(isHovered ? 0.5 : 0.3),
        Colors.white.withOpacity(0.1),
        Colors.white.withOpacity(0.05),
        Colors.white.withOpacity(0.1),
        accentColor.withOpacity(isHovered ? 0.4 : 0.2),
      ],
      stops: const [0.0, 0.12, 0.25, 0.5, 0.85, 1.0],
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
