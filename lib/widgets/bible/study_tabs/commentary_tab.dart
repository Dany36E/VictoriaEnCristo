import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/commentary_entry.dart';
import '../../../services/bible/commentary_service.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../theme/bible_reader_theme.dart';

/// Tab 1 del VerseStudySheet: comentarios multi-fuente.
class CommentaryTab extends StatefulWidget {
  final BibleVerse verse;
  final ScrollController scrollController;

  const CommentaryTab({
    super.key,
    required this.verse,
    required this.scrollController,
  });

  @override
  State<CommentaryTab> createState() => _CommentaryTabState();
}

class _CommentaryTabState extends State<CommentaryTab>
    with AutomaticKeepAliveClientMixin {
  Map<CommentarySource, List<CommentaryEntry>> _allCommentaries = {};
  CommentarySource _selectedSource = CommentarySource.matthewHenry;
  List<CommentaryEntry> _entries = [];
  bool _loading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final all = await CommentaryService.instance.getVerseCommentaryAllSources(
        widget.verse.bookNumber,
        widget.verse.chapter,
        widget.verse.verse,
      );
      if (mounted) {
        setState(() {
          _allCommentaries = all;
          if (all.isNotEmpty && !all.containsKey(_selectedSource)) {
            _selectedSource = all.keys.first;
          }
          _entries = all[_selectedSource] ?? [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('📝 [COMMENTARY] Load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = BibleReaderThemeData.fromId(
        BibleReaderThemeData.migrateId(
            BibleUserDataService.I.readerThemeNotifier.value));

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: t.accent));
    }

    final hasBook = CommentaryService.hasCommentary(widget.verse.bookNumber);
    if (!hasBook) {
      return _emptyState(t, 'Comentario no disponible para este libro');
    }

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        if (_allCommentaries.isNotEmpty || _entries.isNotEmpty) ...[
          _buildSourceSelector(t),
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
        if (_entries.isEmpty)
          _emptyState(t, 'No hay comentario para este versículo')
        else
          ..._entries.map((entry) => _buildEntry(t, entry)),
      ],
    );
  }

  Widget _buildSourceSelector(BibleReaderThemeData t) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: CommentarySource.values.map((source) {
          final isSelected = _selectedSource == source;
          final hasData = _allCommentaries.containsKey(source);
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: hasData
                  ? () => setState(() {
                        _selectedSource = source;
                        _entries = _allCommentaries[source] ?? [];
                      })
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? t.accent.withValues(alpha: 0.15)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? t.accent.withValues(alpha: 0.5)
                        : hasData
                            ? t.accent.withValues(alpha: 0.2)
                            : t.textPrimary.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  source.displayName,
                  style: GoogleFonts.manrope(
                    color: isSelected
                        ? t.accent
                        : hasData
                            ? t.textPrimary.withValues(alpha: 0.6)
                            : t.textPrimary.withValues(alpha: 0.2),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEntry(BibleReaderThemeData t, CommentaryEntry entry) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.accent.withValues(alpha: 0.1)),
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
    );
  }

  Widget _emptyState(BibleReaderThemeData t, String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.menu_book_outlined,
                  size: 40, color: t.accent.withValues(alpha: 0.3)),
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
}
