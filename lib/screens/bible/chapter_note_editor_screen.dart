import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/chapter_study_note.dart';
import '../../services/bible/chapter_note_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../services/bible/bible_user_data_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CHAPTER NOTE EDITOR — Editor de notas de capítulo
///
/// Pantalla completa con título (Cinzel), contenido (serif multiline),
/// selector de color, tags y formato básico.
/// ═══════════════════════════════════════════════════════════════════════════
class ChapterNoteEditorScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final String versionId;
  final ChapterStudyNote? existingNote;

  const ChapterNoteEditorScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.versionId,
    this.existingNote,
  });

  @override
  State<ChapterNoteEditorScreen> createState() =>
      _ChapterNoteEditorScreenState();
}

class _ChapterNoteEditorScreenState extends State<ChapterNoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _tagController;
  late List<String> _tags;
  late String _selectedColor;
  bool _saving = false;
  bool _hasChanges = false;

  static const _noteColors = [
    'D4A853', // gold
    'FF6B6B', // red
    '4ECDC4', // teal
    '45B7D1', // blue
    'A78BFA', // purple
    'F472B6', // pink
  ];

  @override
  void initState() {
    super.initState();
    final note = widget.existingNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _tagController = TextEditingController();
    _tags = List.from(note?.tags ?? []);
    _selectedColor = note?.colorHex ?? 'D4A853';

    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return;

    setState(() => _saving = true);
    await ChapterNoteService.I.saveNote(
      existingId: widget.existingNote?.id,
      versionId: widget.versionId,
      bookNumber: widget.bookNumber,
      bookName: widget.bookName,
      chapter: widget.chapter,
      title: title.isEmpty ? '${widget.bookName} ${widget.chapter}' : title,
      content: content,
      tags: _tags,
      colorHex: _selectedColor,
    );
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final note = widget.existingNote;
    if (note == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(
              BibleUserDataService.I.readerThemeNotifier.value),
        );
        return AlertDialog(
          backgroundColor: t.surface,
          title: Text('Eliminar nota',
              style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 16)),
          content: Text('¿Eliminar esta nota de estudio?',
              style: GoogleFonts.manrope(
                  color: t.textSecondary, fontSize: 14)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancelar',
                  style: GoogleFonts.manrope(color: t.textSecondary)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Eliminar',
                  style: GoogleFonts.manrope(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await ChapterNoteService.I.deleteNote(note.id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _addTag() {
    final tag = _tagController.text.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() {
        _tags.add(tag);
        _hasChanges = true;
      });
      _tagController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );

        SystemChrome.setSystemUIOverlayStyle(
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(t),
                Expanded(child: _buildEditor(t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              '${widget.bookName} ${widget.chapter}',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.6),
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (widget.existingNote != null)
            IconButton(
              icon: Icon(Icons.delete_outline,
                  color: t.textSecondary.withOpacity(0.5), size: 20),
              onPressed: _delete,
            ),
          _saving
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: t.accent, strokeWidth: 1.5),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.check,
                      color: _hasChanges ? t.accent : t.textSecondary.withOpacity(0.3),
                      size: 22),
                  onPressed: _hasChanges ? _save : null,
                ),
        ],
      ),
    );
  }

  Widget _buildEditor(BibleReaderThemeData t) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextField(
            controller: _titleController,
            style: GoogleFonts.cinzel(
              color: t.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'Título de la nota...',
              hintStyle: GoogleFonts.cinzel(
                color: t.textSecondary.withOpacity(0.3),
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
          ),

          const SizedBox(height: 20),

          // Color selector
          Row(
            children: _noteColors.map((hex) {
              final color = Color(int.parse('FF$hex', radix: 16));
              final selected = hex == _selectedColor;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedColor = hex;
                  _hasChanges = true;
                }),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(selected ? 1.0 : 0.4),
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: color, width: 2)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Tags
          if (_tags.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _tags.map((tag) {
                  return GestureDetector(
                    onTap: () => setState(() {
                      _tags.remove(tag);
                      _hasChanges = true;
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.isDark
                            ? Colors.white.withOpacity(0.08)
                            : Colors.black.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: GoogleFonts.manrope(
                              color: t.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.close,
                              color: t.textSecondary.withOpacity(0.4),
                              size: 12),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          // Add tag field
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: t.isDark
                  ? Colors.white.withOpacity(0.04)
                  : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.tag, color: t.textSecondary.withOpacity(0.3),
                    size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _tagController,
                    style: GoogleFonts.manrope(
                        color: t.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Agregar etiqueta...',
                      hintStyle: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.3),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 8),
                    ),
                    onSubmitted: (_) => _addTag(),
                  ),
                ),
                GestureDetector(
                  onTap: _addTag,
                  child: Icon(Icons.add,
                      color: t.accent.withOpacity(0.6), size: 18),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Divider
          Container(
            height: 0.5,
            color: t.textSecondary.withOpacity(0.1),
          ),

          const SizedBox(height: 24),

          // Content
          TextField(
            controller: _contentController,
            style: GoogleFonts.lora(
              color: t.textPrimary,
              fontSize: 16,
              height: 1.8,
            ),
            decoration: InputDecoration(
              hintText:
                  'Escribe tus reflexiones sobre este capítulo...',
              hintStyle: GoogleFonts.lora(
                color: t.textSecondary.withOpacity(0.25),
                fontSize: 16,
                height: 1.8,
              ),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            maxLines: null,
            minLines: 10,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
          ),

          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
