import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/bible_verse.dart';
import '../../models/bible/commentary_entry.dart';
import '../../models/bible/interlinear_word.dart';
import '../../services/bible/commentary_service.dart';
import '../../services/bible/interlinear_service.dart';
import '../../services/bible/treasury_service.dart';
import '../../services/bible/gospel_harmony_service.dart';
import '../../services/bible/typology_service.dart';
import '../../services/bible/ot_quotes_service.dart';
import '../../models/bible/harmony_section.dart';
import '../../models/bible/typology.dart';
import '../../models/bible/ot_quote.dart';
import '../../utils/cross_ref_classifier.dart';
import '../../utils/bible_navigation_helper.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/enduring_word_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'interlinear_word_card.dart';

/// Sheet de estudio profundo para un versículo.
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

// ─── SHEET BODY ──────────────────────────────────────────────

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

  // Datos locales
  InterlinearVerse? _interlinearVerse;
  bool _loadingInterlinear = true;
  List<CommentaryEntry> _commentaryEntries = [];
  bool _loadingCommentary = true;

  // Multi-source commentary
  Map<CommentarySource, List<CommentaryEntry>> _allCommentaries = {};
  CommentarySource _selectedCommentarySource = CommentarySource.matthewHenry;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    // Interlineal
    try {
      final verse = await InterlinearService.instance.getVerse(
        widget.verse.bookNumber,
        widget.verse.chapter,
        widget.verse.verse,
      );
      if (mounted) {
        setState(() {
          _interlinearVerse = verse;
          _loadingInterlinear = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingInterlinear = false);
    }

    // Multi-source commentary
    try {
      final all = await CommentaryService.instance
          .getVerseCommentaryAllSources(
        widget.verse.bookNumber,
        widget.verse.chapter,
        widget.verse.verse,
      );
      if (mounted) {
        setState(() {
          _allCommentaries = all;
          // Legacy: pick first available or MH
          _commentaryEntries =
              all[CommentarySource.matthewHenry] ?? [];
          if (_allCommentaries.isNotEmpty &&
              !_allCommentaries.containsKey(_selectedCommentarySource)) {
            _selectedCommentarySource = _allCommentaries.keys.first;
          }
          _commentaryEntries =
              _allCommentaries[_selectedCommentarySource] ?? [];
          _loadingCommentary = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingCommentary = false);
    }
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
                _buildInterlinealTab(),
                _buildCommentaryTab(),
                _buildConexionesTab(),
                _buildGuzikTab(),
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

  // ─── TAB 0: INTERLINEAL ──────────────────────────────────────

  Widget _buildInterlinealTab() {
    if (_loadingInterlinear) {
      return Center(
          child: CircularProgressIndicator(color: t.accent));
    }

    if (_interlinearVerse == null || _interlinearVerse!.words.isEmpty) {
      return _buildEmptyState(
          'No hay datos interlineales para este versículo');
    }

    return InterlinearSection(
      interlinearVerse: _interlinearVerse!,
      bookNumber: widget.verse.bookNumber,
      verseText: widget.verse.text,
      versionLabel: widget.verse.version,
      scrollController: widget.scrollController,
    );
  }

  // ─── TAB 1: COMENTARIO ──────────────────────────────────────

  Widget _buildCommentaryTab() {
    if (_loadingCommentary) {
      return Center(
          child: CircularProgressIndicator(color: t.accent));
    }

    final hasBook = CommentaryService.hasCommentary(widget.verse.bookNumber);
    if (!hasBook) {
      return _buildEmptyState('Comentario no disponible para este libro');
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Source selector chips
        if (_allCommentaries.isNotEmpty || _commentaryEntries.isNotEmpty) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: CommentarySource.values.map((source) {
                final isSelected = _selectedCommentarySource == source;
                final hasData = _allCommentaries.containsKey(source);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: hasData
                        ? () {
                            setState(() {
                              _selectedCommentarySource = source;
                              _commentaryEntries =
                                  _allCommentaries[source] ?? [];
                            });
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? t.accent.withValues(alpha: 0.15)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? t.accent.withValues(alpha: 0.5)
                              : hasData
                                  ? t.accent
                                      .withValues(alpha: 0.2)
                                  : t.textPrimary
                                      .withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        source.displayName,
                        style: GoogleFonts.manrope(
                          color: isSelected
                              ? t.accent
                              : hasData
                                  ? t.textPrimary
                                      .withValues(alpha: 0.6)
                                  : t.textPrimary
                                      .withValues(alpha: 0.2),
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dominio público',
            style: GoogleFonts.manrope(
              color: t.textPrimary.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_commentaryEntries.isEmpty)
          _buildEmptyState('No hay comentario para este versículo')
        else
          ..._commentaryEntries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: t.surface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (entry.verse > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'v. ${entry.verse}',
                            style: GoogleFonts.manrope(
                              color: t.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Text(
                        entry.text,
                        style: GoogleFonts.manrope(
                          color: t.textPrimary.withValues(alpha: 0.85),
                          fontSize: 14,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
      ],
    );
  }

  // ─── TAB 2: CONEXIONES BÍBLICAS ─────────────────────────────

  Widget _buildConexionesTab() {
    return FutureBuilder<_ConexionesData>(
      future: _loadConexiones(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
              child: CircularProgressIndicator(color: t.accent));
        }
        final data = snapshot.data!;
        final hasContent = data.harmony.isNotEmpty ||
            data.typologies.isNotEmpty ||
            data.quotes.isNotEmpty ||
            data.classifiedRefs.isNotEmpty;

        if (!hasContent) {
          return _buildEmptyState('No se encontraron conexiones para este versículo');
        }

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Cross-refs clasificadas
            if (data.classifiedRefs.isNotEmpty) ...[
              _conexionesSection(
                'Referencias Cruzadas',
                Icons.call_split,
                '${data.classifiedRefs.length} referencias',
              ),
              ...data.classifiedRefs.take(10).map((r) => _buildClassifiedRefTile(r)),
              if (data.classifiedRefs.length > 10)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '+${data.classifiedRefs.length - 10} más...',
                    style: GoogleFonts.manrope(
                      color: t.textPrimary.withValues(alpha: 0.3),
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
            // Armonía
            if (data.harmony.isNotEmpty) ...[
              _conexionesSection(
                'Armonía de los Evangelios',
                Icons.grid_view_rounded,
                '${data.harmony.length} eventos',
              ),
              ...data.harmony.map((h) => _buildHarmonyTile(h)),
            ],
            // Tipologías
            if (data.typologies.isNotEmpty) ...[
              _conexionesSection(
                'Tipologías',
                Icons.compare_arrows,
                '${data.typologies.length} tipologías',
              ),
              ...data.typologies.map((typ) => _buildTypologyTile(typ)),
            ],
            // Citas AT→NT
            if (data.quotes.isNotEmpty) ...[
              _conexionesSection(
                'Citas del AT en el NT',
                Icons.format_quote,
                '${data.quotes.length} citas',
              ),
              ...data.quotes.map((q) => _buildQuoteTile(q)),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Future<_ConexionesData> _loadConexiones() async {
    final book = widget.verse.bookNumber;
    final chapter = widget.verse.chapter;

    final results = await Future.wait([
      GospelHarmonyService.instance.getSectionsForReference(book, chapter),
      TypologyService.instance.getForBookChapter(book, chapter),
      OTQuotesService.instance.getForNTReference(book, chapter),
      TreasuryService.instance.getCrossReferences(book, chapter, widget.verse.verse),
    ]);

    final harmony = results[0] as List<HarmonySection>;
    final typologies = results[1] as List<Typology>;
    final quotes = results[2] as List<OTQuote>;
    final rawRefs = results[3] as List<String>;

    // Classify cross-refs
    final classified = <_ClassifiedRefItem>[];
    for (final ref in rawRefs.take(20)) {
      final parsed = TreasuryService.parseReference(ref);
      if (parsed == null) continue;
      final type = CrossRefClassifier.classify(book, parsed.bookNumber);
      classified.add(_ClassifiedRefItem(
        formatted: TreasuryService.formatReference(ref),
        raw: ref,
        type: type,
        explanation: CrossRefClassifier.defaultExplanation(type),
        bookNumber: parsed.bookNumber,
        chapter: parsed.chapter,
      ));
    }

    return _ConexionesData(
      harmony: harmony,
      typologies: typologies,
      quotes: quotes,
      classifiedRefs: classified,
    );
  }

  Widget _conexionesSection(String title, IconData icon, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: t.accent, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.cinzel(
              color: t.accent,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: GoogleFonts.manrope(
              color: t.textPrimary.withValues(alpha: 0.3),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassifiedRefTile(_ClassifiedRefItem ref) {
    final color = _refTypeColor(ref.type);
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        BibleNavigationHelper.navigateToOsis(context, ref.raw);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: t.textPrimary.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: color, width: 2)),
        ),
        child: Row(
          children: [
            Text(
              ref.formatted,
              style: GoogleFonts.manrope(
                color: t.accent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                CrossRefClassifier.label(ref.type),
                style: GoogleFonts.manrope(
                    color: color, fontSize: 8, fontWeight: FontWeight.w700),
              ),
            ),
            const Spacer(),
            if (ref.explanation != null)
              GestureDetector(
                onTap: () => _showRefExplanation(context, ref),
                child: Text('¿Por qué?',
                  style: GoogleFonts.manrope(
                    fontSize: 10,
                    color: t.accent.withValues(alpha: 0.6),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            if (ref.explanation == null)
              Icon(Icons.chevron_right,
                  color: t.textPrimary.withValues(alpha: 0.2),
                  size: 16),
          ],
        ),
      ),
    );
  }

  void _showRefExplanation(BuildContext context, _ClassifiedRefItem ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(ref.formatted,
          style: GoogleFonts.cinzel(
            color: t.accent,
            fontSize: 16,
          ),
        ),
        content: Text(ref.explanation!,
          style: GoogleFonts.manrope(
            color: t.textPrimary.withValues(alpha: 0.8),
            fontSize: 13,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // dialog
              Navigator.pop(context); // sheet
              BibleNavigationHelper.navigateToOsis(context, ref.raw);
            },
            child: Text('Ir al versículo',
              style: GoogleFonts.manrope(color: t.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar',
              style: GoogleFonts.manrope(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildHarmonyTile(HarmonySection h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded,
              color: t.accent.withValues(alpha: 0.4), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              h.title,
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
          Text(
            '${h.gospelCount}/4',
            style: GoogleFonts.manrope(
              color: t.accent.withValues(alpha: 0.5),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypologyTile(Typology typ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.compare_arrows,
              color: const Color(0xFF26A69A).withValues(alpha: 0.6), size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              typ.title,
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteTile(OTQuote q) {
    Color typeColor;
    switch (q.quoteType) {
      case QuoteType.direct:
        typeColor = const Color(0xFF66BB6A);
        break;
      case QuoteType.paraphrase:
        typeColor = const Color(0xFFFFA726);
        break;
      case QuoteType.allusion:
        typeColor = const Color(0xFF42A5F5);
        break;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${q.otReference} → ${q.ntReference}',
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _refTypeColor(CrossRefType type) {
    switch (type) {
      case CrossRefType.parallel:
        return const Color(0xFF42A5F5);
      case CrossRefType.prophecy:
        return const Color(0xFFAB47BC);
      case CrossRefType.oldTestQuote:
        return const Color(0xFFFF7043);
      case CrossRefType.typology:
        return const Color(0xFF26A69A);
      case CrossRefType.thematic:
        return t.accent;
    }
  }

  // ─── SHARED STATES ─────────────────────────────────────────

  Widget _buildEmptyState(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 40,
                  color: t.accent.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withValues(alpha: 0.5),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      );

  // ─── TAB 3: ENDURING WORD (DAVID GUZIK) ─────────────────────

  Widget _buildGuzikTab() {
    return FutureBuilder<EWChapterCommentary?>(
      future: EnduringWordService.instance
          .getChapterCommentary(widget.verse.bookNumber, widget.verse.chapter),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: t.accent),
                const SizedBox(height: 12),
                Text(
                  'Cargando comentario de David Guzik…',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        }

        final commentary = snapshot.data;
        if (commentary == null || commentary.isEmpty) {
          return _buildEmptyState(
            'Análisis no disponible para este capítulo.',
          );
        }

        return ListView(
          controller: widget.scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            // Attribution header
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: t.accent.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.menu_book_outlined,
                      color: t.accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enduring Word — David Guzik',
                          style: GoogleFonts.manrope(
                            color: t.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'enduringword.com',
                          style: GoogleFonts.manrope(
                            color: t.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Sections
            ...commentary.sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section heading
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: t.accent.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                                color: t.accent, width: 3),
                          ),
                        ),
                        child: Text(
                          section.heading,
                          style: GoogleFonts.cinzel(
                            color: t.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Paragraphs
                      ...section.paragraphs.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              p,
                              style: GoogleFonts.manrope(
                                color: t.textPrimary
                                    .withValues(alpha: 0.85),
                                fontSize: 14,
                                height: 1.7,
                              ),
                            ),
                          )),
                    ],
                  ),
                )),
          ],
        );
      },
    );
  }
}

// ─── HELPER CLASSES ──────────────────────────────────────────

class _ConexionesData {
  final List<HarmonySection> harmony;
  final List<Typology> typologies;
  final List<OTQuote> quotes;
  final List<_ClassifiedRefItem> classifiedRefs;

  const _ConexionesData({
    required this.harmony,
    required this.typologies,
    required this.quotes,
    required this.classifiedRefs,
  });
}

class _ClassifiedRefItem {
  final String formatted;
  final String raw;
  final CrossRefType type;
  final String? explanation;
  final int bookNumber;
  final int chapter;

  const _ClassifiedRefItem({
    required this.formatted,
    required this.raw,
    required this.type,
    this.explanation,
    required this.bookNumber,
    required this.chapter,
  });
}
