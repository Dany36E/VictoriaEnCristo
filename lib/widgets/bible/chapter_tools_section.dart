import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/bible_map_models.dart';
import '../../services/bible/bible_maps_service.dart';
import '../../services/bible/book_intro_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../screens/bible/bible_map_screen.dart';
import '../../screens/bible/bible_parallel_screen.dart';
import '../../screens/bible/book_introduction_screen.dart';
import '../../screens/bible/enduring_word_screen.dart';

/// Sección de herramientas de capítulo al final de cada capítulo
/// en el BibleReaderScreen.
class ChapterToolsSection extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleReaderThemeData theme;

  const ChapterToolsSection({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.theme,
  });

  @override
  State<ChapterToolsSection> createState() => _ChapterToolsSectionState();
}

class _ChapterToolsSectionState extends State<ChapterToolsSection> {
  String? _chapterIntro;
  List<BibleMap> _relatedMaps = [];
  bool _hasBookIntro = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ChapterToolsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookNumber != widget.bookNumber ||
        oldWidget.chapter != widget.chapter) {
      _loaded = false;
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final intro = await BookIntroService.instance
        .getChapterIntro(widget.bookNumber, widget.chapter);
    final maps = await BibleMapsService.instance
        .getMapsForChapter(widget.bookNumber, widget.chapter);
    final hasIntro =
        await BookIntroService.instance.hasIntroduction(widget.bookNumber);

    if (mounted) {
      setState(() {
        _chapterIntro = intro;
        _relatedMaps = maps;
        _hasBookIntro = hasIntro;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const SizedBox.shrink();

    // Always show (at least the parallel reading + enduring word cards)
    final t = widget.theme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Center(
            child: Container(
              width: 40,
              height: 1,
              color: t.accent.withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 16),

          // Section title
          Row(
            children: [
              Icon(Icons.build_outlined,
                  size: 14, color: t.accent.withOpacity(0.5)),
              const SizedBox(width: 8),
              Text(
                'HERRAMIENTAS DEL CAPÍTULO',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chapter intro
          if (_chapterIntro != null) _buildChapterIntroCard(t),

          // Related maps
          if (_relatedMaps.isNotEmpty) _buildMapsCard(t),

          // Book intro link
          if (_hasBookIntro) _buildBookIntroCard(t),

          // Parallel reader
          _buildParallelCard(t),

          // Enduring Word commentary (David Guzik)
          _buildEnduringWordCard(t),
        ],
      ),
    );
  }

  Widget _buildChapterIntroCard(BibleReaderThemeData t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: t.accent.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text(
                'Sobre este capítulo',
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _chapterIntro!,
            style: GoogleFonts.manrope(
              color: t.textPrimary.withOpacity(0.75),
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapsCard(BibleReaderThemeData t) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.map_outlined,
                  size: 16, color: t.accent.withOpacity(0.6)),
              const SizedBox(width: 8),
              Text(
                'Mapas relacionados',
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_relatedMaps.length}',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ..._relatedMaps.take(3).map(
                (map) => GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BibleMapScreen(
                          initialBookNumber: widget.bookNumber),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(Icons.place,
                            size: 14,
                            color: t.accent.withOpacity(0.4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            map.title,
                            style: GoogleFonts.manrope(
                              color: t.textPrimary.withOpacity(0.7),
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 10,
                            color: t.textSecondary.withOpacity(0.3)),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildBookIntroCard(BibleReaderThemeData t) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookIntroductionScreen(
            bookNumber: widget.bookNumber,
            bookName: widget.bookName,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.accent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 18, color: t.accent.withOpacity(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Introducción a ${widget.bookName}',
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Autor, contexto, temas y estructura',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: t.textSecondary.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildParallelCard(BibleReaderThemeData t) {
    return GestureDetector(
      onTap: () {
        final version = BibleUserDataService.I.preferredVersionNotifier.value;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BibleParallelScreen(
              bookNumber: widget.bookNumber,
              bookName: widget.bookName,
              chapter: widget.chapter,
              primaryVersion: version,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.accent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.compare_outlined,
                size: 18, color: t.accent.withOpacity(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Lectura paralela',
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Comparar versiones lado a lado',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: t.textSecondary.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildEnduringWordCard(BibleReaderThemeData t) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EnduringWordScreen(
              bookNumber: widget.bookNumber,
              bookName: widget.bookName,
              chapter: widget.chapter,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withOpacity(0.03)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.accent.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined,
                size: 18, color: t.accent.withOpacity(0.6)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Comentario Enduring Word',
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'David Guzik — análisis del capítulo',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                size: 12, color: t.textSecondary.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
