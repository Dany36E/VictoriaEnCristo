import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/bible_verse.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'study_tabs/interlineal_tab.dart';
import 'study_tabs/commentary_tab.dart';
import 'study_tabs/conexiones_tab.dart';
import 'study_tabs/guzik_tab.dart';

/// Sheet de estudio profundo para un versÃ­culo.
/// 4 tabs: Interlineal | Comentarios | Conexiones | Estudio Guzik.
class VerseStudySheet extends StatefulWidget {
  final BibleVerse verse;
  final VoidCallback? onNavigateToVerse;

  const VerseStudySheet({
    super.key,
    required this.verse,
    this.onNavigateToVerse,
  });

  /// Muestra el sheet desde cualquier contexto.
  static void show(BuildContext context, BibleVerse verse,
      {void Function(int bookNumber, int chapter, int verse)? onNavigate,
      int initialTab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        builder: (ctx, scrollController) => _SheetBody(
          verse: verse,
          scrollController: scrollController,
          onNavigate: onNavigate,
          initialTab: initialTab,
        ),
      ),
    );
  }

  @override
  State<VerseStudySheet> createState() => _VerseStudySheetState();
}

class _VerseStudySheetState extends State<VerseStudySheet> {
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (ctx, scrollController) => _SheetBody(
        verse: widget.verse,
        scrollController: scrollController,
      ),
    );
  }
}

// â”€â”€â”€ SHEET BODY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SheetBody extends StatefulWidget {
  final BibleVerse verse;
  final ScrollController scrollController;
  final void Function(int bookNumber, int chapter, int verse)? onNavigate;
  final int initialTab;

  const _SheetBody({
    required this.verse,
    required this.scrollController,
    this.onNavigate,
    this.initialTab = 0,
  });

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: t.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                InterlinealTab(
                  verse: widget.verse,
                  scrollController: widget.scrollController,
                ),
                CommentaryTab(
                  verse: widget.verse,
                  scrollController: widget.scrollController,
                ),
                ConexionesTab(
                  verse: widget.verse,
                  scrollController: widget.scrollController,
                ),
                GuzikTab(
                  verse: widget.verse,
                  scrollController: widget.scrollController,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.school_outlined,
                color: t.accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ESTUDIO PROFUNDO',
                    style: GoogleFonts.cinzel(
                      color: t.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.verse.reference,
                    style: GoogleFonts.manrope(
                      color: t.textPrimary.withValues(alpha: 0.7),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.close,
                  color: t.textPrimary.withValues(alpha: 0.5)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _buildTabBar() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: t.accent.withValues(alpha: 0.2)),
          ),
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: t.accent,
          indicatorWeight: 2,
          labelColor: t.accent,
          unselectedLabelColor:
              t.textPrimary.withValues(alpha: 0.5),
          labelStyle: GoogleFonts.manrope(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Interlineal'),
            Tab(text: 'Comentarios'),
            Tab(text: 'Conexiones'),
            Tab(text: 'Estudio Guzik'),
          ],
        ),
      );
}

