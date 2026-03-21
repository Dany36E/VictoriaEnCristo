import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/treasury_service.dart';
import '../../utils/cross_ref_classifier.dart';
import '../../utils/bible_navigation_helper.dart';
import '../../theme/bible_reader_theme.dart';

/// Bottom sheet dedicado de referencias cruzadas con clasificación por tipo.
class CrossRefSheet extends StatefulWidget {
  final int bookNumber;
  final int chapter;
  final int verse;
  final String bookName;
  final BibleReaderThemeData theme;
  final void Function(int bookNumber, String bookName, int chapter)? onNavigate;

  const CrossRefSheet({
    super.key,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.bookName,
    required this.theme,
    this.onNavigate,
  });

  @override
  State<CrossRefSheet> createState() => _CrossRefSheetState();
}

class _CrossRefSheetState extends State<CrossRefSheet> {
  final _treasury = TreasuryService.instance;
  List<_ClassifiedRef> _allRefs = [];
  bool _loading = true;
  CrossRefType? _activeFilter;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    final rawRefs = await _treasury.getCrossReferences(
      widget.bookNumber, widget.chapter, widget.verse);

    final version = BibleUserDataService.I.preferredVersionNotifier.value;
    final entries = <_ClassifiedRef>[];

    for (final ref in rawRefs) {
      final parsed = TreasuryService.parseReference(ref);
      if (parsed == null) continue;
      final type = CrossRefClassifier.classify(
          widget.bookNumber, parsed.bookNumber);

      // Cargar texto preview
      String preview = '';
      try {
        final verseData = await BibleParserService.I.getVerse(
          bookNumber: parsed.bookNumber,
          chapter: parsed.chapter,
          verse: parsed.verse,
          version: version,
        );
        if (verseData != null) {
          preview = verseData.text;
          if (preview.length > 120) {
            preview = '${preview.substring(0, 117)}...';
          }
        }
      } catch (_) {}

      final formatted = TreasuryService.formatReference(ref);
      entries.add(_ClassifiedRef(
        raw: ref,
        formatted: formatted,
        type: type,
        preview: preview,
        explanation: CrossRefClassifier.defaultExplanation(type),
        bookNumber: parsed.bookNumber,
        bookName: '',
        chapter: parsed.chapter,
      ));
    }

    if (mounted) setState(() { _allRefs = entries; _loading = false; });
  }

  List<_ClassifiedRef> get _filteredRefs {
    if (_activeFilter == null) return _allRefs;
    return _allRefs.where((r) => r.type == _activeFilter).toList();
  }

  Map<CrossRefType, int> get _typeCounts {
    final map = <CrossRefType, int>{};
    for (final r in _allRefs) {
      map[r.type] = (map[r.type] ?? 0) + 1;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.3,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.call_split, color: t.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.bookName} ${widget.chapter}:${widget.verse}',
                        style: GoogleFonts.cinzel(
                          color: t.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_loading)
                      Text(
                        '${_allRefs.length} refs',
                        style: GoogleFonts.manrope(
                          color: t.textSecondary.withOpacity(0.5),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Filter chips
              if (!_loading && _allRefs.isNotEmpty) _buildFilterChips(t),
              const Divider(height: 1),
              // Content
              Expanded(
                child: _loading
                    ? Center(
                        child: CircularProgressIndicator(color: t.accent),
                      )
                    : _allRefs.isEmpty
                        ? Center(
                            child: Text(
                              'No se encontraron referencias cruzadas',
                              style: GoogleFonts.manrope(
                                  color: t.textSecondary, fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: _filteredRefs.length,
                            itemBuilder: (_, i) =>
                                _buildRefTile(_filteredRefs[i], t),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChips(BibleReaderThemeData t) {
    final counts = _typeCounts;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          _chip(t, 'Todos', null, _allRefs.length),
          ...CrossRefType.values
              .where((type) => counts.containsKey(type))
              .map((type) => _chip(
                  t, CrossRefClassifier.label(type), type, counts[type]!)),
        ],
      ),
    );
  }

  Widget _chip(
      BibleReaderThemeData t, String label, CrossRefType? type, int count) {
    final active = _activeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text('$label ($count)'),
        selected: active,
        onSelected: (_) => setState(() => _activeFilter = type),
        labelStyle: GoogleFonts.manrope(
          color: active ? t.background : t.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: t.isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
        selectedColor: t.accent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }

  Widget _buildRefTile(_ClassifiedRef ref, BibleReaderThemeData t) {
    final typeColor = _typeColor(ref.type, t);
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        widget.onNavigate?.call(ref.bookNumber, ref.bookName, ref.chapter);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: typeColor, width: 3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  ref.formatted,
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    CrossRefClassifier.label(ref.type),
                    style: GoogleFonts.manrope(
                      color: typeColor,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => _showExplanation(context, ref, t),
                  child: Text('¿Por qué?',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: t.accent.withOpacity(0.6),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            if (ref.preview.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                ref.preview,
                style: GoogleFonts.crimsonPro(
                  color: t.textSecondary.withOpacity(0.7),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showExplanation(BuildContext context, _ClassifiedRef ref, BibleReaderThemeData t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(ref.formatted,
          style: GoogleFonts.cinzel(color: t.accent, fontSize: 16)),
        content: Text(ref.explanation,
          style: GoogleFonts.manrope(
            color: t.textPrimary,
            fontSize: 13,
            height: 1.6,
          )),
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

  Color _typeColor(CrossRefType type, BibleReaderThemeData t) {
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
}

class _ClassifiedRef {
  final String raw;
  final String formatted;
  final CrossRefType type;
  final String preview;
  final String explanation;
  final int bookNumber;
  final String bookName;
  final int chapter;

  const _ClassifiedRef({
    required this.raw,
    required this.formatted,
    required this.type,
    required this.preview,
    required this.explanation,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
  });
}
