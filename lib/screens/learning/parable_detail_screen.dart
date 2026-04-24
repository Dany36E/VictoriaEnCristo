/// ═══════════════════════════════════════════════════════════════════════════
/// ParableDetailScreen — lectura cinematográfica + preguntas + aplicación
///
/// Flujo:
///   1. Intro (título, referencia, versículo clave)
///   2. Escenas (swipe de narración tipo cinematográfica)
///   3. Significado
///   4. Preguntas
///   5. Aplicación personal (prompt)
///   6. Completado → XP
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/learning/parable_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/parable_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class ParableDetailScreen extends StatefulWidget {
  final Parable parable;
  const ParableDetailScreen({super.key, required this.parable});

  @override
  State<ParableDetailScreen> createState() => _ParableDetailScreenState();
}

enum _Step { intro, scenes, meaning, questions, apply, done }

class _ParableDetailScreenState extends State<ParableDetailScreen> {
  _Step _step = _Step.intro;
  int _sceneIdx = 0;
  int _qIdx = 0;
  int? _selected;
  bool _answered = false;
  int _correct = 0;
  int _xpAwarded = 0;
  final TextEditingController _applyCtrl = TextEditingController();
  FlutterTts? _tts;
  bool _speaking = false;

  Parable get p => widget.parable;

  @override
  void dispose() {
    _applyCtrl.dispose();
    _tts?.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak(String text) async {
    _tts ??= FlutterTts();
    await _tts!.setLanguage('es-ES');
    await _tts!.setSpeechRate(0.48);
    await _tts!.setPitch(0.95);
    if (_speaking) {
      await _tts!.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }
    setState(() => _speaking = true);
    await _tts!.speak(text);
    _tts!.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  double _progress() {
    switch (_step) {
      case _Step.intro:
        return 0.08;
      case _Step.scenes:
        final total = p.scenes.length;
        return 0.15 +
            0.35 * ((_sceneIdx + 1) / (total == 0 ? 1 : total));
      case _Step.meaning:
        return 0.58;
      case _Step.questions:
        final total = p.questions.length;
        final done = _answered ? _qIdx + 1 : _qIdx;
        return 0.65 + 0.25 * (done / (total == 0 ? 1 : total));
      case _Step.apply:
        return 0.94;
      case _Step.done:
        return 1.0;
    }
  }

  Future<void> _advance() async {
    FeedbackEngine.I.tap();
    await _tts?.stop();
    if (mounted && _speaking) setState(() => _speaking = false);
    switch (_step) {
      case _Step.intro:
        setState(() => _step = _Step.scenes);
        break;
      case _Step.scenes:
        if (_sceneIdx + 1 < p.scenes.length) {
          setState(() => _sceneIdx++);
        } else {
          setState(() => _step = _Step.meaning);
        }
        break;
      case _Step.meaning:
        setState(() {
          _step = _Step.questions;
          _qIdx = 0;
          _selected = null;
          _answered = false;
        });
        break;
      case _Step.questions:
        if (!_answered) return;
        if (_qIdx + 1 < p.questions.length) {
          setState(() {
            _qIdx++;
            _selected = null;
            _answered = false;
          });
        } else {
          setState(() => _step = _Step.apply);
        }
        break;
      case _Step.apply:
        final xp = await ParableProgressService.I
            .markCompleted(p.id, p.xpReward);
        if (!mounted) return;
        setState(() {
          _xpAwarded = xp;
          _step = _Step.done;
        });
        FeedbackEngine.I.confirm();
        break;
      case _Step.done:
        if (mounted) Navigator.pop(context, true);
        break;
    }
  }

  void _answer(int idx) {
    if (_answered) return;
    final q = p.questions[_qIdx];
    final correct = idx == q.correctIndex;
    FeedbackEngine.I.tap();
    setState(() {
      _selected = idx;
      _answered = true;
      if (correct) _correct++;
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
          p.title,
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
      case _Step.intro:
        return _intro(t);
      case _Step.scenes:
        return _scene(t);
      case _Step.meaning:
        return _meaning(t);
      case _Step.questions:
        return _question(t);
      case _Step.apply:
        return _apply(t);
      case _Step.done:
        return _done(t);
    }
  }

  Widget _intro(AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.subtitle,
                  style: AppDesignSystem.bodyLarge(context,
                      color: t.textSecondary),
                ).animate().fadeIn(duration: 400.ms),
                const SizedBox(height: AppDesignSystem.spacingL),
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppDesignSystem.gold.withOpacity(0.12),
                        AppDesignSystem.gold.withOpacity(0.04),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusL),
                    border: Border.all(
                        color: AppDesignSystem.gold.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.reference,
                        style: AppDesignSystem.labelSmall(context,
                            color: AppDesignSystem.gold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '"${p.keyVerse}"',
                        style: AppDesignSystem.scripture(context,
                            color: t.textPrimary),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            onPressed: _advance,
            child: const Text('Comenzar la historia'),
          ),
        ),
      ],
    );
  }

  Widget _scene(AppThemeData t) {
    final scene = p.scenes[_sceneIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Escena ${_sceneIdx + 1} de ${p.scenes.length}',
              style: AppDesignSystem.labelSmall(context,
                  color: t.textSecondary),
            ),
            const Spacer(),
            IconButton(
              tooltip: _speaking ? 'Detener' : 'Escuchar',
              icon: Icon(
                _speaking ? Icons.stop_circle : Icons.volume_up_rounded,
                color: AppDesignSystem.gold,
              ),
              onPressed: () => _toggleSpeak(scene.text),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              key: ValueKey(_sceneIdx),
              width: double.infinity,
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusL),
                border: Border.all(color: t.cardBorder),
                boxShadow: t.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (scene.speaker != null && scene.speaker!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppDesignSystem.gold.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(
                            AppDesignSystem.radiusFull),
                      ),
                      child: Text(
                        scene.speaker!,
                        style: const TextStyle(
                          color: AppDesignSystem.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    scene.text,
                    style: AppDesignSystem.bodyLarge(context,
                        color: t.textPrimary),
                  ),
                ],
              ),
            ).animate(key: ValueKey(_sceneIdx)).fadeIn(duration: 350.ms),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            onPressed: _advance,
            child: Text(_sceneIdx + 1 < p.scenes.length
                ? 'Siguiente escena'
                : 'Entender la parábola'),
          ),
        ),
      ],
    );
  }

  Widget _meaning(AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'El significado',
          style: AppDesignSystem.headlineMedium(context,
              color: t.textPrimary),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusL),
                border: Border.all(color: t.cardBorder),
                boxShadow: t.cardShadow,
              ),
              child: Text(
                p.meaning,
                style: AppDesignSystem.bodyLarge(context,
                    color: t.textPrimary),
              ),
            ).animate().fadeIn(duration: 400.ms),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            onPressed: _advance,
            child: const Text('Comprobar comprensión'),
          ),
        ),
      ],
    );
  }

  Widget _question(AppThemeData t) {
    final q = p.questions[_qIdx];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pregunta ${_qIdx + 1} de ${p.questions.length}',
          style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
        ),
        const SizedBox(height: 10),
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
              final isCorrect = i == q.correctIndex;
              final isSelected = i == _selected;
              Color border = t.cardBorder;
              Color bg = t.cardBg;
              if (_answered) {
                if (isCorrect) {
                  border = AppDesignSystem.gold;
                  bg = AppDesignSystem.gold.withOpacity(0.1);
                } else if (isSelected) {
                  border = Colors.redAccent;
                  bg = Colors.redAccent.withOpacity(0.1);
                }
              } else if (isSelected) {
                border = AppDesignSystem.gold.withOpacity(0.7);
              }
              return InkWell(
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusL),
                onTap: () => _answer(i),
                child: Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusL),
                    border: Border.all(color: border),
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
                            color: AppDesignSystem.gold),
                      if (_answered && isSelected && !isCorrect)
                        const Icon(Icons.cancel_rounded,
                            color: Colors.redAccent),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (_answered && (q.explanation?.isNotEmpty ?? false)) ...[
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.08),
              borderRadius:
                  BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(
                  color: AppDesignSystem.gold.withOpacity(0.3)),
            ),
            child: Text(
              q.explanation!,
              style: AppDesignSystem.bodyMedium(context,
                  color: t.textPrimary),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
        ],
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            onPressed: _answered ? _advance : () {},
            child: Text(_answered
                ? (_qIdx + 1 < p.questions.length
                    ? 'Siguiente'
                    : 'Aplicar a mi vida')
                : 'Elige una opción'),
          ),
        ),
      ],
    );
  }

  Widget _apply(AppThemeData t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Aplicación personal',
          style: AppDesignSystem.headlineMedium(context,
              color: t.textPrimary),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: AppDesignSystem.gold.withOpacity(0.08),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
          ),
          child: Text(
            p.applicationPrompt,
            style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        Expanded(
          child: TextField(
            controller: _applyCtrl,
            maxLines: null,
            expands: true,
            textAlignVertical: TextAlignVertical.top,
            style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
            decoration: InputDecoration(
              hintText:
                  'Escribe unas líneas: ¿cómo aplicas hoy lo que acabas de aprender?',
              hintStyle: AppDesignSystem.bodyMedium(context,
                  color: t.textSecondary),
              filled: true,
              fillColor: t.cardBg,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusL),
                borderSide: BorderSide(color: t.cardBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusL),
                borderSide: BorderSide(color: t.cardBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusL),
                borderSide: const BorderSide(color: AppDesignSystem.gold),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            onPressed: _advance,
            child: const Text('Completar parábola'),
          ),
        ),
      ],
    );
  }

  Widget _done(AppThemeData t) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome_rounded,
                color: AppDesignSystem.gold, size: 80)
            .animate()
            .scale(
                begin: const Offset(0.4, 0.4),
                duration: 500.ms,
                curve: Curves.elasticOut),
        const SizedBox(height: AppDesignSystem.spacingL),
        Text(
          '¡Parábola completada!',
          style: AppDesignSystem.headlineMedium(context,
              color: t.textPrimary),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Text(
          '$_correct de ${p.questions.length} correctas',
          style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
        ),
        const SizedBox(height: AppDesignSystem.spacingL),
        if (_xpAwarded > 0)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.18),
              borderRadius:
                  BorderRadius.circular(AppDesignSystem.radiusFull),
              border: Border.all(
                  color: AppDesignSystem.gold.withOpacity(0.5)),
            ),
            child: Text(
              '+$_xpAwarded XP',
              style: const TextStyle(
                color: AppDesignSystem.gold,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
          ).animate().fadeIn(delay: 300.ms).scale(
              begin: const Offset(0.5, 0.5),
              duration: 400.ms,
              curve: Curves.easeOut),
        const SizedBox(height: AppDesignSystem.spacingXL),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            onPressed: _advance,
            child: const Text('Volver a las parábolas'),
          ),
        ),
      ],
    );
  }
}
