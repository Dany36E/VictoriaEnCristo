/// ═══════════════════════════════════════════════════════════════════════════
/// BibleOrderLearnScreen — Aprende el orden de los libros progresivamente.
///
/// Método didáctico basado en:
///   • Chunking (Miller's Law): grupos de 3-4 libros a la vez.
///   • Active recall inmediato: tras ver el grupo, practica con mini-quiz.
///   • Expansión acumulativa: cada ronda incluye los grupos anteriores.
///   • Feedback de posición: colores verde/rojo + badge de posición canónica.
///
/// Flujo por chunk:
///   1. REVEAL — muestra los libros en orden, con posición y tema breve.
///   2. QUIZ   — tap en orden correcto (solo los libros del chunk acumulado).
///   3. RESULTADO — aciertos, siguiente chunk o fin.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/book_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/bible_order_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

/// Tamaño del chunk inicial. Ajustable sin cambiar lógica.
const int _chunkSize = 4;

enum _LearnPhase { reveal, quiz, result }

class BibleOrderLearnScreen extends StatefulWidget {
  final String categoryKey;
  final String title;
  final List<BibleBook> books;

  const BibleOrderLearnScreen({
    super.key,
    required this.categoryKey,
    required this.title,
    required this.books,
  });

  @override
  State<BibleOrderLearnScreen> createState() => _BibleOrderLearnScreenState();
}

class _BibleOrderLearnScreenState extends State<BibleOrderLearnScreen> {
  /// Libros en orden canónico.
  late List<BibleBook> _canonical;

  /// Índice del chunk actual (0-based). Un chunk son _chunkSize libros nuevos.
  int _chunkIdx = 0;

  _LearnPhase _phase = _LearnPhase.reveal;

  /// Cuántos libros del pool acumulado se muestran en el quiz actual.
  /// Siempre = min(_poolSize, _canonical.length).
  int get _poolSize => ((_chunkIdx + 1) * _chunkSize).clamp(1, _canonical.length);

  /// Libros del pool actual (acumulado hasta el chunk actual).
  List<BibleBook> get _pool => _canonical.sublist(0, _poolSize);

  /// Solo los libros nuevos de este chunk (para el reveal).
  List<BibleBook> get _newBooks {
    final start = _chunkIdx * _chunkSize;
    final end = _poolSize;
    return _canonical.sublist(start, end);
  }

  // Estado del quiz
  List<int> _shuffled = []; // índices sobre _pool, barajados
  final List<int> _picked = []; // índices canónicos que el usuario tocó
  final Set<int> _errors = {};

  // Resultado del chunk
  int _quizErrors = 0;
  int _totalXpEarned = 0;

  // Índice del libro que se está mostrando en reveal (animación uno a uno)
  int _revealIdx = 0;
  bool _revealDone = false;

  @override
  void initState() {
    super.initState();
    _canonical = [...widget.books]..sort((a, b) => a.order.compareTo(b.order));
    AudioEngine.I.switchBgmContext(BgmContext.learningBibleOrder);
    _startReveal();
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.learningBibleOrder);
    super.dispose();
  }

  // ── REVEAL ────────────────────────────────────────────────────────────────

  void _startReveal() {
    _revealIdx = 0;
    _revealDone = false;
    setState(() => _phase = _LearnPhase.reveal);
  }

  void _revealNext() {
    FeedbackEngine.I.tap();
    if (_revealIdx < _newBooks.length - 1) {
      setState(() => _revealIdx++);
    } else {
      setState(() => _revealDone = true);
    }
  }

  void _startQuiz() {
    FeedbackEngine.I.confirm();
    _picked.clear();
    _errors.clear();
    _quizErrors = 0;
    _shuffled = List.generate(_pool.length, (i) => i)..shuffle(Random());
    if (_pool.length > 2 && _listEq(_shuffled, List.generate(_pool.length, (i) => i))) {
      _shuffled = _shuffled.reversed.toList();
    }
    setState(() => _phase = _LearnPhase.quiz);
  }

  // ── QUIZ ──────────────────────────────────────────────────────────────────

  void _onTap(int canonicalIdx) {
    if (_picked.contains(canonicalIdx)) return;
    final expected = _picked.length;
    final correct = canonicalIdx == expected;
    setState(() {
      _picked.add(canonicalIdx);
      if (!correct) {
        _errors.add(canonicalIdx);
        _quizErrors++;
      }
    });
    if (correct) {
      FeedbackEngine.I.confirm();
    } else {
      FeedbackEngine.I.tap();
    }
    if (_picked.length == _pool.length) {
      _finishQuiz();
    }
  }

  Future<void> _finishQuiz() async {
    final total = _pool.length;
    final errCount = _errors.length;
    int stars;
    if (errCount == 0) {
      stars = 3;
    } else if (errCount <= (total * 0.25).ceil()) {
      stars = 2;
    } else {
      stars = 1;
    }
    // Solo registra XP en chunks completados
    final xp = await BibleOrderProgressService.I.recordRound(
      categoryKey: '${widget.categoryKey}_chunk$_chunkIdx',
      stars: stars,
    );
    if (!mounted) return;
    setState(() {
      _totalXpEarned += xp;
      _phase = _LearnPhase.result;
    });
  }

  bool _listEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  // ── NAVEGACIÓN ────────────────────────────────────────────────────────────

  bool get _isLastChunk => _poolSize >= _canonical.length;

  void _nextChunk() {
    FeedbackEngine.I.confirm();
    setState(() {
      _chunkIdx++;
      _picked.clear();
      _errors.clear();
    });
    _startReveal();
  }

  void _repeatChunk() {
    FeedbackEngine.I.tap();
    _startQuiz();
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────

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
          widget.title,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                'Grupo ${_chunkIdx + 1}/${((_canonical.length - 1) ~/ _chunkSize) + 1}',
                style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _LearnPhase.reveal => _buildReveal(t),
          _LearnPhase.quiz => _buildQuiz(t),
          _LearnPhase.result => _buildResult(t),
        },
      ),
    );
  }

  // ── PHASE: REVEAL ─────────────────────────────────────────────────────────

  Widget _buildReveal(AppThemeData t) {
    final book = _newBooks[_revealIdx];
    final canonicalPos = _canonical.indexOf(book) + 1; // 1-based position in full list
    final poolPos = _pool.indexOf(book) + 1; // position within current pool

    return Column(
      children: [
        // Progress: which book in the reveal sequence
        LinearProgressIndicator(
          value: (_revealIdx + 1) / _newBooks.length,
          minHeight: 4,
          backgroundColor: t.surface,
          valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Instruction label
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spacingM,
                    vertical: AppDesignSystem.spacingS,
                  ),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gold.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.visibility_rounded, color: AppDesignSystem.gold, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _revealDone
                              ? '¡Memorizaste estos ${_newBooks.length} libros! ¿Listo para practicar?'
                              : 'Aprende la posición ${_revealIdx < _newBooks.length - 1 ? "de este libro" : "del último"}',
                          style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingL),

                if (!_revealDone) ...[
                  // Book card — main reveal
                  Expanded(
                    child: _BookRevealCard(
                      book: book,
                      position: canonicalPos,
                      poolPosition: poolPos,
                      totalInPool: _pool.length,
                      context_: context,
                      t: t,
                    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),
                  // Mini-list: todos los libros del pool conocidos hasta ahora
                  _PreviousBooksMini(
                    knownBooks: _pool.sublist(0, _pool.indexOf(book)),
                    currentBook: book,
                    t: t,
                    context_: context,
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),
                  // Next / Done button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _revealNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                        ),
                      ),
                      child: Text(
                        _revealIdx < _newBooks.length - 1
                            ? 'Siguiente libro →'
                            : '¡Ya los aprendí!',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                    ),
                  ),
                ] else ...[
                  // Summary: all new books in order
                  Expanded(
                    child: _AllNewBooksSummary(
                      pool: _pool,
                      newBooks: _newBooks,
                      t: t,
                      context_: context,
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingL),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _startQuiz,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text(
                        'Practicar ahora',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppDesignSystem.gold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── PHASE: QUIZ ───────────────────────────────────────────────────────────

  Widget _buildQuiz(AppThemeData t) {
    final pct = _pool.isEmpty ? 0.0 : _picked.length / _pool.length;
    return Column(
      children: [
        LinearProgressIndicator(
          value: pct,
          minHeight: 4,
          backgroundColor: t.surface,
          valueColor: AlwaysStoppedAnimation(
            _errors.isEmpty ? AppDesignSystem.victory : AppDesignSystem.gold,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          child: Text(
            'Toca los libros en orden correcto (${_picked.length}/${_pool.length}):',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDesignSystem.spacingM,
              vertical: AppDesignSystem.spacingS,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _pool.length > 12 ? 4 : 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.6,
            ),
            itemCount: _pool.length,
            itemBuilder: (context, gridIdx) {
              final canonicalIdx = _shuffled[gridIdx];
              final book = _pool[canonicalIdx];
              final pickedPos = _picked.indexOf(canonicalIdx);
              final isPicked = pickedPos >= 0;
              final isError = _errors.contains(canonicalIdx);

              Color borderColor = t.divider;
              Color bgColor = t.cardBg;

              if (isPicked) {
                if (isError) {
                  borderColor = AppDesignSystem.struggle;
                  bgColor = AppDesignSystem.struggle.withOpacity(0.08);
                } else {
                  borderColor = AppDesignSystem.gold;
                  bgColor = AppDesignSystem.gold.withOpacity(0.08);
                }
              }

              return InkWell(
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                onTap: (isPicked) ? null : () => _onTap(canonicalIdx),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    border: Border.all(color: borderColor, width: isPicked ? 2 : 1),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                book.name,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                style: TextStyle(
                                  color: isPicked ? t.textPrimary.withOpacity(0.85) : t.textPrimary,
                                  fontWeight: isPicked ? FontWeight.w500 : FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (isPicked)
                        Positioned(
                          top: -2,
                          left: -2,
                          child: Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: isError ? AppDesignSystem.struggle : AppDesignSystem.gold,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '${pickedPos + 1}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── PHASE: RESULT ─────────────────────────────────────────────────────────

  Widget _buildResult(AppThemeData t) {
    final perfect = _quizErrors == 0;
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Icon(
            perfect ? Icons.emoji_events_rounded : Icons.refresh_rounded,
            size: 80,
            color: perfect ? AppDesignSystem.gold : t.textSecondary,
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            perfect
                ? '¡Sin errores!'
                : _quizErrors == 1
                ? '¡Casi perfecto!'
                : '$_quizErrors ${_quizErrors == 1 ? "error" : "errores"}',
            textAlign: TextAlign.center,
            style: AppDesignSystem.displaySmall(context, color: t.textPrimary),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            perfect
                ? 'Excelente. Ahora estos libros están grabados en tu mente.'
                : 'No pasa nada, la repetición es parte del aprendizaje.',
            textAlign: TextAlign.center,
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ).animate().fadeIn(delay: 300.ms),
          if (_totalXpEarned > 0) ...[
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              '+$_totalXpEarned XP',
              textAlign: TextAlign.center,
              style: AppDesignSystem.headlineMedium(context, color: AppDesignSystem.gold),
            ).animate().fadeIn(delay: 400.ms),
          ],
          const SizedBox(height: AppDesignSystem.spacingL),
          // Correct order display
          _CorrectOrderMini(pool: _pool, errors: _errors, t: t, context_: context),
          const Spacer(),
          // Buttons
          if (!perfect) ...[
            SizedBox(
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _repeatChunk,
                icon: const Icon(Icons.replay_rounded),
                label: const Text('Repetir este grupo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: t.textPrimary,
                  side: BorderSide(color: t.cardBorder),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
          ],
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLastChunk ? () => Navigator.pop(context) : _nextChunk,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppDesignSystem.gold,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
              ),
              child: Text(
                _isLastChunk ? '¡Terminé!' : 'Siguiente grupo →',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ────────────────────────────────────────────────────────────

class _BookRevealCard extends StatelessWidget {
  final BibleBook book;
  final int position; // posición canónica (1-based, en la lista completa)
  final int poolPosition; // posición en el pool actual (1-based)
  final int totalInPool;
  final BuildContext context_;
  final AppThemeData t;

  const _BookRevealCard({
    required this.book,
    required this.position,
    required this.poolPosition,
    required this.totalInPool,
    required this.context_,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppDesignSystem.gold.withOpacity(0.12), AppDesignSystem.gold.withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.4), width: 1.5),
      ),
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Position badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                  border: Border.all(color: AppDesignSystem.gold.withOpacity(0.5)),
                ),
                child: Text(
                  '#$position de 66',
                  style: AppDesignSystem.labelMedium(context_, color: AppDesignSystem.gold),
                ),
              ),
              const Spacer(),
              Text(
                book.testament,
                style: AppDesignSystem.labelSmall(context_, color: t.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          // Book name
          Text(book.name, style: AppDesignSystem.displaySmall(context_, color: t.textPrimary)),
          const SizedBox(height: 4),
          Text(book.category, style: AppDesignSystem.labelMedium(context_, color: t.textSecondary)),
          if (book.theme.isNotEmpty) ...[
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              book.theme,
              style: AppDesignSystem.bodyMedium(context_, color: t.textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (book.keyVerseRef.isNotEmpty) ...[
            const SizedBox(height: AppDesignSystem.spacingS),
            Row(
              children: [
                const Icon(Icons.bookmark_rounded, color: AppDesignSystem.gold, size: 16),
                const SizedBox(width: 4),
                Text(book.keyVerseRef, style: AppDesignSystem.scriptureReference(context_)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini lista de libros ya vistos (antes del actual)
class _PreviousBooksMini extends StatelessWidget {
  final List<BibleBook> knownBooks;
  final BibleBook currentBook;
  final AppThemeData t;
  final BuildContext context_;

  const _PreviousBooksMini({
    required this.knownBooks,
    required this.currentBook,
    required this.t,
    required this.context_,
  });

  @override
  Widget build(BuildContext context) {
    if (knownBooks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Posición en el grupo:',
          style: AppDesignSystem.labelSmall(context_, color: t.textSecondary),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ...knownBooks.asMap().entries.map(
              (e) => _miniChip(e.value.name, e.key + 1, false, context_),
            ),
            _miniChip(currentBook.name, knownBooks.length + 1, true, context_),
          ],
        ),
      ],
    );
  }

  Widget _miniChip(String name, int pos, bool isCurrent, BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isCurrent ? AppDesignSystem.gold.withOpacity(0.15) : t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(
          color: isCurrent ? AppDesignSystem.gold.withOpacity(0.6) : t.cardBorder,
          width: isCurrent ? 1.5 : 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$pos. ',
            style: AppDesignSystem.labelSmall(
              ctx,
              color: isCurrent ? AppDesignSystem.gold : t.textSecondary,
            ),
          ),
          Text(
            name,
            style: AppDesignSystem.labelSmall(
              ctx,
              color: isCurrent ? t.textPrimary : t.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Summary de todos los libros del pool (reveal done)
class _AllNewBooksSummary extends StatelessWidget {
  final List<BibleBook> pool;
  final List<BibleBook> newBooks;
  final AppThemeData t;
  final BuildContext context_;

  const _AllNewBooksSummary({
    required this.pool,
    required this.newBooks,
    required this.t,
    required this.context_,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: pool.length,
      itemBuilder: (context, i) {
        final book = pool[i];
        final isNew = newBooks.contains(book);
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isNew ? AppDesignSystem.gold.withOpacity(0.10) : t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border: Border.all(
              color: isNew ? AppDesignSystem.gold.withOpacity(0.5) : t.cardBorder,
              width: isNew ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isNew ? AppDesignSystem.gold : t.textSecondary.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${i + 1}',
                    style: TextStyle(
                      color: isNew ? Colors.black : t.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  book.name,
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: isNew ? t.textPrimary : t.textSecondary,
                  ),
                ),
              ),
              if (isNew)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.gold.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                  ),
                  child: Text(
                    'Nuevo',
                    style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Mini resumen del orden correcto al final
class _CorrectOrderMini extends StatelessWidget {
  final List<BibleBook> pool;
  final Set<int> errors; // índices canónicos con error
  final AppThemeData t;
  final BuildContext context_;

  const _CorrectOrderMini({
    required this.pool,
    required this.errors,
    required this.t,
    required this.context_,
  });

  @override
  Widget build(BuildContext context) {
    if (errors.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Orden correcto:',
          style: AppDesignSystem.labelMedium(context_, color: t.textSecondary),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: pool.asMap().entries.map((e) {
            final hasError = errors.contains(e.key);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: hasError
                    ? AppDesignSystem.struggle.withOpacity(0.10)
                    : AppDesignSystem.victory.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                border: Border.all(
                  color: hasError
                      ? AppDesignSystem.struggle.withOpacity(0.5)
                      : AppDesignSystem.victory.withOpacity(0.4),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${e.key + 1}. ',
                    style: AppDesignSystem.labelSmall(
                      context_,
                      color: hasError ? AppDesignSystem.struggle : AppDesignSystem.victory,
                    ),
                  ),
                  Text(
                    e.value.name,
                    style: AppDesignSystem.labelSmall(context_, color: t.textPrimary),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
