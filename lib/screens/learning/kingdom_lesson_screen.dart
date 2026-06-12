library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/learning/kingdom_models.dart';
import '../../services/audio_engine.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/kingdom_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class KingdomLessonScreen extends StatefulWidget {
  final LearningLesson lesson;

  const KingdomLessonScreen({super.key, required this.lesson});

  @override
  State<KingdomLessonScreen> createState() => _KingdomLessonScreenState();
}

class _KingdomLessonScreenState extends State<KingdomLessonScreen> {
  final Map<String, int> _answers = {};
  bool _saving = false;

  LearningLesson get lesson => widget.lesson;

  @override
  void initState() {
    super.initState();
    AudioEngine.I.switchBgmContext(BgmContext.bible);
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final progress = _progressValue;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Lección bíblica',
          style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: t.cardBorder,
            valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          children: [
            _HeroCard(lesson: lesson),
            const SizedBox(height: AppDesignSystem.spacingM),
            if (lesson.baseTextRefs.isNotEmpty)
              _ScriptureRefsCard(refs: lesson.baseTextRefs),
            if (lesson.keyVerseRef.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              _ScriptureRefsCard(
                refs: [lesson.keyVerseRef],
                title: 'Versículo clave',
                icon: Icons.bookmark_rounded,
              ),
            ],
            if (lesson.contextNote.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              _InfoCard(
                icon: Icons.travel_explore_rounded,
                title: 'Contexto',
                body: lesson.contextNote,
              ),
            ],
            if (lesson.doctrinePoint.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              _InfoCard(
                icon: Icons.lightbulb_rounded,
                title: 'Verdad central',
                body: lesson.doctrinePoint,
              ),
            ],
            if (lesson.christConnection.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              _InfoCard(
                icon: Icons.auto_awesome_rounded,
                title: 'Conexión con Cristo',
                body: lesson.christConnection,
              ),
            ],
            if (lesson.doctrinalCategory.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              _InfoCard(
                icon: Icons.account_tree_rounded,
                title: 'Categoría doctrinal',
                body: lesson.doctrinalCategory,
              ),
            ],
            if (lesson.commonErrors.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              _InfoCard(
                icon: Icons.warning_amber_rounded,
                title: 'Errores comunes a evitar',
                body: lesson.commonErrors.join('\n'),
              ),
            ],
            if (lesson.masteryCriteria.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingM),
              _InfoCard(
                icon: Icons.workspace_premium_rounded,
                title: 'Criterio de dominio',
                body: lesson.masteryCriteria,
              ),
            ],
            if (lesson.questions.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              const _SectionTitle('Comprensión'),
              const SizedBox(height: AppDesignSystem.spacingS),
              ...lesson.questions.map(_QuestionCard.new),
            ],
            if (lesson.quizItems.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              const _SectionTitle('Mini quiz'),
              const SizedBox(height: AppDesignSystem.spacingS),
              ...lesson.quizItems.map(_buildQuizCard),
            ],
            if (lesson.applicationPrompt.isNotEmpty) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              _InfoCard(
                icon: Icons.edit_note_rounded,
                title: 'Aplicación',
                body: lesson.applicationPrompt,
              ),
            ],
            if (lesson.hasReviewTrail) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              _InfoCard(
                icon: Icons.verified_user_rounded,
                title: 'Revisión teológica',
                body:
                    'Estado: ${_reviewStatusLabel(lesson.theologyReviewStatus)}\n'
                    'Revisado por: ${lesson.reviewedBy}\n'
                    'Fecha: ${lesson.reviewedAt}\n'
                    '${lesson.reviewNotes}',
              ),
            ],
            const SizedBox(height: AppDesignSystem.spacingL),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _canComplete && !_saving ? _completeLesson : null,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_rounded),
                label: Text(
                  _canComplete ? 'Completar lección' : 'Responde el quiz',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.gold,
                  foregroundColor: const Color(0xFF201603),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusM,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingL),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizCard(KingdomQuizItem item) {
    final selected = _answers[item.id];
    return _QuizCard(
      item: item,
      selectedIndex: selected,
      onSelected: (index) {
        FeedbackEngine.I.tap();
        setState(() => _answers[item.id] = index);
      },
    );
  }

  bool get _canComplete =>
      lesson.quizItems.isEmpty || _answers.length == lesson.quizItems.length;

  double get _progressValue {
    if (lesson.quizItems.isEmpty) return 0.7;
    return (_answers.length / lesson.quizItems.length).clamp(0, 1);
  }

  int get _score {
    if (lesson.quizItems.isEmpty) return 100;
    var correct = 0;
    for (final item in lesson.quizItems) {
      if (_answers[item.id] == item.correctIndex) correct++;
    }
    return ((correct / lesson.quizItems.length) * 100).round();
  }

  Future<void> _completeLesson() async {
    setState(() => _saving = true);
    final score = _score;
    await KingdomProgressService.I.markLessonCompleted(lesson.id, score: score);
    if (!mounted) return;
    FeedbackEngine.I.confirm();
    setState(() => _saving = false);
    await showDialog<void>(
      context: context,
      builder: (context) => _LessonResultDialog(score: score),
    );
    if (mounted) Navigator.pop(context);
  }
}

class _HeroCard extends StatelessWidget {
  final LearningLesson lesson;

  const _HeroCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, t.cardBg],
        ),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.24)),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            style: AppDesignSystem.headlineLarge(context, color: t.textPrimary),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            lesson.objective,
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Wrap(
            spacing: AppDesignSystem.spacingS,
            runSpacing: AppDesignSystem.spacingS,
            children: [
              _Chip('${lesson.estimatedMinutes} min'),
              _Chip(_practiceModeLabel(lesson.practiceMode)),
              _Chip(_reviewStatusLabel(lesson.theologyReviewStatus)),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.04, end: 0);
  }
}

class _ScriptureRefsCard extends StatelessWidget {
  final List<String> refs;
  final String title;
  final IconData icon;

  const _ScriptureRefsCard({
    required this.refs,
    this.title = 'Texto base RVR1960',
    this.icon = Icons.menu_book_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppDesignSystem.gold),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingS),
                FutureBuilder<List<_ResolvedScriptureRef>>(
                  future: _loadRefs(refs),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(minHeight: 3),
                      );
                    }
                    final resolved = snapshot.data ?? const [];
                    if (resolved.isEmpty) {
                      return Text(
                        refs.join(' | '),
                        style: AppDesignSystem.bodyMedium(
                          context,
                          color: t.textSecondary,
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final ref in resolved)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppDesignSystem.spacingS,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ref.label,
                                  style: AppDesignSystem.labelLarge(
                                    context,
                                    color: AppDesignSystem.gold,
                                  ),
                                ),
                                const SizedBox(
                                  height: AppDesignSystem.spacingXS,
                                ),
                                for (final verse in ref.verses)
                                  Text(
                                    '${verse.verse}. ${verse.text}',
                                    style: AppDesignSystem.bodyMedium(
                                      context,
                                      color: t.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<List<_ResolvedScriptureRef>> _loadRefs(List<String> refs) async {
    await BibleParserService.I.init();
    final resolved = <_ResolvedScriptureRef>[];
    for (final rawRef in refs) {
      final parsed = _ParsedScriptureRef.tryParse(rawRef);
      if (parsed == null) continue;
      final verses = await BibleParserService.I.getChapter(
        version: BibleVersion.rvr1960,
        bookNumber: parsed.bookNumber,
        chapter: parsed.chapter,
      );
      final selected = verses
          .where(
            (verse) =>
                verse.verse >= parsed.startVerse &&
                verse.verse <= parsed.endVerse,
          )
          .toList(growable: false);
      if (selected.isNotEmpty) {
        resolved.add(_ResolvedScriptureRef(label: rawRef, verses: selected));
      }
    }
    return resolved;
  }
}

class _ResolvedScriptureRef {
  final String label;
  final List<BibleVerse> verses;

  const _ResolvedScriptureRef({required this.label, required this.verses});
}

class _ParsedScriptureRef {
  final int bookNumber;
  final int chapter;
  final int startVerse;
  final int endVerse;

  const _ParsedScriptureRef({
    required this.bookNumber,
    required this.chapter,
    required this.startVerse,
    required this.endVerse,
  });

  static _ParsedScriptureRef? tryParse(String ref) {
    final match = RegExp(
      r'^(.+?)\s+(\d+):(\d+)(?:-(\d+))?$',
    ).firstMatch(ref.trim());
    if (match == null) return null;
    final book = _bookNumberFor(match.group(1)!);
    if (book == null) return null;
    final chapter = int.tryParse(match.group(2)!) ?? 0;
    final start = int.tryParse(match.group(3)!) ?? 0;
    final end = int.tryParse(match.group(4) ?? '') ?? start;
    if (chapter <= 0 || start <= 0 || end < start) return null;
    return _ParsedScriptureRef(
      bookNumber: book,
      chapter: chapter,
      startVerse: start,
      endVerse: end,
    );
  }

  static int? _bookNumberFor(String raw) {
    final normalized = _normalizeBook(raw);
    return _bookNumbers[normalized];
  }
}

String _normalizeBook(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  text = text.replaceAll(RegExp(r'\s+'), ' ');
  return text;
}

const Map<String, int> _bookNumbers = {
  'genesis': 1,
  'exodo': 2,
  'levitico': 3,
  'numeros': 4,
  'deuteronomio': 5,
  'josue': 6,
  'jueces': 7,
  'rut': 8,
  '1 samuel': 9,
  '2 samuel': 10,
  '1 reyes': 11,
  '2 reyes': 12,
  '1 cronicas': 13,
  '2 cronicas': 14,
  'esdras': 15,
  'nehemias': 16,
  'ester': 17,
  'job': 18,
  'salmos': 19,
  'salmo': 19,
  'proverbios': 20,
  'eclesiastes': 21,
  'cantares': 22,
  'isaias': 23,
  'jeremias': 24,
  'lamentaciones': 25,
  'ezequiel': 26,
  'daniel': 27,
  'oseas': 28,
  'joel': 29,
  'amos': 30,
  'abdias': 31,
  'jonas': 32,
  'miqueas': 33,
  'nahum': 34,
  'habacuc': 35,
  'sofonias': 36,
  'hageo': 37,
  'zacarias': 38,
  'malaquias': 39,
  'mateo': 40,
  'marcos': 41,
  'lucas': 42,
  'juan': 43,
  'hechos': 44,
  'romanos': 45,
  '1 corintios': 46,
  '2 corintios': 47,
  'galatas': 48,
  'efesios': 49,
  'filipenses': 50,
  'colosenses': 51,
  '1 tesalonicenses': 52,
  '2 tesalonicenses': 53,
  '1 timoteo': 54,
  '2 timoteo': 55,
  'tito': 56,
  'filemon': 57,
  'hebreos': 58,
  'santiago': 59,
  '1 pedro': 60,
  '2 pedro': 61,
  '1 juan': 62,
  '2 juan': 63,
  '3 juan': 64,
  'judas': 65,
  'apocalipsis': 66,
};

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppDesignSystem.gold),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingXS),
                Text(
                  body,
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final KingdomLessonQuestion question;

  const _QuestionCard(this.question);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      child: _InfoCard(
        icon: Icons.help_rounded,
        title: question.prompt,
        body: 'Idea esperada: ${question.expectedIdea}',
      ),
    );
  }
}

class _QuizCard extends StatelessWidget {
  final KingdomQuizItem item;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _QuizCard({
    required this.item,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final answered = selectedIndex != null;
    final correct = selectedIndex == item.correctIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.prompt,
            style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
          ),
          if (item.ref.isNotEmpty) ...[
            const SizedBox(height: AppDesignSystem.spacingXS),
            Text(
              item.ref,
              style: AppDesignSystem.labelSmall(
                context,
                color: AppDesignSystem.gold,
              ),
            ),
          ],
          const SizedBox(height: AppDesignSystem.spacingM),
          for (var i = 0; i < item.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
              child: OutlinedButton(
                onPressed: () => onSelected(i),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: t.textPrimary,
                  side: BorderSide(color: _optionColor(i, t)),
                  backgroundColor: selectedIndex == i
                      ? _optionColor(i, t).withValues(alpha: 0.12)
                      : Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppDesignSystem.radiusM,
                    ),
                  ),
                ),
                child: Text(item.options[i]),
              ),
            ),
          if (answered) ...[
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              correct ? 'Correcto.' : 'Repasemos esto.',
              style: AppDesignSystem.labelLarge(
                context,
                color: correct ? AppDesignSystem.victory : Colors.orange,
              ),
            ),
            if (item.explanation.isNotEmpty)
              Text(
                item.explanation,
                style: AppDesignSystem.bodyMedium(
                  context,
                  color: t.textSecondary,
                ),
              ),
          ],
        ],
      ),
    );
  }

  Color _optionColor(int index, AppThemeData t) {
    if (selectedIndex != index) return t.cardBorder;
    if (index == item.correctIndex) return AppDesignSystem.victory;
    return Colors.orange;
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Text(
      title,
      style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;

  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingS,
        vertical: AppDesignSystem.spacingXS,
      ),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.26)),
      ),
      child: Text(
        text,
        style: AppDesignSystem.labelSmall(context, color: t.textPrimary),
      ),
    );
  }
}

class _LessonResultDialog extends StatelessWidget {
  final int score;

  const _LessonResultDialog({required this.score});

  @override
  Widget build(BuildContext context) {
    final stars = score >= 90
        ? 3
        : score >= 80
        ? 2
        : score >= 60
        ? 1
        : 0;
    final starText = stars == 0
        ? 'repaso recomendado'
        : List.filled(stars, '*').join();
    return AlertDialog(
      title: const Text('Lección completada'),
      content: Text('Resultado: $score% | $starText'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

String _practiceModeLabel(String id) {
  switch (id) {
    case 'learn':
      return 'Aprendizaje';
    case 'quiz':
      return 'Quiz';
    case 'review':
      return 'Repaso';
    case 'case':
      return 'Caso práctico';
    case 'memory':
      return 'Memoria';
    case 'checkpoint':
      return 'Checkpoint';
    case 'deepStudy':
      return 'Estudio profundo';
    default:
      return id;
  }
}

String _reviewStatusLabel(String id) {
  switch (id) {
    case 'draft':
      return 'Borrador';
    case 'needsReview':
      return 'Revisión pendiente';
    case 'reviewed':
      return 'Revisada';
    case 'approved':
      return 'Aprobada';
    default:
      return id;
  }
}
