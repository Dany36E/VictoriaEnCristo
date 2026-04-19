/// ═══════════════════════════════════════════════════════════════════════════
/// ManaSessionScreen — ejecuta una sesión de quiz (7 preguntas)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../models/learning/learning_models.dart';
import '../../services/daily_practice_service.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/learning_progress_service.dart';
import '../../services/learning/question_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'mana_result_screen.dart';

class ManaSessionScreen extends StatefulWidget {
  const ManaSessionScreen({super.key});

  @override
  State<ManaSessionScreen> createState() => _ManaSessionScreenState();
}

class _ManaSessionScreenState extends State<ManaSessionScreen> {
  late final List<LearningQuestion> _questions;
  int _idx = 0;
  int _correct = 0;
  int _wrong = 0;

  int? _selected; // índice seleccionado (MC/WhoSaid/TF/chooseReference/situational)
  final TextEditingController _textCtrl = TextEditingController();
  bool _answered = false;
  bool _lastWasCorrect = false;

  // Estado específico de orderEvents: secuencia de índices tocados (en orden).
  final List<int> _orderSeq = [];

  // Estado de matchPairs:
  //   _rightOrder: orden en que se muestran los "right" (index sobre pairs).
  //   _matchLeftPtr: siguiente "left" a emparejar (0..pairs.length-1)
  //   _matchResult[leftIndex] = índice pareado en _rightOrder (o null)
  List<int> _rightOrder = const [];
  int _matchLeftPtr = 0;
  Map<int, int> _matchResult = {};
  bool _matchAllCorrect = true;

  // TTS perezoso
  FlutterTts? _tts;
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _questions = QuestionRepository.I.pickSession(count: 7);
    _prepareQuestionState();
  }

  void _prepareQuestionState() {
    final q = _q;
    if (q.type == QuestionType.orderEvents) {
      _orderSeq.clear();
    } else if (q.type == QuestionType.matchPairs) {
      final n = q.pairs.length;
      _rightOrder = List<int>.generate(n, (i) => i)..shuffle();
      _matchLeftPtr = 0;
      _matchResult = {};
      _matchAllCorrect = true;
    }
  }

  Future<void> _speakPrompt() async {
    if (_speaking) return;
    _tts ??= FlutterTts()
      ..setLanguage('es-ES')
      ..setSpeechRate(0.48)
      ..setPitch(0.95);
    _speaking = true;
    final text = _q.type == QuestionType.completeVerse
        ? _q.prompt.replaceAll('____', '… pausa …')
        : _q.prompt;
    await _tts!.speak(text);
    _speaking = false;
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _tts?.stop();
    super.dispose();
  }

  LearningQuestion get _q => _questions[_idx];

  Future<void> _submit() async {
    if (_answered) return;
    final q = _q;
    bool correct;
    if (q.type == QuestionType.completeVerse) {
      final given = _textCtrl.text.trim().toLowerCase();
      final expected = (q.answerText ?? '').trim().toLowerCase();
      correct = given.isNotEmpty && _normalize(given) == _normalize(expected);
    } else if (q.type == QuestionType.orderEvents) {
      if (_orderSeq.length != q.options.length) return;
      final expected = q.correctOrder.isEmpty
          ? List<int>.generate(q.options.length, (i) => i)
          : q.correctOrder;
      correct = _listEq(_orderSeq, expected);
    } else if (q.type == QuestionType.matchPairs) {
      if (_matchResult.length != q.pairs.length) return;
      correct = _matchAllCorrect;
    } else {
      if (_selected == null) return;
      correct = _selected == q.correctIndex;
    }

    setState(() {
      _answered = true;
      _lastWasCorrect = correct;
      if (correct) {
        _correct++;
      } else {
        _wrong++;
      }
    });

    if (correct) {
      FeedbackEngine.I.confirm();
    } else {
      FeedbackEngine.I.tap();
      await LearningProgressService.I.spendHeart();
    }
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  String _normalize(String s) {
    const from = 'áéíóúüñÁÉÍÓÚÜÑ';
    const to = 'aeiouunAEIOUUN';
    var out = s;
    for (int i = 0; i < from.length; i++) {
      out = out.replaceAll(from[i], to[i]);
    }
    return out;
  }

  Future<void> _next() async {
    if (_idx < _questions.length - 1) {
      setState(() {
        _idx++;
        _answered = false;
        _selected = null;
        _textCtrl.clear();
        _orderSeq.clear();
        _matchResult = {};
        _matchLeftPtr = 0;
        _rightOrder = const [];
      });
      _prepareQuestionState();
    } else {
      await _finishSession();
    }
  }

  Future<void> _finishSession() async {
    final xpEarned = await LearningProgressService.I.recordSessionCompleted(
      correctAnswers: _correct,
      totalAnswers: _questions.length,
    );
    // Marcar práctica del día
    await DailyPracticeService.I.mark(DailyPractice.study);

    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ManaResultScreen(
          total: _questions.length,
          correct: _correct,
          wrong: _wrong,
          xpEarned: xpEarned,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);

    if (_questions.isEmpty) {
      return Scaffold(
        backgroundColor: t.scaffoldBg,
        appBar: AppBar(
          backgroundColor: t.surface,
          iconTheme: IconThemeData(color: t.textPrimary),
          title: Text('Maná', style: AppDesignSystem.headlineMedium(context, color: t.textPrimary)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            child: Text(
              'Por ahora no hay preguntas disponibles. Vuelve pronto.',
              textAlign: TextAlign.center,
              style: AppDesignSystem.bodyLarge(context, color: t.textSecondary),
            ),
          ),
        ),
      );
    }

    final p = (_idx + 1) / _questions.length;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Pregunta ${_idx + 1}/${_questions.length}',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: p,
            minHeight: 4,
            backgroundColor: t.textSecondary.withOpacity(0.1),
            valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPrompt(context, t),
              const SizedBox(height: AppDesignSystem.spacingL),
              Expanded(child: _buildAnswerArea(context, t)),
              if (_answered) _buildFeedback(context, t),
              const SizedBox(height: AppDesignSystem.spacingM),
              _buildPrimaryButton(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrompt(BuildContext context, AppThemeData t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _TypeChip(type: _q.type),
              const Spacer(),
              if (_q.ttsEnabled)
                IconButton(
                  tooltip: 'Escuchar',
                  icon: const Icon(Icons.volume_up_rounded,
                      color: AppDesignSystem.gold),
                  onPressed: _speakPrompt,
                ),
              if (_q.reference != null)
                Text(
                  _q.reference!,
                  style: AppDesignSystem.scriptureReference(context),
                ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            _q.prompt,
            style: _q.type == QuestionType.completeVerse
                ? AppDesignSystem.scripture(context, color: t.textPrimary)
                : AppDesignSystem.headlineSmall(context, color: t.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(BuildContext context, AppThemeData t) {
    if (_q.type == QuestionType.completeVerse) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escribe la palabra que falta:',
            style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          TextField(
            controller: _textCtrl,
            enabled: !_answered,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            onSubmitted: (_) => _submit(),
            style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
            decoration: InputDecoration(
              filled: true,
              fillColor: t.inputBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                borderSide: BorderSide(color: t.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                borderSide: BorderSide(color: t.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                borderSide: const BorderSide(color: AppDesignSystem.gold),
              ),
              hintText: 'palabra...',
              hintStyle: AppDesignSystem.bodyMedium(
                context,
                color: t.textSecondary.withOpacity(0.6),
              ),
            ),
          ),
        ],
      );
    }
    if (_q.type == QuestionType.orderEvents) {
      return _buildOrderEvents(context, t);
    }
    if (_q.type == QuestionType.matchPairs) {
      return _buildMatchPairs(context, t);
    }
    // MC / whoSaid / trueFalse / chooseReference / situational
    return _buildChoiceList(context, t);
  }

  Widget _buildChoiceList(BuildContext context, AppThemeData t) {
    return ListView.builder(
      itemCount: _q.options.length,
      itemBuilder: (context, i) {
        final selected = _selected == i;
        final isCorrect = _q.correctIndex == i;
        final showResult = _answered;
        Color border = t.divider;
        Color bg = t.cardBg;
        if (showResult) {
          if (isCorrect) {
            border = AppDesignSystem.victory;
            bg = AppDesignSystem.victory.withOpacity(0.12);
          } else if (selected && !isCorrect) {
            border = AppDesignSystem.struggle;
            bg = AppDesignSystem.struggle.withOpacity(0.12);
          }
        } else if (selected) {
          border = AppDesignSystem.gold;
          bg = AppDesignSystem.gold.withOpacity(0.08);
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            onTap: _answered ? null : () => setState(() => _selected = i),
            child: Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingM),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                border: Border.all(color: border, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _q.options[i],
                      style: AppDesignSystem.bodyLarge(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                  ),
                  if (showResult && isCorrect)
                    const Icon(Icons.check_circle_rounded,
                        color: AppDesignSystem.victory, size: 22),
                  if (showResult && selected && !isCorrect)
                    const Icon(Icons.cancel_rounded,
                        color: AppDesignSystem.struggle, size: 22),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ORDER EVENTS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOrderEvents(BuildContext context, AppThemeData t) {
    final q = _q;
    final expected = q.correctOrder.isEmpty
        ? List<int>.generate(q.options.length, (i) => i)
        : q.correctOrder;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _answered
              ? 'Orden correcto:'
              : 'Toca los eventos en orden cronológico:',
          style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Expanded(
          child: ListView.builder(
            itemCount: q.options.length,
            itemBuilder: (context, i) {
              final opt = q.options[i];
              final pickedPos = _orderSeq.indexOf(i);
              final correctPos = expected.indexOf(i);
              Color border = t.divider;
              Color bg = t.cardBg;
              if (_answered) {
                final isRightPlace = pickedPos == correctPos;
                if (isRightPlace) {
                  border = AppDesignSystem.victory;
                  bg = AppDesignSystem.victory.withOpacity(0.10);
                } else {
                  border = AppDesignSystem.struggle;
                  bg = AppDesignSystem.struggle.withOpacity(0.10);
                }
              } else if (pickedPos >= 0) {
                border = AppDesignSystem.gold;
                bg = AppDesignSystem.gold.withOpacity(0.08);
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusM),
                  onTap: _answered
                      ? null
                      : () {
                          setState(() {
                            if (pickedPos >= 0) {
                              _orderSeq.removeAt(pickedPos);
                            } else {
                              _orderSeq.add(i);
                            }
                          });
                          FeedbackEngine.I.tap();
                        },
                  child: Container(
                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.radiusM),
                      border: Border.all(color: border, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: pickedPos >= 0
                                ? AppDesignSystem.gold
                                : t.cardBorder,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            pickedPos >= 0 ? '${pickedPos + 1}' : '',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            opt,
                            style: AppDesignSystem.bodyLarge(context,
                                color: t.textPrimary),
                          ),
                        ),
                        if (_answered)
                          Text(
                            '#${correctPos + 1}',
                            style: AppDesignSystem.labelMedium(
                              context,
                              color: AppDesignSystem.gold,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MATCH PAIRS
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildMatchPairs(BuildContext context, AppThemeData t) {
    final q = _q;
    final n = q.pairs.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _answered
              ? 'Conexiones correctas:'
              : 'Selecciona el par correcto para "${q.pairs[_matchLeftPtr.clamp(0, n - 1)].left}"',
          style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
        ),
        const SizedBox(height: AppDesignSystem.spacingS),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Columna izquierda (fija)
              Expanded(
                flex: 5,
                child: ListView.builder(
                  itemCount: n,
                  itemBuilder: (context, i) {
                    final matched = _matchResult.containsKey(i);
                    final isCurrent = i == _matchLeftPtr && !_answered;
                    final wasCorrect = _answered &&
                        _matchResult[i] != null &&
                        _rightOrder[_matchResult[i]!] == i;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: matched
                            ? (wasCorrect
                                ? AppDesignSystem.victory.withOpacity(0.12)
                                : _answered
                                    ? AppDesignSystem.struggle
                                        .withOpacity(0.12)
                                    : AppDesignSystem.gold.withOpacity(0.10))
                            : t.cardBg,
                        borderRadius:
                            BorderRadius.circular(AppDesignSystem.radiusM),
                        border: Border.all(
                          color: isCurrent
                              ? AppDesignSystem.gold
                              : wasCorrect
                                  ? AppDesignSystem.victory
                                  : _answered && matched
                                      ? AppDesignSystem.struggle
                                      : t.cardBorder,
                          width: isCurrent ? 2 : 1,
                        ),
                      ),
                      child: Text(
                        q.pairs[i].left,
                        style: AppDesignSystem.bodyMedium(context,
                            color: t.textPrimary),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              // Columna derecha (barajada)
              Expanded(
                flex: 5,
                child: ListView.builder(
                  itemCount: n,
                  itemBuilder: (context, displayIdx) {
                    final pairIdx = _rightOrder[displayIdx];
                    final used = _matchResult.values.contains(displayIdx);
                    final leftOwner = _matchResult.entries
                        .firstWhere((e) => e.value == displayIdx,
                            orElse: () => const MapEntry(-1, -1))
                        .key;
                    final wasCorrect =
                        _answered && leftOwner == pairIdx;
                    Color border = t.cardBorder;
                    Color bg = t.cardBg;
                    if (_answered) {
                      if (wasCorrect) {
                        border = AppDesignSystem.victory;
                        bg = AppDesignSystem.victory.withOpacity(0.12);
                      } else if (used) {
                        border = AppDesignSystem.struggle;
                        bg = AppDesignSystem.struggle.withOpacity(0.12);
                      }
                    } else if (used) {
                      border = AppDesignSystem.gold;
                      bg = AppDesignSystem.gold.withOpacity(0.10);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: InkWell(
                        borderRadius:
                            BorderRadius.circular(AppDesignSystem.radiusM),
                        onTap: (_answered || used || _matchLeftPtr >= n)
                            ? null
                            : () {
                                setState(() {
                                  _matchResult[_matchLeftPtr] = displayIdx;
                                  if (_rightOrder[displayIdx] !=
                                      _matchLeftPtr) {
                                    _matchAllCorrect = false;
                                  }
                                  _matchLeftPtr++;
                                });
                                FeedbackEngine.I.tap();
                              },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(
                                AppDesignSystem.radiusM),
                            border: Border.all(color: border, width: 1.5),
                          ),
                          child: Text(
                            q.pairs[pairIdx].right,
                            style: AppDesignSystem.bodyMedium(context,
                                color: t.textPrimary),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeedback(BuildContext context, AppThemeData t) {
    final color = _lastWasCorrect ? AppDesignSystem.victory : AppDesignSystem.struggle;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: AppDesignSystem.spacingM),
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _lastWasCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                _lastWasCorrect ? '¡Correcto!' : 'Revisemos esto',
                style: AppDesignSystem.labelLarge(context, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _q.explanation,
            style: AppDesignSystem.bodyMedium(context, color: t.textPrimary),
          ),
          if (!_lastWasCorrect && _q.type == QuestionType.completeVerse) ...[
            const SizedBox(height: 4),
            Text(
              'Respuesta: ${_q.answerText}',
              style: AppDesignSystem.labelMedium(context, color: color),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 220.ms);
  }

  Widget _buildPrimaryButton(BuildContext context) {
    final enabled = _answered ||
        switch (_q.type) {
          QuestionType.completeVerse => _textCtrl.text.trim().isNotEmpty,
          QuestionType.orderEvents =>
            _orderSeq.length == _q.options.length && _q.options.isNotEmpty,
          QuestionType.matchPairs =>
            _matchResult.length == _q.pairs.length && _q.pairs.isNotEmpty,
          _ => _selected != null,
        };
    final label = _answered
        ? (_idx == _questions.length - 1 ? 'Ver resultados' : 'Siguiente')
        : 'Responder';
    return SizedBox(
      width: double.infinity,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: IgnorePointer(
          ignoring: !enabled,
          child: PremiumButton(
            onPressed: () {
              if (_answered) {
                _next();
              } else {
                _submit();
              }
            },
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

class _TypeChip extends StatelessWidget {
  final QuestionType type;

  const _TypeChip({required this.type});

  String get _label {
    switch (type) {
      case QuestionType.completeVerse: return 'Completa el versículo';
      case QuestionType.whoSaid:       return '¿Quién dijo?';
      case QuestionType.trueFalse:     return 'Verdadero o falso';
      case QuestionType.multipleChoice: return 'Opción múltiple';
      case QuestionType.orderEvents:   return 'Ordena los eventos';
      case QuestionType.matchPairs:    return 'Conecta pares';
      case QuestionType.chooseReference: return 'Elige la referencia';
      case QuestionType.situational:   return 'Dilema bíblico';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
      ),
      child: Text(
        _label,
        style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
      ),
    );
  }
}
