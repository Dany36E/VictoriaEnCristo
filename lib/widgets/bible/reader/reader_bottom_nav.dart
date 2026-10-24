import 'package:flutter/material.dart';
import '../../../theme/app_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../theme/bible_reader_theme.dart';

class ReaderBottomNav extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;
  final VoidCallback onGoToPrevious;
  final VoidCallback onGoToNext;
  final void Function(int bookNum, String bookName, int chapter) onGoToBook;

  const ReaderBottomNav({
    super.key,
    required this.theme,
    required this.controller,
    required this.onGoToPrevious,
    required this.onGoToNext,
    required this.onGoToBook,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final nextBook = controller.getNextBook();
    final previousBook = controller.getPreviousBook();
    final isLastChapter = controller.currentChapter >= controller.totalChapters;
    final isFirstChapter = controller.currentChapter <= 1;
    // Desde el capítulo 1 se puede volver al último capítulo del libro
    // anterior (antes no había forma de hacerlo).
    final previousLabel = isFirstChapter
        ? (previousBook == null
              ? null
              : '${previousBook.name} ${previousBook.totalChapters}')
        : 'Cap. ${controller.currentChapter - 1}';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: previousLabel == null
                ? const SizedBox.shrink()
                : Semantics(
                    label: 'Anterior: $previousLabel',
                    button: true,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onGoToPrevious,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left,
                              color: t.textSecondary.withValues(alpha: 0.4),
                              size: 18),
                          Flexible(
                            child: Text(
                              previousLabel,
                              style: AppFonts.manrope(
                                color: t.textoTenue(0.4),
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
              style: AppFonts.manrope(
                color: t.textoTenue(0.4),
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
                          behavior: HitTestBehavior.opaque,
                          onTap: onGoToNext,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  nextBook.name,
                                  style: AppFonts.manrope(
                                    color: t.accent.withValues(alpha: 0.6),
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.chevron_right,
                                  color: t.accent.withValues(alpha: 0.6), size: 18),
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
                      behavior: HitTestBehavior.opaque,
                      onTap: onGoToNext,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              'Cap. ${controller.currentChapter + 1}',
                              style: AppFonts.manrope(
                                color: t.textoTenue(0.4),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: t.textSecondary.withValues(alpha: 0.4),
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
