import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme_data.dart';
import '../services/feedback_engine.dart';
import '../services/victory_scoring_service.dart';
import '../services/audio_engine.dart';
import '../services/journal_service.dart';
import '../services/plan_progress_service.dart';
import '../services/widget_sync_service.dart';
import '../widgets/monthly_victory_calendar.dart';
import '../widgets/journal_day_note_card.dart';
import '../widgets/victory_summary_header.dart';
import '../widgets/giant_day_editor.dart';
import '../services/badge_service.dart';
import '../widgets/badge_celebration.dart';
import '../widgets/badge_grid_section.dart';
import '../widgets/offline_banner.dart';
import 'journal_screen.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with TickerProviderStateMixin {
  int _currentStreak = 0;
  int _longestStreak = 0;
  int _totalVictories = 0;
  DateTime? _streakStartDate;
  bool _isLoading = true;
  bool _isLoggedToday = false; // Si hoy ya tiene victoria
  bool _isYesterdayLogged = false; // Si ayer ya tiene registro
  
  // Calendar state
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  Set<String> _victoryDaysISO = {};
  Set<String> _journalDaysISO = {};
  Set<String> _planDaysISO = {};
  JournalEntry? _selectedJournalEntry;
  bool _isLoadingJournal = false;
  final JournalService _journalService = JournalService();
  
  // Animation controllers
  late AnimationController _chartAnimationController;
  late AnimationController _odometerController;
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late ConfettiController _confettiController;
  
  // Progress history for chart (last 7 days)
  List<int> _weeklyProgress = [0, 0, 0, 0, 0, 0, 0];

  @override
  void initState() {
    super.initState();
    AudioEngine.I.muteForScreen();
    
    // Initialize calendar dates
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDate = now;
    
    // Chart line drawing animation
    _chartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Odometer spinning animation
    _odometerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    // Pulse animation for main counter
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    // Glow animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Confetti controller
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    
    _loadProgress();
    _loadCalendarData();
    
    // Inicializar BadgeService
    BadgeService.I.init();
    
    // Reactive sync: escuchar cambios del JournalService (add/edit/delete)
    _journalService.changeNotifier.addListener(_onJournalDataChanged);
  }

  @override
  void dispose() {
    _journalService.changeNotifier.removeListener(_onJournalDataChanged);
    _chartAnimationController.dispose();
    _odometerController.dispose();
    _pulseController.dispose();
    _glowController.dispose();
    _confettiController.dispose();
    super.dispose();
  }
  
  /// Callback reactivo: cuando JournalService cambia, refrescar la tarjeta
  void _onJournalDataChanged() {
    if (!mounted) return;
    _loadJournalForDate(_selectedDate);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CALENDAR DATA LOADING
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _loadCalendarData() async {
    try {
      await VictoryScoringService.I.init();
      await _journalService.initialize();
      await _loadVictoryDaysForMonth(_visibleMonth);
      await _loadJournalForDate(_selectedDate);
      
      // Cargar métricas correctas desde VictoryScoringService
      _refreshMetricsFromService();
    } catch (e) {
      // Ignore errors - calendar will show empty state
    }
  }
  
  /// Recarga las métricas desde VictoryScoringService (totalYear + bestAllTime)
  void _refreshMetricsFromService() {
    if (!mounted) return;
    
    final now = DateTime.now();
    final totalYear = VictoryScoringService.I.getTotalVictoriesForYear(now.year);
    final bestAllTime = VictoryScoringService.I.getBestStreakAllTime();
    final currentStreak = VictoryScoringService.I.getCurrentStreak();
    final isLoggedToday = VictoryScoringService.I.isLoggedToday();
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final isYesterdayLogged = VictoryScoringService.I.isDateLogged(yesterday);
    
    setState(() {
      _totalVictories = totalYear;
      _longestStreak = bestAllTime;
      _currentStreak = currentStreak;
      _isLoggedToday = isLoggedToday;
      _isYesterdayLogged = isYesterdayLogged;
    });
  }
  
  Future<void> _loadVictoryDaysForMonth(DateTime month) async {
    try {
      final days = VictoryScoringService.I.getVictoryDaysInMonth(month);
      // Overlay data: journal entries for this month
      final journalDays = <String>{};
      final planDays = <String>{};
      final lastDay = DateTime(month.year, month.month + 1, 0).day;
      for (int d = 1; d <= lastDay; d++) {
        final date = DateTime(month.year, month.month, d);
        final iso = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        if (_journalService.getEntriesForDate(date).isNotEmpty) journalDays.add(iso);
      }
      // Plan: use lastCompletedAt from each plan
      for (final pp in PlanProgressService.I.allProgress) {
        final lc = pp.lastCompletedAt;
        if (lc != null && lc.month == month.month && lc.year == month.year) {
          planDays.add('${lc.year}-${lc.month.toString().padLeft(2, '0')}-${lc.day.toString().padLeft(2, '0')}');
        }
      }
      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _victoryDaysISO = days;
          _journalDaysISO = journalDays;
          _planDaysISO = planDays;
          // Actualizar si hoy está registrado
          if (month.month == now.month && month.year == now.year) {
            _isLoggedToday = VictoryScoringService.I.isLoggedToday();
            _isYesterdayLogged = VictoryScoringService.I.isDateLogged(
              now.subtract(const Duration(days: 1)),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _victoryDaysISO = {};
        });
      }
    }
  }
  
  Future<void> _loadJournalForDate(DateTime date) async {
    if (mounted) {
      setState(() => _isLoadingJournal = true);
    }
    
    try {
      final entry = _journalService.getEntryForDate(date);
      if (mounted) {
        setState(() {
          _selectedJournalEntry = entry;
          _isLoadingJournal = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedJournalEntry = null;
          _isLoadingJournal = false;
        });
      }
    }
  }
  
  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _visibleMonth = newMonth;
      // Si el día seleccionado no está en el nuevo mes, seleccionar el día 1
      if (_selectedDate.month != newMonth.month || _selectedDate.year != newMonth.year) {
        final now = DateTime.now();
        // Si el nuevo mes es el mes actual, seleccionar hoy
        if (newMonth.month == now.month && newMonth.year == now.year) {
          _selectedDate = now;
        } else {
          _selectedDate = DateTime(newMonth.year, newMonth.month, 1);
        }
      }
    });
    _loadVictoryDaysForMonth(newMonth);
    _loadJournalForDate(_selectedDate);
  }
  
  void _onDaySelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _loadJournalForDate(date);
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // VICTORY EDITING - Actualización INMEDIATA del calendario
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Registra la victoria de HOY con actualización inmediata
  void _registerTodayVictory() async {
    final now = DateTime.now();
    
    // Ya está registrado, no hacer nada
    if (VictoryScoringService.I.isLoggedToday()) return;
    
    // Registrar victoria en todos los gigantes
    await VictoryScoringService.I.setDayAllGiants(now, 1);
    
    // Obtener métricas recalculadas
    final totalYear = VictoryScoringService.I.getTotalVictoriesForYear(now.year);
    final bestAllTime = VictoryScoringService.I.getBestStreakAllTime();
    final currentStreak = VictoryScoringService.I.getCurrentStreak();
    
    // Actualizar UI
    setState(() {
      _victoryDaysISO = VictoryScoringService.I.getVictoryDaysInMonth(_visibleMonth);
      _isLoggedToday = true;
      _currentStreak = currentStreak;
      _totalVictories = totalYear;
      _longestStreak = bestAllTime;
      _streakStartDate ??= now;
    });
    
    // Feedback háptico y sonido
    FeedbackEngine.I.confirm();
    
    // Guardar para compatibilidad legacy
    _saveProgress();
    
    // Animación de confetti
    _confettiController.play();
    _odometerController.reset();
    _odometerController.forward();
    
    // Sincronizar widget
    WidgetSyncService.I.syncWidget();
    
    // Verificar insignias
    _checkBadges();
  }
  
  /// Callback cuando cambia algo en el editor de gigantes
  void _onGiantEditorChanged() {
    final now = DateTime.now();
    
    // Refrescar métricas
    final totalYear = VictoryScoringService.I.getTotalVictoriesForYear(now.year);
    final bestAllTime = VictoryScoringService.I.getBestStreakAllTime();
    final currentStreak = VictoryScoringService.I.getCurrentStreak();
    
    setState(() {
      _victoryDaysISO = VictoryScoringService.I.getVictoryDaysInMonth(_visibleMonth);
      _totalVictories = totalYear;
      _longestStreak = bestAllTime;
      _currentStreak = currentStreak;
      
      // Actualizar flags de registro
      _isLoggedToday = VictoryScoringService.I.isLoggedToday();
      _isYesterdayLogged = VictoryScoringService.I.isDateLogged(
        now.subtract(const Duration(days: 1)),
      );
    });
    
    // Sincronizar widget
    WidgetSyncService.I.syncWidget();
    
    // Verificar insignias
    _checkBadges();
  }
  
  /// Verifica y celebra nuevas insignias desbloqueadas
  Future<void> _checkBadges() async {
    final newBadges = await BadgeService.I.checkForNewBadges();
    if (!mounted || newBadges.isEmpty) return;
    
    // Refrescar UI para actualizar la grilla de insignias
    setState(() {});
    
    // Mostrar celebración completa para el badge más alto
    BadgeCelebration.showFullCelebration(context, newBadges.last);
  }
  
  void _navigateToJournalEditor({bool isNew = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const JournalScreen(),
      ),
    ).then((_) {
      // Recargar datos al volver
      _loadJournalForDate(_selectedDate);
      _loadVictoryDaysForMonth(_visibleMonth);
    }).catchError((e) { debugPrint('⚠️ [PROGRESS] Nav journal error: $e'); });
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load weekly progress
    final weeklyData = prefs.getStringList('weeklyProgress') ?? [];
    if (weeklyData.length == 7) {
      _weeklyProgress = weeklyData.map((e) => int.tryParse(e) ?? 0).toList();
    }
    
    // Cargar métricas desde VictoryScoringService
    await VictoryScoringService.I.init();
    final now = DateTime.now();
    
    setState(() {
      // Usar VictoryScoringService para métricas correctas
      _currentStreak = VictoryScoringService.I.getCurrentStreak();
      _longestStreak = VictoryScoringService.I.getBestStreakAllTime();
      _totalVictories = VictoryScoringService.I.getTotalVictoriesForYear(now.year);
      _isLoggedToday = VictoryScoringService.I.isLoggedToday();
      _isYesterdayLogged = VictoryScoringService.I.isDateLogged(
        DateTime.now().subtract(const Duration(days: 1)),
      );
      
      final startDateStr = prefs.getString('streakStartDate');
      if (startDateStr != null) {
        _streakStartDate = DateTime.parse(startDateStr);
      }
      _isLoading = false;
    });
    
    // Start animations after loading
    Future.delayed(const Duration(milliseconds: 300), () {
      _chartAnimationController.forward();
      _odometerController.forward();
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('currentStreak', _currentStreak);
    await prefs.setInt('longestStreak', _longestStreak);
    await prefs.setInt('totalVictories', _totalVictories);
    await prefs.setStringList('weeklyProgress', _weeklyProgress.map((e) => e.toString()).toList());
    if (_streakStartDate != null) {
      await prefs.setString('streakStartDate', _streakStartDate!.toIso8601String());
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: t.scaffoldBg,
        body: Center(
          child: CircularProgressIndicator(
            color: t.accent,
            strokeWidth: 1.5,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      body: Stack(
        children: [
          // Golden confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: [
                t.accent,
                t.accent.withOpacity(0.8),
                t.accent.withOpacity(0.6),
                const Color(0xFFFFE4B5),
                const Color(0xFFFFF8DC),
              ],
              createParticlePath: (size) {
                final path = Path();
                path.addOval(Rect.fromCircle(center: Offset.zero, radius: size.width / 3));
                return path;
              },
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // ─── Banner de conectividad ───
                const OfflineBanner(),
                // ─── Header editorial (estilo Biblia) ───
                _buildEditorialHeader(),
                
                // ─── Contenido scrolleable ───
                Expanded(
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // 1. Victory Summary Header
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
                          child: VictorySummaryHeader(
                            currentStreak: _currentStreak,
                            longestStreak: _longestStreak,
                            totalVictories: _totalVictories,
                            isLoggedToday: _isLoggedToday,
                            canRegisterToday: DateTime.now().hour >= 18,
                            onRegisterVictory: _registerTodayVictory,
                          ),
                        ),
                      ),
                      
                      // 2. Calendario Mensual
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: MonthlyVictoryCalendar(
                            visibleMonth: _visibleMonth,
                            victoryDaysISO: _victoryDaysISO,
                            selectedDate: _selectedDate,
                            onSelectDay: _onDaySelected,
                            onMonthChanged: _onMonthChanged,
                            journalDaysISO: _journalDaysISO,
                            planDaysISO: _planDaysISO,
                          ),
                        ),
                      ),
                      
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 16),
                      ),
                      
                      // 3. Editor de Estado del Día
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: GiantDayEditor(
                            date: _selectedDate,
                            onChanged: _onGiantEditorChanged,
                          ),
                        ),
                      ),
                      
                      const SliverToBoxAdapter(
                        child: SizedBox(height: 16),
                      ),
                      
                      // 4. Nota del Diario
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: JournalDayNoteCard(
                            selectedDate: _selectedDate,
                            entry: _selectedJournalEntry,
                            isLoading: _isLoadingJournal,
                            onTapEdit: () => _navigateToJournalEditor(),
                            onTapCreate: () => _navigateToJournalEditor(isNew: true),
                          ),
                        ),
                      ),
                      
                      // 5. Insignias
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                          child: BadgeGridSection(),
                        ),
                      ),

                      // Bottom spacing
                      SliverToBoxAdapter(
                        child: SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  String _getHeaderSubtitle() {
    if (_isLoggedToday) {
      if (_currentStreak >= 30) return '🏆 Racha de $_currentStreak días';
      if (_currentStreak >= 7) return '🔥 $_currentStreak días seguidos';
      return '✅ Victoria registrada hoy';
    }
    if (_currentStreak > 0) return '⚔️ Llevas $_currentStreak día${_currentStreak > 1 ? "s" : ""}, ¡no pares!';
    return '💪 Hoy es un buen día para empezar';
  }

  Widget _buildEditorialHeader() {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.maybePop(context);
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: t.textPrimary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: t.textPrimary.withOpacity(0.8),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mi Progreso',
                      style: GoogleFonts.manrope(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: t.textPrimary,
                      ),
                    ),
                    Text(
                      _getHeaderSubtitle(),
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: t.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildContextBanner(),
        ],
      ),
    );
  }

  Widget _buildContextBanner() {
    final t = AppThemeData.of(context);
    final hour = DateTime.now().hour;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));

    // Caso 1: Ayer sin registrar (prioridad alta)
    if (!_isYesterdayLogged) {
      return _buildBannerTile(
        icon: '📝',
        text: '¿Cómo te fue ayer? Aún puedes registrarlo',
        color: t.accent,
        onTap: () {
          _onDaySelected(yesterday);
          // Si ayer no está en el mes visible, navegar al mes correcto
          if (yesterday.month != _visibleMonth.month ||
              yesterday.year != _visibleMonth.year) {
            _onMonthChanged(DateTime(yesterday.year, yesterday.month, 1));
          }
        },
      );
    }

    // Caso 2: Hoy sin registrar — mensaje según hora
    if (!_isLoggedToday) {
      String icon;
      String text;
      if (hour < 12) {
        icon = '🌅';
        text = 'Tu batalla de hoy comienza — ¡ánimo!';
      } else if (hour < 18) {
        icon = '⚔️';
        text = 'Sigue firme, vas por buen camino';
      } else {
        icon = '🌙';
        text = 'El día va terminando... ¡registra tu victoria!';
      }
      return _buildBannerTile(icon: icon, text: text);
    }

    // Caso 3: Todo registrado — no mostrar nada
    return const SizedBox.shrink();
  }

  Widget _buildBannerTile({
    required String icon,
    required String text,
    Color? color,
    VoidCallback? onTap,
  }) {
    final t = AppThemeData.of(context);
    final c = color ?? t.textPrimary;
    final tile = Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: c.withOpacity(0.12),
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.manrope(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: t.textSecondary.withOpacity(0.8),
              ),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: c.withOpacity(0.4),
            ),
        ],
      ),
    );

    return onTap != null
        ? GestureDetector(onTap: onTap, child: tile)
        : tile;
  }
}
