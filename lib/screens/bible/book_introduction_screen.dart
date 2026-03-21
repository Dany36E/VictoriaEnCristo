import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/book_introduction.dart';
import '../../services/bible/bible_maps_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/book_intro_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_map_screen.dart';

/// Pantalla de introducción completa a un libro bíblico.
class BookIntroductionScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;

  const BookIntroductionScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
  });

  @override
  State<BookIntroductionScreen> createState() => _BookIntroductionScreenState();
}

class _BookIntroductionScreenState extends State<BookIntroductionScreen> {
  BookIntroduction? _intro;
  bool _loading = true;
  int _relatedMapsCount = 0;
  bool _showStudy = false;

  BibleReaderThemeData get _t => BibleReaderThemeData.fromId(
        BibleReaderThemeData.migrateId(
            BibleUserDataService.I.readerThemeNotifier.value),
      );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final intro =
          await BookIntroService.instance.getIntroduction(widget.bookNumber);
      final maps =
          await BibleMapsService.instance.getMapsForBook(widget.bookNumber);
      if (mounted) {
        setState(() {
          _intro = intro;
          _relatedMapsCount = maps.length;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('BookIntroScreen: Error loading: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _t.background,
      body: SafeArea(
        child: _loading
            ? Center(
                child:
                    CircularProgressIndicator(color: _t.accent))
            : _intro == null
                ? _buildEmptyState()
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final intro = _intro!;
    return CustomScrollView(
      slivers: [
        // ─── VIEW 1: Summary (visible on open) ───────────────────
        SliverToBoxAdapter(child: _buildHeader(intro)),
        SliverToBoxAdapter(child: _buildQuickFacts(intro)),
        SliverToBoxAdapter(
          child: _buildSection('PROPÓSITO', intro.purpose),
        ),
        SliverToBoxAdapter(child: _buildKeyThemes(intro)),

        // ─── VIEW 2: Context (revealed on scroll) ────────────────
        SliverToBoxAdapter(
          child: _buildSection('CONTEXTO HISTÓRICO', intro.historicalContext),
        ),
        if (intro.structure.isNotEmpty)
          SliverToBoxAdapter(child: _buildStructure(intro)),

        // ─── VIEW 3: Study (behind button) ────────────────────────
        if (!_showStudy)
          SliverToBoxAdapter(child: _buildStudyButton())
        else ...[
          SliverToBoxAdapter(child: _buildKeyVerses(intro)),
          if (_relatedMapsCount > 0)
            SliverToBoxAdapter(child: _buildMapsLink()),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildStudyButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: GestureDetector(
        onTap: () => setState(() => _showStudy = true),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            color: _t.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _t.accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school_outlined,
                  color: _t.accent, size: 18),
              const SizedBox(width: 8),
              Text(
                'Ver estudio completo',
                style: GoogleFonts.manrope(
                  color: _t.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BookIntroduction intro) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back,
                    color: _t.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Icon(Icons.auto_stories_outlined,
                  color: _t.accent, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'INTRODUCCIÓN',
                  style: GoogleFonts.cinzel(
                    color: _t.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 4),
          child: Text(
            intro.name,
            style: GoogleFonts.cinzel(
              color: _t.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 40,
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_t.accent, _t.accent.withValues(alpha: 0.3)],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildQuickFacts(BookIntroduction intro) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _t.surface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: _t.accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            _buildFactRow(Icons.person_outline, 'Autor', intro.author),
            if (intro.authorDetails.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Text(
                  intro.authorDetails,
                  style: GoogleFonts.manrope(
                    color:
                        _t.textPrimary.withValues(alpha: 0.5),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            _buildFactRow(
                Icons.calendar_today_outlined, 'Fecha', intro.writtenDate),
            const SizedBox(height: 10),
            _buildFactRow(
                Icons.history_outlined, 'Período', intro.period),
            const SizedBox(height: 10),
            _buildFactRow(
                Icons.people_outline, 'Audiencia', intro.audience),
          ],
        ),
      ),
    );
  }

  Widget _buildFactRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: _t.accent.withValues(alpha: 0.7)),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: _t.accent.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.manrope(
              color: _t.textPrimary.withValues(alpha: 0.85),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cinzel(
              color: _t.accent.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.manrope(
              color: _t.textPrimary.withValues(alpha: 0.85),
              fontSize: 14,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyThemes(BookIntroduction intro) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TEMAS CLAVE',
            style: GoogleFonts.cinzel(
              color: _t.accent.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: intro.keyThemes
                .map((theme) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            _t.accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _t.accent
                                .withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        theme,
                        style: GoogleFonts.manrope(
                          color: _t.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyVerses(BookIntroduction intro) {
    if (intro.keyVerses.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VERSÍCULOS CLAVE',
            style: GoogleFonts.cinzel(
              color: _t.accent.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...intro.keyVerses.map((ref) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(Icons.bookmark_outline,
                        size: 14,
                        color:
                            _t.accent.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Text(
                      ref,
                      style: GoogleFonts.manrope(
                        color: _t.textPrimary
                            .withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStructure(BookIntroduction intro) {
    if (intro.structure.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ESTRUCTURA',
            style: GoogleFonts.cinzel(
              color: _t.accent.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...intro.structure.map((section) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _t.accent
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        section.chapters,
                        style: GoogleFonts.manrope(
                          color: _t.accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        section.title,
                        style: GoogleFonts.manrope(
                          color: _t.textPrimary
                              .withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildMapsLink() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                BibleMapScreen(initialBookNumber: widget.bookNumber),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _t.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _t.accent.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.map_outlined,
                  color: _t.accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mapas relacionados',
                      style: GoogleFonts.manrope(
                        color: _t.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$_relatedMapsCount mapa${_relatedMapsCount != 1 ? 's' : ''} disponible${_relatedMapsCount != 1 ? 's' : ''}',
                      style: GoogleFonts.manrope(
                        color: _t.textPrimary
                            .withValues(alpha: 0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios,
                  size: 14,
                  color:
                      _t.textPrimary.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back,
                color: _t.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 24),
          Icon(Icons.auto_stories_outlined,
              size: 48,
              color: _t.accent.withValues(alpha: 0.3)),
          const SizedBox(height: 12),
          Text(
            'Introducción no disponible',
            style: GoogleFonts.manrope(
              color: _t.textPrimary.withValues(alpha: 0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
