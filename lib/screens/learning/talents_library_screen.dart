/// ═══════════════════════════════════════════════════════════════════════════
/// TalentsLibraryScreen — Biblioteca coleccionable de los 66 libros.
///
/// Cuadrícula 3 columnas. Cada tarjeta muestra:
///  · Nombre + número de orden
///  · Progreso "X / 5" coleccionables
///  · Marco dorado si el libro está completo
///  · Silueta + candado si todavía no se ha desbloqueado nada
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../models/learning/book_models.dart';
import '../../services/learning/book_repository.dart';
import '../../services/learning/collectibles_service.dart';
import '../../services/learning/talents_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../widgets/learning/talents_badge.dart';
import 'talents_book_detail_screen.dart';

class TalentsLibraryScreen extends StatefulWidget {
  const TalentsLibraryScreen({super.key});

  @override
  State<TalentsLibraryScreen> createState() => _TalentsLibraryScreenState();
}

class _TalentsLibraryScreenState extends State<TalentsLibraryScreen> {
  String _filter = 'all'; // 'all' | 'AT' | 'NT' | 'complete'

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final allBooks = BookRepository.I.all;

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          'Biblioteca de Talentos',
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
          final filtered = _applyFilter(allBooks);
          final totalUnlocked = CollectiblesService.I.totalUnlocked;
          final totalAvailable = CollectiblesService.I.totalAvailable;
          final pct = totalAvailable == 0
              ? 0.0
              : (totalUnlocked / totalAvailable).clamp(0.0, 1.0);

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(context, t, totalUnlocked, totalAvailable, pct),
              ),
              SliverToBoxAdapter(child: _buildFilters(context, t)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDesignSystem.spacingM,
                  AppDesignSystem.spacingS,
                  AppDesignSystem.spacingM,
                  AppDesignSystem.spacingXL,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppDesignSystem.spacingM,
                    crossAxisSpacing: AppDesignSystem.spacingM,
                    childAspectRatio: 0.7,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, i) => _BookTile(book: filtered[i]),
                    childCount: filtered.length,
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
        return books.where((b) => b.testament == 'AT').toList();
      case 'NT':
        return books.where((b) => b.testament == 'NT').toList();
      case 'complete':
        return books
            .where((b) => CollectiblesService.I.isBookComplete(b.id))
            .toList();
      default:
        return books;
    }
  }

  Widget _buildHeader(
    BuildContext context,
    AppThemeData t,
    int totalUnlocked,
    int totalAvailable,
    double pct,
  ) {
    return Container(
      margin: const EdgeInsets.all(AppDesignSystem.spacingM),
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppDesignSystem.gold.withOpacity(0.2),
            AppDesignSystem.goldDark.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories_rounded,
                  color: AppDesignSystem.gold, size: 32),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu colección',
                      style: AppDesignSystem.headlineSmall(context,
                          color: t.textPrimary),
                    ),
                    Text(
                      '$totalUnlocked de $totalAvailable piezas desbloqueadas',
                      style: AppDesignSystem.bodyMedium(context,
                          color: t.textSecondary),
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
              value: pct,
              minHeight: 8,
              backgroundColor: t.cardBg,
              valueColor:
                  const AlwaysStoppedAnimation(AppDesignSystem.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context, AppThemeData t) {
    final chips = [
      ('all', 'Todos'),
      ('AT', 'Antiguo Testamento'),
      ('NT', 'Nuevo Testamento'),
      ('complete', 'Completos'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM, vertical: 4),
      child: Row(
        children: chips.map((c) {
          final selected = _filter == c.$1;
          return Padding(
            padding: const EdgeInsets.only(right: AppDesignSystem.spacingS),
            child: ChoiceChip(
              label: Text(c.$2),
              selected: selected,
              onSelected: (_) => setState(() => _filter = c.$1),
              selectedColor: AppDesignSystem.gold,
              backgroundColor: t.cardBg,
              labelStyle: AppDesignSystem.labelMedium(
                context,
                color: selected
                    ? AppDesignSystem.midnightDeep
                    : t.textPrimary,
              ),
              side: BorderSide(color: t.cardBorder),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BookTile extends StatelessWidget {
  final BibleBook book;
  const _BookTile({required this.book});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final unlocked = CollectiblesService.I.unlockedInBook(book.id);
    final total = CollectiblesService.I.totalInBook(book.id);
    final isComplete = unlocked >= total && total > 0;
    final hasAny = unlocked > 0;

    final accentColor = _colorForBook(book);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TalentsBookDetailScreen(bookId: book.id),
        ),
      ),
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: isComplete
                ? AppDesignSystem.gold
                : (hasAny ? accentColor.withOpacity(0.5) : t.cardBorder),
            width: isComplete ? 2.5 : 1,
          ),
          boxShadow: isComplete
              ? [
                  BoxShadow(
                    color: AppDesignSystem.gold.withOpacity(0.4),
                    blurRadius: 12,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // "Cover" — color del libro + icono o silueta
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(AppDesignSystem.radiusM)),
                  gradient: LinearGradient(
                    colors: hasAny
                        ? [accentColor.withOpacity(0.9), accentColor.withOpacity(0.4)]
                        : [t.cardBorder.withOpacity(0.4), t.cardBorder.withOpacity(0.15)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        hasAny ? _iconForBook(book) : Icons.lock_rounded,
                        size: 40,
                        color: hasAny
                            ? Colors.white.withOpacity(0.95)
                            : t.textSecondary.withOpacity(0.6),
                      ),
                    ),
                    if (isComplete)
                      const Positioned(
                        top: 4,
                        right: 4,
                        child: Icon(Icons.verified_rounded,
                            color: AppDesignSystem.gold, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppDesignSystem.labelMedium(context,
                            color: t.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '$unlocked/$total',
                    style: AppDesignSystem.labelSmall(context,
                        color: hasAny
                            ? AppDesignSystem.gold
                            : t.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Color asignado por categoría (estable y previsible).
  Color _colorForBook(BibleBook b) {
    switch (b.category.toLowerCase()) {
      case 'pentateuco':
        return const Color(0xFF8E5A3A); // tierra
      case 'históricos':
      case 'historicos':
        return const Color(0xFF4A6FA5); // azul histórico
      case 'poéticos':
      case 'poeticos':
        return const Color(0xFF9B5B9B); // violeta lírico
      case 'profetas mayores':
        return const Color(0xFFB8623A); // ámbar
      case 'profetas menores':
        return const Color(0xFFD4A853); // dorado suave
      case 'evangelios':
        return const Color(0xFF3F8F5B); // verde Reino
      case 'historia':
        return const Color(0xFF4A6FA5);
      case 'epístolas paulinas':
      case 'epistolas paulinas':
        return const Color(0xFF6B5BB8);
      case 'epístolas generales':
      case 'epistolas generales':
        return const Color(0xFF8B6B5B);
      case 'profecía':
      case 'profecia':
        return const Color(0xFFB85B3A);
      default:
        return AppDesignSystem.gold;
    }
  }

  IconData _iconForBook(BibleBook b) {
    if (b.testament == 'NT') return Icons.menu_book_rounded;
    return Icons.book_rounded;
  }
}
