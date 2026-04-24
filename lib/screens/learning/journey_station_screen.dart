/// ═══════════════════════════════════════════════════════════════════════════
/// JourneyStationScreen — una estación de la Travesía bíblica
///
/// Estructura en pasos (top bar con progreso):
///   1. Contexto narrativo
///   2. Versículo clave
///   3. Preguntas (auto-calificadas, una por pantalla)
///   4. Reflexión personal
///   5. Completado → otorga XP y marca la estación
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../models/learning/journey_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/journey_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class JourneyStationScreen extends StatefulWidget {
  final JourneyStation station;

  const JourneyStationScreen({super.key, required this.station});

  @override
  State<JourneyStationScreen> createState() => _JourneyStationScreenState();
}

enum _Step { context, verse, questions, reflection, done }

class _JourneyStationScreenState extends State<JourneyStationScreen> {
  _Step _step = _Step.context;
  int _questionIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _correctCount = 0;
  int _awardedXp = 0;

  JourneyStation get s => widget.station;

  double _progress() {
    final totalQuestions = s.questions.length;
    switch (_step) {
      case _Step.context:
        return 0.1;
      case _Step.verse:
        return 0.25;
      case _Step.questions:
        const base = 0.3;
        final per = (totalQuestions == 0) ? 0.5 : 0.5 / totalQuestions;
        final done = _answered ? _questionIndex + 1 : _questionIndex;
        return (base + per * done).clamp(0.0, 0.85);
      case _Step.reflection:
        return 0.92;
      case _Step.done:
        return 1.0;
    }
  }

  void _advance() async {
    FeedbackEngine.I.tap();
    switch (_step) {
      case _Step.context:
        setState(() => _step = _Step.verse);
        break;
      case _Step.verse:
        setState(() {
          _step = _Step.questions;
          _questionIndex = 0;
          _selectedOption = null;
          _answered = false;
        });
        break;
      case _Step.questions:
        if (!_answered) return;
        if (_questionIndex + 1 < s.questions.length) {
          setState(() {
            _questionIndex++;
            _selectedOption = null;
            _answered = false;
          });
        } else {
          setState(() => _step = _Step.reflection);
        }
        break;
      case _Step.reflection:
        final xp = await JourneyProgressService.I.markCompleted(s);
        if (!mounted) return;
        setState(() {
          _awardedXp = xp;
          _step = _Step.done;
        });
        break;
      case _Step.done:
        Navigator.pop(context, true);
        break;
    }
  }

  void _submitAnswer(int idx) {
    if (_answered) return;
    final q = s.questions[_questionIndex];
    final correct = idx == q.correctIndex;
    FeedbackEngine.I.tap();
    setState(() {
      _selectedOption = idx;
      _answered = true;
      if (correct) _correctCount++;
    });
  }

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
          s.title,
          style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: _progress(),
            minHeight: 4,
            backgroundColor: t.cardBorder,
            valueColor:
                const AlwaysStoppedAnimation(AppDesignSystem.gold),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          child: _buildStep(context, t),
        ),
      ),
    );
  }

  Widget _buildStep(BuildContext context, AppThemeData t) {
    switch (_step) {
      case _Step.context:
        return _buildContext(context, t);
      case _Step.verse:
        return _buildVerse(context, t);
      case _Step.questions:
        return _buildQuestion(context, t);
      case _Step.reflection:
        return _buildReflection(context, t);
      case _Step.done:
        return _buildDone(context, t);
    }
  }

  // ─────────────────────────── STEP 1: CONTEXT ───────────────────────────
  Widget _buildContext(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Contexto',
          style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold)
              .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Text(
          s.subtitle,
          style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              s.narrative,
              style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        _primaryAction(context, 'Leer versículo clave'),
      ],
    );
  }

  // ─────────────────────────── STEP 2: VERSE ───────────────────────────
  Widget _buildVerse(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Versículo clave',
          style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold)
              .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusL),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.surface, t.cardBg],
                  ),
                  border: Border.all(
                    color: AppDesignSystem.gold.withOpacity(0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${s.keyVerseText}"',
                      style: AppDesignSystem.scripture(context,
                          color: t.textPrimary),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingM),
                    Text(
                      s.keyVerseReference.toUpperCase(),
                      style: AppDesignSystem.scriptureReference(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        _primaryAction(context, 'Comprobar lo aprendido'),
      ],
    );
  }

  // ───────────────────────── STEP 3: QUESTIONS ─────────────────────────
  Widget _buildQuestion(BuildContext context, AppThemeData t) {
    if (s.questions.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Sin preguntas en esta estación.',
                style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
              ),
            ),
          ),
          _primaryAction(context, 'Continuar', force: true),
        ],
      );
    }

    final q = s.questions[_questionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pregunta ${_questionIndex + 1} de ${s.questions.length}',
          style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Text(
          q.prompt,
          style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        ),
        const SizedBox(height: AppDesignSystem.spacingL),
        Expanded(
          child: ListView.separated(
            itemCount: q.options.length,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppDesignSystem.spacingS),
            itemBuilder: (context, i) {
              final isSelected = _selectedOption == i;
              final isCorrect = i == q.correctIndex;
              Color borderColor = t.cardBorder;
              Color bg = t.cardBg;
              if (_answered) {
                if (isCorrect) {
                  borderColor = AppDesignSystem.victory;
                  bg = AppDesignSystem.victory.withOpacity(0.12);
                } else if (isSelected) {
                  borderColor = AppDesignSystem.struggle;
                  bg = AppDesignSystem.struggle.withOpacity(0.12);
                }
              } else if (isSelected) {
                borderColor = AppDesignSystem.gold;
              }
              return InkWell(
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusM),
                onTap: _answered ? null : () => _submitAnswer(i),
                child: Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusM),
                    border: Border.all(color: borderColor, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          q.options[i],
                          style: AppDesignSystem.bodyLarge(context,
                              color: t.textPrimary),
                        ),
                      ),
                      if (_answered && isCorrect)
                        const Icon(Icons.check_circle_rounded,
                            color: AppDesignSystem.victory)
                      else if (_answered && isSelected)
                        const Icon(Icons.cancel_rounded,
                            color: AppDesignSystem.struggle),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_answered && q.explanation != null) ...[
          const SizedBox(height: AppDesignSystem.spacingS),
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.10),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(
                  color: AppDesignSystem.gold.withOpacity(0.35)),
            ),
            child: Text(
              q.explanation!,
              style:
                  AppDesignSystem.bodyMedium(context, color: t.textPrimary),
            ),
          ),
        ],
        const SizedBox(height: AppDesignSystem.spacingM),
        _primaryAction(
          context,
          _answered
              ? (_questionIndex + 1 < s.questions.length
                  ? 'Siguiente'
                  : 'Reflexionar')
              : 'Selecciona una respuesta',
          force: _answered,
        ),
      ],
    );
  }

  // ──────────────────────── STEP 4: REFLECTION ────────────────────────
  Widget _buildReflection(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reflexión',
          style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold)
              .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
                border: Border.all(color: t.cardBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.self_improvement_rounded,
                      color: AppDesignSystem.gold, size: 36),
                  const SizedBox(height: AppDesignSystem.spacingM),
                  Text(
                    s.reflectionPrompt,
                    textAlign: TextAlign.center,
                    style: AppDesignSystem.bodyLarge(context,
                            color: t.textPrimary)
                        .copyWith(height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        _primaryAction(context, 'Completar estación', force: true),
      ],
    );
  }

  // ────────────────────────── STEP 5: DONE ──────────────────────────
  Widget _buildDone(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppDesignSystem.spacingL),
        const Icon(Icons.emoji_events_rounded,
            color: AppDesignSystem.gold, size: 72),
        const SizedBox(height: AppDesignSystem.spacingM),
        Text(
          '¡Estación completada!',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Text(
          '$_correctCount de ${s.questions.length} correctas',
          style: AppDesignSystem.bodyLarge(context, color: t.textSecondary),
        ),
        const SizedBox(height: AppDesignSystem.spacingL),
        if (_awardedXp > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AppDesignSystem.spacingL,
                vertical: AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppDesignSystem.gold, AppDesignSystem.goldLight],
              ),
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded,
                    color: AppDesignSystem.midnightDeep),
                const SizedBox(width: 6),
                Text(
                  '+$_awardedXp XP',
                  style: AppDesignSystem.headlineSmall(context,
                          color: AppDesignSystem.midnightDeep)
                      .copyWith(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        const Spacer(),
        _primaryAction(context, 'Volver al mapa', force: true),
      ],
    );
  }

  // ─────────────────────────── SHARED BUTTON ───────────────────────────
  Widget _primaryAction(BuildContext context, String label,
      {bool force = true}) {
    final enabled = force;
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: IgnorePointer(
          ignoring: !enabled,
          child: PremiumButton(
            onPressed: _advance,
            gradient: const LinearGradient(
              colors: [AppDesignSystem.gold, AppDesignSystem.goldLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            child: Text(
              label,
              style: AppDesignSystem.labelLarge(
                context,
                color: AppDesignSystem.midnightDeep,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
