import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../theme/bible_reader_theme.dart';

void showBookChapterSelector(
  BuildContext context,
  BibleReaderController controller, {
  required void Function(int bookNum, String bookName, int chapter) onGoToBook,
  required void Function(int chapter) onGoToChapter,
}) {
  final t = BibleReaderThemeData.fromId(
    BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value),
  );
  int? selectedBookNumber;
  String selectedBookName = '';
  int selectedBookChapters = 0;
  final searchCtrl = TextEditingController();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setSheetState) {
          final query = searchCtrl.text.toLowerCase();
          final filteredBooks = query.isEmpty
              ? controller.allBooks
              : controller.allBooks
                  .where((b) => b.name.toLowerCase().contains(query))
                  .toList();

          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.92,
            minChildSize: 0.3,
            builder: (context, scrollCtrl) {
              return Container(
                decoration: BoxDecoration(
                  color: t.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 8),
                      child: Container(
                        width: 36,
                        height: 2,
                        decoration: BoxDecoration(
                          color: t.textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ),
                    if (selectedBookNumber == null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: TextField(
                          controller: searchCtrl,
                          style: GoogleFonts.manrope(
                            color: t.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar libro...',
                            hintStyle: GoogleFonts.manrope(
                              color: t.textSecondary.withOpacity(0.5),
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                    Container(
                      height: 0.5,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: t.textSecondary.withOpacity(0.1),
                    ),
                    Expanded(
                      child: selectedBookNumber != null
                          ? _ChapterGrid(
                              theme: t,
                              bookNumber: selectedBookNumber!,
                              bookName: selectedBookName,
                              totalChapters: selectedBookChapters,
                              currentBookNumber: controller.bookNumber,
                              currentChapter: controller.currentChapter,
                              onBack: () {
                                setSheetState(
                                    () => selectedBookNumber = null);
                              },
                              onSelect: (chapter) {
                                Navigator.pop(context);
                                if (selectedBookNumber ==
                                    controller.bookNumber) {
                                  onGoToChapter(chapter);
                                } else {
                                  onGoToBook(selectedBookNumber!,
                                      selectedBookName, chapter);
                                }
                              },
                            )
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8),
                              itemCount: filteredBooks.length,
                              itemBuilder: (_, index) {
                                final book = filteredBooks[index];
                                final isCurrent = book.number ==
                                    controller.bookNumber;
                                return GestureDetector(
                                  onTap: () {
                                    setSheetState(() {
                                      selectedBookNumber = book.number;
                                      selectedBookName = book.name;
                                      selectedBookChapters =
                                          book.totalChapters;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            book.name,
                                            style: GoogleFonts.manrope(
                                              color: isCurrent
                                                  ? t.accent
                                                  : t.textPrimary,
                                              fontSize: 15,
                                              fontWeight: isCurrent
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${book.totalChapters}',
                                          style: GoogleFonts.manrope(
                                            color: t.textSecondary
                                                .withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

class _ChapterGrid extends StatelessWidget {
  final BibleReaderThemeData theme;
  final int bookNumber;
  final String bookName;
  final int totalChapters;
  final int currentBookNumber;
  final int currentChapter;
  final VoidCallback onBack;
  final void Function(int chapter) onSelect;

  const _ChapterGrid({
    required this.theme,
    required this.bookNumber,
    required this.bookName,
    required this.totalChapters,
    required this.currentBookNumber,
    required this.currentChapter,
    required this.onBack,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Icon(Icons.arrow_back_ios,
                    color: t.textSecondary, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                bookName,
                style: GoogleFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(20),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: totalChapters,
            itemBuilder: (_, index) {
              final chapter = index + 1;
              final isCurrent = bookNumber == currentBookNumber &&
                  chapter == currentChapter;
              return GestureDetector(
                onTap: () => onSelect(chapter),
                child: Container(
                  alignment: Alignment.center,
                  child: Text(
                    '$chapter',
                    style: GoogleFonts.manrope(
                      color: isCurrent ? t.accent : t.textSecondary,
                      fontSize: 13,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
