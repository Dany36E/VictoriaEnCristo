import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// VERSE COMPARE SCREEN — Edición editorial premium
///
/// Carga TODAS las versiones en paralelo. Cada versión tiene su propio
/// estado de carga (loading / loaded / error). No bloquea si una falla.
/// ═══════════════════════════════════════════════════════════════════════════
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
  /// Estado por versión: null = loading, BibleVerse = loaded, 'error' = failed
  final Map<BibleVersion, BibleVerse?> _loaded = {};
  final Set<BibleVersion> _failed = {};
  final Set<BibleVersion> _loading = {};

  @override
  void initState() {
    super.initState();
    _loadAllVersions();
  }

  Future<void> _loadAllVersions() {
    final futures = BibleVersion.values.map(_loadVersion);
    return Future.wait(futures);
  }

  Future<void> _loadVersion(BibleVersion version) async {
    setState(() => _loading.add(version));
    try {
      final result = await BibleParserService.I
          .getVerse(
            version: version,
            bookNumber: widget.bookNumber,
            chapter: widget.chapter,
            verse: widget.verse,
          )
          .timeout(const Duration(seconds: 8));
      if (mounted) {
        setState(() {
          _loading.remove(version);
          if (result != null) {
            _loaded[version] = result;
          } else {
            _failed.add(version);
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading.remove(version);
          _failed.add(version);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
        SystemChrome.setSystemUIOverlayStyle(
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(t),
                Expanded(child: _buildBody(t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comparar',
                style: GoogleFonts.cinzel(
                  color: t.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.bookName} ${widget.chapter}:${widget.verse}',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BibleReaderThemeData t) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      itemCount: BibleVersion.values.length,
      itemBuilder: (context, index) {
        final version = BibleVersion.values[index];

        // Loading
        if (_loading.contains(version)) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.shortName.toUpperCase(),
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    color: t.accent.withOpacity(0.5),
                    backgroundColor: t.textSecondary.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          );
        }

        // Failed
        if (_failed.contains(version)) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  version.shortName.toUpperCase(),
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () {
                    _failed.remove(version);
                    _loadVersion(version);
                  },
                  child: Text(
                    'No disponible. Toca para reintentar.',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Loaded
        final verse = _loaded[version];
        if (verse == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                version.shortName.toUpperCase(),
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                verse.text,
                style: GoogleFonts.lora(
                  color: t.textPrimary,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
