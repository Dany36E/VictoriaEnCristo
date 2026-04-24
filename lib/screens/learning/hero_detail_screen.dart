/// ═══════════════════════════════════════════════════════════════════════════
/// HeroDetailScreen — Detalle de un Héroe de la Fe
///
/// Pasos:
///   1. Historia del héroe (quién fue, qué venció)
///   2. Versículo clave
///   3. Lección práctica
///   4. Reto (2 preguntas auto-calificadas)
///   5. Completado → desbloquea y otorga XP (solo la primera vez)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../models/learning/hero_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/heroes_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class HeroDetailScreen extends StatefulWidget {
  final HeroOfFaith hero;

  const HeroDetailScreen({super.key, required this.hero});

  @override
  State<HeroDetailScreen> createState() => _HeroDetailScreenState();
}

enum _Step { story, verse, lesson, challenge, done }

class _HeroDetailScreenState extends State<HeroDetailScreen> {
  _Step _step = _Step.story;
  int _questionIndex = 0;
  int? _selectedOption;
  bool _answered = false;
  int _correctCount = 0;
  int _awardedXp = 0;

  HeroOfFaith get h => widget.hero;

  double _progress() {
    final total = h.challenges.length;
    switch (_step) {
      case _Step.story:
        return 0.1;
      case _Step.verse:
        return 0.3;
      case _Step.lesson:
        return 0.45;
      case _Step.challenge:
        const base = 0.5;
        final per = (total == 0) ? 0.4 : 0.4 / total;
        final done = _answered ? _questionIndex + 1 : _questionIndex;
        return (base + per * done).clamp(0.0, 0.9);
      case _Step.done:
        return 1.0;
    }
  }

  Future<void> _advance() async {
    FeedbackEngine.I.tap();
    switch (_step) {
      case _Step.story:
        setState(() => _step = _Step.verse);
        break;
      case _Step.verse:
        setState(() => _step = _Step.lesson);
        break;
      case _Step.lesson:
        setState(() {
          _step = _Step.challenge;
          _questionIndex = 0;
          _selectedOption = null;
          _answered = false;
        });
        break;
      case _Step.challenge:
        if (!_answered) return;
        if (_questionIndex + 1 < h.challenges.length) {
          setState(() {
            _questionIndex++;
            _selectedOption = null;
            _answered = false;
          });
        } else {
          final xp = await HeroesProgressService.I.unlock(h);
          if (!mounted) return;
          setState(() {
            _awardedXp = xp;
            _step = _Step.done;
          });
        }
        break;
      case _Step.done:
        Navigator.pop(context, true);
        break;
    }
  }

  void _submitAnswer(int idx) {
    if (_answered) return;
    final q = h.challenges[_questionIndex];
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
          h.name,
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
      case _Step.story:
        return _buildStory(context, t);
      case _Step.verse:
        return _buildVerse(context, t);
      case _Step.lesson:
        return _buildLesson(context, t);
      case _Step.challenge:
        return _buildChallenge(context, t);
      case _Step.done:
        return _buildDone(context, t);
    }
  }

  // ────────────────────────────── STEP 1: STORY ──────────────────────────────
  Widget _buildStory(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          h.epithet.toUpperCase(),
          style: AppDesignSystem.labelMedium(context,
                  color: AppDesignSystem.gold)
              .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDesignSystem.spacingXS),
        Text(
          h.name,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppDesignSystem.struggle.withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: AppDesignSystem.struggle.withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flash_on_rounded,
                      size: 14, color: AppDesignSystem.struggle),
                  const SizedBox(width: 4),
                  Text(
                    'Venció: ${h.giantDefeated}',
                    style: AppDesignSystem.labelSmall(context,
                        color: t.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Expanded(
          child: SingleChildScrollView(
            child: Text(
              h.story,
              style: AppDesignSystem.bodyLarge(context, color: t.textPrimary)
                  .copyWith(height: 1.55),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        _primaryAction(context, 'Leer su versículo'),
      ],
    );
  }

  // ────────────────────────────── STEP 2: VERSE ──────────────────────────────
  Widget _buildVerse(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Versículo clave',
          style: AppDesignSystem.labelMedium(context,
                  color: AppDesignSystem.gold)
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
                      color: AppDesignSystem.gold.withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"${h.keyVerseText}"',
                      style: AppDesignSystem.scripture(context,
                          color: t.textPrimary),
                    ),
                    const SizedBox(height: AppDesignSystem.spacingM),
                    Text(
                      h.keyVerseReference.toUpperCase(),
                      style: AppDesignSystem.scriptureReference(context),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        _primaryAction(context, 'Ver la lección'),
      ],
    );
  }

  // ────────────────────────────── STEP 3: LESSON ──────────────────────────────
  Widget _buildLesson(BuildContext context, AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Lección',
          style: AppDesignSystem.labelMedium(context,
                  color: AppDesignSystem.gold)
              .copyWith(letterSpacing: 1.5, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                decoration: BoxDecoration(
                  color: t.cardBg,
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusL),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        color: AppDesignSystem.gold, size: 36),
                    const SizedBox(height: AppDesignSystem.spacingM),
                    Text(
                      h.lesson,
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
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        _primaryAction(context, 'Aceptar el reto'),
      ],
    );
  }

  // ────────────────────────────── STEP 4: CHALLENGE ──────────────────────────────
  Widget _buildChallenge(BuildContext context, AppThemeData t) {
    if (h.challenges.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Text(
                'Sin reto para este héroe.',
                style:
                    AppDesignSystem.bodyLarge(context, color: t.textPrimary),
              ),
            ),
          ),
          _primaryAction(context, 'Continuar'),
        ],
      );
    }

    final q = h.challenges[_questionIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Reto ${_questionIndex + 1} de ${h.challenges.length}',
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
              border:
                  Border.all(color: AppDesignSystem.gold.withOpacity(0.35)),
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
              ? (_questionIndex + 1 < h.challenges.length
                  ? 'Siguiente'
                  : 'Completar')
              : 'Selecciona una respuesta',
          force: _answered,
        ),
      ],
    );
  }

  // ────────────────────────────── STEP 5: DONE ──────────────────────────────
  Widget _buildDone(BuildContext context, AppThemeData t) {
    final alreadyUnlocked = _awardedXp == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppDesignSystem.spacingL),
        const Icon(Icons.verified_rounded,
            color: AppDesignSystem.gold, size: 72),
        const SizedBox(height: AppDesignSystem.spacingM),
        Text(
          alreadyUnlocked
              ? 'Testimonio repasado'
              : '¡Héroe desbloqueado!',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Text(
          '$_correctCount de ${h.challenges.length} correctas',
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
          )
        else
          Text(
            'Ya habías aprendido su testimonio.',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
        const Spacer(),
        _primaryAction(context, 'Volver a la galería'),
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
