import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/harmony_section.dart';
import '../../../models/bible/typology.dart';
import '../../../models/bible/ot_quote.dart';
import '../../../services/bible/gospel_harmony_service.dart';
import '../../../services/bible/typology_service.dart';
import '../../../services/bible/ot_quotes_service.dart';
import '../../../services/bible/treasury_service.dart';
import '../../../theme/bible_reader_theme.dart';
import '../../../utils/cross_ref_classifier.dart';
import '../../../utils/bible_navigation_helper.dart';
import '../../../services/bible/bible_user_data_service.dart';

/// Tab 2 del VerseStudySheet: conexiones bíblicas (cross-refs, armonía, tipologías, citas AT→NT).
class ConexionesTab extends StatelessWidget {
  final BibleVerse verse;
  final ScrollController scrollController;

  const ConexionesTab({
    super.key,
    required this.verse,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
        BibleReaderThemeData.migrateId(
            BibleUserDataService.I.readerThemeNotifier.value));

    return FutureBuilder<_ConexionesData>(
      future: _loadConexiones(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: t.accent));
        }
        final data = snapshot.data!;
        final hasContent = data.harmony.isNotEmpty ||
            data.typologies.isNotEmpty ||
            data.quotes.isNotEmpty ||
            data.classifiedRefs.isNotEmpty;

        if (!hasContent) {
          return _emptyState(t, 'No se encontraron conexiones para este versículo');
        }

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            if (data.classifiedRefs.isNotEmpty) ...[
              _sectionHeader(t, 'Referencias Cruzadas', Icons.call_split,
                  '${data.classifiedRefs.length} referencias'),
              ...data.classifiedRefs.take(10).map((r) => _buildRefTile(context, t, r)),
              if (data.classifiedRefs.length > 10)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    '+${data.classifiedRefs.length - 10} más...',
                    style: GoogleFonts.manrope(
                      color: t.textPrimary.withValues(alpha: 0.3), fontSize: 11),
                  ),
                ),
            ],
            if (data.harmony.isNotEmpty) ...[
              _sectionHeader(t, 'Armonía de los Evangelios', Icons.grid_view_rounded,
                  '${data.harmony.length} eventos'),
              ...data.harmony.map((h) => _buildHarmonyTile(t, h)),
            ],
            if (data.typologies.isNotEmpty) ...[
              _sectionHeader(t, 'Tipologías', Icons.compare_arrows,
                  '${data.typologies.length} tipologías'),
              ...data.typologies.map((typ) => _buildTypologyTile(t, typ)),
            ],
            if (data.quotes.isNotEmpty) ...[
              _sectionHeader(t, 'Citas del AT en el NT', Icons.format_quote,
                  '${data.quotes.length} citas'),
              ...data.quotes.map((q) => _buildQuoteTile(t, q)),
            ],
            const SizedBox(height: 20),
          ],
        );
      },
    );
  }

  Future<_ConexionesData> _loadConexiones() async {
    final book = verse.bookNumber;
    final chapter = verse.chapter;

    final results = await Future.wait([
      GospelHarmonyService.instance.getSectionsForReference(book, chapter),
      TypologyService.instance.getForBookChapter(book, chapter),
      OTQuotesService.instance.getForNTReference(book, chapter),
      TreasuryService.instance.getCrossReferences(book, chapter, verse.verse),
    ]);

    final harmony = results[0] as List<HarmonySection>;
    final typologies = results[1] as List<Typology>;
    final quotes = results[2] as List<OTQuote>;
    final rawRefs = results[3] as List<String>;

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

  // ── Helpers ──

  Widget _sectionHeader(BibleReaderThemeData t, String title, IconData icon, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: t.accent, size: 16),
          const SizedBox(width: 8),
          Text(title,
              style: GoogleFonts.cinzel(color: t.accent, fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          Text(subtitle,
              style: GoogleFonts.manrope(color: t.textPrimary.withValues(alpha: 0.3), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildRefTile(BuildContext context, BibleReaderThemeData t, _ClassifiedRefItem ref) {
    final color = _refTypeColor(t, ref.type);
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
            Text(ref.formatted,
                style: GoogleFonts.manrope(color: t.accent, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(CrossRefClassifier.label(ref.type),
                  style: GoogleFonts.manrope(color: color, fontSize: 8, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            if (ref.explanation != null)
              GestureDetector(
                onTap: () => _showRefExplanation(context, t, ref),
                child: Text('¿Por qué?',
                    style: GoogleFonts.manrope(
                        fontSize: 10,
                        color: t.accent.withValues(alpha: 0.6),
                        decoration: TextDecoration.underline)),
              ),
            if (ref.explanation == null)
              Icon(Icons.chevron_right, color: t.textPrimary.withValues(alpha: 0.2), size: 16),
          ],
        ),
      ),
    );
  }

  void _showRefExplanation(BuildContext context, BibleReaderThemeData t, _ClassifiedRefItem ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(ref.formatted,
            style: GoogleFonts.cinzel(color: t.accent, fontSize: 16)),
        content: Text(ref.explanation!,
            style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.8), fontSize: 13, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              BibleNavigationHelper.navigateToOsis(context, ref.raw);
            },
            child: Text('Ir al versículo', style: GoogleFonts.manrope(color: t.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar', style: GoogleFonts.manrope(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildHarmonyTile(BibleReaderThemeData t, HarmonySection h) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.grid_view_rounded, color: t.accent.withValues(alpha: 0.4), size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Text(h.title,
                  style: GoogleFonts.manrope(color: t.textPrimary.withValues(alpha: 0.8), fontSize: 12))),
          Text('${h.gospelCount}/4',
              style: GoogleFonts.manrope(
                  color: t.accent.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildTypologyTile(BibleReaderThemeData t, Typology typ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: t.textPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.compare_arrows, color: const Color(0xFF26A69A).withValues(alpha: 0.6), size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Text(typ.title,
                  style: GoogleFonts.manrope(color: t.textPrimary.withValues(alpha: 0.8), fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildQuoteTile(BibleReaderThemeData t, OTQuote q) {
    Color typeColor;
    switch (q.quoteType) {
      case QuoteType.direct:
        typeColor = const Color(0xFF66BB6A);
      case QuoteType.paraphrase:
        typeColor = const Color(0xFFFFA726);
      case QuoteType.allusion:
        typeColor = const Color(0xFF42A5F5);
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
          Container(width: 6, height: 6, decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
              child: Text('${q.otReference} → ${q.ntReference}',
                  style: GoogleFonts.manrope(color: t.textPrimary.withValues(alpha: 0.8), fontSize: 12))),
        ],
      ),
    );
  }

  Color _refTypeColor(BibleReaderThemeData t, CrossRefType type) {
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

  Widget _emptyState(BibleReaderThemeData t, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined, size: 40, color: t.accent.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.manrope(
                      color: t.textPrimary.withValues(alpha: 0.5), fontSize: 14, height: 1.5)),
            ],
          ),
        ),
      );
}

// ── Internal models ──

class _ConexionesData {
  final List<HarmonySection> harmony;
  final List<Typology> typologies;
  final List<OTQuote> quotes;
  final List<_ClassifiedRefItem> classifiedRefs;
  const _ConexionesData({
    required this.harmony, required this.typologies,
    required this.quotes, required this.classifiedRefs,
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
    required this.formatted, required this.raw,
    required this.type, this.explanation,
    required this.bookNumber, required this.chapter,
  });
}
