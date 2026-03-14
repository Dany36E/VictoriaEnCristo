import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/highlight.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../widgets/bible/verse_actions_sheet.dart';
import 'verse_compare_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE READER SCREEN - Lector inmersivo
/// Muestra los versículos de un capítulo con highlights, notas, acciones.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleReaderScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleVersion version;

  const BibleReaderScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.version,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  List<BibleVerse> _verses = [];
  bool _loading = true;
  late int _currentChapter;
  late BibleVersion _currentVersion;
  int _totalChapters = 1;
  final _scrollController = ScrollController();

  // UI toggles
  bool _showHeader = true;

  @override
  void initState() {
    super.initState();
    _currentChapter = widget.chapter;
    _currentVersion = widget.version;
    _loadChapter();
  }

  Future<void> _loadChapter() async {
    setState(() => _loading = true);

    // Get total chapters for navigation
    final books = await BibleParserService.I.getBooks(_currentVersion);
    final book = books.where((b) => b.number == widget.bookNumber).firstOrNull;
    if (book != null) _totalChapters = book.totalChapters;

    final verses = await BibleParserService.I.getChapter(
      version: _currentVersion,
      bookNumber: widget.bookNumber,
      chapter: _currentChapter,
    );

    if (mounted) {
      setState(() {
        _verses = verses;
        _loading = false;
      });
      _scrollController.jumpTo(0);
    }
  }

  void _goToChapter(int chapter) {
    if (chapter < 1 || chapter > _totalChapters) return;
    _currentChapter = chapter;
    _loadChapter();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      body: GestureDetector(
        onTap: () => setState(() => _showHeader = !_showHeader),
        child: SafeArea(
          child: Column(
            children: [
              if (_showHeader) _buildHeader(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppDesignSystem.gold))
                    : _buildVerseList(),
              ),
              _buildChapterNavigation(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: AppDesignSystem.midnight,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.bookName,
                  style: GoogleFonts.cinzel(
                    color: AppDesignSystem.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  'Capítulo $_currentChapter · ${_currentVersion.shortName}',
                  style: GoogleFonts.manrope(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Chapter selector
          IconButton(
            icon: const Icon(Icons.list, color: Colors.white70, size: 22),
            onPressed: _showChapterPicker,
          ),
          // Version selector
          TextButton(
            onPressed: _showVersionPicker,
            child: Text(
              _currentVersion.shortName,
              style: GoogleFonts.manrope(
                color: AppDesignSystem.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseList() {
    return ValueListenableBuilder<Map<String, Highlight>>(
      valueListenable: BibleUserDataService.I.highlightsNotifier,
      builder: (context, highlights, _) {
        return ValueListenableBuilder<Map<String, dynamic>>(
          valueListenable: BibleUserDataService.I.notesNotifier,
          builder: (context, notes, _) {
            return ValueListenableBuilder<double>(
              valueListenable: BibleUserDataService.I.fontSizeNotifier,
              builder: (context, fontSize, _) {
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 16),
                  itemCount: _verses.length,
                  itemBuilder: (context, index) {
                    final verse = _verses[index];
                    final key = verse.uniqueKey;
                    final highlight = highlights[key];
                    final hasNote = notes.containsKey(key);
                    final isSaved = BibleUserDataService.I.isVerseSaved(
                      verse.bookNumber,
                      verse.chapter,
                      verse.verse,
                    );

                    return _VerseWidget(
                      verse: verse,
                      highlight: highlight,
                      hasNote: hasNote,
                      isSaved: isSaved,
                      fontSize: fontSize,
                      onTap: () => _showVerseActions(verse),
                      onLongPress: () => _showVerseActions(verse),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildChapterNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppDesignSystem.midnight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous chapter
          TextButton.icon(
            onPressed:
                _currentChapter > 1 ? () => _goToChapter(_currentChapter - 1) : null,
            icon: Icon(
              Icons.chevron_left,
              color: _currentChapter > 1 ? Colors.white70 : Colors.white12,
              size: 20,
            ),
            label: Text(
              'Anterior',
              style: GoogleFonts.manrope(
                color: _currentChapter > 1 ? Colors.white70 : Colors.white12,
                fontSize: 13,
              ),
            ),
          ),
          // Chapter indicator
          Text(
            '$_currentChapter / $_totalChapters',
            style: GoogleFonts.manrope(
              color: AppDesignSystem.gold,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          // Next chapter
          TextButton.icon(
            onPressed: _currentChapter < _totalChapters
                ? () => _goToChapter(_currentChapter + 1)
                : null,
            icon: Text(
              'Siguiente',
              style: GoogleFonts.manrope(
                color: _currentChapter < _totalChapters
                    ? Colors.white70
                    : Colors.white12,
                fontSize: 13,
              ),
            ),
            label: Icon(
              Icons.chevron_right,
              color: _currentChapter < _totalChapters
                  ? Colors.white70
                  : Colors.white12,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  void _showVerseActions(BibleVerse verse) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VerseActionsSheet(
        verse: verse,
        onCompare: () {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VerseCompareScreen(
                bookNumber: verse.bookNumber,
                bookName: verse.bookName,
                chapter: verse.chapter,
                verse: verse.verse,
              ),
            ),
          );
        },
      ),
    );
  }

  void _showChapterPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignSystem.midnight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CAPÍTULO',
                style: GoogleFonts.cinzel(
                  color: AppDesignSystem.gold,
                  fontSize: 16,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 300,
                child: GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemCount: _totalChapters,
                  itemBuilder: (context, index) {
                    final chapter = index + 1;
                    final isCurrent = chapter == _currentChapter;
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _goToChapter(chapter);
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isCurrent
                              ? AppDesignSystem.gold.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: isCurrent
                              ? Border.all(color: AppDesignSystem.gold)
                              : null,
                        ),
                        child: Text(
                          '$chapter',
                          style: GoogleFonts.manrope(
                            color: isCurrent ? AppDesignSystem.gold : Colors.white70,
                            fontSize: 13,
                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showVersionPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignSystem.midnight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'VERSIÓN',
                style: GoogleFonts.cinzel(
                  color: AppDesignSystem.gold,
                  fontSize: 16,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              ...BibleVersion.values.map((v) => ListTile(
                    leading: Icon(
                      v == _currentVersion ? Icons.check_circle : Icons.circle_outlined,
                      color: v == _currentVersion ? AppDesignSystem.gold : Colors.white24,
                    ),
                    title: Text(v.displayName,
                        style: GoogleFonts.manrope(color: Colors.white)),
                    subtitle: Text(v.shortName,
                        style: GoogleFonts.manrope(
                            color: Colors.white38, fontSize: 12)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentVersion = v;
                      });
                      _loadChapter();
                    },
                  )),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// VERSE WIDGET
// ══════════════════════════════════════════════════════════════════════════

class _VerseWidget extends StatelessWidget {
  final BibleVerse verse;
  final Highlight? highlight;
  final bool hasNote;
  final bool isSaved;
  final double fontSize;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _VerseWidget({
    required this.verse,
    this.highlight,
    required this.hasNote,
    required this.isSaved,
    required this.fontSize,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final highlightColor = highlight?.color.withOpacity(0.2);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: highlightColor != null
            ? BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Verse number
            SizedBox(
              width: 28,
              child: Text(
                '${verse.verse}',
                style: GoogleFonts.manrope(
                  color: AppDesignSystem.gold.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            // Verse text
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: verse.text,
                  style: GoogleFonts.crimsonPro(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: fontSize,
                    height: 1.7,
                  ),
                  children: [
                    if (hasNote)
                      const WidgetSpan(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.note, color: AppDesignSystem.gold, size: 14),
                        ),
                      ),
                    if (isSaved)
                      const WidgetSpan(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.bookmark, color: AppDesignSystem.gold, size: 14),
                        ),
                      ),
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
