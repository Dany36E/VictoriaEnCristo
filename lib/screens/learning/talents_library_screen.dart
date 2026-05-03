/// ═══════════════════════════════════════════════════════════════════════════
/// TalentsLibraryScreen — Biblioteca coleccionable de los 66 libros.
///
/// Cada libro se muestra como un mural de 5 actos: sello, escena, camino,
/// mesa y palabra. Las piezas se generan por código para mantener el APK liviano.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../data/collectibles_catalog.dart';
import '../../models/learning/book_models.dart';
import '../../services/learning/book_repository.dart';
import '../../services/learning/collectibles_service.dart';
import '../../services/learning/talents_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../widgets/learning/collectible_story_art.dart';
import '../../widgets/learning/talents_badge.dart';
import 'talents_book_detail_screen.dart';

class TalentsLibraryScreen extends StatefulWidget {
  const TalentsLibraryScreen({super.key});

  @override
  State<TalentsLibraryScreen> createState() => _TalentsLibraryScreenState();
}

class _TalentsLibraryScreenState extends State<TalentsLibraryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final allBooks = BookRepository.I.all;

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(
          'Biblioteca de Talentos',
          style: AppDesignSystem.headlineSmall(context, color: theme.textPrimary),
        ),
        iconTheme: IconThemeData(color: theme.textPrimary),
        actions: const [TalentsBadge()],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          TalentsService.I.stateNotifier,
          CollectiblesService.I.unlockedNotifier,
        ]),
        builder: (context, child) {
          final filteredBooks = _applyFilter(allBooks);
          final totalUnlocked = CollectiblesService.I.totalUnlocked;
          final totalAvailable = CollectiblesService.I.totalAvailable;
          final completeBooks = allBooks
              .where((book) => CollectiblesService.I.isBookComplete(book.id))
              .length;
          final progress = totalAvailable == 0
              ? 0.0
              : (totalUnlocked / totalAvailable).clamp(0.0, 1.0).toDouble();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(
                  context,
                  theme,
                  totalUnlocked,
                  totalAvailable,
                  completeBooks,
                  progress,
                ),
              ),
              SliverToBoxAdapter(child: _buildFilters(context, theme)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignSystem.spacingM,
                  AppDesignSystem.spacingS,
                  AppDesignSystem.spacingM,
                  AppDesignSystem.spacingXL,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 190,
                    mainAxisExtent: 248,
                    mainAxisSpacing: AppDesignSystem.spacingM,
                    crossAxisSpacing: AppDesignSystem.spacingM,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _BookTile(book: filteredBooks[index]),
                    childCount: filteredBooks.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<BibleBook> _applyFilter(List<BibleBook> books) {
    switch (_filter) {
      case 'AT':
        return books.where((book) => book.testament == 'AT').toList();
      case 'NT':
        return books.where((book) => book.testament == 'NT').toList();
      case 'complete':
        return books.where((book) => CollectiblesService.I.isBookComplete(book.id)).toList();
      default:
        return books;
    }
  }

  Widget _buildHeader(
    BuildContext context,
    AppThemeData theme,
    int totalUnlocked,
    int totalAvailable,
    int completeBooks,
    double progress,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppDesignSystem.spacingM),
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppDesignSystem.midnightLight,
            AppDesignSystem.midnightDeep,
            AppDesignSystem.goldDark.withOpacity(0.28),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.gold.withOpacity(0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                  border: Border.all(color: AppDesignSystem.gold.withOpacity(0.32)),
                ),
                child: const Icon(Icons.auto_awesome_mosaic_rounded, color: AppDesignSystem.gold),
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mural de la Historia',
                      style: AppDesignSystem.headlineSmall(
                        context,
                        color: AppDesignSystem.pureWhite,
                      ),
                    ),
                    Text(
                      '$totalUnlocked/$totalAvailable piezas · $completeBooks/66 libros completos',
                      style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.coolGray),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          const Row(
            children: [
              Expanded(
                child: _HeaderStat(
                  icon: Icons.workspace_premium_rounded,
                  value: '+10',
                  label: 'mín. por libro',
                ),
              ),
              SizedBox(width: AppDesignSystem.spacingS),
              Expanded(
                child: _HeaderStat(icon: Icons.route_rounded, value: '5', label: 'actos por mural'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, AppThemeData theme) {
    final filters = [
      ('all', 'Todos'),
      ('AT', 'Antiguo Testamento'),
      ('NT', 'Nuevo Testamento'),
      ('complete', 'Completos'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM, vertical: 4),
      child: Row(
        children: filters.map((filter) {
          final selected = _filter == filter.$1;
          return Padding(
            padding: const EdgeInsets.only(right: AppDesignSystem.spacingS),
            child: ChoiceChip(
              label: Text(filter.$2),
              selected: selected,
              onSelected: (_) => setState(() => _filter = filter.$1),
              selectedColor: AppDesignSystem.gold,
              backgroundColor: theme.cardBg,
              labelStyle: AppDesignSystem.labelMedium(
                context,
                color: selected ? AppDesignSystem.midnightDeep : theme.textPrimary,
              ),
              side: BorderSide(color: selected ? AppDesignSystem.gold : theme.cardBorder),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _HeaderStat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppDesignSystem.goldLight, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.pureWhite),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final BibleBook book;

  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final unlockedCount = CollectiblesService.I.unlockedInBook(book.id);
    final totalCount = CollectiblesService.I.totalInBook(book.id);
    final isComplete = unlockedCount >= totalCount && totalCount > 0;
    final hasAny = unlockedCount > 0;
    final items = CollectiblesCatalog.I.itemsForBook(book.id);
    final nextItem = items
        .where((item) => !CollectiblesService.I.isUnlocked(item.id))
        .cast<CollectibleItem?>()
        .firstWhere((item) => item != null, orElse: () => null);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TalentsBookDetailScreen(bookId: book.id)),
      ),
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: isComplete
                ? AppDesignSystem.gold
                : (hasAny ? AppDesignSystem.gold.withOpacity(0.42) : theme.cardBorder),
            width: isComplete ? 2 : 1,
          ),
          boxShadow: isComplete
              ? [
                  BoxShadow(
                    color: AppDesignSystem.gold.withOpacity(0.2),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : theme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: BookStoryMural(
                      book: book,
                      unlockedCount: unlockedCount,
                      totalCount: totalCount,
                      compact: true,
                      borderRadius: AppDesignSystem.radiusM,
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _OrderPill(order: book.order, complete: isComplete),
                  ),
                  if (isComplete)
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: Icon(Icons.verified_rounded, color: AppDesignSystem.gold, size: 21),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDesignSystem.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesignSystem.labelMedium(
                      context,
                      color: theme.textPrimary,
                    ).copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isComplete
                        ? CollectiblesCatalog.I.completionRewardTitle(book)
                        : nextItem?.kind.storyAct ?? book.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesignSystem.labelSmall(
                      context,
                      color: isComplete ? AppDesignSystem.gold : theme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                          child: LinearProgressIndicator(
                            value: totalCount == 0 ? 0 : unlockedCount / totalCount,
                            minHeight: 5,
                            backgroundColor: theme.divider,
                            valueColor: AlwaysStoppedAnimation(
                              isComplete ? AppDesignSystem.gold : theme.accent,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$unlockedCount/$totalCount',
                        style: AppDesignSystem.labelSmall(
                          context,
                          color: hasAny ? AppDesignSystem.gold : theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderPill extends StatelessWidget {
  final int order;
  final bool complete;

  const _OrderPill({required this.order, required this.complete});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.34),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: complete ? AppDesignSystem.gold : Colors.white.withOpacity(0.18)),
      ),
      child: Text(
        order.toString().padLeft(2, '0'),
        style: AppDesignSystem.labelSmall(
          context,
          color: complete ? AppDesignSystem.goldLight : AppDesignSystem.pureWhite,
        ),
      ),
    );
  }
}
