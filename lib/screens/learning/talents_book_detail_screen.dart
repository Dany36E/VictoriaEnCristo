/// ═══════════════════════════════════════════════════════════════════════════
/// TalentsBookDetailScreen — arco coleccionable de un libro bíblico.
///
/// Cada libro tiene 5 actos visuales generados por código y una recompensa de
/// cierre al completar el mural.
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

class TalentsBookDetailScreen extends StatelessWidget {
  final String bookId;

  const TalentsBookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final book = BookRepository.I.byId(bookId);
    if (book == null) {
      return Scaffold(
        backgroundColor: theme.scaffoldBg,
        appBar: AppBar(backgroundColor: theme.surface),
        body: Center(
          child: Text(
            'Libro no encontrado',
            style: AppDesignSystem.bodyLarge(context, color: theme.textPrimary),
          ),
        ),
      );
    }

    final items = CollectiblesCatalog.I.itemsForBook(bookId);

    return Scaffold(
      backgroundColor: theme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: theme.surface,
        title: Text(
          book.name,
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
          final unlockedCount = CollectiblesService.I.unlockedInBook(bookId);
          final isComplete = unlockedCount == items.length;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _BookHero(
                  book: book,
                  unlockedCount: unlockedCount,
                  totalCount: items.length,
                  complete: isComplete,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignSystem.spacingM,
                  0,
                  AppDesignSystem.spacingM,
                  AppDesignSystem.spacingXL,
                ),
                sliver: SliverList.separated(
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _ItemTile(book: book, item: item);
                  },
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemCount: items.length,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BookHero extends StatelessWidget {
  final BibleBook book;
  final int unlockedCount;
  final int totalCount;
  final bool complete;

  const _BookHero({
    required this.book,
    required this.unlockedCount,
    required this.totalCount,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final progress = totalCount == 0 ? 0.0 : unlockedCount / totalCount;
    return Padding(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(
            color: complete ? AppDesignSystem.gold : theme.cardBorder,
            width: complete ? 2 : 1,
          ),
          boxShadow: theme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 148,
              child: BookStoryMural(
                book: book,
                unlockedCount: unlockedCount,
                totalCount: totalCount,
                borderRadius: AppDesignSystem.radiusL,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDesignSystem.spacingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.theme,
                              style: AppDesignSystem.bodyLarge(context, color: theme.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${book.category} · ${book.chapters} capítulos',
                              style: AppDesignSystem.labelMedium(
                                context,
                                color: theme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _ProgressSeal(
                        unlockedCount: unlockedCount,
                        totalCount: totalCount,
                        complete: complete,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDesignSystem.spacingM),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: theme.divider,
                      valueColor: AlwaysStoppedAnimation(
                        complete ? AppDesignSystem.gold : theme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDesignSystem.spacingM),
                  Text(
                    '"${book.keyVerse}"',
                    style: AppDesignSystem.scripture(context, color: theme.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.keyVerseRef.toUpperCase(),
                    style: AppDesignSystem.scriptureReference(context),
                  ),
                  if (complete) ...[
                    const SizedBox(height: AppDesignSystem.spacingM),
                    _CompletionBanner(book: book),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressSeal extends StatelessWidget {
  final int unlockedCount;
  final int totalCount;
  final bool complete;

  const _ProgressSeal({
    required this.unlockedCount,
    required this.totalCount,
    required this.complete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: complete
            ? AppDesignSystem.gold.withOpacity(0.18)
            : AppDesignSystem.midnight.withOpacity(0.07),
        border: Border.all(
          color: complete ? AppDesignSystem.gold : AppDesignSystem.gold.withOpacity(0.28),
        ),
      ),
      child: Center(
        child: Text(
          '$unlockedCount/$totalCount',
          style: AppDesignSystem.labelLarge(
            context,
            color: complete ? AppDesignSystem.gold : AppDesignSystem.goldDark,
          ),
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  final BibleBook book;

  const _CompletionBanner({required this.book});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.36)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: AppDesignSystem.gold),
          const SizedBox(width: AppDesignSystem.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CollectiblesCatalog.I.completionRewardTitle(book),
                  style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.goldDark),
                ),
                Text('Recompensa reclamada', style: AppDesignSystem.labelSmall(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final BibleBook book;
  final CollectibleItem item;

  const _ItemTile({required this.book, required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    final unlocked = CollectiblesService.I.isUnlocked(item.id);
    final balance = TalentsService.I.stateNotifier.value.balance;
    final canAfford = balance >= item.cost;

    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      onTap: () => _showItemModal(
        context: context,
        book: book,
        item: item,
        unlocked: unlocked,
        canAfford: canAfford,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: unlocked ? AppDesignSystem.gold.withOpacity(0.78) : theme.cardBorder,
            width: unlocked ? 2 : 1,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: AppDesignSystem.gold.withOpacity(0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : theme.cardShadow,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 116,
              height: 132,
              child: CollectibleStoryArt(
                book: book,
                item: item,
                unlocked: unlocked,
                borderRadius: AppDesignSystem.radiusM,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.kind.storyAct,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppDesignSystem.labelSmall(
                              context,
                              color: unlocked ? AppDesignSystem.gold : theme.textSecondary,
                            ),
                          ),
                        ),
                        Icon(
                          unlocked ? Icons.verified_rounded : item.kind.icon,
                          size: 18,
                          color: unlocked ? AppDesignSystem.gold : theme.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.headlineSmall(context, color: theme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      unlocked ? item.rewardDetail : item.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppDesignSystem.bodyMedium(context, color: theme.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    _ItemStatusPill(unlocked: unlocked, canAfford: canAfford, cost: item.cost),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemStatusPill extends StatelessWidget {
  final bool unlocked;
  final bool canAfford;
  final int cost;

  const _ItemStatusPill({required this.unlocked, required this.canAfford, required this.cost});

  @override
  Widget build(BuildContext context) {
    final color = unlocked
        ? AppDesignSystem.gold
        : (canAfford ? AppDesignSystem.victory : AppDesignSystem.coolGray);
    final text = unlocked ? 'Desbloqueado' : '$cost talentos';
    final icon = unlocked ? Icons.check_circle_rounded : Icons.star_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: color.withOpacity(0.36)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(text, style: AppDesignSystem.labelSmall(context, color: color)),
        ],
      ),
    );
  }
}

class _RewardPreview extends StatelessWidget {
  final CollectibleItem item;
  final bool unlocked;

  const _RewardPreview({required this.item, required this.unlocked});

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: unlocked ? AppDesignSystem.gold.withOpacity(0.14) : theme.inputBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(
          color: unlocked ? AppDesignSystem.gold.withOpacity(0.34) : theme.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
            unlocked ? Icons.verified_rounded : Icons.card_giftcard_rounded,
            color: unlocked ? AppDesignSystem.gold : theme.textSecondary,
          ),
          const SizedBox(width: AppDesignSystem.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.rewardTitle,
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: unlocked ? AppDesignSystem.goldDark : theme.textPrimary,
                  ),
                ),
                Text(
                  item.rewardDetail,
                  style: AppDesignSystem.bodyMedium(context, color: theme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnlockedButton extends StatelessWidget {
  final CollectibleItem item;

  const _UnlockedButton({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM, vertical: 13),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withOpacity(0.16),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded, color: AppDesignSystem.gold, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${item.kind.label} desbloqueado',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.gold),
            ),
          ),
        ],
      ),
    );
  }
}

void _showItemModal({
  required BuildContext context,
  required BibleBook book,
  required CollectibleItem item,
  required bool unlocked,
  required bool canAfford,
}) {
  final theme = AppThemeData.of(context);
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: theme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppDesignSystem.radiusL)),
    ),
    builder: (sheetContext) => SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppDesignSystem.spacingL,
          AppDesignSystem.spacingL,
          AppDesignSystem.spacingL,
          AppDesignSystem.spacingL + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 220,
              child: CollectibleStoryArt(
                book: book,
                item: item,
                unlocked: unlocked,
                borderRadius: AppDesignSystem.radiusL,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingL),
            Text(
              item.kind.storyAct,
              style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold),
            ),
            const SizedBox(height: 6),
            Text(
              item.title,
              style: AppDesignSystem.headlineMedium(context, color: theme.textPrimary),
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              item.story,
              style: AppDesignSystem.bodyMedium(context, color: theme.textSecondary),
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
            _RewardPreview(item: item, unlocked: unlocked),
            const SizedBox(height: AppDesignSystem.spacingL),
            if (unlocked)
              _UnlockedButton(item: item)
            else
              ElevatedButton.icon(
                onPressed: canAfford
                    ? () async {
                        final result = await CollectiblesService.I.unlockWithResult(item);
                        if (sheetContext.mounted) Navigator.pop(sheetContext);
                        if (context.mounted && result.unlocked) {
                          _showUnlockSnackBar(context, item, result);
                        }
                      }
                    : null,
                icon: const Icon(Icons.star_rounded),
                label: Text(
                  canAfford
                      ? 'Desbloquear por ${item.cost} talentos'
                      : 'Necesitas ${item.cost} talentos',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.gold,
                  foregroundColor: AppDesignSystem.midnightDeep,
                  disabledBackgroundColor: theme.divider,
                  disabledForegroundColor: theme.textSecondary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

void _showUnlockSnackBar(
  BuildContext context,
  CollectibleItem item,
  CollectibleUnlockResult result,
) {
  final message = result.completedBook
      ? '${result.rewardTitle} · +${result.bonusTalents} talentos'
      : '${item.rewardTitle}: ${item.title}';
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppDesignSystem.midnightDeep,
      behavior: SnackBarBehavior.floating,
      content: Row(
        children: [
          Icon(
            result.completedBook ? Icons.workspace_premium_rounded : Icons.celebration_rounded,
            color: AppDesignSystem.gold,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.goldLight),
            ),
          ),
        ],
      ),
    ),
  );
}
