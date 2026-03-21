import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../models/bible/chapter_study_note.dart';
import '../../../services/bible/chapter_note_service.dart';
import '../../../theme/bible_reader_theme.dart';
import '../../../screens/bible/chapter_note_editor_screen.dart';

class ReaderChapterNoteIndicator extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;

  const ReaderChapterNoteIndicator({
    super.key,
    required this.theme,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return ValueListenableBuilder<Map<String, ChapterStudyNote>>(
      valueListenable: ChapterNoteService.I.notesNotifier,
      builder: (context, notesMap, _) {
        final key =
            '${controller.bookNumber}:${controller.currentChapter}';
        final note = notesMap[key];

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => ChapterNoteEditorScreen(
                bookNumber: controller.bookNumber,
                bookName: controller.bookName,
                chapter: controller.currentChapter,
                versionId: controller.currentVersion.id,
                existingNote: note,
              ),
              transitionDuration: const Duration(milliseconds: 150),
              transitionsBuilder: (ctx, a, sa, child) =>
                  FadeTransition(opacity: a, child: child),
            ),
          ),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: t.isDark
                    ? Colors.white.withOpacity(0.04)
                    : Colors.black.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: note != null
                    ? Border.all(
                        color:
                            Color(note.colorValue).withOpacity(0.3),
                        width: 0.5,
                      )
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    note != null
                        ? Icons.description
                        : Icons.description_outlined,
                    color: note != null
                        ? Color(note.colorValue)
                        : t.textSecondary.withOpacity(0.3),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: note != null
                        ? Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: GoogleFonts.manrope(
                                  color: t.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (note.content.isNotEmpty)
                                Text(
                                  note.content,
                                  style: GoogleFonts.manrope(
                                    color: t.textSecondary
                                        .withOpacity(0.4),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          )
                        : Text(
                            'Agregar nota de estudio...',
                            style: GoogleFonts.manrope(
                              color:
                                  t.textSecondary.withOpacity(0.3),
                              fontSize: 13,
                            ),
                          ),
                  ),
                  Icon(Icons.chevron_right,
                      color: t.textSecondary.withOpacity(0.3),
                      size: 18),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
