import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import '../../widgets/selector_modo_papel.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_fonts.dart';
import '../../models/bible/adjunto_nota.dart';
import '../../models/bible/dibujo_nota.dart';
import '../../models/bible/listas_nota.dart';

import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/rich_note_document.dart';
import '../../models/bible/sermon_note.dart';
import '../../services/bible/adjuntos_nota_service.dart';
import '../../services/bible/notas_sync.dart';
import '../../services/bible/bible_download_service.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/sermon_note_export_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/sermon_note_service.dart';
import '../../services/bible/sermon_reference_parser.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/bible_reader_theme.dart';
import 'lienzo_dibujo_screen.dart';
import 'sermon_notes_saved_screen.dart';
import 'study_mode_screen.dart' show StudyPickerResult;
import '../../widgets/bible/sermon/adjuntos_nota.dart';
import '../../widgets/bible/sermon/hoja_formato_nota.dart';
import '../../widgets/bible/sermon/sermon_highlight_controller.dart';
import '../../widgets/bible/sermon/sermon_rich_text_controller.dart';
import '../../widgets/bible/study/study_chapter_picker.dart';
import '../../widgets/bible/study/study_reading_panel.dart';
import '../../widgets/bible/sermon/sermon_header_bar.dart';

enum _PdfExportAction { share, save }

class _PdfExportChoice {
  final _PdfExportAction action;
  final bool cleanCover;

  const _PdfExportChoice({required this.action, required this.cleanCover});
}

// ignore_for_file: cancel_subscriptions — _SpellBridge below stores subscription
// in a field for the lint; actual lifecycle is managed by Flutter's EditableText.

// Routes Flutter's native spell check lifecycle to the custom suggestion bar.
class _SpellBridge implements SpellCheckService {
  _SpellBridge({required this.onResults});

  final void Function(List<SuggestionSpan> results, String forText) onResults;
  final _inner = DefaultSpellCheckService();

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(
    Locale locale,
    String text,
  ) async {
    final results = await _inner.fetchSpellCheckSuggestions(locale, text);
    if (results != null) onResults(results, text);
    return results;
  }
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
    this.bookName = 'Génesis',
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
  int? _readingStartVerse;
  int? _readingEndVerse;
  late BibleVersion _primaryVersion;
  late BibleVersion _secondaryVersion;
  late TabController _tabController;

  List<BibleBook> _books = const [];
  List<BibleVerse> _verses = const [];
  List<BibleVerse> _secondaryVerses = const [];
  // Versiculos agregados a la lectura (independientes de las Notas). Derivados
  // de _note.verses; se muestran en el panel izquierdo bajo la lectura actual.
  List<BibleVerse> _addedPrimary = const [];
  List<BibleVerse> _addedSecondary = const [];
  bool _loading = true;

  late SermonNote _note;
  late RichNoteDocument _notesDocument;
  Timer? _saveDebounce;
  Timer? _saveStatusTicker;
  bool _hydrating = false;
  bool _isSaving = false;
  bool _hasPendingChanges = false;
  DateTime? _lastSavedAt;
  final Set<String> _ignoredReferenceKeys = <String>{};
  final Set<String> _ignoredSpellTokens = <String>{};
  // Claves de versiculos cuyo TEXTO ya se inserto en las Notas (via deteccion
  // inline de citas). Independiente de _note.verses (panel izquierdo).
  final Set<String> _notesInsertedKeys = <String>{};
  late final _SpellBridge _spellBridge;
  // Resaltados POR APUNTE (independientes del Modo Estudio).
  late final SermonHighlightController _highlightController;
  List<DetectedSermonReference> _detectedReferences =
      const <DetectedSermonReference>[];
  List<SuggestionSpan> _rawSpellSuggestions = const <SuggestionSpan>[];
  List<SuggestionSpan> _spellSuggestions = const <SuggestionSpan>[];
  String _lastNotesText = '';
  TextSelection _lastNotesSelection = const TextSelection.collapsed(offset: -1);

  final _titleController = TextEditingController();
  final _speakerController = TextEditingController();
  late final SermonRichTextController _notesController;
  final _takeawayController = TextEditingController();
  // Foco del editor de Notas: cuando esta activo mostramos la barra de formato
  // flotante pegada al teclado.
  final _notesFocusNode = FocusNode();
  final _picker = ImagePicker();
  bool _agregandoAdjunto = false;
  bool _editandoListas = false;

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
    _highlightController = SermonHighlightController(
      onChanged: _onHighlightsChanged,
    );
    _notesController = SermonRichTextController(document: _notesDocument);
    _spellBridge = _SpellBridge(
      onResults: (results, forText) {
        if (!mounted || forText != _notesController.text) return;
        setState(() {
          _rawSpellSuggestions = results;
          _filterSpellSuggestions();
        });
      },
    );
    _notesController.addListener(_onNotesEdited);
    _notesController.constructorAdjunto = _construirAdjuntoEnLinea;
    NotasSync.I.estado.addListener(_alCambiarNube);
    AdjuntosNotaService.I.aviso.addListener(_alAvisoAdjuntos);
    _notesFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
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
      _huellaGuardada = existing.huellaContenido;
      _highlightController.seed(existing.highlights);
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
        _readingStartVerse = central.startVerse;
        _readingEndVerse = central.endVerse;
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
      await _rebuildAddedVerses();
    } catch (e) {
      debugPrint('[SERMON-NOTES] load chapter error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeChapter(
    int bookNumber,
    String bookName,
    int chapter, {
    int? startVerse,
    int? endVerse,
  }) async {
    await _flushNote();
    if (!mounted) return;
    setState(() {
      _bookNumber = bookNumber;
      _bookName = bookName;
      _chapter = chapter;
      _readingStartVerse = startVerse;
      _readingEndVerse = endVerse;
      // Persistir el pasaje elegido para que la nota lo recuerde al reabrir
      // (consistente con _openCentralPassagePicker).
      if (startVerse != null && endVerse != null) {
        _note = _note.copyWith(
          centralPassage: SermonCentralPassage(
            bookNumber: bookNumber,
            bookName: bookName,
            chapter: chapter,
            startVerse: startVerse,
            endVerse: endVerse,
          ),
        );
      }
    });
    await _loadChapter();
    _scheduleSave();
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
    // Auto-aplicar desde la búsqueda (un versículo), con opción de ajustar.
    if (result.autoApply && result.verse != null) {
      final v = result.verse!;
      await _changeChapter(
        result.bookNumber,
        result.bookName,
        result.chapter,
        startVerse: v,
        endVerse: v,
      );
      if (mounted) {
        _showSnackAction(
          'Lectura: ${result.bookName} ${result.chapter}:$v',
          actionLabel: 'Ajustar rango',
          onAction: () => _openPassageRangeFor(result),
        );
      }
      return;
    }
    await _openPassageRangeFor(result);
  }

  /// Abre el selector de rango para la lectura y aplica el resultado.
  Future<void> _openPassageRangeFor(StudyPickerResult result) async {
    final chapterVerses = await BibleParserService.I.getChapter(
      version: _primaryVersion,
      bookNumber: result.bookNumber,
      chapter: result.chapter,
    );
    if (!mounted) return;
    final range = await showModalBottomSheet<_VerseRangeResult>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseRangeSheet(
        theme: _theme(),
        verses: chapterVerses,
        title: '${result.bookName} ${result.chapter}',
        actionLabel: 'Usar lectura',
        initialStart: result.verse,
        initialEnd: result.verseEnd ?? result.verse,
      ),
    );
    if (range == null) return;
    await _changeChapter(
      result.bookNumber,
      result.bookName,
      result.chapter,
      startVerse: range.start,
      endVerse: range.end,
    );
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

  /// Intercambia la version principal por la secundaria (y viceversa).
  Future<void> _swapVersions() async {
    await _flushNote();
    if (!mounted) return;
    final newPrimary = _secondaryVersion;
    final newSecondary = _primaryVersion;
    setState(() {
      _primaryVersion = newPrimary;
      _secondaryVersion = newSecondary;
      _note = _note.copyWith(
        primaryVersionId: newPrimary.id,
        secondaryVersionId: newSecondary.id,
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
    // Auto-aplicar desde la búsqueda (un versículo), con opción de ajustar.
    if (picked.autoApply && picked.verse != null) {
      final v = picked.verse!;
      await _applyCentralPassage(picked, v, v);
      if (mounted) {
        _showSnackAction(
          'Pasaje central: ${picked.bookName} ${picked.chapter}:$v',
          actionLabel: 'Ajustar rango',
          onAction: () => _openCentralRangeFor(picked),
        );
      }
      return;
    }
    await _openCentralRangeFor(picked);
  }

  Future<void> _openCentralRangeFor(StudyPickerResult picked) async {
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
        initialStart: picked.verse,
        initialEnd: picked.verseEnd ?? picked.verse,
      ),
    );
    if (range == null) return;
    await _applyCentralPassage(picked, range.start, range.end);
  }

  Future<void> _applyCentralPassage(
    StudyPickerResult picked,
    int startVerse,
    int endVerse,
  ) async {
    setState(() {
      _note = _note.copyWith(
        centralPassage: SermonCentralPassage(
          bookNumber: picked.bookNumber,
          bookName: picked.bookName,
          chapter: picked.chapter,
          startVerse: startVerse,
          endVerse: endVerse,
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
    if (_hydrating || _editandoListas) return;
    final anterior = _lastNotesText;
    final textChanged = anterior != _notesController.text;
    if (textChanged) _continuarListaSiHaceFalta(anterior);
    final selectionChanged = _lastNotesSelection != _notesController.selection;
    if (!textChanged && !selectionChanged) return;
    _lastNotesText = _notesController.text;
    _lastNotesSelection = _notesController.selection;
    _notesDocument = _notesController.document;
    if (textChanged) {
      _syncReferenceDecorations();
      _scheduleSave();
    }
    if (mounted) setState(() {});
  }

  String _referenceKey(DetectedSermonReference reference) {
    return '${reference.book.number}:${reference.chapter}:${reference.startVerse}:${reference.endVerse}:${reference.start}';
  }

  bool _hasInsertedReference(DetectedSermonReference reference) {
    for (
      var verse = reference.startVerse;
      verse <= reference.endVerse;
      verse++
    ) {
      final key =
          '${_primaryVersion.id}:${reference.book.number}:${reference.chapter}:$verse';
      if (!_notesInsertedKeys.contains(key)) return false;
    }
    return true;
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
    final filtered = _rawSpellSuggestions
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


  void _replaceMisspelledWord(SuggestionSpan suggestion, String replacement) {
    final text = _notesController.text;
    final start = suggestion.range.start.clamp(0, text.length);
    final end = suggestion.range.end.clamp(start, text.length);
    final next = text.replaceRange(start, end, replacement);
    _notesController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
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
    // Formato inline: al seleccionar texto, negrita, cursiva, subrayado y
    // resaltado aparecen en el menú de la selección; «Formato…» abre el panel
    // completo (estilos, listas, colores y tamaño).
    final selection = editableTextState.textEditingValue.selection;
    if (selection.isValid && !selection.isCollapsed) {
      var insertAt = 0;
      void addFormat(String label, VoidCallback apply) {
        items.insert(
          insertAt++,
          ContextMenuButtonItem(
            label: label,
            onPressed: () {
              editableTextState.hideToolbar();
              apply();
            },
          ),
        );
      }

      addFormat('Negrita', () => _applyNotesFormat(RichNoteFormat.bold));
      addFormat('Cursiva', () => _applyNotesFormat(RichNoteFormat.italic));
      addFormat('Subrayar', () => _applyNotesFormat(RichNoteFormat.underline));
      addFormat('Resaltar', () {
        final actual = _notesController.document
            .formatIn(selection.start, selection.end)
            .highlight;
        _applyNotesFormat(
          RichNoteFormat.highlight,
          value: actual == null ? richNoteHighlightColors.first : null,
        );
      });
      addFormat('Formato…', _abrirFormato);
    }
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

  /// Enter dentro de una lista: sigue la lista o la termina, como en Notas.
  void _continuarListaSiHaceFalta(String anterior) {
    final nuevo = _notesController.text;
    final sel = _notesController.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    final cursor = sel.baseOffset;
    if (nuevo.length != anterior.length + 1 ||
        cursor <= 0 ||
        cursor > nuevo.length ||
        nuevo[cursor - 1] != '\n' ||
        nuevo.replaceRange(cursor - 1, cursor, '') != anterior) {
      return;
    }
    final resultado = continuarLista(nuevo, cursor);
    if (resultado == null) return;
    _editandoListas = true;
    _notesController.aplicarEdiciones(resultado);
    _editandoListas = false;
  }

  /// Tocar la casilla de una tarea la marca o la desmarca.
  void _alTocarNotas() {
    final sel = _notesController.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    final resultado = alternarTareaEn(_notesController.text, sel.baseOffset);
    if (resultado == null) return;
    HapticFeedback.selectionClick();
    _notesController.aplicarEdiciones(resultado);
  }

  void _alternarLista(TipoLista tipo) {
    final texto = _notesController.text;
    final sel = _notesController.selection;
    final inicio = sel.isValid ? sel.start : texto.length;
    final fin = sel.isValid ? sel.end : texto.length;
    HapticFeedback.selectionClick();
    _notesController.aplicarEdiciones(alternarLista(texto, inicio, fin, tipo));
    if (!_notesFocusNode.hasFocus) _notesFocusNode.requestFocus();
  }

  void _aplicarParrafo(RichNoteParagraphStyle estilo) {
    _notesController.applyParagraphStyle(estilo);
    _notesDocument = _notesController.document;
    _scheduleSave();
    if (mounted) setState(() {});
  }

  Future<void> _abrirFormato() async {
    await mostrarHojaFormatoNota(
      context,
      theme: _theme(),
      controller: _notesController,
      acciones: AccionesFormatoNota(
        formato: (formato, {valor}) =>
            _applyNotesFormat(formato, value: valor),
        parrafo: _aplicarParrafo,
        lista: _alternarLista,
        tamano: _bumpNotesSize,
      ),
    );
    if (mounted) _notesFocusNode.requestFocus();
  }

  // ── Fotos y dibujos ────────────────────────────────────────────────────

  void _alCambiarNube() {
    if (mounted && !_cerrando) setState(() {});
  }

  /// Avisos del servicio de adjuntos (p. ej. una foto que pasa del límite).
  void _alAvisoAdjuntos() {
    final aviso = AdjuntosNotaService.I.aviso.value;
    if (aviso == null || !mounted || _cerrando) return;
    AdjuntosNotaService.I.aviso.value = null;
    _showSnack(aviso);
  }

  /// La foto o el dibujo que va dentro del texto, en el lugar de su marca.
  Widget? _construirAdjuntoEnLinea(String id) {
    for (final adjunto in _note.adjuntos) {
      if (adjunto.id == id) {
        return AdjuntoEnLinea(
          key: ValueKey('en_linea_$id'),
          theme: _theme(),
          notaId: _note.id,
          adjunto: adjunto,
          onAccion: (accion) => _accionAdjunto(adjunto, accion),
        );
      }
    }
    return null;
  }

  /// Adjuntos que no están dentro del texto (notas antiguas, o cuya marca se
  /// borró): se siguen viendo al final, como antes.
  List<AdjuntoNota> get _adjuntosAlFinal {
    final enLinea = _notesController.document.idsEnLinea.toSet();
    return [
      for (final a in _note.adjuntos)
        if (!enLinea.contains(a.id)) a,
    ];
  }

  /// Pone los adjuntos nuevos dentro del texto, donde estaba el cursor (o al
  /// final si nunca se tocó el editor), uno debajo del otro.
  void _insertarEnTexto(List<AdjuntoNota> nuevos, TextSelection cursor) {
    if (nuevos.isEmpty) return;
    if (!_notesController.selection.isValid && cursor.isValid) {
      _notesController.selection = cursor;
    }
    _editandoListas = true;
    for (final a in nuevos) {
      _notesController.insertarAdjunto(a.id);
    }
    _editandoListas = false;
    _lastNotesText = _notesController.text;
    _lastNotesSelection = _notesController.selection;
    _notesDocument = _notesController.document;
    _syncReferenceDecorations();
  }

  void _actualizarAdjuntos(List<AdjuntoNota> adjuntos) {
    setState(() => _note = _note.copyWith(adjuntos: adjuntos));
    _scheduleSave();
  }

  void _reemplazarAdjunto(AdjuntoNota nuevo) {
    _actualizarAdjuntos([
      for (final a in _note.adjuntos) a.id == nuevo.id ? nuevo : a,
    ]);
  }

  Future<void> _agregarFotos(ImageSource fuente) async {
    final cursor = _notesController.selection;
    _notesFocusNode.unfocus();
    try {
      final List<XFile> elegidas;
      if (fuente == ImageSource.camera) {
        final foto = await _picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 82,
        );
        elegidas = [?foto];
      } else {
        elegidas = await _picker.pickMultiImage(
          maxWidth: 2048,
          maxHeight: 2048,
          imageQuality: 82,
          limit: 10,
        );
      }
      if (elegidas.isEmpty || !mounted) return;
      setState(() => _agregandoAdjunto = true);
      final nuevos = <AdjuntoNota>[];
      for (final foto in elegidas) {
        final adjunto = await AdjuntosNotaService.I.agregarFoto(
          _note.id,
          await foto.readAsBytes(),
        );
        if (adjunto != null) nuevos.add(adjunto);
      }
      if (!mounted) return;
      if (nuevos.isNotEmpty) {
        _insertarEnTexto(nuevos, cursor);
        _actualizarAdjuntos([..._note.adjuntos, ...nuevos]);
        HapticFeedback.lightImpact();
      }
      if (nuevos.length < elegidas.length) {
        _showSnack('No se pudo agregar alguna foto.');
      }
    } on PlatformException catch (e) {
      _showSnack(
        e.code.contains('access_denied')
            ? 'Permite el acceso a la cámara y a las fotos en los ajustes del teléfono.'
            : 'No se pudo abrir la cámara ni las fotos.',
      );
    } finally {
      if (mounted) setState(() => _agregandoAdjunto = false);
    }
  }

  Future<void> _agregarDibujo() async {
    final cursor = _notesController.selection;
    _notesFocusNode.unfocus();
    final datos = await LienzoDibujoScreen.abrir(context);
    if (datos == null || datos.vacio || !mounted) return;
    final adjunto = await AdjuntosNotaService.I.guardarDibujo(_note.id, datos);
    if (adjunto == null || !mounted) return;
    _insertarEnTexto([adjunto], cursor);
    _actualizarAdjuntos([..._note.adjuntos, adjunto]);
  }

  Future<void> _accionAdjunto(AdjuntoNota adjunto, AccionAdjunto accion) async {
    switch (accion) {
      case AccionAdjunto.ver:
        final elegida = await VisorAdjunto.abrir(
          context,
          notaId: _note.id,
          adjunto: adjunto,
          theme: _theme(),
        );
        if (elegida != null && mounted) await _accionAdjunto(adjunto, elegida);
      case AccionAdjunto.editar:
        if (adjunto.tipo == TipoAdjunto.dibujo) {
          await _editarDibujo(adjunto);
        } else {
          await _marcarFoto(adjunto);
        }
      case AccionAdjunto.pie:
        await _editarPie(adjunto);
      case AccionAdjunto.subir || AccionAdjunto.bajar:
        // Solo entre los que se ven al final (los del texto se mueven
        // con el texto).
        final visibles = _adjuntosAlFinal;
        final k = visibles.indexWhere((a) => a.id == adjunto.id);
        final m = accion == AccionAdjunto.subir ? k - 1 : k + 1;
        if (k < 0 || m < 0 || m >= visibles.length) return;
        final otro = visibles[m];
        final lista = [..._note.adjuntos];
        final i = lista.indexWhere((a) => a.id == adjunto.id);
        final j = lista.indexWhere((a) => a.id == otro.id);
        if (i < 0 || j < 0) return;
        lista[i] = otro;
        lista[j] = adjunto;
        _actualizarAdjuntos(lista);
      case AccionAdjunto.quitar:
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: Text(
              adjunto.tipo == TipoAdjunto.foto ? '¿Quitar la foto?' : '¿Quitar el dibujo?',
            ),
            content: const Text('Se borrará de este apunte y de la nube.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Quitar'),
              ),
            ],
          ),
        );
        if (ok != true || !mounted) return;
        if (_notesController.document.embeds.contains(adjunto.id)) {
          _editandoListas = true;
          _notesController.quitarAdjunto(adjunto.id);
          _editandoListas = false;
          _lastNotesText = _notesController.text;
          _lastNotesSelection = _notesController.selection;
          _notesDocument = _notesController.document;
          _syncReferenceDecorations();
        }
        _actualizarAdjuntos([
          for (final a in _note.adjuntos)
            if (a.id != adjunto.id) a,
        ]);
        unawaited(AdjuntosNotaService.I.borrarAdjunto(_note.id, adjunto));
    }
  }

  Future<void> _editarDibujo(AdjuntoNota adjunto) async {
    final actual = await AdjuntosNotaService.I.leerDibujo(_note.id, adjunto.archivo);
    if (!mounted) return;
    final datos = await LienzoDibujoScreen.abrir(
      context,
      inicial: actual ?? const DatosDibujo(),
    );
    if (datos == null || !mounted) return;
    final nuevo = await AdjuntosNotaService.I.guardarDibujo(
      _note.id,
      datos,
      existente: adjunto,
    );
    if (nuevo != null && mounted) _reemplazarAdjunto(nuevo);
  }

  Future<void> _marcarFoto(AdjuntoNota adjunto) async {
    final contenido = await cargarAdjunto(_note.id, adjunto);
    if (!mounted) return;
    final foto = contenido.foto;
    if (foto == null) {
      _showSnack('No se pudo abrir la foto. Revisa tu conexión.');
      return;
    }
    final datos = await LienzoDibujoScreen.abrir(
      context,
      inicial: contenido.dibujo,
      foto: foto,
      titulo: 'Marcar la foto',
    );
    if (datos == null || !mounted) return;
    final nuevo = await AdjuntosNotaService.I.guardarMarcas(
      _note.id,
      adjunto,
      datos,
    );
    if (nuevo != null && mounted) _reemplazarAdjunto(nuevo);
  }

  Future<void> _editarPie(AdjuntoNota adjunto) async {
    final controller = TextEditingController(text: adjunto.pie);
    final pie = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Pie de foto'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 140,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Ej. Bosquejo del pastor'),
          onSubmitted: (v) => Navigator.pop(c, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (pie == null || !mounted) return;
    _reemplazarAdjunto(adjunto.copyWith(pie: pie.trim()));
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

  /// true desde dispose: el guardado final ya no toca el estado.
  bool _cerrando = false;

  /// Contenido del último guardado: cerrar o cambiar de versión sin editar
  /// nada ya no vuelve a escribir el apunte (ni lo sube al primer lugar de
  /// «Más recientes»).
  String? _huellaGuardada;

  Future<void> _flushNote() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    if (mounted && !_cerrando) {
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
    final sinCambios = updated.huellaContenido == _huellaGuardada;
    if (!sinCambios) _note = updated;
    if (!updated.hasContent || sinCambios) {
      if (mounted && !_cerrando) {
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
    _huellaGuardada = updated.huellaContenido;
    if (mounted && !_cerrando) {
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

  /// Guardado explicito desde el boton "Guardar" del encabezado. Ademas del
  /// autoguardado por debounce, da al usuario confirmacion visible de que su
  /// apunte quedo a salvo.
  Future<void> _saveNow() async {
    await _flushNote();
    if (!mounted) return;
    HapticFeedback.selectionClick();
    _showSnack(
      _note.hasContent ? 'Apunte guardado' : 'Escribe algo para guardar.',
    );
  }

  void _applyNotesFormat(
    RichNoteFormat format, {
    double? fontSize,
    String? value,
  }) {
    _notesController.applyFormat(format, fontSize: fontSize, value: value);
    _notesDocument = _notesController.document;
    _scheduleSave();
    if (mounted) setState(() {});
  }

  /// Aplica formato desde la barra flotante. Estilo Word: si no hay seleccion,
  /// toma automaticamente la palabra bajo el cursor para que un solo toque
  /// baste; si hay seleccion la respeta. Mantiene la seleccion visible tras
  /// aplicar (el teclado no se cierra gracias al TextFieldTapRegion de la barra).
  void _applyFloatingFormat(RichNoteFormat format, {double? fontSize}) {
    var selection = _notesController.selection;
    if (!selection.isValid) return;
    if (selection.isCollapsed) {
      final word = _wordRangeAt(_notesController.text, selection.baseOffset);
      if (word == null) {
        _showSnack('Selecciona el texto que quieres cambiar.');
        return;
      }
      selection = TextSelection(
        baseOffset: word.$1,
        extentOffset: word.$2,
      );
      _notesController.selection = selection;
    }
    _applyNotesFormat(format, fontSize: fontSize);
  }

  /// Sube o baja el tamaño de la seleccion en pasos de 2, partiendo del tamaño
  /// EFECTIVO actual (no de un valor fijo). Asi la barra "sabe" en que tamaño
  /// esta parada, como el selector de tamaño de Word.
  void _bumpNotesSize(double delta) {
    final selection = _notesController.selection;
    final current = _notesController.document
        .formatIn(
          selection.isValid ? selection.start : 0,
          selection.isValid ? selection.end : 0,
        )
        .fontSize;
    // 14 es el tamaño base del editor cuando el texto no tiene formato propio.
    final next = ((current ?? 14) + delta).clamp(10, 28).toDouble();
    _applyFloatingFormat(RichNoteFormat.size, fontSize: next);
  }

  /// Limites de la palabra (letras/numeros/acentos) alrededor de [offset].
  /// Devuelve null si el cursor no esta sobre una palabra (p. ej. un espacio).
  (int, int)? _wordRangeAt(String text, int offset) {
    if (text.isEmpty) return null;
    final wordChar = RegExp(r'[\p{L}\p{N}]', unicode: true);
    bool isWord(int index) {
      if (index < 0 || index >= text.length) return false;
      return wordChar.hasMatch(text[index]);
    }

    var start = offset.clamp(0, text.length);
    var end = start;
    while (start > 0 && isWord(start - 1)) {
      start--;
    }
    while (end < text.length && isWord(end)) {
      end++;
    }
    if (start == end) return null;
    return (start, end);
  }

  Future<void> _openAddVersesPicker() async {
    final picked = await showModalBottomSheet<StudyPickerResult>(
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
    if (picked == null || !mounted) return;
    final chapterVerses = await BibleParserService.I.getChapter(
      version: _primaryVersion,
      bookNumber: picked.bookNumber,
      chapter: picked.chapter,
    );
    if (!mounted) return;

    // Auto-agregar desde la búsqueda (un versículo), con opción de ajustar.
    if (picked.autoApply && picked.verse != null) {
      final v = picked.verse!;
      final selected = chapterVerses
          .where((verse) => verse.verse == v)
          .toList(growable: false);
      await _addVersesToCollection(selected);
      if (mounted) {
        _showSnackAction(
          'Agregado ${picked.bookName} ${picked.chapter}:$v',
          actionLabel: 'Ajustar rango',
          onAction: () => _openAddVersesRangeFor(picked, chapterVerses),
        );
      }
      return;
    }
    await _openAddVersesRangeFor(picked, chapterVerses);
  }

  Future<void> _openAddVersesRangeFor(
    StudyPickerResult picked,
    List<BibleVerse> chapterVerses,
  ) async {
    final range = await showModalBottomSheet<_VerseRangeResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseRangeSheet(
        theme: _theme(),
        verses: chapterVerses,
        title: '${picked.bookName} ${picked.chapter}',
        actionLabel: 'Agregar versículos',
        initialStart: picked.verse,
        initialEnd: picked.verseEnd ?? picked.verse,
        allowMultiSelect: true,
      ),
    );
    if (range == null) return;
    final List<BibleVerse> selected;
    if (range.verses != null && range.verses!.isNotEmpty) {
      // Selección discontinua (versículos sueltos).
      final set = range.verses!;
      selected = chapterVerses
          .where((verse) => set.contains(verse.verse))
          .toList(growable: false);
    } else {
      selected = chapterVerses
          .where(
            (verse) => verse.verse >= range.start && verse.verse <= range.end,
          )
          .toList(growable: false);
    }
    // "Agregar versiculos" agrega a la coleccion del panel izquierdo (la
    // lectura), de forma acumulativa e independiente de las Notas.
    await _addVersesToCollection(selected);
  }

  /// Agrega versiculos a la coleccion de la lectura (panel izquierdo).
  /// Acumula sin reemplazar y es independiente del texto de las Notas.
  Future<void> _addVersesToCollection(List<BibleVerse> loaded) async {
    if (loaded.isEmpty || !mounted) return;
    final verses = List<SermonVerseReference>.from(_note.verses);
    var changed = false;
    for (final verse in loaded) {
      if (verse.text.trim().isEmpty) continue;
      final saved = SermonVerseReference.fromVerse(verse);
      if (!verses.any((v) => v.key == saved.key)) {
        verses.add(saved);
        changed = true;
      }
    }
    if (!changed) {
      _showSnack('Esos versículos ya están agregados a la lectura.');
      return;
    }
    setState(() => _note = _note.copyWith(verses: verses));
    HapticFeedback.selectionClick();
    await _rebuildAddedVerses();
    _scheduleSave();
    // En vista compacta, mostrar la pestana de Lectura para que se vean.
    if (mounted) _tabController.animateTo(0);
  }

  /// Persiste en la nota los resaltados (por apunte) cuando cambian.
  void _onHighlightsChanged() {
    _note = _note.copyWith(highlights: _highlightController.value);
    if (mounted) setState(() {});
    _scheduleSave();
  }

  /// Quita un versiculo de la coleccion de la lectura.
  Future<void> _removeAddedVerse(SermonVerseReference verse) async {
    final verses = _note.verses
        .where((v) => v.key != verse.key)
        .toList(growable: false);
    setState(() => _note = _note.copyWith(verses: verses));
    HapticFeedback.selectionClick();
    await _rebuildAddedVerses();
    _scheduleSave();
  }

  /// Reconstruye las listas de versiculos agregados (primaria y secundaria)
  /// a partir de _note.verses, cargando el texto de las versiones actuales.
  Future<void> _rebuildAddedVerses() async {
    if (_note.verses.isEmpty) {
      if (mounted &&
          (_addedPrimary.isNotEmpty || _addedSecondary.isNotEmpty)) {
        setState(() {
          _addedPrimary = const [];
          _addedSecondary = const [];
        });
      }
      return;
    }
    final primary = <BibleVerse>[];
    final secondary = <BibleVerse>[];
    for (final ref in _note.verses) {
      final pv = await BibleParserService.I.getVerse(
        version: _primaryVersion,
        bookNumber: ref.bookNumber,
        chapter: ref.chapter,
        verse: ref.verse,
      );
      primary.add(
        pv ??
            BibleVerse(
              bookName: ref.bookName,
              bookNumber: ref.bookNumber,
              chapter: ref.chapter,
              verse: ref.verse,
              text: ref.text,
              version: _primaryVersion.id,
            ),
      );
      if (_secondaryVersion != _primaryVersion) {
        final sv = await BibleParserService.I.getVerse(
          version: _secondaryVersion,
          bookNumber: ref.bookNumber,
          chapter: ref.chapter,
          verse: ref.verse,
        );
        if (sv != null) secondary.add(sv);
      }
    }
    if (!mounted) return;
    setState(() {
      _addedPrimary = primary;
      _addedSecondary = secondary;
    });
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
    await _insertVersesIntoNotes(
      loaded,
      replaceRange: _expandedReferenceReplacementRange(
        _notesController.text,
        reference,
      ),
    );
  }

  TextRange _expandedReferenceReplacementRange(
    String text,
    DetectedSermonReference reference,
  ) {
    var start = reference.start.clamp(0, text.length).toInt();
    var end = reference.end.clamp(start, text.length).toInt();

    while (start > 0 && text[start - 1] == ' ') {
      start--;
    }
    while (end < text.length && text[end] == ' ') {
      end++;
    }

    final isWrappedInParentheses =
        start > 0 &&
        end < text.length &&
        text[start - 1] == '(' &&
        text[end] == ')';
    if (isWrappedInParentheses) {
      start--;
      end++;
    }

    return TextRange(start: start, end: end);
  }

  String _verseInsertionText(List<BibleVerse> loaded) {
    final buffer = StringBuffer();
    for (var i = 0; i < loaded.length; i++) {
      final verse = loaded[i];
      if (i > 0) buffer.writeln();
      buffer
        ..writeln('${verse.reference} (${_primaryVersion.shortName})')
        ..write(verse.text);
    }
    return buffer.toString();
  }

  Future<void> _insertVersesIntoNotes(
    List<BibleVerse> loaded, {
    TextRange? replaceRange,
  }) async {
    if (loaded.isEmpty || !mounted) return;
    final text = _notesController.text;
    final selection = _notesController.selection;
    final useReplacement =
        replaceRange != null &&
        replaceRange.start >= 0 &&
        replaceRange.end >= replaceRange.start &&
        replaceRange.end <= text.length;
    final start = useReplacement
        ? replaceRange.start
        : selection.isValid
        ? selection.end
        : text.length;
    final end = useReplacement ? replaceRange.end : start;
    final before = text.substring(0, start);
    final after = text.substring(end);
    var insertion = _verseInsertionText(loaded);
    if (before.isNotEmpty && !before.endsWith('\n')) {
      insertion = '\n\n$insertion';
    }
    if (after.isNotEmpty && !after.startsWith('\n')) {
      insertion = '$insertion\n\n';
    }
    final next = '$before$insertion$after';
    final nextOffset = start + insertion.length;
    setState(() {
      _notesController.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: nextOffset),
      );
    });
    for (final verse in loaded) {
      _notesInsertedKeys.add(
        '${_primaryVersion.id}:${verse.bookNumber}:${verse.chapter}:${verse.verse}',
      );
    }
    HapticFeedback.selectionClick();
    await _flushNote();
  }

  Future<void> _openTypographySheet(BibleReaderThemeData t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TypographySheet(theme: t),
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
      final highlights = _highlightController.value;
      final imagenes = await imagenesParaPdf(_note.id, _note.adjuntos);
      final File file = choice.action == _PdfExportAction.share
          ? await SermonNoteExportService.I.exportAndShareSermonNote(
              note: _note,
              chapterVerses: _verses,
              secondaryChapterVerses: _secondaryVerses,
              highlights: highlights,
              imagenes: imagenes,
              cleanCover: choice.cleanCover,
            )
          : await SermonNoteExportService.I.exportSermonNoteToPdf(
              note: _note,
              chapterVerses: _verses,
              secondaryChapterVerses: _secondaryVerses,
              highlights: highlights,
              imagenes: imagenes,
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

  void _showSnackAction(
    String text, {
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: actionLabel, onPressed: onAction),
      ),
    );
  }

  String _saveStatusLabel() {
    if (_isSaving) return 'Guardando...';
    if (_hasPendingChanges) return 'Cambios sin guardar';
    if (!_note.hasContent) return 'Borrador vacío';
    final savedAt = _lastSavedAt;
    if (savedAt == null) return 'Sin guardado reciente';
    // Sin conexión ya está a salvo en el teléfono: decirlo claro.
    final nube = NotasSync.I.estado.value;
    if (nube == EstadoNotasNube.esperandoConexion ||
        nube == EstadoNotasNube.error) {
      return etiquetaEstadoNotas(nube);
    }
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
    NotasSync.I.estado.removeListener(_alCambiarNube);
    AdjuntosNotaService.I.aviso.removeListener(_alAvisoAdjuntos);
    _saveDebounce?.cancel();
    _saveStatusTicker?.cancel();
    // El último guardado corre al cerrar: no debe redibujar la pantalla.
    _cerrando = true;
    unawaited(_flushNote());
    _titleController.dispose();
    _speakerController.dispose();
    _notesController.dispose();
    _notesFocusNode.dispose();
    _takeawayController.dispose();
    _tabController.dispose();
    _highlightController.dispose();
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
          t.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        _notesController
          ..colorMarcas = t.accent
          ..fondoOscuro = t.oscuro;
        return Scaffold(
          backgroundColor: t.pageBg,
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
                          SermonHeaderBar(
                            theme: t,
                            isWide: isWide,
                            bookName: _bookName,
                            chapter: _chapter,
                            primaryVersion: _primaryVersion,
                            secondaryVersion: _secondaryVersion,
                            readingLabel: _readingLabel(),
                            onBack: () => Navigator.maybePop(context),
                            onOpenPassagePicker: _openPassagePicker,
                            onOpenVersionPicker: _openVersionPicker,
                            onSwapVersions: _swapVersions,
                            onOpenAddVersesPicker: _openAddVersesPicker,
                            onOpenSavedNotes: _openSavedNotes,
                            onExportPdf: _exportPdf,
                            onOpenTypographySheet: _openTypographySheet,
                            onSave: _saveNow,
                          ),
                          Expanded(
                            child: isWide ? _buildSplit(t) : _buildTabbed(t),
                          ),
                          _buildFloatingFormatBar(t),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildSplit(BibleReaderThemeData t) {
    return Row(
      children: [
        Expanded(child: _buildReading(t)),
        Container(width: 1, color: t.textSecondary.withValues(alpha: 0.10)),
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

  /// Barra de formato flotante. Al ir como ultimo hijo del Column, el Scaffold
  /// (resizeToAvoidBottomInset) la empuja justo por encima del teclado. Solo se
  /// muestra cuando el editor de Notas tiene el foco.
  Widget _buildFloatingFormatBar(BibleReaderThemeData t) {
    if (!_notesFocusNode.hasFocus) return const SizedBox.shrink();
    final selection = _notesController.selection;
    final state = _notesController.document.formatIn(
      selection.isValid ? selection.start : 0,
      selection.isValid ? selection.end : 0,
    );
    return _NotesFormatBar(
      theme: t,
      state: state,
      onFormato: _abrirFormato,
      onBold: () => _applyFloatingFormat(RichNoteFormat.bold),
      onItalic: () => _applyFloatingFormat(RichNoteFormat.italic),
      onUnderline: () => _applyFloatingFormat(RichNoteFormat.underline),
      onTareas: () => _alternarLista(TipoLista.tareas),
      onVinetas: () => _alternarLista(TipoLista.vinetas),
      onCamara: () => _agregarFotos(ImageSource.camera),
      onDibujo: _agregarDibujo,
      onDismiss: _notesFocusNode.unfocus,
    );
  }

  Widget _buildReading(BibleReaderThemeData t) {
    final reading = _visibleReadingVerses(_verses);
    final readingSecondary = _visibleReadingVerses(_secondaryVerses);
    // Lectura actual + versiculos agregados (abajo), evitando duplicados.
    final seen = <String>{for (final v in reading) v.uniqueKey};
    final combined = List<BibleVerse>.from(reading);
    for (final v in _addedPrimary) {
      if (seen.add(v.uniqueKey)) combined.add(v);
    }
    final combinedSecondary = <BibleVerse>[
      ...readingSecondary,
      ..._addedSecondary,
    ];
    return StudyReadingPanel(
      theme: t,
      verses: combined,
      secondaryVerses: combinedSecondary,
      primaryVersion: _primaryVersion,
      secondaryVersion: _secondaryVersion,
      bookNumber: _bookNumber,
      chapter: _chapter,
      highlightStore: _highlightController,
    );
  }

  String _readingLabel() {
    final start = _readingStartVerse;
    final end = _readingEndVerse;
    if (start == null || end == null) return '$_bookName $_chapter';
    if (start == end) return '$_bookName $_chapter:$start';
    return '$_bookName $_chapter:$start-$end';
  }

  List<BibleVerse> _visibleReadingVerses(List<BibleVerse> source) {
    final start = _readingStartVerse;
    final end = _readingEndVerse;
    if (start == null || end == null) return source;
    final lo = start < end ? start : end;
    final hi = start < end ? end : start;
    return source
        .where((verse) => verse.verse >= lo && verse.verse <= hi)
        .toList(growable: false);
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
        if (_note.verses.isNotEmpty) ...[
          _AddedVersesCard(
            theme: t,
            verses: _note.verses,
            onRemove: _removeAddedVerse,
          ),
          const SizedBox(height: 12),
        ],
        _NotesEditorCard(
          theme: t,
          controller: _notesController,
          focusNode: _notesFocusNode,
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
          notaId: _note.id,
          adjuntos: _adjuntosAlFinal,
          agregandoAdjunto: _agregandoAdjunto,
          onTapNotas: _alTocarNotas,
          onFormato: _abrirFormato,
          onTareas: () => _alternarLista(TipoLista.tareas),
          onCamara: () => _agregarFotos(ImageSource.camera),
          onFotos: () => _agregarFotos(ImageSource.gallery),
          onDibujo: _agregarDibujo,
          onAccionAdjunto: _accionAdjunto,
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
          spellCheckConfiguration: SpellCheckConfiguration(
            spellCheckService: _spellBridge,
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
            'Apunte de predicación',
            style: AppFonts.cinzel(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          _LabeledField(
            theme: t,
            controller: titleController,
            label: 'Título',
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
                child: _SpeakerAutocompleteField(
                  theme: t,
                  controller: speakerController,
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
  final FocusNode focusNode;
  final DetectedSermonReference? activeReference;
  final SuggestionSpan? activeSuggestion;
  final int insertedVerseCount;
  final String saveStatusLabel;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final String notaId;
  final List<AdjuntoNota> adjuntos;
  final bool agregandoAdjunto;
  final VoidCallback onTapNotas;
  final VoidCallback onFormato;
  final VoidCallback onTareas;
  final VoidCallback onCamara;
  final VoidCallback onFotos;
  final VoidCallback onDibujo;
  final void Function(AdjuntoNota, AccionAdjunto) onAccionAdjunto;
  final VoidCallback? onInsertVerse;
  final VoidCallback? onIgnoreReference;
  final VoidCallback? onReplaceSuggestion;
  final VoidCallback? onIgnoreSuggestion;
  final EditableTextContextMenuBuilder contextMenuBuilder;
  final SpellCheckConfiguration spellCheckConfiguration;

  const _NotesEditorCard({
    required this.theme,
    required this.controller,
    required this.focusNode,
    required this.activeReference,
    required this.activeSuggestion,
    required this.insertedVerseCount,
    required this.saveStatusLabel,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.notaId,
    required this.adjuntos,
    required this.agregandoAdjunto,
    required this.onTapNotas,
    required this.onFormato,
    required this.onTareas,
    required this.onCamara,
    required this.onFotos,
    required this.onDibujo,
    required this.onAccionAdjunto,
    required this.onInsertVerse,
    required this.onIgnoreReference,
    required this.onReplaceSuggestion,
    required this.onIgnoreSuggestion,
    required this.contextMenuBuilder,
    required this.spellCheckConfiguration,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Notas',
                      style: AppFonts.cinzel(
                        color: t.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    _SaveStatusChip(theme: t, label: saveStatusLabel),
                  ],
                ),
              ),
              _FormatIcon(
                theme: t,
                icon: Icons.undo_rounded,
                tooltip: 'Deshacer',
                enabled: canUndo,
                onTap: onUndo,
              ),
              _FormatIcon(
                theme: t,
                icon: Icons.redo_rounded,
                tooltip: 'Rehacer',
                enabled: canRedo,
                onTap: onRedo,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Herramientas como en Notas: formato, tareas, cámara, fotos y dibujo.
          Row(
            children: [
              _HerramientaNota(theme: t, icono: Icons.text_format_rounded, texto: 'Formato', onTap: onFormato),
              _HerramientaNota(theme: t, icono: Icons.checklist_rounded, texto: 'Tareas', onTap: onTareas),
              _HerramientaNota(theme: t, icono: Icons.photo_camera_outlined, texto: 'Cámara', onTap: onCamara),
              _HerramientaNota(theme: t, icono: Icons.photo_library_outlined, texto: 'Fotos', onTap: onFotos),
              _HerramientaNota(theme: t, icono: Icons.draw_outlined, texto: 'Dibujar', onTap: onDibujo),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            focusNode: focusNode,
            maxLines: null,
            minLines: 10,
            hintLocales: const [Locale('es')],
            spellCheckConfiguration: spellCheckConfiguration,
            contextMenuBuilder: contextMenuBuilder,
            onTap: onTapNotas,
            textCapitalization: TextCapitalization.sentences,
            style: AppFonts.lora(
              color: t.textPrimary,
              fontSize: 15,
              height: 1.55,
            ),
            decoration: _inputDecoration(
              t,
              'Escribe tus apuntes. Usa Formato para títulos, listas y '
              'colores; toca una cita para agregar el versículo.',
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
          if (agregandoAdjunto) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 3,
                color: t.accent,
                backgroundColor: t.accent.withValues(alpha: 0.15),
              ),
            ),
          ],
          if (adjuntos.isNotEmpty)
            GaleriaAdjuntos(
              theme: t,
              notaId: notaId,
              adjuntos: adjuntos,
              onAccion: onAccionAdjunto,
            ),
        ],
      ),
    );
  }
}

/// Botón con ícono y texto debajo de la barra de herramientas de Notas.
/// Los cinco comparten el ancho para que quepan en un teléfono.
class _HerramientaNota extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  const _HerramientaNota({
    required this.theme,
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Semantics(
          button: true,
          label: texto,
          excludeSemantics: true,
          child: Material(
            color: t.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icono, size: 22, color: t.accent),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        texto,
                        maxLines: 1,
                        style: AppFonts.manrope(
                          color: t.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Barra de formato flotante pegada al teclado (estilo app de notas / Word).
/// Se envuelve en [TextFieldTapRegion] para que tocar sus botones NO cierre el
/// teclado ni pierda la seleccion del editor, y en un [Focus] no enfocable para
/// que el foco permanezca en el campo de Notas.
class _NotesFormatBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final RichNoteFormatState state;
  final VoidCallback onFormato;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onTareas;
  final VoidCallback onVinetas;
  final VoidCallback onCamara;
  final VoidCallback onDibujo;
  final VoidCallback onDismiss;

  const _NotesFormatBar({
    required this.theme,
    required this.state,
    required this.onFormato,
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onTareas,
    required this.onVinetas,
    required this.onCamara,
    required this.onDibujo,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    Widget separador() => Container(
      width: 1,
      height: 24,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: t.textSecondary.withValues(alpha: 0.14),
    );
    return TextFieldTapRegion(
      child: Focus(
        canRequestFocus: false,
        descendantsAreFocusable: false,
        child: Material(
          color: t.surface,
          child: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: t.textSecondary.withValues(alpha: 0.14),
                  ),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _BarButton(
                            theme: t,
                            icon: Icons.text_format_rounded,
                            tooltip: 'Formato',
                            onTap: onFormato,
                          ),
                          separador(),
                          _BarButton(
                            theme: t,
                            icon: Icons.format_bold_rounded,
                            tooltip: 'Negrita',
                            active: state.bold,
                            onTap: onBold,
                          ),
                          _BarButton(
                            theme: t,
                            icon: Icons.format_italic_rounded,
                            tooltip: 'Cursiva',
                            active: state.italic,
                            onTap: onItalic,
                          ),
                          _BarButton(
                            theme: t,
                            icon: Icons.format_underlined_rounded,
                            tooltip: 'Subrayar',
                            active: state.underline,
                            onTap: onUnderline,
                          ),
                          separador(),
                          _BarButton(
                            theme: t,
                            icon: Icons.checklist_rounded,
                            tooltip: 'Lista de tareas',
                            onTap: onTareas,
                          ),
                          _BarButton(
                            theme: t,
                            icon: Icons.format_list_bulleted_rounded,
                            tooltip: 'Viñetas',
                            onTap: onVinetas,
                          ),
                          separador(),
                          _BarButton(
                            theme: t,
                            icon: Icons.photo_camera_outlined,
                            tooltip: 'Tomar foto',
                            onTap: onCamara,
                          ),
                          _BarButton(
                            theme: t,
                            icon: Icons.draw_outlined,
                            tooltip: 'Dibujar',
                            onTap: onDibujo,
                          ),
                        ],
                      ),
                    ),
                  ),
                  separador(),
                  _BarButton(
                    theme: t,
                    icon: Icons.keyboard_hide_rounded,
                    tooltip: 'Ocultar teclado',
                    onTap: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _BarButton({
    required this.theme,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: active ? t.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: active ? t.accent : t.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AddedVersesCard extends StatefulWidget {
  final BibleReaderThemeData theme;
  final List<SermonVerseReference> verses;
  final ValueChanged<SermonVerseReference> onRemove;

  const _AddedVersesCard({
    required this.theme,
    required this.verses,
    required this.onRemove,
  });

  @override
  State<_AddedVersesCard> createState() => _AddedVersesCardState();
}

class _AddedVersesCardState extends State<_AddedVersesCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final verses = widget.verses;
    return _PanelCard(
      theme: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.library_books_outlined, color: t.accent, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Versículos agregados',
                      style: AppFonts.cinzel(
                        color: t.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${verses.length}',
                      style: AppFonts.manrope(
                        color: t.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: t.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _expanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'Aparecen en la lectura (izquierda) y en el PDF. Quitalos con la X.',
                  style: AppFonts.manrope(
                    color: t.textSecondary.withValues(alpha: 0.72),
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 10),
                for (final verse in verses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
                      decoration: BoxDecoration(
                        color: t.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: t.textSecondary.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${verse.reference} · ${verse.versionId}',
                                  style: AppFonts.manrope(
                                    color: t.accent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (verse.text.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    verse.text.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppFonts.lora(
                                      color:
                                          t.textSecondary.withValues(alpha: 0.85),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Quitar de la lectura',
                            visualDensity: VisualDensity.compact,
                            onPressed: () => widget.onRemove(verse),
                            icon: Icon(Icons.close,
                                color: t.textSecondary, size: 18),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
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
            '¿Con qué me quedo?',
            style: AppFonts.cinzel(
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
            style: AppFonts.lora(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: _inputDecoration(
              t,
              'Una idea, convicción o acción concreta.',
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
        color: t.oscuro
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.textSecondary.withValues(alpha: 0.08)),
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
      style: AppFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: _inputDecoration(t, hint).copyWith(labelText: label),
    );
  }
}

/// Campo "Predicador" con autocompletado a partir de los predicadores ya
/// usados en apuntes previos. Coincide por subcadena (insensible a
/// mayúsculas/acentos) para que escribir "Ja", "Vi" o "Pa" sugiera
/// "Pastor Victor Jabes". Así los nombres quedan homologados para filtrar
/// después sin duplicados.
class _SpeakerAutocompleteField extends StatefulWidget {
  final BibleReaderThemeData theme;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SpeakerAutocompleteField({
    required this.theme,
    required this.controller,
    required this.onChanged,
  });

  @override
  State<_SpeakerAutocompleteField> createState() =>
      _SpeakerAutocompleteFieldState();
}

class _SpeakerAutocompleteFieldState extends State<_SpeakerAutocompleteField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  /// Normaliza para comparar: minúsculas, sin acentos, sin espacios extra.
  static String _normalize(String s) {
    var r = s.toLowerCase().trim();
    const from = 'áàäâãéèëêíìïîóòöôõúùüûñ';
    const to = 'aaaaaeeeeiiiiooooouuuun';
    for (var i = 0; i < from.length; i++) {
      r = r.replaceAll(from[i], to[i]);
    }
    return r;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (TextEditingValue value) {
        final query = _normalize(value.text);
        if (query.isEmpty) return const Iterable<String>.empty();
        final all = SermonNoteService.I.speakers;
        return all.where((s) {
          final ns = _normalize(s);
          // Coincidencia por subcadena, pero ocultar el exacto ya escrito.
          return ns != query && ns.contains(query);
        });
      },
      onSelected: (selection) {
        widget.onChanged(selection);
        _focusNode.unfocus();
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: focusNode,
          onChanged: widget.onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
          textCapitalization: TextCapitalization.words,
          style: AppFonts.manrope(color: t.textPrimary, fontSize: 13),
          decoration: _inputDecoration(t, 'Pastor / maestro').copyWith(
            labelText: 'Predicador',
            suffixIcon: Icon(
              Icons.person_search_rounded,
              color: t.textSecondary.withValues(alpha: 0.6),
              size: 18,
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            color: t.surface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.person_rounded,
                              size: 16, color: t.accent),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              option,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppFonts.manrope(
                                color: t.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
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
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.12)),
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
                style: AppFonts.manrope(
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
    final color = enabled ? t.accent : t.textSecondary.withValues(alpha: 0.45);
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
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: AppFonts.manrope(
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
        color: highlight.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: highlight.withValues(alpha: 0.14),
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
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cita detectada. Puedes insertarla en tus apuntes o ignorarla.',
                  style: AppFonts.manrope(
                    color: t.textSecondary.withValues(alpha: 0.76),
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
              backgroundColor: highlight.withValues(alpha: 0.14),
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
        color: highlight.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight.withValues(alpha: 0.26)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: highlight.withValues(alpha: 0.12),
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
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sugerencia: $replacement',
                  style: AppFonts.manrope(
                    color: t.textSecondary.withValues(alpha: 0.76),
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
              backgroundColor: highlight.withValues(alpha: 0.10),
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
        color: t.background.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.textSecondary.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_outlined, color: t.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              insertedVerseCount == 0
                  ? 'Escribe una cita como «Juan 3:16» y pon el cursor encima para agregar el versículo. Las palabras dudosas se subrayan en rojo.'
                  : 'Pon el cursor sobre otra cita bíblica para agregarla sin salir de la nota.',
              style: AppFonts.manrope(
                color: t.textSecondary.withValues(alpha: 0.76),
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
        ? '1 versículo agregado a la lectura'
        : '$count versículos agregados a la lectura';
    return Row(
      children: [
        Icon(Icons.library_books_outlined, color: t.accent, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: AppFonts.manrope(
            color: t.textSecondary.withValues(alpha: 0.80),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
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
              style: AppFonts.cinzel(
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
      initialValue: value,
      items: [
        for (final version in versions)
          DropdownMenuItem(
            value: version,
            child: Text('${version.shortName} · ${version.displayName}'),
          ),
      ],
      onChanged: onChanged,
      dropdownColor: t.surface,
      style: AppFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: _inputDecoration(t, label),
    );
  }
}

class _VerseRangeResult {
  final int start;
  final int end;

  /// Versículos sueltos (selección múltiple discontinua). Cuando no es `null`,
  /// tiene prioridad sobre [start]/[end].
  final Set<int>? verses;

  const _VerseRangeResult(this.start, this.end, {this.verses});
}

class _VerseRangeSheet extends StatefulWidget {
  final BibleReaderThemeData theme;
  final List<BibleVerse> verses;
  final String title;
  final String actionLabel;

  /// Rango inicial. Si es `null`, se toma el capítulo completo
  /// (del primer al último versículo).
  final int? initialStart;
  final int? initialEnd;

  /// Habilita el modo de selección múltiple (versículos sueltos).
  final bool allowMultiSelect;

  const _VerseRangeSheet({
    required this.theme,
    required this.verses,
    required this.title,
    this.actionLabel = 'Usar pasaje',
    this.initialStart,
    this.initialEnd,
    this.allowMultiSelect = false,
  });

  @override
  State<_VerseRangeSheet> createState() => _VerseRangeSheetState();
}

class _VerseRangeSheetState extends State<_VerseRangeSheet> {
  late int _start;
  late int _end;
  bool _multiSelect = false;
  final Set<int> _selected = {};

  @override
  void initState() {
    super.initState();
    final firstVerse = widget.verses.isEmpty ? 1 : widget.verses.first.verse;
    final lastVerse = widget.verses.isEmpty ? 1 : widget.verses.last.verse;
    _start = widget.initialStart ?? firstVerse;
    _end = widget.initialEnd ?? lastVerse;
    if (_end < _start) _end = _start;
  }

  void _enterMultiSelect() {
    HapticFeedback.selectionClick();
    setState(() {
      _multiSelect = true;
      _selected
        ..clear()
        ..addAll([for (int v = _start; v <= _end; v++) v]);
    });
  }

  void _toggle(int verse) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(verse)) _selected.add(verse);
    });
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
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.allowMultiSelect && !_multiSelect)
                  TextButton.icon(
                    icon: const Icon(Icons.playlist_add, size: 16),
                    label: const Text('Sueltos'),
                    style: TextButton.styleFrom(
                      foregroundColor: t.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: Size.zero,
                      textStyle: AppFonts.manrope(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    onPressed: _enterMultiSelect,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            if (_multiSelect)
              _buildMultiSelect(t, verses)
            else
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
            Row(
              children: [
                if (_multiSelect)
                  TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: t.textSecondary,
                    ),
                    onPressed: () => setState(() {
                      _multiSelect = false;
                      _selected.clear();
                    }),
                    child: const Text('Cancelar'),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _multiSelect
                      ? (_selected.isEmpty
                            ? null
                            : () => Navigator.pop(
                                context,
                                _VerseRangeResult(
                                  0,
                                  0,
                                  verses: Set<int>.from(_selected),
                                ),
                              ))
                      : () => Navigator.pop(
                          context,
                          _VerseRangeResult(
                            _start < _end ? _start : _end,
                            _start < _end ? _end : _start,
                          ),
                        ),
                  child: Text(
                    _multiSelect
                        ? (_selected.isEmpty
                              ? 'Elige versículos'
                              : 'Agregar ${_selected.length}')
                        : widget.actionLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelect(BibleReaderThemeData t, List<int> verses) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Toca los versículos que quieras (pueden ser salteados).',
          style: AppFonts.manrope(
            color: t.textSecondary.withValues(alpha: 0.7),
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in verses)
                  _VerseChip(
                    theme: t,
                    number: v,
                    selected: _selected.contains(v),
                    onTap: () => _toggle(v),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _VerseChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final int number;
  final bool selected;
  final VoidCallback onTap;

  const _VerseChip({
    required this.theme,
    required this.number,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Material(
      color: selected
          ? t.accent
          : t.textSecondary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 38,
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: AppFonts.manrope(
              color: selected ? t.background : t.textPrimary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
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
      initialValue: value,
      items: [
        for (final verse in verses)
          DropdownMenuItem(value: verse, child: Text('v. $verse')),
      ],
      onChanged: onChanged,
      dropdownColor: t.surface,
      style: AppFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: _inputDecoration(t, label),
    );
  }
}

// ignore: unused_element
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
          style: AppFonts.manrope(color: t.textPrimary, fontSize: 14),
        ),
      ),
    );
  }
}

class _TypographySheet extends StatelessWidget {
  final BibleReaderThemeData theme;

  const _TypographySheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TEXTO Y COLORES',
              style: AppFonts.manrope(
                color: t.textSecondary.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<double>(
              valueListenable: BibleUserDataService.I.fontSizeNotifier,
              builder: (_, size, _) {
                return Row(
                  children: [
                    Text(
                      'A',
                      style: AppFonts.lora(
                        color: t.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: size,
                        min: 14,
                        max: 28,
                        divisions: 7,
                        activeColor: t.accent,
                        inactiveColor: t.textSecondary.withValues(alpha: 0.2),
                        onChanged: (v) => BibleUserDataService.I.setFontSize(v),
                      ),
                    ),
                    Text(
                      'A',
                      style: AppFonts.lora(
                        color: t.textSecondary,
                        fontSize: 26,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'TEMA',
              style: AppFonts.manrope(
                color: t.textSecondary.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            // Claro, oscuro o automático: va en el papel de la app.
            const SelectorModoPapel(),
          ],
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
                  color: t.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exportar PDF',
              style: AppFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Elige si quieres una portada más limpia para compartir o guardar.',
              style: AppFonts.manrope(
                color: t.textSecondary.withValues(alpha: 0.66),
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
              activeThumbColor: t.accent,
              title: Text(
                'Portada limpia',
                style: AppFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Reduce adornos y deja un encabezado más sobrio.',
                style: AppFonts.manrope(
                  color: t.textSecondary.withValues(alpha: 0.64),
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
          color: t.background.withValues(alpha: 0.58),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.12),
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
                    style: AppFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.manrope(
                      color: t.textSecondary.withValues(alpha: 0.65),
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
    hintStyle: AppFonts.manrope(
      color: t.textSecondary.withValues(alpha: 0.45),
      fontSize: 13,
    ),
    labelStyle: AppFonts.manrope(color: t.textSecondary, fontSize: 12),
    filled: true,
    fillColor: t.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: t.textSecondary.withValues(alpha: 0.10)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: t.textSecondary.withValues(alpha: 0.10)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide(color: t.accent.withValues(alpha: 0.55)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
  );
}

String _formatDate(DateTime date) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
