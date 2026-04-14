import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/content_repository.dart';
import '../models/content_item.dart';
import '../models/content_enums.dart';
import '../widgets/premium_components.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISES SCREEN - Galería de Ejercicios Prácticos
// Ejercicios de respiración, mindfulness y técnicas cognitivas
// ═══════════════════════════════════════════════════════════════════════════

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final engine = PersonalizationEngine.I;
    final repo = ContentRepository.I;

    // Ejercicios personalizados
    final recommended = repo.isInitialized
        ? engine.getRecommendedExercises(limit: 3)
        : <ScoredItem<ExerciseItem>>[];
    final hasPersonalization = recommended.isNotEmpty;
    final primaryGiant = engine.primaryGiant;

    // Todos los ejercicios agrupados por etapa
    final allExercises = repo.exercises;
    final crisisExercises =
        allExercises.where((e) => e.metadata.stage == ContentStage.crisis).toList();
    final habitExercises =
        allExercises.where((e) => e.metadata.stage == ContentStage.habit).toList();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: const Text('Ejercicios'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, MediaQuery.of(context).padding.bottom + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Descripción
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Text(
                'Técnicas prácticas para resistir la tentación y fortalecer tu mente.',
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ),

            // ═════════════════════════════════════════════════════════════
            // SECCIÓN PERSONALIZADA
            // ═════════════════════════════════════════════════════════════
            if (hasPersonalization) ...[
              _SectionTitle(
                emoji: '⭐',
                title: 'Para Ti',
                subtitle: primaryGiant != null
                    ? 'Enfoque: ${primaryGiant.displayName}'
                    : 'Recomendados para tu batalla',
                color: AppDesignSystem.gold,
              ),
              const SizedBox(height: 12),
              ...recommended.asMap().entries.map((entry) =>
                  _ExerciseCard(
                    exercise: entry.value.item,
                    reason: entry.value.reason,
                    index: entry.key,
                    accentColor: AppDesignSystem.gold,
                  )),
              const SizedBox(height: 28),
            ],

            // ═════════════════════════════════════════════════════════════
            // SECCIÓN CRISIS
            // ═════════════════════════════════════════════════════════════
            if (crisisExercises.isNotEmpty) ...[
              _SectionTitle(
                emoji: '🆘',
                title: 'Momento de Crisis',
                subtitle: 'Para cuando la tentación es fuerte',
                color: AppDesignSystem.struggle,
              ),
              const SizedBox(height: 12),
              ...crisisExercises.asMap().entries.map((entry) =>
                  _ExerciseCard(
                    exercise: entry.value,
                    index: entry.key,
                    accentColor: AppDesignSystem.struggle,
                  )),
              const SizedBox(height: 28),
            ],

            // ═════════════════════════════════════════════════════════════
            // SECCIÓN HÁBITO
            // ═════════════════════════════════════════════════════════════
            if (habitExercises.isNotEmpty) ...[
              _SectionTitle(
                emoji: '🔄',
                title: 'Formación de Hábito',
                subtitle: 'Fortalece tu mente cada día',
                color: AppDesignSystem.hope,
              ),
              const SizedBox(height: 12),
              ...habitExercises.asMap().entries.map((entry) =>
                  _ExerciseCard(
                    exercise: entry.value,
                    index: entry.key,
                    accentColor: AppDesignSystem.hope,
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION TITLE
// ═══════════════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionTitle({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 22)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: t.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISE CARD
// ═══════════════════════════════════════════════════════════════════════════

class _ExerciseCard extends StatelessWidget {
  final ExerciseItem exercise;
  final String? reason;
  final int index;
  final Color accentColor;

  const _ExerciseCard({
    required this.exercise,
    this.reason,
    required this.index,
    required this.accentColor,
  });

  IconData _iconForExercise(String id) {
    switch (id) {
      case 'e001': return Icons.air; // Respiración
      case 'e002': return Icons.touch_app; // Anclaje sensorial
      case 'e003': return Icons.waves; // Surfear antojo
      case 'e004': return Icons.timer; // Retraso 10 min
      case 'e005': return Icons.psychology; // Reencuadre cognitivo
      case 'e006': return Icons.record_voice_over; // Declaración identidad
      case 'e007': return Icons.list_alt; // Inventario gatillos
      case 'e008': return Icons.flag; // Micro-compromiso
      case 'e009': return Icons.home_work; // Diseño entorno
      case 'e010': return Icons.phone_in_talk; // Llamada rendición
      default: return Icons.fitness_center;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);

    return AnimatedListItem(
      index: index,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            onTap: () {
              FeedbackEngine.I.tap();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ExerciseDetailScreen(
                    exercise: exercise,
                    accentColor: accentColor,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                border: Border.all(
                  color: reason != null
                      ? accentColor.withOpacity(0.4)
                      : t.cardBorder,
                ),
                boxShadow: AppDesignSystem.shadowSoft,
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      _iconForExercise(exercise.id),
                      color: accentColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (reason != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              reason!,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        Text(
                          exercise.title,
                          style: TextStyle(
                            color: t.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (exercise.subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              exercise.subtitle!,
                              style: TextStyle(
                                color: t.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Duration badge + chevron
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${exercise.durationMinutes} min',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Icon(
                        Icons.chevron_right,
                        color: t.textSecondary.withOpacity(0.5),
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISE DETAIL SCREEN — Paso a paso con temporizador
// ═══════════════════════════════════════════════════════════════════════════

class ExerciseDetailScreen extends StatefulWidget {
  final ExerciseItem exercise;
  final Color accentColor;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
    required this.accentColor,
  });

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  bool _timerRunning = false;
  int _timerSeconds = 0;
  int _totalTimerSeconds = 0;
  Timer? _timer;
  late final AnimationController _pulseController;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _totalTimerSeconds = (widget.exercise.durationMinutes ?? 5) * 60;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < widget.exercise.steps.length - 1) {
      FeedbackEngine.I.tap();
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: AppDesignSystem.durationMedium,
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      FeedbackEngine.I.tap();
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: AppDesignSystem.durationMedium,
        curve: Curves.easeInOut,
      );
    }
  }

  void _toggleTimer() {
    FeedbackEngine.I.confirm();
    if (_timerRunning) {
      _timer?.cancel();
      _pulseController.stop();
      setState(() => _timerRunning = false);
    } else {
      _pulseController.repeat(reverse: true);
      setState(() => _timerRunning = true);
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        setState(() {
          _timerSeconds++;
          if (_timerSeconds >= _totalTimerSeconds) {
            _timer?.cancel();
            _timerRunning = false;
            _pulseController.stop();
            FeedbackEngine.I.confirm();
          }
        });
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _timerSeconds = 0;
      _timerRunning = false;
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final steps = widget.exercise.steps;
    final color = widget.accentColor;
    final progress = steps.isEmpty
        ? 0.0
        : (_currentStep + 1) / steps.length;
    final timerProgress = _totalTimerSeconds > 0
        ? _timerSeconds / _totalTimerSeconds
        : 0.0;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.exercise.title,
          style: TextStyle(color: t.textPrimary, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          // Progress bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            height: 4,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: t.surface,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),

          // Step counter
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Paso ${_currentStep + 1} de ${steps.length}',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.timer_outlined,
                          color: color, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '${widget.exercise.durationMinutes} min',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Step content (PageView)
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: steps.length,
              onPageChanged: (i) => setState(() => _currentStep = i),
              itemBuilder: (context, index) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Column(
                    children: [
                      // Step card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: t.cardBg,
                          borderRadius:
                              BorderRadius.circular(AppDesignSystem.radiusL),
                          border: Border.all(color: t.cardBorder),
                          boxShadow: AppDesignSystem.shadowSoft,
                        ),
                        child: Column(
                          children: [
                            // Step number badge
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Step text
                            Text(
                              steps[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: t.textPrimary,
                                fontSize: 17,
                                height: 1.6,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(
                            duration: AppDesignSystem.durationMedium,
                          ),
                    ],
                  ),
                );
              },
            ),
          ),

          // ═════════════════════════════════════════════════════════════
          // TIMER + NAVIGATION
          // ═════════════════════════════════════════════════════════════
          Container(
            padding: EdgeInsets.fromLTRB(
                24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
            decoration: BoxDecoration(
              color: t.surface,
              border: Border(
                top: BorderSide(color: t.cardBorder),
              ),
            ),
            child: Column(
              children: [
                // Timer section
                _buildTimerSection(t, color, timerProgress),
                const SizedBox(height: 16),

                // Navigation buttons
                Row(
                  children: [
                    // Previous
                    if (_currentStep > 0)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _prevStep,
                          icon: const Icon(Icons.arrow_back, size: 18),
                          label: const Text('Anterior'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: t.textSecondary,
                            side: BorderSide(color: t.cardBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    if (_currentStep > 0) const SizedBox(width: 12),

                    // Next / Complete
                    Expanded(
                      flex: _currentStep == 0 ? 1 : 1,
                      child: _currentStep < steps.length - 1
                          ? ElevatedButton.icon(
                              onPressed: _nextStep,
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('Siguiente'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: color,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            )
                          : ElevatedButton.icon(
                              onPressed: () {
                                FeedbackEngine.I.confirm();
                                Navigator.pop(context);
                              },
                              icon: const Icon(Icons.check_circle_outline,
                                  size: 20),
                              label: const Text('Completar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppDesignSystem.victory,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerSection(AppThemeData t, Color color, double timerProgress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          // Timer display
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final scale = _timerRunning
                  ? 1.0 + (_pulseController.value * 0.05)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Text(
              _formatTime(_timerSeconds),
              style: TextStyle(
                color: _timerRunning ? color : t.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                fontFamily: 'Manrope',
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '/ ${_formatTime(_totalTimerSeconds)}',
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 14,
            ),
          ),

          const Spacer(),

          // Timer controls
          if (_timerSeconds > 0)
            IconButton(
              onPressed: _resetTimer,
              icon: Icon(
                Icons.replay,
                color: t.textSecondary,
                size: 22,
              ),
              tooltip: 'Reiniciar',
            ),
          const SizedBox(width: 4),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: _timerRunning
                  ? color.withOpacity(0.15)
                  : color,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _toggleTimer,
                child: Icon(
                  _timerRunning ? Icons.pause : Icons.play_arrow,
                  color: _timerRunning ? color : Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
