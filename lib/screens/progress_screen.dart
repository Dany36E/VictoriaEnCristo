import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';
import '../services/feedback_engine.dart';
import '../services/victory_scoring_service.dart';
import '../services/journal_service.dart';
import '../services/widget_sync_service.dart';
import '../widgets/monthly_victory_calendar.dart';
import '../widgets/journal_day_note_card.dart';
import '../widgets/victory_summary_header.dart';
import '../widgets/giant_day_editor.dart';
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
  
  // Calendar state
  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  Set<String> _victoryDaysISO = {};
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
    
    setState(() {
      _totalVictories = totalYear;
      _longestStreak = bestAllTime;
      _currentStreak = currentStreak;
      _isLoggedToday = isLoggedToday;
    });
  }
  
  Future<void> _loadVictoryDaysForMonth(DateTime month) async {
    try {
      final days = VictoryScoringService.I.getVictoryDaysInMonth(month);
      if (mounted) {
        final now = DateTime.now();
        setState(() {
          _victoryDaysISO = days;
          // Actualizar si hoy está registrado
          if (month.month == now.month && month.year == now.year) {
            _isLoggedToday = VictoryScoringService.I.isLoggedToday();
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
      
      // Actualizar si hoy fue modificado
      if (_selectedDate.year == now.year && 
          _selectedDate.month == now.month && 
          _selectedDate.day == now.day) {
        _isLoggedToday = VictoryScoringService.I.hasDataForToday();
      }
    });
    
    // Sincronizar widget
    WidgetSyncService.I.syncWidget();
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
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppDesignSystem.midnight : AppDesignSystem.pureWhite,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppDesignSystem.gold,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppDesignSystem.midnight : AppDesignSystem.pureWhite,
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
              colors: const [
                AppDesignSystem.gold,
                AppDesignSystem.goldLight,
                AppDesignSystem.goldDark,
                Color(0xFFFFE4B5),
                Color(0xFFFFF8DC),
              ],
              createParticlePath: (size) {
                // Create ember-like particles
                final path = Path();
                path.addOval(Rect.fromCircle(center: Offset.zero, radius: size.width / 3));
                return path;
              },
            ),
          ),
          
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Premium App Bar
              SliverAppBar(
                expandedHeight: 80,
                pinned: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.pop(context);
                  },
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppDesignSystem.midnightLight : Colors.white).withOpacity(0.8),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppDesignSystem.gold.withOpacity(0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? AppDesignSystem.pureWhite : AppDesignSystem.midnight,
                      size: 20,
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: ShaderMask(
                    shaderCallback: (bounds) => AppDesignSystem.goldShimmer.createShader(bounds),
                    child: Text(
                      'Mi Progreso',
                      style: AppDesignSystem.headlineSmall(context, color: Colors.white),
                    ),
                  ),
                  centerTitle: true,
                ),
              ),
              
              // ═══════════════════════════════════════════════════════════════
              // NUEVO LAYOUT: Header + Calendario + Editor + Diario
              // ═══════════════════════════════════════════════════════════════
              
              // 1. Victory Summary Header (Contador + Registrar)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  child: VictorySummaryHeader(
                    currentStreak: _currentStreak,
                    longestStreak: _longestStreak,
                    totalVictories: _totalVictories,
                    isLoggedToday: _isLoggedToday,
                    onRegisterVictory: _registerTodayVictory,
                  ),
                ),
              ),
              
              // 2. Calendario Mensual (Light Theme)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM),
                  child: MonthlyVictoryCalendar(
                    visibleMonth: _visibleMonth,
                    victoryDaysISO: _victoryDaysISO,
                    selectedDate: _selectedDate,
                    onSelectDay: _onDaySelected,
                    onMonthChanged: _onMonthChanged,
                    useLightTheme: !isDark,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(
                child: SizedBox(height: AppDesignSystem.spacingM),
              ),
              
              // 3. Editor de Estado del Día (por gigante)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM),
                  child: GiantDayEditor(
                    date: _selectedDate,
                    onChanged: _onGiantEditorChanged,
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(
                child: SizedBox(height: AppDesignSystem.spacingM),
              ),
              
              // 4. Nota del Diario para el Día Seleccionado
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spacingM,
                  ),
                  child: JournalDayNoteCard(
                    selectedDate: _selectedDate,
                    entry: _selectedJournalEntry,
                    isLoading: _isLoadingJournal,
                    onTapEdit: () => _navigateToJournalEditor(),
                    onTapCreate: () => _navigateToJournalEditor(isNew: true),
                  ),
                ),
              ),
              
              // Bottom spacing with Safe Area
              SliverToBoxAdapter(
                child: SizedBox(height: MediaQuery.of(context).padding.bottom + 40),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
