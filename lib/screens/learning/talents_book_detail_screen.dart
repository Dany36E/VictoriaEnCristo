/// ═══════════════════════════════════════════════════════════════════════════
/// TalentsBookDetailScreen — vista de los 5 coleccionables de un libro.
/// Tap a un ítem bloqueado → modal con preview + botón "Desbloquear".
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../data/collectibles_catalog.dart';
import '../../services/learning/book_repository.dart';
import '../../services/learning/collectibles_service.dart';
import '../../services/learning/talents_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../widgets/learning/talents_badge.dart';

class TalentsBookDetailScreen extends StatelessWidget {
  final String bookId;
  const TalentsBookDetailScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final book = BookRepository.I.byId(bookId);
    if (book == null) {
      return Scaffold(
        backgroundColor: t.scaffoldBg,
        appBar: AppBar(backgroundColor: t.surface),
        body: Center(
          child: Text('Libro no encontrado',
              style: AppDesignSystem.bodyLarge(context, color: t.textPrimary)),
        ),
      );
    }
    final items = CollectiblesCatalog.I.itemsForBook(bookId);

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          book.name,
          style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
        actions: const [TalentsBadge()],
      ),
      body: AnimatedBuilder(
        animation: Listenable.merge([
          TalentsService.I.stateNotifier,
          CollectiblesService.I.unlockedNotifier,
        ]),
        builder: (context, _) {
          final unlocked = CollectiblesService.I.unlockedInBook(bookId);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book.theme,
                          style: AppDesignSystem.bodyLarge(context,
                              color: t.textPrimary)),
                      const SizedBox(height: AppDesignSystem.spacingS),
                      Text(
                        '"${book.keyVerse}" — ${book.keyVerseRef}',
                        style: AppDesignSystem.bodyMedium(context,
                                color: t.textSecondary)
                            .copyWith(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: AppDesignSystem.spacingM),
                      Text(
                        'Coleccionables: $unlocked / ${items.length}',
                        style: AppDesignSystem.labelLarge(context,
                            color: AppDesignSystem.gold),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignSystem.spacingM,
                  0,
                  AppDesignSystem.spacingM,
                  AppDesignSystem.spacingXL,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: AppDesignSystem.spacingM,
                    crossAxisSpacing: AppDesignSystem.spacingM,
                    childAspectRatio: 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _ItemTile(item: items[i]),
                    childCount: items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final CollectibleItem item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final unlocked = CollectiblesService.I.isUnlocked(item.id);
    final balance = TalentsService.I.stateNotifier.value.balance;
    final canAfford = balance >= item.cost;

    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      onTap: () => _showItemModal(context, item, unlocked, canAfford),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: unlocked
                ? AppDesignSystem.gold
                : t.cardBorder,
            width: unlocked ? 2 : 1,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: AppDesignSystem.gold.withOpacity(0.25),
                    blurRadius: 10,
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDesignSystem.radiusM)),
                  gradient: LinearGradient(
                    colors: unlocked
                        ? [
                            AppDesignSystem.gold.withOpacity(0.85),
                            AppDesignSystem.goldDark.withOpacity(0.55),
                          ]
                        : [
                            t.cardBorder.withOpacity(0.3),
                            t.cardBorder.withOpacity(0.1),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Icon(
                    unlocked ? item.kind.icon : Icons.lock_rounded,
                    size: 48,
                    color: unlocked
                        ? AppDesignSystem.midnightDeep
                        : t.textSecondary.withOpacity(0.5),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDesignSystem.spacingS),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.kind.label,
                    style: AppDesignSystem.labelMedium(context,
                            color: t.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppDesignSystem.gold),
                      const SizedBox(width: 2),
                      Text(
                        unlocked ? 'Desbloqueado' : '${item.cost}',
                        style: AppDesignSystem.labelSmall(
                          context,
                          color: unlocked
                              ? AppDesignSystem.gold
                              : (canAfford
                                  ? t.textSecondary
                                  : t.textSecondary.withOpacity(0.5)),
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

  void _showItemModal(
    BuildContext context,
    CollectibleItem item,
    bool unlocked,
    bool canAfford,
  ) {
    final t = AppThemeData.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppDesignSystem.radiusL)),
      ),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: unlocked
                      ? [AppDesignSystem.gold, AppDesignSystem.goldDark]
                      : [t.cardBg, t.cardBg],
                ),
                shape: BoxShape.circle,
                border: Border.all(color: AppDesignSystem.gold, width: 2),
              ),
              child: Icon(
                unlocked ? item.kind.icon : Icons.lock_rounded,
                size: 40,
                color: unlocked
                    ? AppDesignSystem.midnightDeep
                    : t.textSecondary,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(item.kind.label,
                style: AppDesignSystem.headlineSmall(context,
                    color: t.textPrimary)),
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(item.description,
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(context,
                    color: t.textSecondary)),
            const SizedBox(height: AppDesignSystem.spacingL),
            if (unlocked)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppDesignSystem.spacingM, vertical: 10),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified_rounded,
                        color: AppDesignSystem.gold, size: 18),
                    const SizedBox(width: 6),
                    Text('Desbloqueado',
                        style: AppDesignSystem.labelLarge(
                          context,
                          color: AppDesignSystem.gold,
                        )),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canAfford
                      ? () async {
                          final ok =
                              await CollectiblesService.I.unlock(item);
                          if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                          if (ok && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: AppDesignSystem.midnightDeep,
                                content: Row(
                                  children: [
                                    const Icon(Icons.celebration_rounded,
                                        color: AppDesignSystem.gold),
                                    const SizedBox(width: 8),
                                    Text(
                                      '¡${item.kind.label} desbloqueado!',
                                      style: AppDesignSystem.labelLarge(
                                          context,
                                          color: AppDesignSystem.goldLight),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.star_rounded),
                  label: Text(canAfford
                      ? 'Desbloquear por ${item.cost} talentos'
                      : 'Necesitas ${item.cost} talentos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppDesignSystem.gold,
                    foregroundColor: AppDesignSystem.midnightDeep,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.radiusM),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
