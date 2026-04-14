import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/interlinear_word.dart';
import '../../../services/bible/interlinear_service.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../theme/bible_reader_theme.dart';
import '../interlinear_word_card.dart';

/// Tab 0 del VerseStudySheet: vista interlineal (hebreo/griego).
class InterlinealTab extends StatefulWidget {
  final BibleVerse verse;
  final ScrollController scrollController;

  const InterlinealTab({
    super.key,
    required this.verse,
    required this.scrollController,
  });

  @override
  State<InterlinealTab> createState() => _InterlinealTabState();
}

class _InterlinealTabState extends State<InterlinealTab>
    with AutomaticKeepAliveClientMixin {
  InterlinearVerse? _interlinearVerse;
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
      final verse = await InterlinearService.instance.getVerse(
        widget.verse.bookNumber,
        widget.verse.chapter,
        widget.verse.verse,
      );
      if (mounted) setState(() { _interlinearVerse = verse; _loading = false; });
    } catch (e) {
      debugPrint('🔤 [INTERLINEAL] Load error: $e');
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

    if (_interlinearVerse == null || _interlinearVerse!.words.isEmpty) {
      return _emptyState(t, 'No hay datos interlineales para este versículo');
    }

    return InterlinearSection(
      interlinearVerse: _interlinearVerse!,
      bookNumber: widget.verse.bookNumber,
      verseText: widget.verse.text,
      versionLabel: widget.verse.version,
      scrollController: widget.scrollController,
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
