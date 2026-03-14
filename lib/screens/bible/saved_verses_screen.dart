import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/bible/saved_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_user_data_service.dart';
import 'bible_reader_screen.dart';

/// Pantalla de versículos guardados/marcados por el usuario.
class SavedVersesScreen extends StatelessWidget {
  const SavedVersesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.midnight,
        elevation: 0,
        title: Text(
          'GUARDADOS',
          style: GoogleFonts.cinzel(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: AppDesignSystem.gold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ValueListenableBuilder<List<SavedVerse>>(
        valueListenable: BibleUserDataService.I.savedVersesNotifier,
        builder: (context, saved, _) {
          if (saved.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_border, color: Colors.white12, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes versículos guardados',
                    style: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Toca un versículo mientras lees\npara marcarlo',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: saved.length,
            itemBuilder: (context, index) {
              final sv = saved[index];
              return _SavedVerseTile(
                savedVerse: sv,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BibleReaderScreen(
                      bookNumber: sv.bookNumber,
                      bookName: sv.bookName,
                      chapter: sv.chapter,
                      version: BibleVersion.fromId(sv.version),
                    ),
                  ),
                ),
                onDelete: () {
                  BibleUserDataService.I.toggleSavedVerse(
                    bookNumber: sv.bookNumber,
                    chapter: sv.chapter,
                    verse: sv.verse,
                    bookName: sv.bookName,
                    text: sv.text,
                    version: sv.version,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _SavedVerseTile extends StatelessWidget {
  final SavedVerse savedVerse;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  const _SavedVerseTile({
    required this.savedVerse,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bookmark, color: AppDesignSystem.gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  savedVerse.reference,
                  style: GoogleFonts.manrope(
                    color: AppDesignSystem.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  savedVerse.version,
                  style: GoogleFonts.manrope(
                    color: Colors.white24,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.close, color: Colors.white24, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              savedVerse.text,
              style: GoogleFonts.crimsonPro(
                color: Colors.white70,
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
