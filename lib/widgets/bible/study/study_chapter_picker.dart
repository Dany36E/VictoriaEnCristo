import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/bible_book.dart';
import '../../../screens/bible/study_mode_screen.dart' show StudyPickerResult;
import '../../../theme/bible_reader_theme.dart';
import '../../../services/bible/bible_user_data_service.dart';

/// Bottom sheet para elegir libro + capítulo en Modo Estudio.
class StudyChapterPicker extends StatefulWidget {
  final List<BibleBook> books;
  final int currentBookNumber;
  final int currentChapter;

  const StudyChapterPicker({
    super.key,
    required this.books,
    required this.currentBookNumber,
    required this.currentChapter,
  });

  @override
  State<StudyChapterPicker> createState() => _StudyChapterPickerState();
}

class _StudyChapterPickerState extends State<StudyChapterPicker> {
  late int _selectedBookNumber;
  late String _selectedBookName;
  late int _selectedChapter;

  @override
  void initState() {
    super.initState();
    _selectedBookNumber = widget.currentBookNumber;
    _selectedChapter = widget.currentChapter;
    _selectedBookName = widget.books
        .firstWhere(
          (b) => b.number == widget.currentBookNumber,
          orElse: () => widget.books.isNotEmpty
              ? widget.books.first
              : const BibleBook(
                  number: 1,
                  name: 'Génesis',
                  testament: 'AT',
                  totalChapters: 50,
                  versesPerChapter: {},
                ),
        )
        .name;
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );
    final book = widget.books.firstWhere(
      (b) => b.number == _selectedBookNumber,
      orElse: () => widget.books.first,
    );
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: t.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Elegir capítulo',
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(
                      context,
                      StudyPickerResult(
                        _selectedBookNumber,
                        _selectedBookName,
                        _selectedChapter,
                      ),
                    ),
                    child: Text(
                      'Abrir',
                      style: GoogleFonts.manrope(
                        color: t.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  // Lista de libros
                  Expanded(
                    flex: 5,
                    child: ListView.builder(
                      controller: scroll,
                      itemCount: widget.books.length,
                      itemBuilder: (_, i) {
                        final b = widget.books[i];
                        final selected = b.number == _selectedBookNumber;
                        return ListTile(
                          dense: true,
                          title: Text(
                            b.name,
                            style: GoogleFonts.lora(
                              color: selected ? t.accent : t.textPrimary,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 14,
                            ),
                          ),
                          onTap: () => setState(() {
                            _selectedBookNumber = b.number;
                            _selectedBookName = b.name;
                            _selectedChapter = 1;
                          }),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: 1,
                    color: t.textSecondary.withOpacity(0.12),
                  ),
                  // Grilla de capítulos
                  Expanded(
                    flex: 4,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                        childAspectRatio: 1,
                      ),
                      itemCount: book.totalChapters,
                      itemBuilder: (_, i) {
                        final n = i + 1;
                        final selected = n == _selectedChapter;
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              setState(() => _selectedChapter = n),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? t.accent
                                  : t.textSecondary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '$n',
                              style: GoogleFonts.manrope(
                                color: selected
                                    ? t.background
                                    : t.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
