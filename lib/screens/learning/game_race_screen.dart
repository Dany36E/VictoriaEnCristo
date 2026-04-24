/// ═══════════════════════════════════════════════════════════════════════════
/// GameRaceScreen — La Carrera de la Fe (1 vs 1 local) · Epic Edition
///
/// "De Egipto a Jerusalén" — Elige un personaje bíblico y compite
/// respondiendo preguntas. Cada acierto avanza casillas en el Camino
/// de la Fe. ¡El primero en llegar a Jerusalén gana!
///
/// Inspirado en Hebreos 12:1 — "Corramos con paciencia la carrera".
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

// ═══════════════════════════════════════════════════════════════════════════
// PERSONAJES BÍBLICOS
// ═══════════════════════════════════════════════════════════════════════════

class _BiblicalRunner {
  final String name;
  final String title;
  final String emoji;
  final Color color;
  final String verse;

  const _BiblicalRunner({
    required this.name,
    required this.title,
    required this.emoji,
    required this.color,
    required this.verse,
  });
}

const List<_BiblicalRunner> _kRunners = [
  _BiblicalRunner(
    name: 'David',
    title: 'Guerrero de Dios',
    emoji: '🦁',
    color: Color(0xFF4CAF50),
    verse: '1 Samuel 17:47',
  ),
  _BiblicalRunner(
    name: 'Elías',
    title: 'Carro de fuego',
    emoji: '🔥',
    color: Color(0xFFFF7043),
    verse: '2 Reyes 2:11',
  ),
  _BiblicalRunner(
    name: 'Moisés',
    title: 'Libertador',
    emoji: '🌊',
    color: Color(0xFF42A5F5),
    verse: 'Éxodo 14:21',
  ),
  _BiblicalRunner(
    name: 'Josué',
    title: 'Conquistador',
    emoji: '⚔️',
    color: Color(0xFFFFB74D),
    verse: 'Josué 1:9',
  ),
  _BiblicalRunner(
    name: 'Débora',
    title: 'Jueza valiente',
    emoji: '⭐',
    color: Color(0xFFAB47BC),
    verse: 'Jueces 4:9',
  ),
  _BiblicalRunner(
    name: 'Gedeón',
    title: 'Valiente guerrero',
    emoji: '🏹',
    color: Color(0xFF26A69A),
    verse: 'Jueces 6:12',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
// HITOS DEL CAMINO
// ═══════════════════════════════════════════════════════════════════════════

class _Milestone {
  final int position;
  final String name;
  final String emoji;
  const _Milestone(this.position, this.name, this.emoji);
}

const List<_Milestone> _kMilestones = [
  _Milestone(0, 'Egipto', '🏛'),
  _Milestone(5, 'Mar Rojo', '🌊'),
  _Milestone(10, 'Desierto', '🏜'),
  _Milestone(15, 'Jericó', '⚔'),
  _Milestone(20, 'Jerusalén', '✨'),
];

String _locationFor(int pos) {
  if (pos >= 20) return '¡Jerusalén!';
  if (pos >= 15) return 'Jericó';
  if (pos >= 10) return 'Desierto';
  if (pos >= 5) return 'Mar Rojo';
  return 'Egipto';
}

String _locationEmoji(int pos) {
  if (pos >= 20) return '✨';
  if (pos >= 15) return '⚔';
  if (pos >= 10) return '🏜';
  if (pos >= 5) return '🌊';
  return '🏛';
}

// ═══════════════════════════════════════════════════════════════════════════
// WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class GameRaceScreen extends StatefulWidget {
  const GameRaceScreen({super.key});

  @override
  State<GameRaceScreen> createState() => _GameRaceScreenState();
}

enum _Phase { setup, turnIntro, question, turnResult, finished }

const int _finishLine = 20;
const int _timePerQuestion = 15;

class _GameRaceScreenState extends State<GameRaceScreen>
    with TickerProviderStateMixin {
  // ── Selección de personaje ──
  int _runner1Idx = 0;
  int _runner2Idx = 1;

  // ── Nombres ──
  final _nameCtrl1 = TextEditingController();
  final _nameCtrl2 = TextEditingController();

  // ── Estado del juego ──
  _Phase _phase = _Phase.setup;
  List<String> _names = [];
  final List<int> _positions = [0, 0];
  int _turn = 0;
  LearningQuestion? _q;
  int? _selected;
  bool _answered = false;
  bool _wasCorrect = false;
  int _advance = 0;
  int _winnerIdx = -1;

  Timer? _ticker;
  int _remaining = _timePerQuestion;
  DateTime? _qStart;
  List<LearningQuestion> _pool = [];
  int _poolIdx = 0;

  // ── Confetti ──
  late AnimationController _confettiCtrl;

  // ── Helpers ──
  _BiblicalRunner get _p1Runner => _kRunners[_runner1Idx];
  _BiblicalRunner get _p2Runner => _kRunners[_runner2Idx];
  _BiblicalRunner get _currentRunner => _turn == 0 ? _p1Runner : _p2Runner;

  @override
  void initState() {
    super.initState();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _nameCtrl1.dispose();
    _nameCtrl2.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LÓGICA DEL JUEGO
  // ═══════════════════════════════════════════════════════════════════════════

  void _startGame() {
    final r1 = _kRunners[_runner1Idx];
    final r2 = _kRunners[_runner2Idx];
    final n1 =
        _nameCtrl1.text.trim().isEmpty ? r1.name : _nameCtrl1.text.trim();
    final n2 =
        _nameCtrl2.text.trim().isEmpty ? r2.name : _nameCtrl2.text.trim();
    _names = [n1, n2];
    _pool = _buildPool();
    _poolIdx = 0;
    _positions[0] = 0;
    _positions[1] = 0;
    _turn = Random().nextInt(2);
    _winnerIdx = -1;
    FeedbackEngine.I.tap();
    setState(() => _phase = _Phase.turnIntro);
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

  LearningQuestion _nextQuestion() {
    if (_pool.isEmpty) {
      return const LearningQuestion(
        id: 'fallback',
        type: QuestionType.trueFalse,
        prompt: '¿La Biblia tiene 66 libros?',
        options: ['Verdadero', 'Falso'],
        correctIndex: 0,
        explanation: '',
        answerText: '',
      );
    }
    final q = _pool[_poolIdx % _pool.length];
    _poolIdx++;
    return q;
  }

  void _beginQuestion() {
    _q = _nextQuestion();
    _selected = null;
    _answered = false;
    _wasCorrect = false;
    _advance = 0;
    _remaining = _timePerQuestion;
    _qStart = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _remaining--;
        if (_remaining <= 0) {
          _ticker?.cancel();
          _lockAnswer(null);
        }
      });
    });
    setState(() => _phase = _Phase.question);
  }

  void _lockAnswer(int? idx) {
    _ticker?.cancel();
    final q = _q!;
    final correct = idx != null && idx == q.correctIndex;
    final elapsed = _qStart == null
        ? _timePerQuestion.toDouble()
        : DateTime.now().difference(_qStart!).inMilliseconds / 1000.0;
    int advance = 0;
    if (correct) {
      advance = 2;
      if (elapsed < 5.0) advance = 3;
    }
    _positions[_turn] = min(_finishLine, _positions[_turn] + advance);
    setState(() {
      _selected = idx;
      _answered = true;
      _wasCorrect = correct;
      _advance = advance;
    });
    if (correct) {
      FeedbackEngine.I.confirm();
    } else {
      FeedbackEngine.I.tap();
    }

    if (_positions[_turn] >= _finishLine) {
      _winnerIdx = _turn;
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        _confettiCtrl.forward(from: 0);
        setState(() => _phase = _Phase.finished);
      });
    } else {
      Future.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted) return;
        setState(() => _phase = _Phase.turnResult);
      });
    }
  }

  void _nextTurn() {
    _turn = 1 - _turn;
    FeedbackEngine.I.tap();
    setState(() => _phase = _Phase.turnIntro);
  }

  void _resetAll() {
    FeedbackEngine.I.tap();
    _confettiCtrl.reset();
    setState(() {
      _phase = _Phase.setup;
      _positions[0] = 0;
      _positions[1] = 0;
      _turn = 0;
      _winnerIdx = -1;
      _q = null;
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚔ ', style: TextStyle(fontSize: 20)),
            Text(
              'Carrera de la Fe',
              style: AppDesignSystem.headlineMedium(
                  context,
                  color: t.textPrimary),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            _body(t),
            if (_phase == _Phase.finished) _confettiOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _body(AppThemeData t) {
    switch (_phase) {
      case _Phase.setup:
        return _buildSetup(t);
      case _Phase.turnIntro:
        return _buildTurnIntro(t);
      case _Phase.question:
        return _buildQuestion(t);
      case _Phase.turnResult:
        return _buildTurnResult(t);
      case _Phase.finished:
        return _buildFinished(t);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SETUP — Selección de personaje
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildSetup(AppThemeData t) {
    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      children: [
        // ── Encabezado épico ──
        Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFD4A574).withOpacity(0.2),
                const Color(0xFFE8D5B7).withOpacity(0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border:
                Border.all(color: const Color(0xFFD4A574).withOpacity(0.3)),
          ),
          child: Column(
            children: [
              const Text('🏛  →  🌊  →  🏜  →  ⚔  →  ✨',
                  style: TextStyle(fontSize: 18, letterSpacing: 2)),
              const SizedBox(height: 8),
              Text('De Egipto a Jerusalén',
                  style: AppDesignSystem.headlineSmall(
                      context,
                      color: const Color(0xFFD4A574))),
              const SizedBox(height: 4),
              Text(
                '20 casillas · Hebreos 12:1',
                style: AppDesignSystem.labelSmall(
                    context,
                    color: t.textSecondary),
              ),
              const SizedBox(height: AppDesignSystem.spacingM),
              _rule(t, '⚡', 'Respuesta rápida (<5s) = +3 casillas'),
              _rule(t, '🎯', 'Correcto = +2 casillas'),
              _rule(t, '❌', 'Fallo o tiempo = no avanzas'),
              _rule(t, '✨', 'Primero en llegar a Jerusalén gana'),
            ],
          ),
        )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(begin: -0.1, duration: 400.ms),

        const SizedBox(height: AppDesignSystem.spacingL),

        // ── Jugador 1 ──
        _playerSection(t, 1),

        const SizedBox(height: AppDesignSystem.spacingM),

        // ── Jugador 2 ──
        _playerSection(t, 2),

        const SizedBox(height: AppDesignSystem.spacingL),

        // ── Botón inicio ──
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: _startGame,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4A574),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusFull),
              ),
              textStyle: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('⚔ ', style: TextStyle(fontSize: 22)),
                Text('¡A la carrera!'),
              ],
            ),
          ),
        ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
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
                style:
                    AppDesignSystem.bodyMedium(context, color: t.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _playerSection(AppThemeData t, int player) {
    final isP1 = player == 1;
    final selectedIdx = isP1 ? _runner1Idx : _runner2Idx;
    final otherIdx = isP1 ? _runner2Idx : _runner1Idx;
    final ctrl = isP1 ? _nameCtrl1 : _nameCtrl2;
    final runner = _kRunners[selectedIdx];

    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: runner.color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: runner.color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: runner.color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text('$player',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ),
              ),
              const SizedBox(width: 10),
              Text('Jugador $player',
                  style: AppDesignSystem.labelLarge(
                      context, color: runner.color)),
              const Spacer(),
              Text(runner.verse,
                  style: AppDesignSystem.labelSmall(
                      context, color: t.textSecondary)),
            ],
          ),

          const SizedBox(height: AppDesignSystem.spacingS),

          // ── Grid de personajes ──
          SizedBox(
            height: 95,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _kRunners.length,
              itemBuilder: (context, i) {
                final r = _kRunners[i];
                final isSelected = i == selectedIdx;
                final isOther = i == otherIdx;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: isOther
                        ? null
                        : () {
                            FeedbackEngine.I.select();
                            setState(() {
                              if (isP1) {
                                _runner1Idx = i;
                              } else {
                                _runner2Idx = i;
                              }
                            });
                          },
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 200),
                      opacity: isOther ? 0.3 : 1.0,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 74,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? r.color.withOpacity(0.15)
                              : t.cardBg,
                          borderRadius: BorderRadius.circular(
                              AppDesignSystem.radiusM),
                          border: Border.all(
                            color: isSelected ? r.color : t.divider,
                            width: isSelected ? 2.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: r.color.withOpacity(0.3),
                                    blurRadius: 12,
                                  ),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(r.emoji,
                                style: const TextStyle(fontSize: 28)),
                            const SizedBox(height: 4),
                            Text(
                              r.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? r.color
                                    : t.textSecondary,
                              ),
                            ),
                            if (isSelected)
                              Text(
                                r.title,
                                style: TextStyle(
                                  fontSize: 8,
                                  color: r.color.withOpacity(0.7),
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: AppDesignSystem.spacingS),

          // ── Campo de nombre ──
          Container(
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(color: runner.color.withOpacity(0.3)),
            ),
            child: TextField(
              controller: ctrl,
              textAlign: TextAlign.center,
              style:
                  AppDesignSystem.bodyLarge(context, color: t.textPrimary),
              decoration: InputDecoration(
                hintText: runner.name,
                hintStyle:
                    TextStyle(color: t.textSecondary.withOpacity(0.5)),
                prefixIcon: Text(runner.emoji,
                    style: const TextStyle(fontSize: 20)),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 48),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TURN INTRO — Presentación dramática del personaje
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTurnIntro(AppThemeData t) {
    final runner = _currentRunner;
    final color = runner.color;
    final loc = _locationFor(_positions[_turn]);
    final locEmoji = _locationEmoji(_positions[_turn]);

    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      child: Column(
        children: [
          _epicRaceTrack(t),
          const Spacer(),

          // ── Avatar del personaje ──
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.3),
                  color.withOpacity(0.05),
                ],
              ),
              border: Border.all(color: color, width: 3),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child:
                  Text(runner.emoji, style: const TextStyle(fontSize: 60)),
            ),
          )
              .animate()
              .scale(
                  begin: const Offset(0.5, 0.5),
                  duration: 500.ms,
                  curve: Curves.elasticOut)
              .fadeIn(duration: 300.ms),

          const SizedBox(height: AppDesignSystem.spacingM),

          Text('Turno de',
              style: AppDesignSystem.bodyLarge(
                  context, color: t.textSecondary)),
          Text(
            _names[_turn],
            style: AppDesignSystem.displayMedium(context, color: color),
          ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

          const SizedBox(height: 6),
          Text(
            '${runner.title} · $locEmoji $loc · ${_positions[_turn]}/$_finishLine',
            style: AppDesignSystem.labelMedium(
                context, color: t.textSecondary),
          ).animate().fadeIn(delay: 300.ms, duration: 300.ms),
          const SizedBox(height: 4),
          Text(
            'Pasa el celular',
            style: AppDesignSystem.labelSmall(
                context,
                color: t.textSecondary.withOpacity(0.5)),
          ),

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _beginQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_arrow_rounded, size: 24),
                  const SizedBox(width: 8),
                  Text('¡Adelante, ${_names[_turn]}!'),
                ],
              ),
            ),
          )
              .animate()
              .slideY(begin: 0.3, duration: 400.ms, delay: 200.ms)
              .fadeIn(),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // QUESTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildQuestion(AppThemeData t) {
    final q = _q!;
    final runner = _currentRunner;
    final color = runner.color;

    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _epicRaceTrack(t),
          const SizedBox(height: AppDesignSystem.spacingM),

          // ── Timer ──
          Row(
            children: [
              Text(runner.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: _remaining <= 5
                    ? AppDesignSystem.struggle
                    : t.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                '$_remaining s',
                style: AppDesignSystem.labelLarge(
                  context,
                  color: _remaining <= 5
                      ? AppDesignSystem.struggle
                      : t.textPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _remaining / _timePerQuestion,
                    minHeight: 6,
                    backgroundColor: t.cardBg,
                    valueColor: AlwaysStoppedAnimation(
                      _remaining <= 5
                          ? AppDesignSystem.struggle
                          : color,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppDesignSystem.spacingM),

          // ── Pregunta ──
          Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: BoxDecoration(
              color: t.cardBg,
              borderRadius:
                  BorderRadius.circular(AppDesignSystem.radiusL),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Text(
              q.prompt,
              style: AppDesignSystem.headlineSmall(
                  context, color: t.textPrimary),
            ),
          ),

          const SizedBox(height: AppDesignSystem.spacingS),

          // ── Opciones ──
          Expanded(
            child: ListView.builder(
              itemCount: q.options.length,
              itemBuilder: (context, i) {
                Color border = t.divider;
                Color bg = t.cardBg;
                if (_answered) {
                  if (i == q.correctIndex) {
                    border = AppDesignSystem.victory;
                    bg = AppDesignSystem.victory.withOpacity(0.10);
                  } else if (i == _selected) {
                    border = AppDesignSystem.struggle;
                    bg = AppDesignSystem.struggle.withOpacity(0.10);
                  }
                } else if (i == _selected) {
                  border = color;
                  bg = color.withOpacity(0.10);
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                        AppDesignSystem.radiusM),
                    onTap:
                        _answered ? null : () => _lockAnswer(i),
                    child: Container(
                      padding: const EdgeInsets.all(
                          AppDesignSystem.spacingM),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(
                            AppDesignSystem.radiusM),
                        border:
                            Border.all(color: border, width: 1.5),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              q.options[i],
                              style: AppDesignSystem.bodyLarge(
                                  context,
                                  color: t.textPrimary),
                            ),
                          ),
                          if (_answered &&
                              i == q.correctIndex)
                            const Icon(
                                Icons.check_circle_rounded,
                                color: AppDesignSystem.victory),
                          if (_answered &&
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

  // ═══════════════════════════════════════════════════════════════════════════
  // TURN RESULT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildTurnResult(AppThemeData t) {
    final runner = _currentRunner;
    final loc = _locationFor(_positions[_turn]);
    final locEmoji = _locationEmoji(_positions[_turn]);
    final nextRunner = _turn == 0 ? _p2Runner : _p1Runner;

    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        children: [
          _epicRaceTrack(t),
          const Spacer(),

          if (_wasCorrect) ...[
            // ── Correcto ──
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppDesignSystem.victory.withOpacity(0.3),
                    AppDesignSystem.victory.withOpacity(0.05),
                  ],
                ),
              ),
              child: Center(
                child: Text(runner.emoji,
                    style: const TextStyle(fontSize: 50)),
              ),
            )
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              _advance == 3 ? '🔥 ¡Velocista!' : '⚡ ¡Correcto!',
              style: AppDesignSystem.headlineMedium(
                  context, color: AppDesignSystem.gold),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 6),
            Text(
              '+$_advance casillas → $locEmoji $loc (${_positions[_turn]}/$_finishLine)',
              style: AppDesignSystem.bodyLarge(
                  context, color: t.textSecondary),
            ),
          ] else ...[
            // ── Incorrecto ──
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppDesignSystem.struggle.withOpacity(0.1),
              ),
              child: Center(
                child: Text(runner.emoji,
                    style: const TextStyle(fontSize: 50)),
              ),
            )
                .animate()
                .shake(hz: 3, duration: 500.ms)
                .fadeIn(duration: 300.ms),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              '❌ ${_names[_turn]} no avanza',
              style: AppDesignSystem.headlineMedium(
                  context, color: AppDesignSystem.struggle),
            ),
            const SizedBox(height: 6),
            Text(
              'Sigues en $locEmoji $loc (${_positions[_turn]}/$_finishLine)',
              style: AppDesignSystem.bodyLarge(
                  context, color: t.textSecondary),
            ),
          ],

          const Spacer(),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: _nextTurn,
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text('Turno de ${_names[1 - _turn]}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: nextRunner.color,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                textStyle: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FINISHED — Celebración de victoria
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFinished(AppThemeData t) {
    final winner = _winnerIdx == 0 ? _p1Runner : _p2Runner;

    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        children: [
          _epicRaceTrack(t),
          const Spacer(),

          // ── Trofeo + Personaje ──
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppDesignSystem.gold.withOpacity(0.3),
                      AppDesignSystem.gold.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
              Column(
                children: [
                  Text(winner.emoji,
                      style: const TextStyle(fontSize: 64)),
                  const Text('🏆',
                      style: TextStyle(fontSize: 48)),
                ],
              ),
            ],
          )
              .animate()
              .scale(
                  begin: const Offset(0.3, 0.3),
                  duration: 600.ms,
                  curve: Curves.elasticOut)
              .fadeIn(duration: 300.ms),

          const SizedBox(height: AppDesignSystem.spacingM),

          Text(
            '¡${_names[_winnerIdx]} llega a Jerusalén!',
            style: AppDesignSystem.displaySmall(
                context, color: AppDesignSystem.gold),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

          const SizedBox(height: 8),

          // ── Marcadores ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _scoreChip(
                  _p1Runner, _names[0], _positions[0], _winnerIdx == 0),
              const SizedBox(width: 16),
              Text('vs',
                  style: AppDesignSystem.bodyLarge(
                      context, color: t.textSecondary)),
              const SizedBox(width: 16),
              _scoreChip(
                  _p2Runner, _names[1], _positions[1], _winnerIdx == 1),
            ],
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

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
                      borderRadius: BorderRadius.circular(
                          AppDesignSystem.radiusFull),
                    ),
                  ),
                  child: Text('Salir',
                      style: TextStyle(color: t.textSecondary)),
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: ElevatedButton(
                  onPressed: _resetAll,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.gold,
                    foregroundColor: Colors.black,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AppDesignSystem.radiusFull),
                    ),
                  ),
                  child: const Text('⚔ Revancha'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scoreChip(
      _BiblicalRunner runner, String name, int pos, bool isWinner) {
    return Column(
      children: [
        Text(runner.emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(name,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color:
                  isWinner ? AppDesignSystem.gold : Colors.white70,
            )),
        Text('$pos/$_finishLine',
            style: TextStyle(
              fontSize: 12,
              color:
                  isWinner ? AppDesignSystem.gold : Colors.white54,
            )),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PISTA ÉPICA — "Camino a Jerusalén"
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _epicRaceTrack(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: const Color(0xFF2A2A4E)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Título ──
          Text(
            'CAMINO A JERUSALÉN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFD4A574).withOpacity(0.7),
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),

          // ── Carriles ──
          _epicLane(t, 0),
          const SizedBox(height: 8),
          _epicLane(t, 1),
          const SizedBox(height: 10),

          // ── Hitos ──
          _milestoneRow(),
        ],
      ),
    );
  }

  Widget _epicLane(AppThemeData t, int playerIdx) {
    final runner = playerIdx == 0 ? _p1Runner : _p2Runner;
    final pos = _positions[playerIdx];
    final pct = pos / _finishLine;
    final name = _names.length > playerIdx
        ? _names[playerIdx]
        : runner.name;
    final isCurrent = _phase != _Phase.setup &&
        _phase != _Phase.finished &&
        playerIdx == _turn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(runner.emoji, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              name,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    isCurrent ? FontWeight.w700 : FontWeight.w500,
                color: isCurrent ? runner.color : Colors.white70,
              ),
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: runner.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$pos/$_finishLine',
                style: TextStyle(
                  fontSize: 11,
                  color: runner.color.withOpacity(0.9),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            const runnerSize = 34.0;
            final runnerX =
                (w - runnerSize) * pct.clamp(0.0, 1.0);

            return SizedBox(
              height: 40,
              child: Stack(
                children: [
                  // ── Pista base ──
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A4E),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),

                  // ── Progreso ──
                  Positioned(
                    left: 0,
                    top: 16,
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 8,
                      width: w * pct.clamp(0.0, 1.0),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            runner.color.withOpacity(0.3),
                            runner.color,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: [
                          BoxShadow(
                            color: runner.color.withOpacity(0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Puntos de hito ──
                  for (final m in _kMilestones)
                    if (m.position > 0 && m.position < _finishLine)
                      Positioned(
                        left: (w - 8) *
                            (m.position / _finishLine),
                        top: 16,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: pos >= m.position
                                ? runner.color
                                : const Color(0xFF3A3A5E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF4A4A7E),
                              width: 1,
                            ),
                          ),
                        ),
                      ),

                  // ── Meta ──
                  const Positioned(
                    right: 0,
                    top: 4,
                    child: Text('✨',
                        style: TextStyle(fontSize: 18)),
                  ),

                  // ── Corredor ──
                  AnimatedPositioned(
                    duration:
                        const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    left: runnerX,
                    top: 3,
                    child: Container(
                      width: runnerSize,
                      height: runnerSize,
                      decoration: BoxDecoration(
                        color: runner.color.withOpacity(0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: runner.color.withOpacity(
                                isCurrent ? 0.6 : 0.3),
                            blurRadius: isCurrent ? 16 : 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(runner.emoji,
                            style: const TextStyle(
                                fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _milestoneRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _kMilestones.map((m) {
        return Column(
          children: [
            Text(m.emoji,
                style: const TextStyle(fontSize: 10)),
            Text(
              m.name,
              style: TextStyle(
                fontSize: 7,
                color:
                    const Color(0xFFD4A574).withOpacity(0.6),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFETTI
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _confettiOverlay() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _confettiCtrl,
        builder: (context, _) {
          final size = MediaQuery.of(context).size;
          return CustomPaint(
            size: size,
            painter: _ConfettiPainter(_confettiCtrl.value),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CONFETTI PAINTER
// ═══════════════════════════════════════════════════════════════════════════

class _ConfettiPainter extends CustomPainter {
  final double t;
  _ConfettiPainter(this.t);

  static const _colors = [
    Color(0xFFFFD700),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF45B7D1),
    Color(0xFFF9CA24),
    Color(0xFFA29BFE),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final rng = Random(42);

    for (int i = 0; i < 60; i++) {
      final x0 = rng.nextDouble() * size.width;
      final speed = 0.6 + rng.nextDouble() * 0.8;
      final delay = rng.nextDouble() * 0.3;

      final localT = ((t - delay) / speed).clamp(0.0, 1.0);
      if (localT <= 0) continue;

      final y = -20 + (size.height + 40) * localT;
      final wobble = sin(localT * 8 * pi + i) * (15 + rng.nextDouble() * 20);

      final opacity = localT < 0.8 ? 1.0 : (1.0 - (localT - 0.8) / 0.2);

      final paint = Paint()
        ..color = _colors[rng.nextInt(_colors.length)]
            .withOpacity(opacity.clamp(0.0, 1.0));

      final w = 4.0 + rng.nextDouble() * 8;
      final h = 2.0 + rng.nextDouble() * 6;

      canvas.save();
      canvas.translate(x0 + wobble, y);
      canvas.rotate(localT * (2 + rng.nextDouble() * 8));
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => true;
}
