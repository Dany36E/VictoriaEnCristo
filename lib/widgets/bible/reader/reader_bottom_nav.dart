import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../theme/bible_reader_theme.dart';

class ReaderBottomNav extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;
  final VoidCallback onGoToNextBook;
  final void Function(int bookNum, String bookName, int chapter) onGoToBook;

  const ReaderBottomNav({
    super.key,
    required this.theme,
    required this.controller,
    required this.onGoToNextBook,
    required this.onGoToBook,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final nextBook = controller.getNextBook();
    final isLastChapter = controller.currentChapter >= controller.totalChapters;
    final isFirstChapter = controller.currentChapter <= 1;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: isFirstChapter
                ? const SizedBox.shrink()
                : Semantics(
                    label:
                        'Capítulo anterior: ${controller.currentChapter - 1}',
                    button: true,
                    child: GestureDetector(
                      onTap: () =>
                          controller.goToChapter(controller.currentChapter - 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left,
                              color: t.textSecondary.withOpacity(0.4),
                              size: 18),
                          Flexible(
                            child: Text(
                              'Cap. ${controller.currentChapter - 1}',
                              style: GoogleFonts.manrope(
                                color: t.textSecondary.withOpacity(0.4),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          GestureDetector(
            onTap: () {
              final book = controller.allBooks
                  .where((b) => b.number == controller.bookNumber)
                  .firstOrNull;
              if (book == null) return;
              onGoToBook(book.number, book.name, controller.currentChapter);
            },
            child: Text(
              '${controller.bookName} ${controller.currentChapter}',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.4),
                fontSize: 11,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Expanded(
            child: isLastChapter
                ? (nextBook != null
                    ? Semantics(
                        label: 'Siguiente libro: ${nextBook.name}',
                        button: true,
                        child: GestureDetector(
                          onTap: onGoToNextBook,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  nextBook.name,
                                  style: GoogleFonts.manrope(
                                    color: t.accent.withOpacity(0.6),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right,
                                  color: t.accent.withOpacity(0.6), size: 18),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox.shrink())
                : Semantics(
                    label:
                        'Siguiente capítulo: ${controller.currentChapter + 1}',
                    button: true,
                    child: GestureDetector(
                      onTap: () =>
                          controller.goToChapter(controller.currentChapter + 1),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              'Cap. ${controller.currentChapter + 1}',
                              style: GoogleFonts.manrope(
                                color: t.textSecondary.withOpacity(0.4),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: t.textSecondary.withOpacity(0.4),
                              size: 18),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
