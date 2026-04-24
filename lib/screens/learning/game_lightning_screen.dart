/// ═══════════════════════════════════════════════════════════════════════════
/// GameLightningScreen — Duelo Relámpago (1 vs 1 local)
///
/// Cada jugador tiene 60 segundos. Responde la mayor cantidad de preguntas.
/// Al terminar el tiempo del primer jugador, pasa el celular y empieza el 2do.
/// Gana quien obtenga más respuestas correctas.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/learning_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/question_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

const int _matchSeconds = 60;
const int _penaltyMs = 1500;

class GameLightningScreen extends StatefulWidget {
  const GameLightningScreen({super.key});

  @override
  State<GameLightningScreen> createState() => _GameLightningScreenState();
}

enum _Phase { setup, intro, playing, between, finished }

class _GameLightningScreenState extends State<GameLightningScreen> {
  final _nameCtrl1 = TextEditingController(text: 'Jugador 1');
  final _nameCtrl2 = TextEditingController(text: 'Jugador 2');

  _Phase _phase = _Phase.setup;
  List<String> _names = [];
  final List<int> _scores = [0, 0];
  int _turn = 0;

  LearningQuestion? _q;
  int? _selected;
  bool _locked = false;

  Timer? _clock;
  int _remaining = _matchSeconds;
  List<LearningQuestion> _pool = [];
  int _poolIdx = 0;

  @override
  void dispose() {
    _clock?.cancel();
    _nameCtrl1.dispose();
    _nameCtrl2.dispose();
    super.dispose();
  }

  List<LearningQuestion> _buildPool() {
    final all = QuestionRepository.I.all.where((q) {
      return q.type == QuestionType.multipleChoice ||
          q.type == QuestionType.whoSaid ||
          q.type == QuestionType.trueFalse ||
          q.type == QuestionType.chooseReference ||
          q.type == QuestionType.situational;
    }).toList();
    all.shuffle(Random());
    return all;
  }

  void _startMatch() {
    final n1 = _nameCtrl1.text.trim().isEmpty ? 'Jugador 1' : _nameCtrl1.text.trim();
    final n2 = _nameCtrl2.text.trim().isEmpty ? 'Jugador 2' : _nameCtrl2.text.trim();
    _names = [n1, n2];
    _scores[0] = 0;
    _scores[1] = 0;
    _turn = 0;
    _pool = _buildPool();
    _poolIdx = 0;
    FeedbackEngine.I.tap();
    setState(() => _phase = _Phase.intro);
  }

  void _startTurn() {
    _remaining = _matchSeconds;
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _clock?.cancel();
          _endTurn();
        }
      });
    });
    _pool = _buildPool();
    _poolIdx = 0;
    _nextQuestion();
    setState(() => _phase = _Phase.playing);
  }

  void _nextQuestion() {
    if (_pool.isEmpty) return;
    _q = _pool[_poolIdx % _pool.length];
    _poolIdx++;
    _selected = null;
    _locked = false;
    if (mounted) setState(() {});
  }

  void _answer(int idx) {
    if (_locked) return;
    final correct = idx == _q!.correctIndex;
    _selected = idx;
    _locked = true;
    if (correct) {
      _scores[_turn]++;
      FeedbackEngine.I.confirm();
      // Avanza rápido tras correcto
      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted || _phase != _Phase.playing) return;
        _nextQuestion();
      });
    } else {
      FeedbackEngine.I.tap();
      // Penalización: muestra la correcta ~1.5s, luego siguiente
      Future.delayed(const Duration(milliseconds: _penaltyMs), () {
        if (!mounted || _phase != _Phase.playing) return;
        _nextQuestion();
      });
    }
    if (mounted) setState(() {});
  }

  void _endTurn() {
    if (_turn == 0) {
      setState(() {
        _phase = _Phase.between;
        _turn = 1;
      });
    } else {
      setState(() => _phase = _Phase.finished);
    }
  }

  void _reset() {
    FeedbackEngine.I.tap();
    setState(() {
      _phase = _Phase.setup;
      _scores[0] = 0;
      _scores[1] = 0;
      _turn = 0;
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
          'Duelo Relámpago',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: SafeArea(child: _body(t)),
    );
  }

  Widget _body(AppThemeData t) {
    switch (_phase) {
      case _Phase.setup:
        return _buildSetup(t);
      case _Phase.intro:
      case _Phase.between:
        return _buildIntro(t);
      case _Phase.playing:
        return _buildPlaying(t);
      case _Phase.finished:
        return _buildFinished(t);
    }
  }

  Widget _buildSetup(AppThemeData t) {
    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      children: [
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppDesignSystem.gold.withOpacity(0.15),
                AppDesignSystem.gold.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: AppDesignSystem.gold, size: 28),
                  const SizedBox(width: 8),
                  Text('Duelo Relámpago',
                      style: AppDesignSystem.headlineSmall(context,
                          color: t.textPrimary)),
                ],
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                'Cada jugador tiene 60 segundos. ¡Responde rápido para sumar puntos!',
                style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
              ),
              const SizedBox(height: AppDesignSystem.spacingM),
              _rule(t, '⏱️', '60 segundos por jugador'),
              _rule(t, '✅', 'Correcto = +1 punto, siguiente pregunta al instante'),
              _rule(t, '❌', 'Fallo = 1.5s de penalización mostrando la respuesta'),
              _rule(t, '🏆', 'Más puntos al final gana'),
            ],
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingL),
        _nameField(t, _nameCtrl1, 'Jugador 1', const Color(0xFFE89E5C)),
        const SizedBox(height: AppDesignSystem.spacingM),
        _nameField(t, _nameCtrl2, 'Jugador 2', const Color(0xFFB59FE3)),
        const SizedBox(height: AppDesignSystem.spacingL),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _startMatch,
            icon: const Icon(Icons.bolt_rounded),
            label: const Text('¡Comenzar duelo!'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppDesignSystem.gold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
              ),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _rule(AppThemeData t, String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppDesignSystem.bodyMedium(context, color: t.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _nameField(
      AppThemeData t, TextEditingController c, String hint, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.person_rounded, color: color),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildIntro(AppThemeData t) {
    final color = _turn == 0 ? const Color(0xFFE89E5C) : const Color(0xFFB59FE3);
    final isHandoff = _phase == _Phase.between;
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isHandoff) ...[
            Text(
              'Turno 1 terminado',
              style: AppDesignSystem.bodyLarge(context, color: t.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              '${_names[0]}: ${_scores[0]} pts',
              style: AppDesignSystem.headlineMedium(context,
                  color: const Color(0xFFE89E5C)),
            ),
            const SizedBox(height: AppDesignSystem.spacingL),
            const Divider(),
            const SizedBox(height: AppDesignSystem.spacingL),
          ],
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(Icons.bolt_rounded, color: color, size: 70),
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: AppDesignSystem.spacingL),
          Text(isHandoff ? 'Pasa el celular a' : 'Empieza',
              style: AppDesignSystem.bodyLarge(context, color: t.textSecondary)),
          Text(
            _names[_turn],
            style: AppDesignSystem.displayMedium(context, color: color),
          ),
          const SizedBox(height: 8),
          Text('60 segundos · responde rápido',
              style: AppDesignSystem.labelMedium(context, color: t.textSecondary)),
          const SizedBox(height: AppDesignSystem.spacingXL),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _startTurn,
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(isHandoff ? '¡Listo!' : '¡Empezar!'),
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaying(AppThemeData t) {
    final q = _q!;
    final color = _turn == 0 ? const Color(0xFFE89E5C) : const Color(0xFFB59FE3);
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: player + score
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                  border: Border.all(color: color.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_rounded, size: 16, color: color),
                    const SizedBox(width: 4),
                    Text(
                      _names[_turn],
                      style: AppDesignSystem.labelLarge(context, color: color),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text('${_scores[_turn]} pts',
                  style: AppDesignSystem.headlineMedium(context, color: AppDesignSystem.gold)),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          // Timer bar
          Row(
            children: [
              Icon(Icons.timer_outlined,
                  size: 18,
                  color: _remaining <= 10
                      ? AppDesignSystem.struggle
                      : t.textSecondary),
              const SizedBox(width: 6),
              Text('$_remaining s',
                  style: AppDesignSystem.labelLarge(context,
                      color: _remaining <= 10
                          ? AppDesignSystem.struggle
                          : t.textPrimary)),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _remaining / _matchSeconds,
                    minHeight: 8,
                    backgroundColor: t.cardBg,
                    valueColor: AlwaysStoppedAnimation(
                      _remaining <= 10 ? AppDesignSystem.struggle : color,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              q.prompt,
              style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (context, i) {
                Color border = t.divider;
                Color bg = t.cardBg;
                if (_locked) {
                  if (i == q.correctIndex) {
                    border = AppDesignSystem.victory;
                    bg = AppDesignSystem.victory.withOpacity(0.10);
                  } else if (i == _selected) {
                    border = AppDesignSystem.struggle;
                    bg = AppDesignSystem.struggle.withOpacity(0.10);
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    onTap: _locked ? null : () => _answer(i),
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
                            child: Text(q.options[i],
                                style: AppDesignSystem.bodyLarge(context,
                                    color: t.textPrimary)),
                          ),
                          if (_locked && i == q.correctIndex)
                            const Icon(Icons.check_circle_rounded,
                                color: AppDesignSystem.victory),
                          if (_locked &&
                              i == _selected &&
                              i != q.correctIndex)
                            const Icon(Icons.cancel_rounded,
                                color: AppDesignSystem.struggle),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinished(AppThemeData t) {
    final tie = _scores[0] == _scores[1];
    final winnerIdx = _scores[0] > _scores[1] ? 0 : 1;
    final winnerColor = winnerIdx == 0
        ? const Color(0xFFE89E5C)
        : const Color(0xFFB59FE3);
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        children: [
          const Spacer(),
          Icon(
            tie ? Icons.handshake_rounded : Icons.emoji_events_rounded,
            size: 100,
            color: AppDesignSystem.gold,
          )
              .animate()
              .scale(duration: 500.ms, curve: Curves.elasticOut)
              .then()
              .shake(hz: 2, duration: 600.ms),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            tie ? '¡Empate!' : '¡${_names[winnerIdx]} gana!',
            style: AppDesignSystem.displaySmall(
                context, color: tie ? AppDesignSystem.gold : winnerColor),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              border: Border.all(color: t.cardBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _scoreBlock(_names[0], _scores[0], const Color(0xFFE89E5C)),
                Container(width: 1, height: 50, color: t.divider),
                _scoreBlock(_names[1], _scores[1], const Color(0xFFB59FE3)),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: t.cardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.radiusFull),
                    ),
                  ),
                  child: Text('Salir',
                      style: TextStyle(color: t.textSecondary)),
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: ElevatedButton(
                  onPressed: _reset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.radiusFull),
                    ),
                  ),
                  child: const Text('Revancha'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreBlock(String name, int score, Color color) {
    return Column(
      children: [
        Text(name,
            style: AppDesignSystem.labelMedium(context, color: color)),
        const SizedBox(height: 4),
        Text('$score',
            style: AppDesignSystem.displaySmall(context, color: color)),
        Text('pts',
            style: AppDesignSystem.labelSmall(
                context, color: AppThemeData.of(context).textSecondary)),
      ],
    );
  }
}
