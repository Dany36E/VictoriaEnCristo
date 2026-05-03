/// ═══════════════════════════════════════════════════════════════════════════
/// BibleOrderScreen — Aprende el orden de los 66 libros de la Biblia
///
/// Dos tabs: Antiguo Testamento / Nuevo Testamento.
/// Cada categoría (Pentateuco, Históricos, etc.) es una tarjeta practicable.
/// Al tocar "Practicar" se abre un quiz de ordenar libros.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/book_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/bible_order_progress_service.dart';
import '../../services/learning/book_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'bible_order_learn_screen.dart';
import 'bible_order_quiz_screen.dart';

class BibleOrderScreen extends StatefulWidget {
  const BibleOrderScreen({super.key});

  @override
  State<BibleOrderScreen> createState() => _BibleOrderScreenState();
}

class _BibleOrderScreenState extends State<BibleOrderScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    AudioEngine.I.switchBgmContext(BgmContext.learningBibleOrder);
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    super.dispose();
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
          'Orden de la Biblia',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        bottom: TabBar(
          controller: _tabs,
          onTap: (_) => FeedbackEngine.I.tabChange(),
          labelColor: AppDesignSystem.gold,
          unselectedLabelColor: t.textSecondary,
          indicatorColor: AppDesignSystem.gold,
          tabs: const [
            Tab(text: 'Antiguo Testamento'),
            Tab(text: 'Nuevo Testamento'),
          ],
        ),
      ),
      body: ValueListenableBuilder<BibleOrderProgressState>(
        valueListenable: BibleOrderProgressService.I.stateNotifier,
        builder: (context, state, _) {
          return Column(
            children: [
              _summaryBar(t, state),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildTestamentView(BookRepository.I.ot, state, t),
                    _buildTestamentView(BookRepository.I.nt, state, t),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBar(AppThemeData t, BibleOrderProgressState state) {
    final totalCats = _allCategories().length;
    final done = state.bestStars.length;
    final stars = state.totalStars;
    final pct = totalCats == 0 ? 0.0 : done / totalCats;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sort_rounded, color: AppDesignSystem.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$done/$totalCats secciones · $stars ★',
                  style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: t.cardBg,
              valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye la lista de categorías para un testamento.
  Widget _buildTestamentView(List<BibleBook> books, BibleOrderProgressState state, AppThemeData t) {
    final Map<String, List<BibleBook>> byCat = {};
    for (final b in books) {
      byCat.putIfAbsent(b.category, () => []).add(b);
    }
    final cats = byCat.keys.toList();
    final testament = books.isNotEmpty ? books.first.testament : 'AT';

    return ListView.builder(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      itemCount: cats.length + 1, // +1 for the "All" card
      itemBuilder: (context, i) {
        // First card: practice all books of this testament
        if (i == 0) {
          final allKey = '${testament}_all';
          final bestStars = state.bestStars[allKey] ?? 0;
          return _CategoryCard(
            title: testament == 'AT' ? 'Todo el Antiguo Testamento' : 'Todo el Nuevo Testamento',
            bookNames: books.map((b) => b.name).toList(),
            bookCount: books.length,
            bestStars: bestStars,
            icon: Icons.auto_stories_rounded,
            onLearn: () => _startLearn(
              context,
              key: allKey,
              title: testament == 'AT' ? 'AT completo' : 'NT completo',
              books: books,
            ),
            onPractice: () => _startQuiz(
              context,
              key: allKey,
              title: testament == 'AT' ? 'AT completo' : 'NT completo',
              books: books,
            ),
          ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
        }
        final catIdx = i - 1;
        final cat = cats[catIdx];
        final items = byCat[cat]!;
        final catKey = '${testament}_$cat';
        final bestStars = state.bestStars[catKey] ?? 0;
        return Padding(
          padding: const EdgeInsets.only(top: AppDesignSystem.spacingS),
          child: _CategoryCard(
            title: cat,
            bookNames: items.map((b) => b.name).toList(),
            bookCount: items.length,
            bestStars: bestStars,
            icon: Icons.library_books_rounded,
            onLearn: items.length < 2
                ? null
                : () => _startLearn(context, key: catKey, title: cat, books: items),
            onPractice: items.length < 2
                ? null
                : () => _startQuiz(context, key: catKey, title: cat, books: items),
          ).animate().fadeIn(duration: 250.ms, delay: (40 * i).ms).slideY(begin: 0.05, end: 0),
        );
      },
    );
  }

  Future<void> _startLearn(
    BuildContext context, {
    required String key,
    required String title,
    required List<BibleBook> books,
  }) async {
    FeedbackEngine.I.tap();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleOrderLearnScreen(categoryKey: key, title: title, books: books),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _startQuiz(
    BuildContext context, {
    required String key,
    required String title,
    required List<BibleBook> books,
  }) async {
    FeedbackEngine.I.tap();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleOrderQuizScreen(categoryKey: key, title: title, books: books),
      ),
    );
    if (mounted) setState(() {});
  }

  List<String> _allCategories() {
    final Set<String> cats = {};
    // Categories + 2 "all" entries
    for (final b in BookRepository.I.all) {
      cats.add('${b.testament}_${b.category}');
    }
    cats.add('AT_all');
    cats.add('NT_all');
    return cats.toList();
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CATEGORY CARD
// ══════════════════════════════════════════════════════════════════════════

class _CategoryCard extends StatelessWidget {
  final String title;
  final List<String> bookNames;
  final int bookCount;
  final int bestStars;
  final IconData icon;
  final VoidCallback? onLearn;
  final VoidCallback? onPractice;

  const _CategoryCard({
    required this.title,
    required this.bookNames,
    required this.bookCount,
    required this.bestStars,
    required this.icon,
    this.onLearn,
    this.onPractice,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final completed = bestStars > 0;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(
          color: completed ? AppDesignSystem.gold.withOpacity(0.5) : t.cardBorder,
          width: completed ? 1.5 : 1,
        ),
        boxShadow: completed ? AppDesignSystem.shadowVictory : t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: AppDesignSystem.gold, size: 22),
              ),
              const SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                    ),
                    Text(
                      '$bookCount libros',
                      style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
                    ),
                  ],
                ),
              ),
              if (bestStars > 0) _starRow(bestStars),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          // Show book names preview
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: bookNames.map((name) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                  border: Border.all(color: t.divider),
                ),
                child: Text(
                  name,
                  style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
                ),
              );
            }).toList(),
          ),
          if (onLearn != null || onPractice != null) ...[
            const SizedBox(height: AppDesignSystem.spacingM),
            Row(
              children: [
                if (onLearn != null)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onLearn,
                      icon: const Icon(Icons.school_rounded, size: 16),
                      label: const Text('Aprender'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppDesignSystem.gold,
                        side: BorderSide(color: AppDesignSystem.gold.withOpacity(0.7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                        ),
                      ),
                    ),
                  ),
                if (onLearn != null && onPractice != null) const SizedBox(width: 8),
                if (onPractice != null)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPractice,
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      label: Text(completed ? 'Practicar' : 'Practicar'),
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
            ),
          ],
        ],
      ),
    );
  }

  Widget _starRow(int stars) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Icon(
          i < stars ? Icons.star_rounded : Icons.star_border_rounded,
          size: 20,
          color: i < stars ? AppDesignSystem.gold : AppDesignSystem.gold.withOpacity(0.3),
        );
      }),
    );
  }
}
