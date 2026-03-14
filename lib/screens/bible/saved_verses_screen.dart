import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/saved_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// SAVED VERSES SCREEN — Edición editorial premium
///
/// Sin AppBar, sin cards. Items planos con swipe-to-delete.
/// ═══════════════════════════════════════════════════════════════════════════
class SavedVersesScreen extends StatelessWidget {
  const SavedVersesScreen({super.key});

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
                _buildHeader(context, t),
                Expanded(child: _buildBody(context, t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, BibleReaderThemeData t) {
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
          Text(
            'Versículos guardados',
            style: GoogleFonts.cinzel(
              color: t.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, BibleReaderThemeData t) {
    return ValueListenableBuilder<List<SavedVerse>>(
      valueListenable: BibleUserDataService.I.savedVersesNotifier,
      builder: (context, saved, _) {
        if (saved.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                'Los versículos que guardes\naparecerán aquí',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          itemCount: saved.length,
          itemBuilder: (context, index) {
            final sv = saved[index];
            return _buildVerseTile(context, sv, t);
          },
        );
      },
    );
  }

  Widget _buildVerseTile(
      BuildContext context, SavedVerse sv, BibleReaderThemeData t) {
    return Dismissible(
      key: ValueKey(sv.verseKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          'Eliminar',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onDismissed: (_) {
        BibleUserDataService.I.toggleSavedVerse(
          bookNumber: sv.bookNumber,
          chapter: sv.chapter,
          verse: sv.verse,
          bookName: sv.bookName,
          text: sv.text,
          version: sv.version,
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => BibleReaderScreen(
              bookNumber: sv.bookNumber,
              bookName: sv.bookName,
              chapter: sv.chapter,
              version: BibleVersion.fromId(sv.version),
            ),
            transitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (ctx, a, sa, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        ),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sv.reference.toUpperCase(),
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                sv.text,
                style: GoogleFonts.lora(
                  color: t.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
