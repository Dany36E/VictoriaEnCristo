import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/rich_note_document.dart';
import '../../models/bible/sermon_note.dart';
import '../../services/bible/bible_download_service.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/sermon_note_export_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/sermon_note_service.dart';
import '../../services/bible/sermon_reference_parser.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/bible_reader_theme.dart';
import 'sermon_notes_saved_screen.dart';
import 'study_mode_screen.dart' show StudyPickerResult;
import '../../widgets/bible/sermon/sermon_rich_text_controller.dart';
import '../../widgets/bible/study/study_chapter_picker.dart';
import '../../widgets/bible/study/study_reading_panel.dart';

enum _SermonHeaderAction {
  passage,
  versions,
  centralPassage,
  savedNotes,
  exportPdf,
  text,
}

enum _PdfExportAction { share, save }

class _PdfExportChoice {
  final _PdfExportAction action;
  final bool cleanCover;

  const _PdfExportChoice({required this.action, required this.cleanCover});
}

class SermonNotesModeScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleVersion? version;
  final String? noteId;

  const SermonNotesModeScreen({
    super.key,
    this.bookNumber = 1,
    this.bookName = 'Genesis',
    this.chapter = 1,
    this.version,
    this.noteId,
  });

  @override
  State<SermonNotesModeScreen> createState() => _SermonNotesModeScreenState();
}

class _SermonNotesModeScreenState extends State<SermonNotesModeScreen>
    with SingleTickerProviderStateMixin {
  late int _bookNumber;
  late String _bookName;
  late int _chapter;
  late BibleVersion _primaryVersion;
  late BibleVersion _secondaryVersion;
  late TabController _tabController;

  List<BibleBook> _books = const [];
  List<BibleVerse> _verses = const [];
  List<BibleVerse> _secondaryVerses = const [];
  bool _loading = true;

  late SermonNote _note;
  late RichNoteDocument _notesDocument;
  Timer? _saveDebounce;
  Timer? _spellCheckDebounce;
  Timer? _saveStatusTicker;
  bool _hydrating = false;
  bool _isSaving = false;
  bool _hasPendingChanges = false;
  DateTime? _lastSavedAt;
  final Set<String> _ignoredReferenceKeys = <String>{};
  final Set<String> _ignoredSpellTokens = <String>{};
  final _spellCheckService = DefaultSpellCheckService();
  List<DetectedSermonReference> _detectedReferences =
      const <DetectedSermonReference>[];
  List<SuggestionSpan> _spellSuggestions = const <SuggestionSpan>[];
  int _spellRequestId = 0;
  String _lastNotesText = '';
  TextSelection _lastNotesSelection = const TextSelection.collapsed(offset: -1);

  final _titleController = TextEditingController();
  final _speakerController = TextEditingController();
  late final SermonRichTextController _notesController;
  final _takeawayController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bookNumber = widget.bookNumber;
    _bookName = widget.bookName;
    _chapter = widget.chapter;
    _primaryVersion = BibleDownloadService.I.bestAvailableVersion(
      widget.version ?? BibleUserDataService.I.preferredVersionNotifier.value,
    );
    _secondaryVersion = BibleDownloadService.I.bestAvailableSecondary(
      _primaryVersion,
    );
    _notesDocument = RichNoteDocument.empty();
    _note = SermonNote.empty(
      id: widget.noteId,
      primaryVersionId: _primaryVersion.id,
      secondaryVersionId: _secondaryVersion.id,
    );
    _tabController = TabController(length: 2, vsync: this);
    _notesController = SermonRichTextController(document: _notesDocument);
    _notesController.addListener(_onNotesEdited);
    _lastNotesText = _notesController.text;
    _lastNotesSelection = _notesController.selection;
    _saveStatusTicker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await UserScopedServices.I.ensureSermonNotes();
    if (!mounted) return;
    final existing = SermonNoteService.I.noteById(widget.noteId);
    if (existing != null) {
      _note = existing;
      _primaryVersion = BibleDownloadService.I.bestAvailableVersion(
        BibleVersion.fromId(existing.primaryVersionId),
      );
      _secondaryVersion = BibleDownloadService.I.bestAvailableVersion(
        BibleVersion.fromId(existing.secondaryVersionId),
      );
      final central = existing.centralPassage;
      if (central != null) {
        _bookNumber = central.bookNumber;
        _bookName = central.bookName;
        _chapter = central.chapter;
      }
      _hydrateControllers(existing);
    }
    await _loadChapter();
  }

  void _hydrateControllers(SermonNote note) {
    _hydrating = true;
    _titleController.text = note.title;
    _speakerController.text = note.speaker;
    _notesDocument = RichNoteDocument.fromStorage(note.notes);
    _notesController.loadDocument(_notesDocument);
    _takeawayController.text = note.takeaway;
    _lastNotesText = _notesController.text;
    _lastNotesSelection = _notesController.selection;
    _lastSavedAt = note.updatedAt;
    _hasPendingChanges = false;
    _isSaving = false;
    _hydrating = false;
    _syncReferenceDecorations();
    _scheduleSpellCheck();
  }

  Future<void> _loadChapter() async {
    setState(() => _loading = true);
    try {
      _primaryVersion = BibleDownloadService.I.bestAvailableVersion(
        _primaryVersion,
      );
      if (!BibleDownloadService.I.isAvailable(_secondaryVersion) ||
          _secondaryVersion == _primaryVersion) {
        _secondaryVersion = BibleDownloadService.I.bestAvailableSecondary(
          _primaryVersion,
        );
      }
      final books = await BibleParserService.I.getBooks(_primaryVersion);
      final verses = await BibleParserService.I.getChapter(
        version: _primaryVersion,
        bookNumber: _bookNumber,
        chapter: _chapter,
      );
      final secondary = _secondaryVersion == _primaryVersion
          ? const <BibleVerse>[]
          : await BibleParserService.I.getChapter(
              version: _secondaryVersion,
              bookNumber: _bookNumber,
              chapter: _chapter,
            );
      if (!mounted) return;
      setState(() {
        _books = books;
        _verses = verses;
        _secondaryVerses = secondary;
        _loading = false;
      });
      _syncReferenceDecorations();
      _scheduleSpellCheck();
    } catch (e) {
      debugPrint('[SERMON-NOTES] load chapter error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeChapter(
    int bookNumber,
    String bookName,
    int chapter,
  ) async {
    await _flushNote();
    if (!mounted) return;
    setState(() {
      _bookNumber = bookNumber;
      _bookName = bookName;
      _chapter = chapter;
    });
    await _loadChapter();
  }

  Future<void> _openPassagePicker() async {
    final result = await showModalBottomSheet<StudyPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudyChapterPicker(
        books: _books,
        version: _primaryVersion,
        currentBookNumber: _bookNumber,
        currentChapter: _chapter,
      ),
    );
    if (result == null) return;
    await _changeChapter(result.bookNumber, result.bookName, result.chapter);
  }

  Future<void> _openVersionPicker() async {
    final result = await showModalBottomSheet<_VersionPairResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VersionPairSheet(
        initialPrimary: _primaryVersion,
        initialSecondary: _secondaryVersion,
        theme: _theme(),
      ),
    );
    if (result == null) return;
    await _flushNote();
    if (!mounted) return;
    setState(() {
      _primaryVersion = result.primary;
      _secondaryVersion = result.secondary;
      _note = _note.copyWith(
        primaryVersionId: result.primary.id,
        secondaryVersionId: result.secondary.id,
      );
    });
    await _loadChapter();
    await _flushNote();
  }

  Future<void> _openCentralPassagePicker() async {
    final picked = await showModalBottomSheet<StudyPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudyChapterPicker(
        books: _books,
        version: _primaryVersion,
        currentBookNumber: _note.centralPassage?.bookNumber ?? _bookNumber,
        currentChapter: _note.centralPassage?.chapter ?? _chapter,
      ),
    );
    if (picked == null || !mounted) return;
    final chapterVerses = await BibleParserService.I.getChapter(
      version: _primaryVersion,
      bookNumber: picked.bookNumber,
      chapter: picked.chapter,
    );
    if (!mounted) return;
    final range = await showModalBottomSheet<_VerseRangeResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseRangeSheet(
        theme: _theme(),
        verses: chapterVerses,
        title: '${picked.bookName} ${picked.chapter}',
      ),
    );
    if (range == null) return;
    setState(() {
      _note = _note.copyWith(
        centralPassage: SermonCentralPassage(
          bookNumber: picked.bookNumber,
          bookName: picked.bookName,
          chapter: picked.chapter,
          startVerse: range.start,
          endVerse: range.end,
        ),
      );
      _bookNumber = picked.bookNumber;
      _bookName = picked.bookName;
      _chapter = picked.chapter;
    });
    await _loadChapter();
    _scheduleSave();
  }

  Future<void> _clearCentralPassage() async {
    setState(() => _note = _note.copyWith(clearCentralPassage: true));
    _scheduleSave();
  }

  void _onFieldChanged(String _) => _scheduleSave();

  void _onNotesEdited() {
    if (_hydrating) return;
    final textChanged = _lastNotesText != _notesController.text;
    final selectionChanged = _lastNotesSelection != _notesController.selection;
    if (!textChanged && !selectionChanged) return;
    _lastNotesText = _notesController.text;
    _lastNotesSelection = _notesController.selection;
    _notesDocument = _notesController.document;
    if (textChanged) {
      _syncReferenceDecorations();
      _scheduleSpellCheck();
      _scheduleSave();
    }
    if (mounted) setState(() {});
  }

  String _referenceKey(DetectedSermonReference reference) {
    return '${reference.book.number}:${reference.chapter}:${reference.startVerse}:${reference.endVerse}:${reference.start}';
  }

  bool _hasInsertedReference(DetectedSermonReference reference) {
    final requiredVerses = <int>{
      for (
        var verse = reference.startVerse;
        verse <= reference.endVerse;
        verse++
      )
        verse,
    };
    final insertedVerses = _note.verses
        .where(
          (verse) =>
              verse.bookNumber == reference.book.number &&
              verse.chapter == reference.chapter,
        )
        .map((verse) => verse.verse)
        .toSet();
    return requiredVerses.every(insertedVerses.contains);
  }

  DetectedSermonReference? _activeReferenceAtCursor(
    List<DetectedSermonReference> suggestions,
  ) {
    final selection = _notesController.selection;
    if (!selection.isValid) return null;
    final cursor = selection.extentOffset;
    for (final suggestion in suggestions) {
      if (_ignoredReferenceKeys.contains(_referenceKey(suggestion))) continue;
      if (_hasInsertedReference(suggestion)) continue;
      if (cursor >= suggestion.start && cursor <= suggestion.end) {
        return suggestion;
      }
    }
    return null;
  }

  void _ignoreReference(DetectedSermonReference reference) {
    setState(() {
      _ignoredReferenceKeys.add(_referenceKey(reference));
      _syncReferenceDecorations();
      _filterSpellSuggestions();
    });
  }

  SuggestionSpan? _activeSuggestionAtCursor() {
    final selection = _notesController.selection;
    if (!selection.isValid) return null;
    final cursor = selection.extentOffset;
    for (final suggestion in _spellSuggestions) {
      if (cursor >= suggestion.range.start && cursor <= suggestion.range.end) {
        return suggestion;
      }
    }
    return null;
  }

  String _tokenForSuggestion(SuggestionSpan suggestion) {
    final text = _notesController.text;
    final start = suggestion.range.start.clamp(0, text.length);
    final end = suggestion.range.end.clamp(start, text.length);
    return text.substring(start, end);
  }

  String _normalizeToken(String value) {
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
    return out.replaceAll(RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'), '');
  }

  bool _overlapsReferenceRange(SuggestionSpan suggestion) {
    for (final reference in _detectedReferences) {
      if (suggestion.range.start < reference.end &&
          suggestion.range.end > reference.start) {
        return true;
      }
    }
    return false;
  }

  void _filterSpellSuggestions() {
    final filtered = _spellSuggestions
        .where((suggestion) {
          final token = _normalizeToken(_tokenForSuggestion(suggestion));
          if (token.isEmpty) return false;
          if (_ignoredSpellTokens.contains(token)) return false;
          if (_overlapsReferenceRange(suggestion)) return false;
          return true;
        })
        .toList(growable: false);
    _spellSuggestions = filtered;
    _notesController.updateSpellSuggestions(filtered);
  }

  void _syncReferenceDecorations() {
    final suggestions = detectSermonReferences(_notesController.text, _books)
        .where(
          (reference) =>
              !_ignoredReferenceKeys.contains(_referenceKey(reference)),
        )
        .where((reference) => !_hasInsertedReference(reference))
        .toList(growable: false);
    _detectedReferences = suggestions;
    _notesController.updateReferenceRanges([
      for (final reference in suggestions)
        NoteDecorationRange(start: reference.start, end: reference.end),
    ]);
  }

  void _scheduleSpellCheck() {
    _spellCheckDebounce?.cancel();
    _spellCheckDebounce = Timer(
      const Duration(milliseconds: 420),
      _runSpellCheck,
    );
  }

  Future<void> _runSpellCheck() async {
    final text = _notesController.text;
    if (text.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _spellSuggestions = const <SuggestionSpan>[];
      });
      _notesController.updateSpellSuggestions(const <SuggestionSpan>[]);
      return;
    }
    final requestId = ++_spellRequestId;
    try {
      final results = await _spellCheckService.fetchSpellCheckSuggestions(
        const Locale('es'),
        text,
      );
      if (!mounted ||
          requestId != _spellRequestId ||
          text != _notesController.text) {
        return;
      }
      setState(() {
        _spellSuggestions = List<SuggestionSpan>.from(results ?? const []);
        _filterSpellSuggestions();
      });
    } catch (_) {
      if (!mounted || requestId != _spellRequestId) return;
      setState(() => _spellSuggestions = const <SuggestionSpan>[]);
      _notesController.updateSpellSuggestions(const <SuggestionSpan>[]);
    }
  }

  void _replaceMisspelledWord(SuggestionSpan suggestion, String replacement) {
    final text = _notesController.text;
    final start = suggestion.range.start.clamp(0, text.length);
    final end = suggestion.range.end.clamp(start, text.length);
    final next = text.replaceRange(start, end, replacement);
    _notesController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    _scheduleSpellCheck();
    _scheduleSave();
  }

  void _ignoreMisspelledWord(SuggestionSpan suggestion) {
    final token = _normalizeToken(_tokenForSuggestion(suggestion));
    if (token.isEmpty) return;
    setState(() {
      _ignoredSpellTokens.add(token);
      _filterSpellSuggestions();
    });
  }

  Widget _buildNotesContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
    DetectedSermonReference? activeReference,
    SuggestionSpan? activeSuggestion,
  ) {
    final items = List<ContextMenuButtonItem>.from(
      editableTextState.contextMenuButtonItems,
    );
    if (activeSuggestion != null) {
      final replacements = activeSuggestion.suggestions.take(3).toList();
      for (var i = replacements.length - 1; i >= 0; i--) {
        final replacement = replacements[i];
        items.insert(
          0,
          ContextMenuButtonItem(
            label: 'Cambiar a "$replacement"',
            onPressed: () {
              editableTextState.hideToolbar();
              _replaceMisspelledWord(activeSuggestion, replacement);
            },
          ),
        );
      }
      items.insert(
        replacements.length,
        ContextMenuButtonItem(
          label: 'Omitir palabra',
          onPressed: () {
            editableTextState.hideToolbar();
            _ignoreMisspelledWord(activeSuggestion);
          },
        ),
      );
    }
    if (activeReference != null) {
      items.insert(
        0,
        ContextMenuButtonItem(
          label: 'Agregar ${activeReference.label}',
          onPressed: () async {
            editableTextState.hideToolbar();
            await _insertDetectedVerse(activeReference);
          },
        ),
      );
      items.insert(
        1,
        ContextMenuButtonItem(
          label: 'Omitir referencia',
          onPressed: () {
            editableTextState.hideToolbar();
            _ignoreReference(activeReference);
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  Future<void> _openNotesTypographyMenu() async {
    final size = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NotesFontSizeSheet(theme: _theme()),
    );
    if (size == null) return;
    _applyNotesFormat(RichNoteFormat.size, fontSize: size);
  }

  void _scheduleSave() {
    _saveDebounce?.cancel();
    if (mounted && !_hasPendingChanges) {
      setState(() => _hasPendingChanges = true);
    } else {
      _hasPendingChanges = true;
    }
    _saveDebounce = Timer(const Duration(milliseconds: 650), _flushNote);
  }

  Future<void> _flushNote() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (mounted) {
      setState(() {
        _isSaving = true;
      });
    } else {
      _isSaving = true;
    }
    _notesDocument = _notesController.document;
    final notesStorage = _notesDocument.text.trim().isEmpty
        ? ''
        : _notesDocument.toStorage();
    final updated = _note.copyWith(
      title: _titleController.text.trim(),
      speaker: _speakerController.text.trim(),
      notes: notesStorage,
      takeaway: _takeawayController.text.trim(),
      primaryVersionId: _primaryVersion.id,
      secondaryVersionId: _secondaryVersion.id,
    );
    _note = updated;
    if (!updated.hasContent) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _hasPendingChanges = false;
        });
      } else {
        _isSaving = false;
        _hasPendingChanges = false;
      }
      return;
    }
    await SermonNoteService.I.saveNote(updated);
    if (mounted) {
      setState(() {
        _lastSavedAt = updated.updatedAt;
        _isSaving = false;
        _hasPendingChanges = false;
      });
    } else {
      _lastSavedAt = updated.updatedAt;
      _isSaving = false;
      _hasPendingChanges = false;
    }
  }

  void _applyNotesFormat(RichNoteFormat format, {double? fontSize}) {
    _notesController.applyFormat(format, fontSize: fontSize);
    _notesDocument = _notesController.document;
    _scheduleSave();
    if (mounted) setState(() {});
  }

  Future<void> _insertDetectedVerse(DetectedSermonReference reference) async {
    final loaded = <BibleVerse>[];
    for (
      var verseNumber = reference.startVerse;
      verseNumber <= reference.endVerse;
      verseNumber++
    ) {
      final verse = await BibleParserService.I.getVerse(
        version: _primaryVersion,
        bookNumber: reference.book.number,
        chapter: reference.chapter,
        verse: verseNumber,
      );
      if (verse != null) loaded.add(verse);
    }
    if (loaded.isEmpty || !mounted) return;
    final verses = List<SermonVerseReference>.from(_note.verses);
    for (final verse in loaded) {
      final saved = SermonVerseReference.fromVerse(verse);
      if (!verses.any((v) => v.key == saved.key)) {
        verses.add(saved);
      }
    }
    final buffer = StringBuffer('\n\n');
    for (var i = 0; i < loaded.length; i++) {
      final verse = loaded[i];
      if (i > 0) buffer.writeln();
      buffer
        ..writeln('${verse.reference} (${_primaryVersion.shortName})')
        ..write(verse.text);
    }
    final insertion = buffer.toString();
    final text = _notesController.text;
    final selection = _notesController.selection;
    final offset = selection.isValid ? selection.end : text.length;
    final next =
        '${text.substring(0, offset)}$insertion${text.substring(offset)}';
    setState(() {
      _note = _note.copyWith(verses: verses);
      _notesController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: offset + insertion.length),
      );
    });
    HapticFeedback.selectionClick();
    await _flushNote();
  }

  Future<void> _openTypographySheet(BibleReaderThemeData t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TypographyHintSheet(theme: t),
    );
  }

  BibleReaderThemeData _theme() => BibleReaderThemeData.fromId(
    BibleReaderThemeData.migrateId(
      BibleUserDataService.I.readerThemeNotifier.value,
    ),
  );

  Future<void> _openSavedNotes() async {
    await _flushNote();
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SermonNotesSavedScreen()),
    );
  }

  Future<void> _exportPdf() async {
    try {
      await _flushNote();
      if (!_note.hasContent) {
        if (!mounted) return;
        _showSnack('Escribe algo antes de exportar el PDF.');
        return;
      }
      final choice = await _pickPdfExportAction();
      if (choice == null) return;
      final File file = choice.action == _PdfExportAction.share
          ? await SermonNoteExportService.I.exportAndShareSermonNote(
              note: _note,
              chapterVerses: _verses,
              secondaryChapterVerses: _secondaryVerses,
              cleanCover: choice.cleanCover,
            )
          : await SermonNoteExportService.I.exportSermonNoteToPdf(
              note: _note,
              chapterVerses: _verses,
              secondaryChapterVerses: _secondaryVerses,
              saveToDownloads: true,
              cleanCover: choice.cleanCover,
            );
      if (!mounted) return;
      final label = choice.action == _PdfExportAction.share
          ? 'PDF listo para compartir'
          : 'PDF guardado';
      _showSnack('$label: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('No se pudo exportar el PDF: $e');
    }
  }

  Future<_PdfExportChoice?> _pickPdfExportAction() async {
    return showModalBottomSheet<_PdfExportChoice>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PdfExportSheet(theme: _theme()),
    );
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  String _saveStatusLabel() {
    if (_isSaving) return 'Guardando...';
    if (_hasPendingChanges) return 'Cambios sin guardar';
    if (!_note.hasContent) return 'Borrador vacio';
    final savedAt = _lastSavedAt;
    if (savedAt == null) return 'Sin guardado reciente';
    return 'Guardado hace ${_relativeTime(savedAt)}';
  }

  String _relativeTime(DateTime savedAt) {
    final diff = DateTime.now().difference(savedAt);
    if (diff.inSeconds < 30) return 'ahora';
    if (diff.inMinutes < 1) return '${diff.inSeconds}s';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return _formatDate(savedAt);
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _spellCheckDebounce?.cancel();
    _saveStatusTicker?.cancel();
    unawaited(_flushNote());
    _titleController.dispose();
    _speakerController.dispose();
    _notesController.dispose();
    _takeawayController.dispose();
    _tabController.dispose();
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
                : LayoutBuilder(
                    builder: (_, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      return Column(
                        children: [
                          _buildHeader(t, isWide),
                          Expanded(
                            child: isWide ? _buildSplit(t) : _buildTabbed(t),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t, bool isWide) {
    if (!isWide) return _buildCompactHeader(t);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: t.textSecondary,
              size: 18,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _openPassagePicker,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Modo Predicacion',
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HeaderChip(
                    theme: t,
                    icon: Icons.menu_book_outlined,
                    label: '$_bookName $_chapter',
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: _openVersionPicker,
            icon: Icon(Icons.compare_arrows, color: t.accent, size: 17),
            label: Text(
              '${_primaryVersion.shortName} / ${_secondaryVersion.shortName}',
            ),
            style: TextButton.styleFrom(
              foregroundColor: t.accent,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              textStyle: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Pasaje central',
            icon: Icon(Icons.my_location, color: t.accent, size: 21),
            onPressed: _openCentralPassagePicker,
          ),
          IconButton(
            tooltip: 'Apuntes guardados',
            icon: Icon(Icons.folder_open_outlined, color: t.accent, size: 20),
            onPressed: _openSavedNotes,
          ),
          IconButton(
            tooltip: 'Exportar PDF',
            icon: Icon(
              Icons.picture_as_pdf_outlined,
              color: t.accent,
              size: 21,
            ),
            onPressed: _exportPdf,
          ),
          IconButton(
            tooltip: 'Texto',
            icon: Icon(Icons.text_fields, color: t.textSecondary, size: 20),
            onPressed: () => _openTypographySheet(t),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 2),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: t.textSecondary,
              size: 18,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _openPassagePicker,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Modo Predicacion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_bookName $_chapter · ${_primaryVersion.shortName}/${_secondaryVersion.shortName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_SermonHeaderAction>(
            tooltip: 'Opciones de apuntes',
            color: t.surface,
            icon: Icon(Icons.more_vert, color: t.textSecondary, size: 22),
            onSelected: (action) async {
              switch (action) {
                case _SermonHeaderAction.passage:
                  await _openPassagePicker();
                  break;
                case _SermonHeaderAction.versions:
                  await _openVersionPicker();
                  break;
                case _SermonHeaderAction.centralPassage:
                  await _openCentralPassagePicker();
                  break;
                case _SermonHeaderAction.savedNotes:
                  await _openSavedNotes();
                  break;
                case _SermonHeaderAction.exportPdf:
                  await _exportPdf();
                  break;
                case _SermonHeaderAction.text:
                  await _openTypographySheet(t);
                  break;
              }
            },
            itemBuilder: (_) => [
              _menuItem(t, _SermonHeaderAction.passage, 'Cambiar lectura'),
              _menuItem(t, _SermonHeaderAction.versions, 'Versiones'),
              _menuItem(
                t,
                _SermonHeaderAction.centralPassage,
                'Pasaje central',
              ),
              _menuItem(t, _SermonHeaderAction.savedNotes, 'Apuntes guardados'),
              _menuItem(t, _SermonHeaderAction.exportPdf, 'Exportar PDF'),
              _menuItem(t, _SermonHeaderAction.text, 'Texto'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_SermonHeaderAction> _menuItem(
    BibleReaderThemeData t,
    _SermonHeaderAction value,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Text(
        label,
        style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
      ),
    );
  }

  Widget _buildSplit(BibleReaderThemeData t) {
    return Row(
      children: [
        Expanded(child: _buildReading(t)),
        Container(width: 1, color: t.textSecondary.withOpacity(0.10)),
        Expanded(child: _buildNotes(t)),
      ],
    );
  }

  Widget _buildTabbed(BibleReaderThemeData t) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: t.accent,
          labelColor: t.textPrimary,
          unselectedLabelColor: t.textSecondary,
          tabs: const [
            Tab(text: 'Lectura'),
            Tab(text: 'Apuntes'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildReading(t), _buildNotes(t)],
          ),
        ),
      ],
    );
  }

  Widget _buildReading(BibleReaderThemeData t) {
    return StudyReadingPanel(
      theme: t,
      verses: _verses,
      secondaryVerses: _secondaryVerses,
      primaryVersion: _primaryVersion,
      secondaryVersion: _secondaryVersion,
      bookNumber: _bookNumber,
      chapter: _chapter,
    );
  }

  Widget _buildNotes(BibleReaderThemeData t) {
    final activeReference = _activeReferenceAtCursor(_detectedReferences);
    final activeSuggestion = _activeSuggestionAtCursor();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
      children: [
        _SermonMetaCard(
          theme: t,
          titleController: _titleController,
          speakerController: _speakerController,
          date: _note.sermonDate,
          centralPassage: _note.centralPassage,
          onChanged: _onFieldChanged,
          onPickDate: _pickDate,
          onPickCentralPassage: _openCentralPassagePicker,
          onClearCentralPassage: _clearCentralPassage,
        ),
        const SizedBox(height: 12),
        _NotesEditorCard(
          theme: t,
          controller: _notesController,
          activeReference: activeReference,
          activeSuggestion: activeSuggestion,
          insertedVerseCount: _note.verses.length,
          saveStatusLabel: _saveStatusLabel(),
          canUndo: _notesController.canUndo,
          canRedo: _notesController.canRedo,
          onUndo: () {
            if (_notesController.undo()) {
              _scheduleSave();
              if (mounted) setState(() {});
            }
          },
          onRedo: () {
            if (_notesController.redo()) {
              _scheduleSave();
              if (mounted) setState(() {});
            }
          },
          onBold: () => _applyNotesFormat(RichNoteFormat.bold),
          onUnderline: () => _applyNotesFormat(RichNoteFormat.underline),
          onPickSize: _openNotesTypographyMenu,
          onInsertVerse: activeReference == null
              ? null
              : () => _insertDetectedVerse(activeReference),
          onIgnoreReference: activeReference == null
              ? null
              : () => _ignoreReference(activeReference),
          onReplaceSuggestion:
              activeSuggestion == null || activeSuggestion.suggestions.isEmpty
              ? null
              : () => _replaceMisspelledWord(
                  activeSuggestion,
                  activeSuggestion.suggestions.first,
                ),
          onIgnoreSuggestion: activeSuggestion == null
              ? null
              : () => _ignoreMisspelledWord(activeSuggestion),
          contextMenuBuilder: (context, editableTextState) =>
              _buildNotesContextMenu(
                context,
                editableTextState,
                activeReference,
                activeSuggestion,
              ),
        ),
        const SizedBox(height: 12),
        _TakeawayCard(
          theme: t,
          controller: _takeawayController,
          onChanged: _onFieldChanged,
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _note.sermonDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => _note = _note.copyWith(sermonDate: picked));
    _scheduleSave();
  }
}

class _SermonMetaCard extends StatelessWidget {
  final BibleReaderThemeData theme;
  final TextEditingController titleController;
  final TextEditingController speakerController;
  final DateTime date;
  final SermonCentralPassage? centralPassage;
  final ValueChanged<String> onChanged;
  final VoidCallback onPickDate;
  final VoidCallback onPickCentralPassage;
  final VoidCallback onClearCentralPassage;

  const _SermonMetaCard({
    required this.theme,
    required this.titleController,
    required this.speakerController,
    required this.date,
    required this.centralPassage,
    required this.onChanged,
    required this.onPickDate,
    required this.onPickCentralPassage,
    required this.onClearCentralPassage,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return _PanelCard(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Apunte de predicacion',
            style: GoogleFonts.cinzel(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            theme: t,
            controller: titleController,
            label: 'Titulo',
            hint: 'Ej. La fe que permanece',
            onChanged: onChanged,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoButton(
                  theme: t,
                  icon: Icons.event,
                  label: _formatDate(date),
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _LabeledField(
                  theme: t,
                  controller: speakerController,
                  label: 'Predicador',
                  hint: 'Pastor / maestro',
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _InfoButton(
                  theme: t,
                  icon: Icons.my_location,
                  label: centralPassage?.label ?? 'Pasaje central',
                  onTap: onPickCentralPassage,
                ),
              ),
              if (centralPassage != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Quitar pasaje central',
                  onPressed: onClearCentralPassage,
                  icon: Icon(Icons.close, color: t.textSecondary, size: 18),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NotesEditorCard extends StatelessWidget {
  final BibleReaderThemeData theme;
  final SermonRichTextController controller;
  final DetectedSermonReference? activeReference;
  final SuggestionSpan? activeSuggestion;
  final int insertedVerseCount;
  final String saveStatusLabel;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onBold;
  final VoidCallback onUnderline;
  final VoidCallback onPickSize;
  final VoidCallback? onInsertVerse;
  final VoidCallback? onIgnoreReference;
  final VoidCallback? onReplaceSuggestion;
  final VoidCallback? onIgnoreSuggestion;
  final EditableTextContextMenuBuilder contextMenuBuilder;

  const _NotesEditorCard({
    required this.theme,
    required this.controller,
    required this.activeReference,
    required this.activeSuggestion,
    required this.insertedVerseCount,
    required this.saveStatusLabel,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.onBold,
    required this.onUnderline,
    required this.onPickSize,
    required this.onInsertVerse,
    required this.onIgnoreReference,
    required this.onReplaceSuggestion,
    required this.onIgnoreSuggestion,
    required this.contextMenuBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return _PanelCard(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Notas',
                      style: GoogleFonts.cinzel(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _SaveStatusChip(theme: t, label: saveStatusLabel),
                  ],
                ),
              ),
              _FormatIcon(
                theme: t,
                icon: Icons.undo,
                tooltip: 'Deshacer',
                enabled: canUndo,
                onTap: onUndo,
              ),
              _FormatIcon(
                theme: t,
                icon: Icons.redo,
                tooltip: 'Rehacer',
                enabled: canRedo,
                onTap: onRedo,
              ),
              _FormatIcon(
                theme: t,
                icon: Icons.format_bold,
                tooltip: 'Negrita',
                onTap: onBold,
              ),
              _FormatIcon(
                theme: t,
                icon: Icons.format_underlined,
                tooltip: 'Subrayado',
                onTap: onUnderline,
              ),
              _FormatIcon(
                theme: t,
                icon: Icons.format_size,
                tooltip: 'Tamaño de texto',
                onTap: onPickSize,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: null,
            minLines: 10,
            hintLocales: const [Locale('es')],
            contextMenuBuilder: contextMenuBuilder,
            style: GoogleFonts.lora(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: _inputDecoration(
              t,
              'Escribe tus apuntes. Mueve el cursor sobre una cita para verla como sugerencia.',
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child:
                activeSuggestion != null &&
                    activeSuggestion!.suggestions.isNotEmpty
                ? _SpellingSuggestionBar(
                    key: ValueKey(
                      '${activeSuggestion!.range.start}:${activeSuggestion!.range.end}',
                    ),
                    theme: t,
                    token: _safeSuggestionLabel(controller, activeSuggestion!),
                    replacement: activeSuggestion!.suggestions.first,
                    onReplace: onReplaceSuggestion!,
                    onIgnore: onIgnoreSuggestion!,
                  )
                : activeReference == null
                ? _InlineEditorHint(
                    key: const ValueKey('notes_hint'),
                    theme: t,
                    insertedVerseCount: insertedVerseCount,
                  )
                : _ReferenceSuggestionBar(
                    key: ValueKey(activeReference!.label),
                    theme: t,
                    reference: activeReference!,
                    onInsert: onInsertVerse!,
                    onIgnore: onIgnoreReference!,
                  ),
          ),
          if (insertedVerseCount > 0) ...[
            const SizedBox(height: 10),
            _InsertedVersesIndicator(theme: t, count: insertedVerseCount),
          ],
        ],
      ),
    );
  }
}

class _TakeawayCard extends StatelessWidget {
  final BibleReaderThemeData theme;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _TakeawayCard({
    required this.theme,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return _PanelCard(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Con que me quedo?',
            style: GoogleFonts.cinzel(
              color: t.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            minLines: 3,
            style: GoogleFonts.lora(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: _inputDecoration(
              t,
              'Una idea, conviccion o accion concreta.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final BibleReaderThemeData theme;
  final Widget child;

  const _PanelCard({required this.theme, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.textSecondary.withOpacity(0.08)),
      ),
      child: child,
    );
  }
}

class _LabeledField extends StatelessWidget {
  final BibleReaderThemeData theme;
  final TextEditingController controller;
  final String label;
  final String hint;
  final ValueChanged<String> onChanged;

  const _LabeledField({
    required this.theme,
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: _inputDecoration(t, hint).copyWith(labelText: label),
    );
  }
}

class _InfoButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InfoButton({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: t.textSecondary.withOpacity(0.12)),
        ),
        child: Row(
          children: [
            Icon(icon, color: t.accent, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;

  const _HeaderChip({
    required this.theme,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: t.accent, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.lora(
              color: t.accent,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatIcon extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  const _FormatIcon({
    required this.theme,
    required this.icon,
    this.tooltip = 'Formato',
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = enabled ? t.accent : t.textSecondary.withOpacity(0.45);
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, color: color, size: 18),
    );
  }
}

class _SaveStatusChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String label;

  const _SaveStatusChip({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final saving = label.startsWith('Guardando');
    final pending = label.startsWith('Cambios');
    final color = saving
        ? const Color(0xFFC78D1B)
        : pending
        ? const Color(0xFFD64045)
        : t.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(t.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ReferenceSuggestionBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final DetectedSermonReference reference;
  final VoidCallback onInsert;
  final VoidCallback onIgnore;

  const _ReferenceSuggestionBar({
    super.key,
    required this.theme,
    required this.reference,
    required this.onInsert,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const highlight = Color(0xFFC78D1B);
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight.withOpacity(t.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight.withOpacity(0.34)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: highlight.withOpacity(0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.auto_awesome, color: highlight, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reference.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cita detectada. Puedes insertarla en tus apuntes o ignorarla.',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.76),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onIgnore,
            style: TextButton.styleFrom(
              foregroundColor: t.textSecondary,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Omitir'),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: onInsert,
            style: FilledButton.styleFrom(
              backgroundColor: highlight.withOpacity(t.isDark ? 0.20 : 0.14),
              foregroundColor: highlight,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }
}

String _safeSuggestionLabel(
  TextEditingController controller,
  SuggestionSpan suggestion,
) {
  final text = controller.text;
  final start = suggestion.range.start.clamp(0, text.length);
  final end = suggestion.range.end.clamp(start, text.length);
  return text.substring(start, end);
}

class _SpellingSuggestionBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String token;
  final String replacement;
  final VoidCallback onReplace;
  final VoidCallback onIgnore;

  const _SpellingSuggestionBar({
    super.key,
    required this.theme,
    required this.token,
    required this.replacement,
    required this.onReplace,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const highlight = Color(0xFFD64045);
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight.withOpacity(t.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight.withOpacity(0.26)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: highlight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.spellcheck, color: highlight, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sugerencia: $replacement',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.76),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onIgnore,
            style: TextButton.styleFrom(
              foregroundColor: t.textSecondary,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Omitir'),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: onReplace,
            style: FilledButton.styleFrom(
              backgroundColor: highlight.withOpacity(t.isDark ? 0.18 : 0.10),
              foregroundColor: highlight,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Corregir'),
          ),
        ],
      ),
    );
  }
}

class _InlineEditorHint extends StatelessWidget {
  final BibleReaderThemeData theme;
  final int insertedVerseCount;

  const _InlineEditorHint({
    super.key,
    required this.theme,
    required this.insertedVerseCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: t.background.withOpacity(t.isDark ? 0.28 : 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.textSecondary.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_outlined, color: t.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insertedVerseCount == 0
                  ? 'El corrector subraya palabras dudosas en rojo. Si el cursor cae sobre una cita biblica detectada, veras aqui la sugerencia para insertarla.'
                  : 'El corrector sigue activo mientras escribes. Si colocas el cursor sobre una cita biblica detectada, podras insertarla sin salir de la nota.',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.76),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsertedVersesIndicator extends StatelessWidget {
  final BibleReaderThemeData theme;
  final int count;

  const _InsertedVersesIndicator({required this.theme, required this.count});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final label = count == 1
        ? '1 versiculo insertado'
        : '$count versiculos insertados';
    return Row(
      children: [
        Icon(Icons.library_books_outlined, color: t.accent, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.80),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NotesFontSizeSheet extends StatelessWidget {
  final BibleReaderThemeData theme;

  const _NotesFontSizeSheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const sizes = <double>[14, 18, 22];
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tamano del texto',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona una parte de la nota y despues elige el tamano que quieras aplicar.',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.72),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            for (final size in sizes) ...[
              _NotesFontSizeTile(
                theme: t,
                size: size,
                preview: size == 14
                    ? 'Texto base'
                    : size == 18
                    ? 'Enfasis intermedio'
                    : 'Enfasis fuerte',
                onTap: () => Navigator.pop(context, size),
              ),
              if (size != sizes.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotesFontSizeTile extends StatelessWidget {
  final BibleReaderThemeData theme;
  final double size;
  final String preview;
  final VoidCallback onTap;

  const _NotesFontSizeTile({
    required this.theme,
    required this.size,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.background.withOpacity(t.isDark ? 0.28 : 0.60),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.textSecondary.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                size.toInt().toString(),
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview,
                    style: GoogleFonts.lora(
                      color: t.textPrimary,
                      fontSize: size,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Aplicar a la seleccion actual',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.72),
                      fontSize: 11.5,
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

class _VersionPairResult {
  final BibleVersion primary;
  final BibleVersion secondary;

  const _VersionPairResult(this.primary, this.secondary);
}

class _VersionPairSheet extends StatefulWidget {
  final BibleVersion initialPrimary;
  final BibleVersion initialSecondary;
  final BibleReaderThemeData theme;

  const _VersionPairSheet({
    required this.initialPrimary,
    required this.initialSecondary,
    required this.theme,
  });

  @override
  State<_VersionPairSheet> createState() => _VersionPairSheetState();
}

class _VersionPairSheetState extends State<_VersionPairSheet> {
  late BibleVersion _primary;
  late BibleVersion _secondary;

  @override
  void initState() {
    super.initState();
    _primary = widget.initialPrimary;
    _secondary = widget.initialSecondary;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final versions = BibleDownloadService.I.availableVersions;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versiones',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            _VersionDropdown(
              theme: t,
              label: 'Principal',
              value: _primary,
              versions: versions,
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _primary = v;
                  if (_secondary == _primary) {
                    _secondary = BibleDownloadService.I.bestAvailableSecondary(
                      _primary,
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 10),
            _VersionDropdown(
              theme: t,
              label: 'Secundaria',
              value: _secondary,
              versions: versions.where((v) => v != _primary).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _secondary = v);
              },
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  _VersionPairResult(_primary, _secondary),
                ),
                child: const Text('Aplicar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionDropdown extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String label;
  final BibleVersion value;
  final List<BibleVersion> versions;
  final ValueChanged<BibleVersion?> onChanged;

  const _VersionDropdown({
    required this.theme,
    required this.label,
    required this.value,
    required this.versions,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return DropdownButtonFormField<BibleVersion>(
      value: value,
      items: [
        for (final version in versions)
          DropdownMenuItem(
            value: version,
            child: Text('${version.shortName} · ${version.displayName}'),
          ),
      ],
      onChanged: onChanged,
      dropdownColor: t.surface,
      style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: _inputDecoration(t, label),
    );
  }
}

class _VerseRangeResult {
  final int start;
  final int end;

  const _VerseRangeResult(this.start, this.end);
}

class _VerseRangeSheet extends StatefulWidget {
  final BibleReaderThemeData theme;
  final List<BibleVerse> verses;
  final String title;

  const _VerseRangeSheet({
    required this.theme,
    required this.verses,
    required this.title,
  });

  @override
  State<_VerseRangeSheet> createState() => _VerseRangeSheetState();
}

class _VerseRangeSheetState extends State<_VerseRangeSheet> {
  late int _start;
  late int _end;

  @override
  void initState() {
    super.initState();
    _start = widget.verses.isEmpty ? 1 : widget.verses.first.verse;
    _end = _start;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final verses = widget.verses.map((v) => v.verse).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pasaje central · ${widget.title}',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _VerseDropdown(
                    theme: t,
                    label: 'Inicio',
                    value: _start,
                    verses: verses,
                    onChanged: (v) => setState(() {
                      _start = v ?? _start;
                      if (_end < _start) _end = _start;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _VerseDropdown(
                    theme: t,
                    label: 'Fin',
                    value: _end,
                    verses: verses,
                    onChanged: (v) => setState(() => _end = v ?? _end),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(
                  context,
                  _VerseRangeResult(
                    _start < _end ? _start : _end,
                    _start < _end ? _end : _start,
                  ),
                ),
                child: const Text('Usar pasaje'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerseDropdown extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String label;
  final int value;
  final List<int> verses;
  final ValueChanged<int?> onChanged;

  const _VerseDropdown({
    required this.theme,
    required this.label,
    required this.value,
    required this.verses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return DropdownButtonFormField<int>(
      value: value,
      items: [
        for (final verse in verses)
          DropdownMenuItem(value: verse, child: Text('v. $verse')),
      ],
      onChanged: onChanged,
      dropdownColor: t.surface,
      style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: _inputDecoration(t, label),
    );
  }
}

class _TypographyHintSheet extends StatelessWidget {
  final BibleReaderThemeData theme;

  const _TypographyHintSheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: SafeArea(
        top: false,
        child: Text(
          'Selecciona texto dentro de Notas y usa B, subrayado o tamaño.',
          style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 14),
        ),
      ),
    );
  }
}

class _PdfExportSheet extends StatefulWidget {
  final BibleReaderThemeData theme;

  const _PdfExportSheet({required this.theme});

  @override
  State<_PdfExportSheet> createState() => _PdfExportSheetState();
}

class _PdfExportSheetState extends State<_PdfExportSheet> {
  bool _cleanCover = true;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exportar PDF',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige si quieres una portada mas limpia para compartir o guardar.',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.66),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _cleanCover,
              onChanged: (value) => setState(() => _cleanCover = value),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: t.accent,
              title: Text(
                'Portada limpia',
                style: GoogleFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Reduce adornos y deja un encabezado mas sobrio.',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.64),
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _PdfExportTile(
              icon: Icons.ios_share_outlined,
              title: 'Compartir PDF',
              subtitle: 'Generar el archivo y abrir el share sheet.',
              theme: t,
              onTap: () => Navigator.pop(
                context,
                _PdfExportChoice(
                  action: _PdfExportAction.share,
                  cleanCover: _cleanCover,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _PdfExportTile(
              icon: Icons.download_outlined,
              title: 'Guardar PDF',
              subtitle: 'Guardar una copia local del apunte en PDF.',
              theme: t,
              onTap: () => Navigator.pop(
                context,
                _PdfExportChoice(
                  action: _PdfExportAction.save,
                  cleanCover: _cleanCover,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfExportTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final BibleReaderThemeData theme;
  final VoidCallback onTap;

  const _PdfExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.background.withOpacity(t.isDark ? 0.26 : 0.58),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.textSecondary.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: t.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.65),
                      fontSize: 12,
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

InputDecoration _inputDecoration(BibleReaderThemeData t, String hint) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.manrope(
      color: t.textSecondary.withOpacity(0.45),
      fontSize: 13,
    ),
    labelStyle: GoogleFonts.manrope(color: t.textSecondary, fontSize: 12),
    filled: true,
    fillColor: t.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: t.textSecondary.withOpacity(0.10)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: t.textSecondary.withOpacity(0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: t.accent.withOpacity(0.55)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
