import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/content_repository.dart';
import '../services/exercise_log_service.dart';
import '../models/content_item.dart';
import '../models/content_enums.dart';
import '../widgets/premium_components.dart';
import '../widgets/exercises/breathing_guide.dart';
import '../widgets/exercises/crisis_exercises_sheet.dart';
import '../widgets/exercises/post_exercise_reflection.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EXERCISES SCREEN - Galería de Ejercicios Prácticos
// Ejercicios de respiración, mindfulness y técnicas cognitivas
// ═══════════════════════════════════════════════════════════════════════════

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  void _openExercise(BuildContext context, ExerciseItem ex, Color color) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exercise: ex,
          accentColor: color,
        ),
      ),
    );
  }

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
    final recommendedIds = recommended.map((e) => e.item.id).toSet();

    // Todos los ejercicios agrupados por etapa, excluyendo los ya mostrados
    // en la sección "Para Ti" para evitar duplicación visual.
    final allExercises = repo.exercises;
    final crisisExercises = allExercises
        .where((e) =>
            e.metadata.stage == ContentStage.crisis &&
            !recommendedIds.contains(e.id))
        .toList();
    final habitExercises = allExercises
        .where((e) =>
            e.metadata.stage == ContentStage.habit &&
            !recommendedIds.contains(e.id))
        .toList();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        title: const Text('Ejercicios'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBuilder(
        animation: ExerciseLogService.I,
        builder: (context, _) {
          final log = ExerciseLogService.I;
          final doneToday = log.todayCompletedIds();

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, MediaQuery.of(context).padding.bottom + 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descripción
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Técnicas prácticas para resistir la tentación y fortalecer tu mente.',
                    style: TextStyle(
                      color: t.textSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),

                // ─────────────────────────────────────────────────────────
                // CTA: ACCESO RÁPIDO A CRISIS (1 tap desde cualquier punto)
                // ─────────────────────────────────────────────────────────
                _CrisisQuickCta(
                  onTap: () {
                    FeedbackEngine.I.tap();
                    CrisisExercisesSheet.show(
                      context,
                      onTapExercise: (ex) =>
                          _openExercise(context, ex, AppDesignSystem.struggle),
                    );
                  },
                ),
                const SizedBox(height: 22),

                // Contador de ejercicios completados (self-efficacy)
                if (log.totalCount > 0) ...[
                  _CompletionsBanner(total: log.totalCount),
                  const SizedBox(height: 18),
                ],

                // ═════════════════════════════════════════════════════════
                // SECCIÓN PERSONALIZADA
                // ═════════════════════════════════════════════════════════
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
                        doneToday: doneToday.contains(entry.value.item.id),
                      )),
                  const SizedBox(height: 28),
                ],

                // ═════════════════════════════════════════════════════════
                // SECCIÓN CRISIS
                // ═════════════════════════════════════════════════════════
                if (crisisExercises.isNotEmpty) ...[
                  const _SectionTitle(
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
                        doneToday: doneToday.contains(entry.value.id),
                      )),
                  const SizedBox(height: 28),
                ],

                // ═════════════════════════════════════════════════════════
                // SECCIÓN HÁBITO
                // ═════════════════════════════════════════════════════════
                if (habitExercises.isNotEmpty) ...[
                  const _SectionTitle(
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
                        doneToday: doneToday.contains(entry.value.id),
                      )),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CRISIS QUICK CTA — 1-tap shortcut a ejercicios de crisis
// ═══════════════════════════════════════════════════════════════════════════

class _CrisisQuickCta extends StatelessWidget {
  final VoidCallback onTap;
  const _CrisisQuickCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppDesignSystem.struggle.withOpacity(0.18),
                AppDesignSystem.struggle.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border: Border.all(
              color: AppDesignSystem.struggle.withOpacity(0.4),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppDesignSystem.struggle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_moon,
                    color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Necesito ayuda ahora',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Acceso directo a 3 ejercicios de crisis',
                      style: TextStyle(
                        color: t.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward,
                  color: AppDesignSystem.struggle, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPLETIONS BANNER — Self-efficacy ("has completado N ejercicios")
// ═══════════════════════════════════════════════════════════════════════════

class _CompletionsBanner extends StatelessWidget {
  final int total;
  const _CompletionsBanner({required this.total});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppDesignSystem.victory.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppDesignSystem.victory.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center,
              color: AppDesignSystem.victory, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: t.textPrimary,
                  fontSize: 13,
                  height: 1.3,
                ),
                children: [
                  const TextSpan(text: 'Has completado '),
                  TextSpan(
                    text: '$total ${total == 1 ? "ejercicio" : "ejercicios"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppDesignSystem.victory,
                    ),
                  ),
                  const TextSpan(text: ' — tu mente se está fortaleciendo.'),
                ],
              ),
            ),
          ),
        ],
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
  final bool doneToday;

  const _ExerciseCard({
    required this.exercise,
    this.reason,
    required this.index,
    required this.accentColor,
    this.doneToday = false,
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
                  color: doneToday
                      ? AppDesignSystem.victory.withOpacity(0.5)
                      : reason != null
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
                        Row(
                          children: [
                            if (reason != null)
                              Flexible(
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 4, right: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: accentColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    reason!,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: accentColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            if (doneToday)
                              Container(
                                margin: const EdgeInsets.only(bottom: 4),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.victory.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        size: 12,
                                        color: AppDesignSystem.victory),
                                    SizedBox(width: 3),
                                    Text(
                                      'Hecho hoy',
                                      style: TextStyle(
                                        color: AppDesignSystem.victory,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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
  int _totalTimerSeconds = 0;
  late final ValueNotifier<int> _timerSecondsVN;
  Timer? _timer;
  late final AnimationController _pulseController;
  late final PageController _pageController;
  final DateTime _startedAt = DateTime.now();
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _timerSecondsVN = ValueNotifier<int>(0);
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
    _timerSecondsVN.dispose();
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
        // Defensa ante dispose: si el widget se desmontó, cancelamos.
        if (!mounted) {
          timer.cancel();
          return;
        }
        final next = _timerSecondsVN.value + 1;
        _timerSecondsVN.value = next;
        if (next >= _totalTimerSeconds) {
          timer.cancel();
          _pulseController.stop();
          setState(() => _timerRunning = false);
          FeedbackEngine.I.confirm();
        }
      });
    }
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseController.stop();
    _timerSecondsVN.value = 0;
    setState(() => _timerRunning = false);
  }

  /// Flujo de finalización: pide reflexión opcional, registra log, sale.
  Future<void> _completeExercise() async {
    if (_completed) return; // evita doble-tap
    _completed = true;
    FeedbackEngine.I.confirm();

    // Detener timer si seguía corriendo
    _timer?.cancel();
    _pulseController.stop();

    // Pedir reflexión post-ejercicio (opcional, no bloqueante en lo emocional)
    final moodAfter = await PostExerciseReflectionSheet.show(
      context,
      accentColor: widget.accentColor,
    );

    if (!mounted) return;

    // Calcular duración real (mejor señal que el timer in-app)
    final realDurationSeconds =
        DateTime.now().difference(_startedAt).inSeconds;

    // Registrar la compleción (offline-first + Firestore best-effort)
    await ExerciseLogService.I.log(
      exerciseId: widget.exercise.id,
      durationSeconds: realDurationSeconds,
      moodAfter: moodAfter,
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  /// La guía de respiración aparece en el último paso del ejercicio,
  /// que es donde se invita al usuario a poner en práctica el ciclo.
  bool _shouldShowBreathingGuideAt(int stepIndex) {
    final phases = widget.exercise.phases;
    if (phases == null || phases.isEmpty) return false;
    return stepIndex == widget.exercise.steps.length - 1;
  }

  bool _shouldShowScriptureAt(int stepIndex) {
    if (widget.exercise.scriptureAnchor == null) return false;
    return stepIndex == widget.exercise.steps.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final steps = widget.exercise.steps;
    final color = widget.accentColor;
    final progress = steps.isEmpty
        ? 0.0
        : (_currentStep + 1) / steps.length;

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

                            // Breathing guide: solo en el último paso, si el
                            // ejercicio tiene fases declaradas. Anima un
                            // círculo según inhala/mantén/exhala.
                            if (_shouldShowBreathingGuideAt(index)) ...[
                              const SizedBox(height: 28),
                              BreathingGuide(
                                phases: widget.exercise.phases!,
                                color: color,
                                isRunning: _timerRunning,
                              ),
                            ],

                            // Scripture anchor: visible en el último paso.
                            if (_shouldShowScriptureAt(index)) ...[
                              const SizedBox(height: 24),
                              _ScriptureAnchorCard(
                                reference: widget.exercise.scriptureAnchor!,
                                color: color,
                              ),
                            ],
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
                _buildTimerSection(t, color),
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
                              onPressed: _completed ? null : _completeExercise,
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

  Widget _buildTimerSection(AppThemeData t, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          // Timer display (solo se reconstruye este Text cada segundo)
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
            child: ValueListenableBuilder<int>(
              valueListenable: _timerSecondsVN,
              builder: (context, seconds, _) => Text(
                _formatTime(seconds),
                style: TextStyle(
                  color: _timerRunning ? color : t.textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Manrope',
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
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

          // Botón reiniciar (solo aparece cuando hay tiempo acumulado)
          ValueListenableBuilder<int>(
            valueListenable: _timerSecondsVN,
            builder: (context, seconds, _) {
              if (seconds == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  onPressed: _resetTimer,
                  icon: Icon(
                    Icons.replay,
                    color: t.textSecondary,
                    size: 22,
                  ),
                  tooltip: 'Reiniciar',
                ),
              );
            },
          ),
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

// ═══════════════════════════════════════════════════════════════════════════
// SCRIPTURE ANCHOR CARD — Versículo de cierre del ejercicio
// ═══════════════════════════════════════════════════════════════════════════

class _ScriptureAnchorCard extends StatelessWidget {
  final String reference;
  final Color color;

  const _ScriptureAnchorCard({
    required this.reference,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.menu_book, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                'Ancla en la Palabra',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reference,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: AppDesignSystem.durationMedium).slideY(
          begin: 0.1,
          duration: AppDesignSystem.durationMedium,
          curve: Curves.easeOutCubic,
        );
  }
}
