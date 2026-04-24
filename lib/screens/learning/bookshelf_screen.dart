/// ═══════════════════════════════════════════════════════════════════════════
/// BookshelfScreen — Los 66 Libros de la Biblia
/// Estantería con separadores por categoría. Libros estudiados brillan.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/book_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/book_progress_service.dart';
import '../../services/learning/book_repository.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'book_detail_screen.dart';

class BookshelfScreen extends StatefulWidget {
  const BookshelfScreen({super.key});

  @override
  State<BookshelfScreen> createState() => _BookshelfScreenState();
}

class _BookshelfScreenState extends State<BookshelfScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
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
          'Los 66 Libros',
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
      body: ValueListenableBuilder<BookProgressState>(
        valueListenable: BookProgressService.I.stateNotifier,
        builder: (context, state, _) {
          return Column(
            children: [
              _summaryBar(t, state),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _buildList(BookRepository.I.ot, state, t),
                    _buildList(BookRepository.I.nt, state, t),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBar(AppThemeData t, BookProgressState state) {
    final total = BookRepository.I.all.length;
    final done = state.studied.length;
    final pct = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded,
                  color: AppDesignSystem.gold),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Biblioteca estudiada: $done de $total libros',
                  style: AppDesignSystem.bodyLarge(context,
                      color: t.textPrimary),
                ),
              ),
              Text(
                '${(pct * 100).round()}%',
                style: AppDesignSystem.labelMedium(
                  context,
                  color: AppDesignSystem.gold,
                ),
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
              valueColor:
                  const AlwaysStoppedAnimation(AppDesignSystem.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
      List<BibleBook> books, BookProgressState state, AppThemeData t) {
    // Agrupar por categoría manteniendo orden canónico
    final Map<String, List<BibleBook>> byCat = {};
    for (final b in books) {
      byCat.putIfAbsent(b.category, () => []).add(b);
    }
    final cats = byCat.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      itemCount: cats.length,
      itemBuilder: (context, i) {
        final cat = cats[i];
        final items = byCat[cat]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  left: 4, top: 8, bottom: 8),
              child: Text(
                cat,
                style: AppDesignSystem.headlineSmall(context,
                    color: AppDesignSystem.gold),
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 0.72,
              ),
              itemBuilder: (context, j) {
                final b = items[j];
                final studied = state.studied.contains(b.id);
                final score = state.bestScores[b.id] ?? 0;
                return _BookSpine(
                  book: b,
                  studied: studied,
                  score: score,
                  onTap: () async {
                    FeedbackEngine.I.tap();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookDetailScreen(book: b),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                ).animate().fadeIn(
                    duration: 250.ms, delay: (30 * j).ms);
              },
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
          ],
        );
      },
    );
  }
}

class _BookSpine extends StatelessWidget {
  final BibleBook book;
  final bool studied;
  final int score;
  final VoidCallback onTap;

  const _BookSpine({
    required this.book,
    required this.studied,
    required this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          gradient: studied
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3A2A10),
                    Color(0xFF6B4E20),
                  ],
                )
              : null,
          color: studied ? null : t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: studied ? AppDesignSystem.gold : t.cardBorder,
            width: studied ? 1.5 : 1,
          ),
          boxShadow: studied
              ? [
                  BoxShadow(
                    color: AppDesignSystem.gold.withOpacity(0.35),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${book.order}',
                  style: AppDesignSystem.labelSmall(context,
                      color: AppDesignSystem.gold),
                ),
                if (studied)
                  const Icon(Icons.check_circle_rounded,
                      color: AppDesignSystem.gold, size: 14),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: Text(
                  book.name,
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.headlineSmall(context,
                      color: t.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            Text(
              '${book.chapters} cap.',
              textAlign: TextAlign.center,
              style: AppDesignSystem.labelSmall(context,
                  color: t.textSecondary),
            ),
            if (studied && score > 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '$score/3 ✓',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.labelSmall(
                    context,
                    color: AppDesignSystem.gold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
