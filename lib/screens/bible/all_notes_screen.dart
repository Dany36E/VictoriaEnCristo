import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/bible/bible_note.dart';
import '../../services/bible/bible_user_data_service.dart';
import 'bible_reader_screen.dart';

/// Pantalla con todas las notas del usuario ordenadas por fecha.
class AllNotesScreen extends StatelessWidget {
  const AllNotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.midnight,
        elevation: 0,
        title: Text(
          'MIS NOTAS',
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
      body: ValueListenableBuilder<Map<String, BibleNote>>(
        valueListenable: BibleUserDataService.I.notesNotifier,
        builder: (context, notesMap, _) {
          final notes = notesMap.values.toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.note_outlined, color: Colors.white12, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes notas',
                    style: GoogleFonts.manrope(color: Colors.white38, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Escribe reflexiones sobre los\nversículos que lees',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(color: Colors.white24, fontSize: 12),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notes.length,
            itemBuilder: (context, index) {
              final note = notes[index];
              return _NoteTile(
                note: note,
                onTap: () {
                  final version = BibleUserDataService.I.preferredVersionNotifier.value;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BibleReaderScreen(
                        bookNumber: note.bookNumber,
                        bookName: note.bookName,
                        chapter: note.chapter,
                        version: version,
                      ),
                    ),
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

class _NoteTile extends StatelessWidget {
  final BibleNote note;
  final VoidCallback onTap;
  const _NoteTile({required this.note, required this.onTap});

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
                Icon(Icons.note, color: AppDesignSystem.gold, size: 16),
                const SizedBox(width: 8),
                Text(
                  note.reference,
                  style: GoogleFonts.manrope(
                    color: AppDesignSystem.gold,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(note.updatedAt),
                  style: GoogleFonts.manrope(
                    color: Colors.white24,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              note.text,
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
