import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_parser_service.dart';

/// Pantalla de comparación de un versículo en todas las versiones.
class VerseCompareScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int verse;

  const VerseCompareScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
  });

  @override
  State<VerseCompareScreen> createState() => _VerseCompareScreenState();
}

class _VerseCompareScreenState extends State<VerseCompareScreen> {
  Map<BibleVersion, BibleVerse?> _versions = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    final results = await BibleParserService.I.getVerseInAllVersions(
      bookNumber: widget.bookNumber,
      chapter: widget.chapter,
      verse: widget.verse,
    );
    if (mounted) {
      setState(() {
        _versions = results;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.midnight,
        elevation: 0,
        title: Column(
          children: [
            Text(
              'COMPARAR',
              style: GoogleFonts.cinzel(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: AppDesignSystem.gold,
              ),
            ),
            Text(
              '${widget.bookName} ${widget.chapter}:${widget.verse}',
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: Colors.white38,
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppDesignSystem.gold))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: BibleVersion.values.map((version) {
                final verse = _versions[version];
                if (verse == null) return const SizedBox.shrink();
                return _VersionCard(version: version, verse: verse);
              }).toList(),
            ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final BibleVersion version;
  final BibleVerse verse;
  const _VersionCard({required this.version, required this.verse});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppDesignSystem.gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              version.shortName,
              style: GoogleFonts.manrope(
                color: AppDesignSystem.gold,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            verse.text,
            style: GoogleFonts.crimsonPro(
              color: Colors.white.withOpacity(0.85),
              fontSize: 18,
              fontStyle: FontStyle.italic,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            version.displayName,
            style: GoogleFonts.manrope(
              color: Colors.white24,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
