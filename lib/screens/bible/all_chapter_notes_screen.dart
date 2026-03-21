import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/chapter_study_note.dart';
import '../../services/bible/chapter_note_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';
import 'chapter_note_editor_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ALL CHAPTER NOTES SCREEN — Lista de notas de estudio por capítulo
///
/// Agrupadas por libro, búsqueda, tap navega al reader + nota.
/// ═══════════════════════════════════════════════════════════════════════════
class AllChapterNotesScreen extends StatefulWidget {
  const AllChapterNotesScreen({super.key});

  @override
  State<AllChapterNotesScreen> createState() => _AllChapterNotesScreenState();
}

class _AllChapterNotesScreenState extends State<AllChapterNotesScreen> {
  bool _searchMode = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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
                Expanded(child: _buildBody(t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    if (_searchMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: GoogleFonts.manrope(
                      color: t.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar en notas de capítulo...',
                    hintStyle: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, color: t.textSecondary, size: 20),
              onPressed: () {
                setState(() {
                  _searchMode = false;
                  _searchQuery = '';
                });
                _searchController.clear();
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Icon(Icons.description_outlined, color: t.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Notas de capítulo',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search,
                color: t.textSecondary.withOpacity(0.6), size: 20),
            onPressed: () {
              setState(() => _searchMode = true);
              _searchFocus.requestFocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BibleReaderThemeData t) {
    return ValueListenableBuilder<Map<String, ChapterStudyNote>>(
      valueListenable: ChapterNoteService.I.notesNotifier,
      builder: (context, notesMap, _) {
        List<ChapterStudyNote> notes;
        if (_searchQuery.isNotEmpty) {
          notes = ChapterNoteService.I.searchNotes(_searchQuery);
        } else {
          notes = ChapterNoteService.I.allNotes;
        }

        if (notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.description_outlined,
                      color: t.textSecondary.withOpacity(0.2), size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isNotEmpty
                        ? 'Sin resultados'
                        : 'Tus notas de estudio por\ncapítulo aparecerán aquí',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // Agrupar por libro
        final grouped = <String, List<ChapterStudyNote>>{};
        for (final note in notes) {
          grouped.putIfAbsent(note.bookName, () => []).add(note);
        }

        final bookNames = grouped.keys.toList();

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          itemCount: bookNames.length,
          itemBuilder: (context, index) {
            final bookName = bookNames[index];
            final bookNotes = grouped[bookName]!;
            return _buildBookGroup(t, bookName, bookNotes);
          },
        );
      },
    );
  }

  Widget _buildBookGroup(
    BibleReaderThemeData t,
    String bookName,
    List<ChapterStudyNote> notes,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Text(
                bookName,
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${notes.length}',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        ...notes.map((note) => _buildNoteTile(t, note)),
      ],
    );
  }

  Widget _buildNoteTile(BibleReaderThemeData t, ChapterStudyNote note) {
    final version = BibleUserDataService.I.preferredVersionNotifier.value;
    final noteColor = Color(note.colorValue);

    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          'Eliminar',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: t.surface,
            title: Text('Eliminar nota',
                style: GoogleFonts.manrope(
                    color: t.textPrimary, fontSize: 16)),
            content: Text('¿Eliminar "${note.title}"?',
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
          ),
        );
      },
      onDismissed: (_) => ChapterNoteService.I.deleteNote(note.id),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => ChapterNoteEditorScreen(
              bookNumber: note.bookNumber,
              bookName: note.bookName,
              chapter: note.chapter,
              versionId: note.versionId,
              existingNote: note,
            ),
            transitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (ctx, a, sa, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        ),
        onLongPress: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => BibleReaderScreen(
              bookNumber: note.bookNumber,
              bookName: note.bookName,
              chapter: note.chapter,
              version: version,
            ),
            transitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (ctx, a, sa, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        ),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: noteColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Cap. ${note.chapter}',
                          style: GoogleFonts.manrope(
                            color: t.textSecondary.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(note.updatedAt),
                          style: GoogleFonts.manrope(
                            color: t.textSecondary.withOpacity(0.3),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      note.title,
                      style: GoogleFonts.manrope(
                        color: t.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.content.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        note.content,
                        style: GoogleFonts.lora(
                          color: t.textSecondary.withOpacity(0.5),
                          fontSize: 13,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: note.tags.map((tag) {
                          return Text(
                            '#$tag',
                            style: GoogleFonts.manrope(
                              color: noteColor.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'hace ${diff.inHours}h';
    if (diff.inDays < 7) return 'hace ${diff.inDays}d';
    if (diff.inDays < 30) return 'hace ${diff.inDays ~/ 7}sem';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
