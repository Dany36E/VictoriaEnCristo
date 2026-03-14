import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../models/bible/bible_verse.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_share_service.dart';
import '../../screens/bible/template_picker_screen.dart';
import 'color_picker_row.dart';
import 'note_editor_sheet.dart';
import 'prayer_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// VERSE ACTIONS SHEET
/// Bottom sheet con todas las acciones para un versículo:
/// resaltar, nota, guardar, compartir, orar, comparar.
/// ═══════════════════════════════════════════════════════════════════════════
class VerseActionsSheet extends StatelessWidget {
  final BibleVerse verse;
  final VoidCallback? onCompare;

  const VerseActionsSheet({
    super.key,
    required this.verse,
    this.onCompare,
  });

  @override
  Widget build(BuildContext context) {
    final data = BibleUserDataService.I;
    final isSaved = data.isVerseSaved(verse.bookNumber, verse.chapter, verse.verse);
    final highlight = data.highlightsNotifier.value[verse.uniqueKey];
    final hasNote = data.notesNotifier.value.containsKey(verse.uniqueKey);
    final hasPrayer = data.prayersNotifier.value.containsKey(verse.uniqueKey);

    return Container(
      decoration: const BoxDecoration(
        color: AppDesignSystem.midnight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Verse preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                ),
                child: Column(
                  children: [
                    Text(
                      verse.text,
                      style: GoogleFonts.crimsonPro(
                        color: Colors.white70,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.6,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '— ${verse.reference} (${verse.version})',
                      style: GoogleFonts.manrope(
                        color: AppDesignSystem.gold,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Highlight colors
              ColorPickerRow(
                selectedColor: highlight?.colorHex,
                onColorSelected: (colorHex) {
                  if (colorHex == null) {
                    data.removeHighlight(verse.bookNumber, verse.chapter, verse.verse);
                  } else {
                    data.addHighlight(
                      bookNumber: verse.bookNumber,
                      chapter: verse.chapter,
                      verse: verse.verse,
                      colorHex: colorHex,
                    );
                  }
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),

              // Action buttons grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ActionButton(
                    icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
                    label: isSaved ? 'Guardado' : 'Guardar',
                    color: isSaved ? AppDesignSystem.gold : Colors.white54,
                    onTap: () {
                      data.toggleSavedVerse(
                        bookNumber: verse.bookNumber,
                        chapter: verse.chapter,
                        verse: verse.verse,
                        bookName: verse.bookName,
                        text: verse.text,
                        version: verse.version,
                      );
                      Navigator.pop(context);
                    },
                  ),
                  _ActionButton(
                    icon: hasNote ? Icons.note : Icons.note_add_outlined,
                    label: 'Nota',
                    color: hasNote ? AppDesignSystem.gold : Colors.white54,
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => NoteEditorSheet(verse: verse),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.volunteer_activism,
                    label: 'Orar',
                    color: hasPrayer ? AppDesignSystem.gold : Colors.white54,
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        builder: (_) => PrayerSheet(verse: verse),
                      );
                    },
                  ),
                  _ActionButton(
                    icon: Icons.compare_arrows,
                    label: 'Comparar',
                    color: Colors.white54,
                    onTap: onCompare,
                  ),
                  _ActionButton(
                    icon: Icons.share_outlined,
                    label: 'Texto',
                    color: Colors.white54,
                    onTap: () {
                      Navigator.pop(context);
                      BibleShareService.shareAsText(verse);
                    },
                  ),
                  _ActionButton(
                    icon: Icons.image_outlined,
                    label: 'Imagen',
                    color: Colors.white54,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TemplatePickerScreen(verse: verse),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
