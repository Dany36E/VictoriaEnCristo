import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_note.dart';
import '../../services/bible/bible_user_data_service.dart';

/// Bottom sheet para crear/editar una nota sobre un versículo.
class NoteEditorSheet extends StatefulWidget {
  final BibleVerse verse;
  const NoteEditorSheet({super.key, required this.verse});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController _controller;
  BibleNote? _existing;

  @override
  void initState() {
    super.initState();
    _existing = BibleUserDataService.I.notesNotifier.value[widget.verse.uniqueKey];
    _controller = TextEditingController(text: _existing?.text ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      // Delete if empty
      await BibleUserDataService.I.deleteNote(
        widget.verse.bookNumber,
        widget.verse.chapter,
        widget.verse.verse,
      );
    } else {
      await BibleUserDataService.I.saveNote(
        bookNumber: widget.verse.bookNumber,
        chapter: widget.verse.chapter,
        verse: widget.verse.verse,
        bookName: widget.verse.bookName,
        text: text,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  const Icon(Icons.note, color: Color(0xFFD4AF37), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Nota — ${widget.verse.reference}',
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_existing != null)
                    GestureDetector(
                      onTap: () async {
                        await BibleUserDataService.I.deleteNote(
                          widget.verse.bookNumber,
                          widget.verse.chapter,
                          widget.verse.verse,
                        );
                        if (mounted) Navigator.pop(context);
                      },
                      child: Icon(Icons.delete_outline,
                          color: const Color(0xFFE57373), size: 20),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Text field
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: t.isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  minLines: 4,
                  autofocus: true,
                  style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 14, height: 1.5),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu reflexión...',
                    hintStyle: GoogleFonts.manrope(color: t.textSecondary.withOpacity(0.5), fontSize: 14),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent.withOpacity(0.2),
                    foregroundColor: t.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    _existing != null ? 'Guardar cambios' : 'Guardar nota',
                    style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
