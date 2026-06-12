import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_note.dart';
import '../../services/bible/bible_user_data_service.dart';

/// Bottom sheet para crear/editar una nota sobre un versículo.
class NoteEditorSheet extends StatefulWidget {
  final BibleVerse verse;
  final BibleReaderThemeData? theme;

  const NoteEditorSheet({super.key, required this.verse, this.theme});

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late TextEditingController _controller;
  BibleNote? _existing;

  @override
  void initState() {
    super.initState();
    _existing =
        BibleUserDataService.I.notesNotifier.value[widget.verse.uniqueKey];
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
    final t =
        widget.theme ??
        BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(
            BibleUserDataService.I.readerThemeNotifier.value,
          ),
        );
    final noteFontSize = (BibleUserDataService.I.fontSizeNotifier.value * 0.82)
        .clamp(15.0, 21.0)
        .toDouble();
    final fieldBg = t.isDark
        ? Color.lerp(t.surface, Colors.white, 0.08)!
        : Color.lerp(t.surface, t.accent, 0.06)!;
    final fieldBorder = t.accent.withValues(alpha: t.isDark ? 0.52 : 0.34);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Row(
                children: [
                  Icon(Icons.note, color: t.accent, size: 20),
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
                        final nav = Navigator.of(context);
                        await BibleUserDataService.I.deleteNote(
                          widget.verse.bookNumber,
                          widget.verse.chapter,
                          widget.verse.verse,
                        );
                        if (mounted) nav.pop();
                      },
                      child: const Icon(
                        Icons.delete_outline,
                        color: Color(0xFFE57373),
                        size: 20,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              // Text field
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: fieldBg,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(color: fieldBorder),
                ),
                child: Theme(
                  data: Theme.of(context).copyWith(
                    textSelectionTheme: TextSelectionThemeData(
                      cursorColor: t.accent,
                      selectionColor: t.accent.withValues(alpha: 0.24),
                      selectionHandleColor: t.accent,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    minLines: 4,
                    autofocus: true,
                    cursorColor: t.accent,
                    style: GoogleFonts.lora(
                      color: t.textPrimary,
                      fontSize: noteFontSize,
                      height: 1.55,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu reflexión...',
                      hintStyle: GoogleFonts.lora(
                        color: t.textSecondary.withValues(alpha: 0.70),
                        fontSize: noteFontSize,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(16),
                    ),
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
                    backgroundColor: t.accent.withValues(alpha: 0.2),
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
