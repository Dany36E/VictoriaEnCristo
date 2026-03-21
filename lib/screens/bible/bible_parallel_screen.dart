import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/highlight.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/recent_colors_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/full_color_picker_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PARALLEL BIBLE VIEW — Split-screen de 2 versiones, capítulo completo,
/// scroll sincronizado, lectura continua tipo prosa.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleParallelScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleVersion primaryVersion;

  const BibleParallelScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.primaryVersion,
  });

  @override
  State<BibleParallelScreen> createState() => _BibleParallelScreenState();
}

class _BibleParallelScreenState extends State<BibleParallelScreen> {
  late BibleVersion _leftVersion;
  late BibleVersion _rightVersion;
  late int _currentChapter;
  late int _bookNumber;
  late String _bookName;
  int _maxChapters = 150;
  bool _loading = true;
  List<BibleVerse> _leftVerses = [];
  List<BibleVerse> _rightVerses = [];
  List<BibleBook> _allBooks = [];

  // Synchronized scroll
  final ScrollController _leftScroll = ScrollController();
  final ScrollController _rightScroll = ScrollController();
  bool _syncing = false;
  int? _selectedVerse;

  // Font size for parallel view
  double _parallelFontSize = 14.0;

  @override
  void initState() {
    super.initState();
    _bookNumber = widget.bookNumber;
    _bookName = widget.bookName;
    _currentChapter = widget.chapter;
    _leftVersion = widget.primaryVersion;
    // Pick a different version for right side
    _rightVersion = BibleVersion.values.firstWhere(
      (v) => v != _leftVersion,
      orElse: () => BibleVersion.values.first,
    );
    _leftScroll.addListener(_onLeftScroll);
    _rightScroll.addListener(_onRightScroll);
    SharedPreferences.getInstance().then((prefs) {
      final saved = prefs.getDouble('parallel_font_size');
      if (saved != null && mounted) setState(() => _parallelFontSize = saved);
    });
    _loadAll();
  }

  void _onLeftScroll() {
    if (_syncing) return;
    _syncing = true;
    if (_rightScroll.hasClients && _leftScroll.hasClients) {
      final max = _leftScroll.position.maxScrollExtent;
      if (max > 0) {
        final ratio = _leftScroll.offset / max;
        final target = ratio * _rightScroll.position.maxScrollExtent;
        _rightScroll.jumpTo(target.clamp(0, _rightScroll.position.maxScrollExtent));
      }
    }
    _syncing = false;
  }

  void _onRightScroll() {
    if (_syncing) return;
    _syncing = true;
    if (_leftScroll.hasClients && _rightScroll.hasClients) {
      final max = _rightScroll.position.maxScrollExtent;
      if (max > 0) {
        final ratio = _rightScroll.offset / max;
        final target = ratio * _leftScroll.position.maxScrollExtent;
        _leftScroll.jumpTo(target.clamp(0, _leftScroll.position.maxScrollExtent));
      }
    }
    _syncing = false;
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final books = await BibleParserService.I.getBooks(_leftVersion);
      _allBooks = books;
      final book = books.where((b) => b.number == _bookNumber).firstOrNull;
      if (book != null) _maxChapters = book.totalChapters;

      final results = await Future.wait([
        BibleParserService.I.getChapter(
          version: _leftVersion, bookNumber: _bookNumber, chapter: _currentChapter),
        BibleParserService.I.getChapter(
          version: _rightVersion, bookNumber: _bookNumber, chapter: _currentChapter),
      ]);
      _leftVerses = results[0];
      _rightVerses = results[1];
    } catch (_) {
      _leftVerses = [];
      _rightVerses = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _changeChapter(int delta) {
    final next = _currentChapter + delta;
    if (next < 1 || next > _maxChapters) return;
    _currentChapter = next;
    if (_leftScroll.hasClients) _leftScroll.jumpTo(0);
    if (_rightScroll.hasClients) _rightScroll.jumpTo(0);
    _loadAll();
  }

  void _swapVersions() {
    HapticFeedback.lightImpact();
    setState(() {
      final tmp = _leftVersion;
      _leftVersion = _rightVersion;
      _rightVersion = tmp;
      final tmpV = _leftVerses;
      _leftVerses = _rightVerses;
      _rightVerses = tmpV;
    });
  }

  void _pickVersion({required bool isLeft}) {
    final current = isLeft ? _leftVersion : _rightVersion;
    final other = isLeft ? _rightVersion : _leftVersion;
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: t.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isLeft ? 'VERSIÓN IZQUIERDA' : 'VERSIÓN DERECHA',
              style: GoogleFonts.cinzel(
                color: t.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            ...BibleVersion.values.map((v) {
              final isCurrent = v == current;
              final isOtherSide = v == other;
              return ListTile(
                leading: Icon(
                  isCurrent ? Icons.check_circle : Icons.menu_book_outlined,
                  color: isCurrent ? t.accent : (isOtherSide ? t.textSecondary.withOpacity(0.3) : t.textSecondary),
                  size: 20,
                ),
                title: Text(
                  v.displayName,
                  style: GoogleFonts.manrope(
                    color: isOtherSide ? t.textSecondary.withOpacity(0.3) : t.textPrimary,
                    fontSize: 14,
                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(v.shortName,
                    style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5), fontSize: 12)),
                enabled: !isOtherSide,
                onTap: isOtherSide ? null : () {
                  Navigator.pop(ctx);
                  setState(() {
                    if (isLeft) {
                      _leftVersion = v;
                    } else {
                      _rightVersion = v;
                    }
                  });
                  _loadAll();
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openBookPicker() async {
    if (_allBooks.isEmpty) return;
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );

    // Step 1: pick book
    final BibleBook? selectedBook = await showModalBottomSheet<BibleBook>(
      context: context,
      backgroundColor: t.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (ctx, scroll) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('SELECCIONAR LIBRO',
                style: GoogleFonts.cinzel(
                  color: t.accent, fontSize: 12,
                  fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            ),
            Expanded(
              child: ListView.builder(
                controller: scroll,
                itemCount: _allBooks.length,
                itemBuilder: (ctx, i) {
                  final book = _allBooks[i];
                  final isCurrent = book.number == _bookNumber;
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.menu_book_outlined,
                        color: isCurrent ? t.accent : t.textSecondary, size: 18),
                    title: Text(book.name,
                      style: GoogleFonts.manrope(
                        color: isCurrent ? t.accent : t.textPrimary,
                        fontSize: 14,
                        fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w400)),
                    trailing: Text('${book.totalChapters} cap.',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5), fontSize: 11)),
                    onTap: () => Navigator.pop(ctx, book),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedBook == null || !mounted) return;

    // Step 2: pick chapter
    final int? selectedChapter = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: t.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${selectedBook.name.toUpperCase()} — CAPÍTULO',
              style: GoogleFonts.cinzel(
                color: t.accent, fontSize: 12,
                fontWeight: FontWeight.w700, letterSpacing: 1)),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7, mainAxisSpacing: 8, crossAxisSpacing: 8),
                itemCount: selectedBook.totalChapters,
                itemBuilder: (ctx, i) {
                  final ch = i + 1;
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(ctx, ch),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: t.textSecondary.withOpacity(0.06),
                        ),
                        child: Text('$ch',
                          style: GoogleFonts.manrope(
                            color: t.textPrimary, fontSize: 14,
                            fontWeight: FontWeight.w500)),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedChapter == null || !mounted) return;

    _bookNumber = selectedBook.number;
    _bookName = selectedBook.name;
    _currentChapter = selectedChapter;
    _maxChapters = selectedBook.totalChapters;
    if (_leftScroll.hasClients) _leftScroll.jumpTo(0);
    if (_rightScroll.hasClients) _rightScroll.jumpTo(0);
    _loadAll();
  }

  @override
  void dispose() {
    _leftScroll.removeListener(_onLeftScroll);
    _rightScroll.removeListener(_onRightScroll);
    _leftScroll.dispose();
    _rightScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );

    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(t),
            _buildVersionBar(t),
            Expanded(child: _buildSplitContent(t)),
            _buildBottomNav(t),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      color: t.background,
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          GestureDetector(
            onTap: _openBookPicker,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.compare_arrows, color: t.accent, size: 18),
                const SizedBox(width: 6),
                Text(
                  '$_bookName $_currentChapter',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.keyboard_arrow_down, color: t.textSecondary, size: 18),
              ],
            ),
          ),
          const Spacer(),
          // Font size controls
          GestureDetector(
            onTap: () {
              setState(() => _parallelFontSize = (_parallelFontSize - 1).clamp(10.0, 24.0));
              SharedPreferences.getInstance().then((p) => p.setDouble('parallel_font_size', _parallelFontSize));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('A\u2212', style: GoogleFonts.manrope(
                color: t.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
          Text('${_parallelFontSize.toInt()}',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.6), fontSize: 11)),
          GestureDetector(
            onTap: () {
              setState(() => _parallelFontSize = (_parallelFontSize + 1).clamp(10.0, 24.0));
              SharedPreferences.getInstance().then((p) => p.setDouble('parallel_font_size', _parallelFontSize));
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text('A+', style: GoogleFonts.manrope(
                color: t.textSecondary, fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(Icons.swap_horiz, color: t.accent, size: 22),
            onPressed: _swapVersions,
            tooltip: 'Intercambiar versiones',
          ),
        ],
      ),
    );
  }

  Widget _buildVersionBar(BibleReaderThemeData t) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.textSecondary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _pickVersion(isLeft: true),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.06),
                  border: Border(
                    bottom: BorderSide(color: t.accent, width: 2),
                    right: BorderSide(color: t.textSecondary.withOpacity(0.15)),
                  ),
                ),
                child: Text(
                  _leftVersion.shortName,
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _pickVersion(isLeft: false),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.06),
                  border: Border(
                    bottom: BorderSide(color: t.accent, width: 2),
                  ),
                ),
                child: Text(
                  _rightVersion.shortName,
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitContent(BibleReaderThemeData t) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: t.accent, strokeWidth: 1.5),
      );
    }

    if (_leftVerses.isEmpty && _rightVerses.isEmpty) {
      return Center(
        child: Text(
          'No se pudieron cargar los versículos',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.5), fontSize: 14),
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: _buildColumn(t, _leftVerses, _leftScroll, true)),
        Container(width: 1, color: t.textSecondary.withOpacity(0.12)),
        Expanded(child: _buildColumn(t, _rightVerses, _rightScroll, false)),
      ],
    );
  }

  Widget _buildColumn(
    BibleReaderThemeData t,
    List<BibleVerse> verses,
    ScrollController controller,
    bool isLeft,
  ) {
    return ValueListenableBuilder<Map<String, Highlight>>(
      valueListenable: BibleUserDataService.I.highlightsNotifier,
      builder: (context, highlights, _) {
        return ListView.builder(
          controller: controller,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          itemCount: verses.length,
          itemBuilder: (ctx, idx) {
            final verse = verses[idx];
            final isSelected = _selectedVerse == verse.verse;
            final hlKey = '${_bookNumber}:${_currentChapter}:${verse.verse}';
            final highlight = highlights[hlKey];
            final highlightBg = highlight != null
                ? t.highlightOverlay(highlight.color)
                : null;
            return GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                setState(() =>
                    _selectedVerse = isSelected ? null : verse.verse);
                if (!isSelected) _showVerseActions(t, verse);
              },
              onTap: _selectedVerse != null
                  ? () => setState(() => _selectedVerse = null)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                decoration: isSelected
                    ? BoxDecoration(
                        color: t.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      )
                    : null,
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${verse.verse} ',
                        style: GoogleFonts.manrope(
                          color: t.accent.withOpacity(isSelected ? 0.9 : 0.5),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: verse.text,
                        style: GoogleFonts.lora(
                          color: t.textPrimary,
                          fontSize: _parallelFontSize,
                          height: 1.7,
                          backgroundColor: highlightBg,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showVerseActions(BibleReaderThemeData t, BibleVerse verse) {
    // Find the matching verse from both sides
    final leftVerse = _leftVerses.where((v) => v.verse == verse.verse).firstOrNull;
    final rightVerse = _rightVerses.where((v) => v.verse == verse.verse).firstOrNull;

    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              '$_bookName $_currentChapter:${verse.verse}',
              style: GoogleFonts.cinzel(
                color: t.accent,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _actionChip(t, Icons.format_paint_outlined, 'Subrayar', () {
                  Navigator.pop(ctx);
                  _showHighlightPicker(t, verse.verse);
                }),
                _actionChip(t, Icons.copy_outlined, 'Copiar ambas', () {
                  Navigator.pop(ctx);
                  _copyBothVersions(leftVerse, rightVerse);
                }),
                _actionChip(t, Icons.copy, _leftVersion.shortName, () {
                  Navigator.pop(ctx);
                  if (leftVerse != null) {
                    Clipboard.setData(ClipboardData(
                      text:
                          '$_bookName $_currentChapter:${leftVerse.verse} (${_leftVersion.shortName})\n${leftVerse.text}',
                    ));
                    _showSnack('Versículo copiado');
                  }
                }),
                _actionChip(t, Icons.copy, _rightVersion.shortName, () {
                  Navigator.pop(ctx);
                  if (rightVerse != null) {
                    Clipboard.setData(ClipboardData(
                      text:
                          '$_bookName $_currentChapter:${rightVerse.verse} (${_rightVersion.shortName})\n${rightVerse.text}',
                    ));
                    _showSnack('Versículo copiado');
                  }
                }),
                _actionChip(t, Icons.share_outlined, 'Compartir', () {
                  Navigator.pop(ctx);
                  _copyBothVersions(leftVerse, rightVerse);
                }),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedVerse = null);
    });
  }

  Widget _actionChip(
    BibleReaderThemeData t, IconData icon, String label, VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.accent.withOpacity(0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: t.accent),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _copyBothVersions(BibleVerse? left, BibleVerse? right) {
    final buf = StringBuffer();
    buf.writeln('$_bookName $_currentChapter:${left?.verse ?? right?.verse}');
    if (left != null) {
      buf.writeln('${_leftVersion.shortName}: ${left.text}');
    }
    if (right != null) {
      buf.writeln('${_rightVersion.shortName}: ${right.text}');
    }
    Clipboard.setData(ClipboardData(text: buf.toString().trim()));
    _showSnack('Ambas versiones copiadas');
  }

  void _showHighlightPicker(BibleReaderThemeData t, int verseNumber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Subrayar versículo $verseNumber',
              style: GoogleFonts.manrope(
                color: t.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ...HighlightColors.defaults.map((color) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _highlightVerse(verseNumber, HighlightColors.toHex(color));
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                }),
                GestureDetector(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final color = await showModalBottomSheet<Color>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      builder: (_) => FullColorPickerSheet(theme: t),
                    );
                    if (color != null) {
                      _highlightVerse(verseNumber, HighlightColors.toHex(color));
                    }
                  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Color(0xFFFF0000), Color(0xFFFFFF00),
                          Color(0xFF00FF00), Color(0xFF00FFFF),
                          Color(0xFF0000FF), Color(0xFFFF00FF),
                          Color(0xFFFF0000),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _highlightVerse(int verseNumber, String colorHex) {
    RecentColorsService.I.addRecentColor(colorHex);
    BibleUserDataService.I.addHighlight(
      bookNumber: _bookNumber,
      chapter: _currentChapter,
      verse: verseNumber,
      colorHex: colorHex,
    );
    HapticFeedback.lightImpact();
    setState(() => _selectedVerse = null);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  Widget _buildBottomNav(BibleReaderThemeData t) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: t.textSecondary.withOpacity(0.1)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _currentChapter > 1
              ? GestureDetector(
                  onTap: () => _changeChapter(-1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left, size: 18, color: t.accent),
                      Text('Cap. ${_currentChapter - 1}',
                          style: GoogleFonts.manrope(
                              color: t.accent, fontSize: 13, fontWeight: FontWeight.w500)),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
          Text(
            '$_bookName $_currentChapter',
            style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.5), fontSize: 12),
          ),
          _currentChapter < _maxChapters
              ? GestureDetector(
                  onTap: () => _changeChapter(1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Cap. ${_currentChapter + 1}',
                          style: GoogleFonts.manrope(
                              color: t.accent, fontSize: 13, fontWeight: FontWeight.w500)),
                      Icon(Icons.chevron_right, size: 18, color: t.accent),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
