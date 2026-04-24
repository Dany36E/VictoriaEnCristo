/// ═══════════════════════════════════════════════════════════════════════════
/// BookDetailScreen — ficha del libro + mini-quiz de 3 preguntas.
/// Quiz generado runtime a partir de los metadatos + libros cercanos.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/book_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/book_progress_service.dart';
import '../../services/learning/book_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class BookDetailScreen extends StatefulWidget {
  final BibleBook book;
  const BookDetailScreen({super.key, required this.book});

  @override
  State<BookDetailScreen> createState() => _BookDetailScreenState();
}

class _Question {
  final String text;
  final List<String> options;
  final int correct;
  _Question(this.text, this.options, this.correct);
}

class _BookDetailScreenState extends State<BookDetailScreen> {
  late List<_Question> _quiz;
  int _current = 0;
  int _correct = 0;
  bool _showQuiz = false;
  int? _selected;
  bool _done = false;
  int _awardedXp = 0;

  BibleBook get b => widget.book;

  @override
  void initState() {
    super.initState();
    _quiz = _buildQuiz();
  }

  List<_Question> _buildQuiz() {
    final rnd = Random(b.order);
    final others = BookRepository.I.all.where((x) => x.id != b.id).toList();

    // Pregunta 1: categoría
    final catOthers = (others.map((x) => x.category).toSet().toList()
          ..removeWhere((c) => c == b.category))
        .take(3)
        .toList();
    final opts1 = [b.category, ...catOthers]..shuffle(rnd);
    final q1 = _Question(
      '¿A qué categoría pertenece ${b.name}?',
      opts1,
      opts1.indexOf(b.category),
    );

    // Pregunta 2: capítulos (rango cercano)
    final correctCh = b.chapters.toString();
    final distractorsCh = <String>{};
    while (distractorsCh.length < 3) {
      final delta = rnd.nextInt(9) - 4;
      final v = b.chapters + delta;
      if (v > 0 && v != b.chapters) distractorsCh.add(v.toString());
    }
    final opts2 = [correctCh, ...distractorsCh]..shuffle(rnd);
    final q2 = _Question(
      '¿Cuántos capítulos tiene ${b.name}?',
      opts2,
      opts2.indexOf(correctCh),
    );

    // Pregunta 3: versículo clave → libro
    final othersForVerse = others.toList()..shuffle(rnd);
    final opts3 = [
      b.name,
      ...othersForVerse.take(3).map((x) => x.name),
    ]..shuffle(rnd);
    final q3 = _Question(
      '¿De qué libro es este versículo clave?\n"${b.keyVerse}"',
      opts3,
      opts3.indexOf(b.name),
    );

    return [q1, q2, q3];
  }

  Future<void> _answer(int idx) async {
    if (_selected != null) return;
    setState(() => _selected = idx);
    final isRight = idx == _quiz[_current].correct;
    FeedbackEngine.I.confirm();
    if (isRight) _correct++;
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    if (_current + 1 >= _quiz.length) {
      final xp = await BookProgressService.I.completeBook(
        bookId: b.id,
        score: _correct,
        xpReward: b.xpReward,
      );
      if (!mounted) return;
      setState(() {
        _done = true;
        _awardedXp = xp;
      });
    } else {
      setState(() {
        _current++;
        _selected = null;
      });
    }
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
          b.name,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: _showQuiz ? _buildQuizBody(t) : _buildInfoBody(t),
    );
  }

  Widget _buildInfoBody(AppThemeData t) {
    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      children: [
        _banner(t),
        const SizedBox(height: AppDesignSystem.spacingM),
        _factGrid(t),
        const SizedBox(height: AppDesignSystem.spacingM),
        _verseCard(t),
        const SizedBox(height: AppDesignSystem.spacingM),
        _summaryCard(t),
        const SizedBox(height: AppDesignSystem.spacingL),
        SizedBox(
          width: double.infinity,
          child: PremiumButton(
            onPressed: () {
              FeedbackEngine.I.tap();
              setState(() => _showQuiz = true);
            },
            child: const Text('Comenzar mini-quiz (3 preguntas)'),
          ),
        ),
        const SizedBox(height: AppDesignSystem.spacingXL),
      ],
    );
  }

  Widget _banner(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3A2A10), Color(0xFF6B4E20)],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '#${b.order}',
              style: AppDesignSystem.headlineSmall(context,
                  color: AppDesignSystem.gold),
            ),
          ),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  style: AppDesignSystem.headlineMedium(context,
                      color: t.textPrimary),
                ),
                Text(
                  '${b.testament == 'AT' ? 'Antiguo' : 'Nuevo'} Testamento · ${b.category}',
                  style: AppDesignSystem.labelMedium(context,
                      color: AppDesignSystem.gold),
                ),
                const SizedBox(height: 6),
                Text(
                  b.theme,
                  style: AppDesignSystem.bodyMedium(context,
                      color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _factGrid(AppThemeData t) {
    return Row(
      children: [
        _fact(t, 'Autor', b.author, Icons.person_rounded),
        const SizedBox(width: 8),
        _fact(t, 'Fecha', b.date, Icons.calendar_today_rounded),
        const SizedBox(width: 8),
        _fact(t, 'Caps.', '${b.chapters}', Icons.menu_book_rounded),
      ],
    );
  }

  Widget _fact(AppThemeData t, String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(color: t.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppDesignSystem.gold, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppDesignSystem.labelSmall(context,
                  color: t.textSecondary),
            ),
            Text(
              value,
              textAlign: TextAlign.center,
              style: AppDesignSystem.labelMedium(context,
                  color: t.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _verseCard(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Versículo clave · ${b.keyVerseRef}',
            style: AppDesignSystem.labelSmall(context,
                color: AppDesignSystem.gold),
          ),
          const SizedBox(height: 6),
          Text(
            '"${b.keyVerse}"',
            style: AppDesignSystem.scripture(context,
                color: t.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: t.cardBorder),
      ),
      child: Text(
        b.summary,
        style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
      ),
    );
  }

  Widget _buildQuizBody(AppThemeData t) {
    if (_done) {
      return Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_stories_rounded,
                    color: AppDesignSystem.gold, size: 72)
                .animate()
                .scale(
                    begin: const Offset(0.4, 0.4),
                    duration: 400.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              '$_correct / ${_quiz.length} correctas',
              style: AppDesignSystem.headlineMedium(context,
                  color: t.textPrimary),
            ),
            const SizedBox(height: 8),
            if (_awardedXp > 0)
              Text(
                '+$_awardedXp XP · ${b.name} añadido a tu biblioteca',
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(context,
                    color: AppDesignSystem.gold),
              )
            else
              Text(
                'Ya estudiaste ${b.name} antes — ¡sigue repasando!',
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(context,
                    color: t.textSecondary),
              ),
            const SizedBox(height: AppDesignSystem.spacingL),
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Volver a la estantería'),
              ),
            ),
          ],
        ),
      );
    }

    final q = _quiz[_current];
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: (_current + 1) / _quiz.length,
            backgroundColor: t.cardBg,
            valueColor:
                const AlwaysStoppedAnimation(AppDesignSystem.gold),
          ),
          const SizedBox(height: AppDesignSystem.spacingL),
          Text(
            'Pregunta ${_current + 1} de ${_quiz.length}',
            style: AppDesignSystem.labelMedium(context,
                color: AppDesignSystem.gold),
          ),
          const SizedBox(height: 8),
          Text(
            q.text,
            style: AppDesignSystem.headlineSmall(context,
                color: t.textPrimary),
          ),
          const SizedBox(height: AppDesignSystem.spacingL),
          ...List.generate(q.options.length, (i) {
            final isSelected = _selected == i;
            final isCorrect = i == q.correct;
            Color? bg;
            Color? border;
            if (_selected != null) {
              if (isCorrect) {
                bg = const Color(0x334CAF50);
                border = const Color(0xFF4CAF50);
              } else if (isSelected) {
                bg = const Color(0x33F44336);
                border = const Color(0xFFF44336);
              }
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => _answer(i),
                borderRadius:
                    BorderRadius.circular(AppDesignSystem.radiusM),
                child: Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  decoration: BoxDecoration(
                    color: bg ?? t.cardBg,
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusM),
                    border: Border.all(
                      color: border ?? t.cardBorder,
                      width: border != null ? 2 : 1,
                    ),
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
                      if (_selected != null && isCorrect)
                        const Icon(Icons.check_rounded,
                            color: Color(0xFF4CAF50)),
                      if (_selected != null && isSelected && !isCorrect)
                        const Icon(Icons.close_rounded,
                            color: Color(0xFFF44336)),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
