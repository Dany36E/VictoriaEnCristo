import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/rich_note_document.dart';
import '../../models/bible/sermon_note.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/sermon_note_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';
import 'sermon_notes_mode_screen.dart';

class SermonNotesSavedScreen extends StatefulWidget {
  const SermonNotesSavedScreen({super.key});

  @override
  State<SermonNotesSavedScreen> createState() => _SermonNotesSavedScreenState();
}

class _SermonNotesSavedScreenState extends State<SermonNotesSavedScreen> {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _searchQuery = '';
  String? _speakerFilter;
  DateTime? _dateFilter;
  _SermonNoteSort _sort = _SermonNoteSort.updatedDesc;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await UserScopedServices.I.ensureSermonNotes();
    if (!mounted) return;
    setState(() => _loading = false);
  }

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
      builder: (_, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
        SystemChrome.setSystemUIOverlayStyle(
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: t.accent,
                      strokeWidth: 1.5,
                    ),
                  )
                : Column(
                    children: [
                      _buildHeader(t),
                      _buildFilters(t),
                      Expanded(child: _buildBody(t)),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios,
                    color: t.textSecondary,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.folder_open_outlined, color: t.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Apuntes Guardados',
                  style: GoogleFonts.cinzel(
                    color: t.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            focusNode: _searchFocus,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Buscar por titulo, pastor o pasaje',
              hintStyle: GoogleFonts.manrope(
                color: t.textSecondary.withValues(alpha: 0.55),
                fontSize: 13,
              ),
              prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 18),
              suffixIcon: _searchQuery.trim().isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Limpiar',
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      icon: Icon(Icons.close, color: t.textSecondary, size: 17),
                    ),
              isDense: true,
              filled: true,
              fillColor: t.background.withValues(alpha: t.isDark ? 0.78 : 0.88),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
              border: _inputBorder(t),
              enabledBorder: _inputBorder(t),
              focusedBorder: _inputBorder(t, focused: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BibleReaderThemeData t) {
    final speakers = SermonNoteService.I.speakers;
    final hasFilters =
        _speakerFilter != null ||
        _dateFilter != null ||
        _searchQuery.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          PopupMenuButton<_SermonNoteSort>(
            tooltip: 'Ordenar apuntes',
            color: t.surface,
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (_) => [
              for (final sort in _SermonNoteSort.values)
                PopupMenuItem<_SermonNoteSort>(
                  value: sort,
                  child: Text(
                    _sortLabel(sort),
                    style: GoogleFonts.manrope(color: t.textPrimary),
                  ),
                ),
            ],
            child: _FilterShell(
              theme: t,
              icon: Icons.sort,
              label: _sortLabel(_sort),
              selected: _sort != _SermonNoteSort.updatedDesc,
            ),
          ),
          PopupMenuButton<String?>(
            tooltip: 'Filtrar por pastor',
            color: t.surface,
            onSelected: (value) => setState(() => _speakerFilter = value),
            itemBuilder: (_) => [
              PopupMenuItem<String?>(
                value: null,
                child: Text(
                  'Todos los pastores',
                  style: GoogleFonts.manrope(color: t.textPrimary),
                ),
              ),
              for (final speaker in speakers)
                PopupMenuItem<String?>(
                  value: speaker,
                  child: Text(
                    speaker,
                    style: GoogleFonts.manrope(color: t.textPrimary),
                  ),
                ),
            ],
            child: _FilterShell(
              theme: t,
              icon: Icons.person_outline,
              label: _speakerFilter ?? 'Todos los pastores',
              selected: _speakerFilter != null,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _pickDateFilter,
            child: _FilterShell(
              theme: t,
              icon: Icons.event_outlined,
              label: _dateFilter == null
                  ? 'Todas las fechas'
                  : _formatDate(_dateFilter!),
              selected: _dateFilter != null,
            ),
          ),
          if (hasFilters)
            GestureDetector(
              onTap: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _speakerFilter = null;
                  _dateFilter = null;
                });
              },
              child: _ChoiceChipShell(
                theme: t,
                icon: Icons.refresh,
                label: 'Limpiar',
                selected: false,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BibleReaderThemeData t) {
    return ValueListenableBuilder<Map<String, SermonNote>>(
      valueListenable: SermonNoteService.I.notesNotifier,
      builder: (context, notesMap, child) {
        final filtered = _filteredNotes();
        if (filtered.isEmpty) {
          final hasFilters =
              _speakerFilter != null ||
              _dateFilter != null ||
              _searchQuery.trim().isNotEmpty;
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                hasFilters
                    ? 'No hay apuntes con esos filtros.'
                    : 'Tus apuntes de predicacion guardados apareceran aqui.',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withValues(alpha: 0.45),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildNoteTile(t, filtered[index]),
        );
      },
    );
  }

  List<SermonNote> _filteredNotes() {
    final query = _normalize(_searchQuery);
    final list = SermonNoteService.I.allNotes.where((note) {
      if (_speakerFilter != null &&
          note.speaker.trim().toLowerCase() !=
              _speakerFilter!.trim().toLowerCase()) {
        return false;
      }
      if (_dateFilter != null && !_isSameDate(note.sermonDate, _dateFilter!)) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = _noteSearchText(note);
      return haystack.contains(query);
    }).toList();
    list.sort((a, b) {
      switch (_sort) {
        case _SermonNoteSort.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case _SermonNoteSort.updatedAsc:
          return a.updatedAt.compareTo(b.updatedAt);
        case _SermonNoteSort.titleAsc:
          return _noteTitle(
            a,
          ).toLowerCase().compareTo(_noteTitle(b).toLowerCase());
        case _SermonNoteSort.titleDesc:
          return _noteTitle(
            b,
          ).toLowerCase().compareTo(_noteTitle(a).toLowerCase());
      }
    });
    return list;
  }

  String _noteTitle(SermonNote note) {
    final title = note.title.trim();
    return title.isEmpty ? 'Apunte sin titulo' : title;
  }

  String _noteSearchText(SermonNote note) {
    final buffer = StringBuffer()
      ..write(note.title)
      ..write(' ')
      ..write(note.speaker)
      ..write(' ')
      ..write(richNotePlainText(note.notes))
      ..write(' ')
      ..write(note.takeaway);
    final central = note.centralPassage;
    if (central != null) {
      buffer
        ..write(' ')
        ..write(central.label)
        ..write(' ')
        ..write('${central.bookName} ${central.chapter}');
    }
    for (final verse in note.verses) {
      buffer
        ..write(' ')
        ..write(verse.reference)
        ..write(' ')
        ..write(verse.bookName)
        ..write(' ')
        ..write('${verse.chapter}:${verse.verse}');
    }
    return _normalize(buffer.toString());
  }

  Future<void> _deleteNote(BibleReaderThemeData t, SermonNote note) async {
    final title = _noteTitle(note);
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: t.surface,
            title: Text(
              'Eliminar apunte',
              style: GoogleFonts.manrope(
                color: t.textPrimary,
                fontSize: 16,
              ),
            ),
            content: Text(
              'Eliminar "$title"?',
              style: GoogleFonts.manrope(
                color: t.textSecondary,
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.manrope(color: t.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Eliminar',
                  style: GoogleFonts.manrope(color: Colors.red),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await SermonNoteService.I.deleteNote(note.id);
  }

  Widget _buildNoteTile(BibleReaderThemeData t, SermonNote note) {
    final preview = _previewText(note);
    final central = note.centralPassage;
    return Dismissible(
      key: ValueKey(note.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          'Eliminar',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withValues(alpha: 0.5),
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
                title: Text(
                  'Eliminar apunte',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 16,
                  ),
                ),
                content: Text(
                  '¿Eliminar "${note.title.trim().isEmpty ? 'Apunte sin titulo' : note.title}"?',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontSize: 14,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.manrope(color: t.textSecondary),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      'Eliminar',
                      style: GoogleFonts.manrope(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => SermonNoteService.I.deleteNote(note.id),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                SermonNotesModeScreen(noteId: note.id),
            transitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) =>
                    FadeTransition(opacity: animation, child: child),
          ),
        ),
        onLongPress: central == null
            ? null
            : () => Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      BibleReaderScreen(
                        bookNumber: central.bookNumber,
                        bookName: central.bookName,
                        chapter: central.chapter,
                        version: BibleUserDataService
                            .I
                            .preferredVersionNotifier
                            .value,
                      ),
                  transitionDuration: const Duration(milliseconds: 150),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          FadeTransition(opacity: animation, child: child),
                ),
              ),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
          margin: const EdgeInsets.only(bottom: 18),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: t.textSecondary.withValues(alpha: 0.10)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _noteTitle(note).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: t.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    _formatDate(note.sermonDate),
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withValues(alpha: 0.4),
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Eliminar apunte',
                    visualDensity: VisualDensity.compact,
                    splashRadius: 18,
                    onPressed: () => _deleteNote(t, note),
                    icon: Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: t.textSecondary.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (note.speaker.trim().isNotEmpty)
                    _ChoiceChipShell(
                      theme: t,
                      icon: Icons.person_outline,
                      label: note.speaker,
                      selected: true,
                    ),
                  if (central != null)
                    _ChoiceChipShell(
                      theme: t,
                      icon: Icons.my_location_outlined,
                      label: central.label,
                      selected: true,
                    ),
                ],
              ),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  preview,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.lora(
                    color: t.textPrimary,
                    fontSize: 14.5,
                    height: 1.55,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _previewText(SermonNote note) {
    final takeaway = note.takeaway.trim();
    if (takeaway.isNotEmpty) return takeaway;
    final notes = richNotePlainText(note.notes).trim();
    if (notes.isNotEmpty) return notes;
    if (note.verses.isNotEmpty) {
      final verse = note.verses.first;
      return '${verse.reference} ${verse.text}';
    }
    return '';
  }

  Future<void> _pickDateFilter() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFilter ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _dateFilter = picked);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _normalize(String value) {
    var out = value.trim().toLowerCase();
    const replacements = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    replacements.forEach((from, to) => out = out.replaceAll(from, to));
    return out;
  }

  String _sortLabel(_SermonNoteSort sort) {
    switch (sort) {
      case _SermonNoteSort.updatedDesc:
        return 'Más recientes';
      case _SermonNoteSort.updatedAsc:
        return 'Más antiguos';
      case _SermonNoteSort.titleAsc:
        return 'Título A-Z';
      case _SermonNoteSort.titleDesc:
        return 'Título Z-A';
    }
  }

  OutlineInputBorder _inputBorder(
    BibleReaderThemeData t, {
    bool focused = false,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: focused
            ? t.accent.withValues(alpha: 0.7)
            : t.textSecondary.withValues(alpha: 0.14),
      ),
    );
  }
}

enum _SermonNoteSort { updatedDesc, updatedAsc, titleAsc, titleDesc }

class _FilterShell extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;
  final bool selected;

  const _FilterShell({
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? t.accent.withValues(alpha: 0.13)
            : t.textSecondary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? t.accent.withValues(alpha: 0.38)
              : t.textSecondary.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? t.accent : t.textSecondary, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: selected ? t.accent : t.textPrimary.withValues(alpha: 0.78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.expand_more,
            color: selected ? t.accent : t.textSecondary,
            size: 15,
          ),
        ],
      ),
    );
  }
}

class _ChoiceChipShell extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;
  final bool selected;

  const _ChoiceChipShell({
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? t.accent.withValues(alpha: t.isDark ? 0.22 : 0.14)
            : t.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? t.accent.withValues(alpha: 0.55)
              : t.textSecondary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: selected ? t.accent : t.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.manrope(
              color: selected ? t.accent : t.textPrimary.withValues(alpha: 0.76),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
