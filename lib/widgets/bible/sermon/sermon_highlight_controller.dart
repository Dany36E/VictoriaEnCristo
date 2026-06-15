import 'package:flutter/foundation.dart';

import '../../../models/bible/study_word_highlight.dart';
import '../reading_highlight_store.dart';

/// Almacen de resaltados POR APUNTE para el Modo Predicacion.
///
/// Mantiene los resaltados en memoria (notificados al panel de lectura) y avisa
/// con [onChanged] para que la pantalla los persista en la `SermonNote`. Es
/// totalmente independiente del almacen global del Modo Estudio: un apunte nuevo
/// empieza limpio y cada apunte conserva sus propios resaltados.
class SermonHighlightController implements ReadingHighlightStore {
  SermonHighlightController({required this.onChanged});

  final VoidCallback onChanged;

  final ValueNotifier<List<StudyWordHighlight>> _highlights =
      ValueNotifier(const []);
  final ValueNotifier<bool> _canUndo = ValueNotifier(false);
  final ValueNotifier<bool> _canRedo = ValueNotifier(false);
  final List<List<StudyWordHighlight>> _undoStack = [];
  final List<List<StudyWordHighlight>> _redoStack = [];
  int _idCounter = 0;

  @override
  ValueListenable<List<StudyWordHighlight>> get highlightsListenable =>
      _highlights;
  @override
  ValueListenable<bool> get canUndoListenable => _canUndo;
  @override
  ValueListenable<bool> get canRedoListenable => _canRedo;

  List<StudyWordHighlight> get value => _highlights.value;

  /// Carga los resaltados guardados al abrir un apunte. No registra historial.
  void seed(List<StudyWordHighlight> highlights) {
    _idCounter = highlights.length;
    _highlights.value = List.unmodifiable(highlights);
    _undoStack.clear();
    _redoStack.clear();
    _updateHistory();
  }

  String _nextId() =>
      'sh_${DateTime.now().microsecondsSinceEpoch}_${_idCounter++}';

  void _remember() {
    _undoStack.add(List<StudyWordHighlight>.from(_highlights.value));
    if (_undoStack.length > 50) _undoStack.removeAt(0);
    _redoStack.clear();
    _updateHistory();
  }

  void _updateHistory() {
    _canUndo.value = _undoStack.isNotEmpty;
    _canRedo.value = _redoStack.isNotEmpty;
  }

  void _commit(List<StudyWordHighlight> next) {
    _highlights.value = List.unmodifiable(next);
    onChanged();
  }

  @override
  Future<void> addHighlight({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required int startWord,
    required int endWord,
    required StudyHighlightCode code,
  }) async {
    if (endWord <= startWord) return;
    _remember();
    _commit([
      ..._highlights.value,
      StudyWordHighlight(
        id: _nextId(),
        versionId: versionId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        startWord: startWord,
        endWord: endWord,
        code: code.key,
        createdAt: DateTime.now(),
      ),
    ]);
  }

  @override
  Future<void> clearRange({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required int startWord,
    required int endWord,
  }) async {
    if (endWord <= startWord) return;
    final current = _highlights.value;
    final affected = current
        .where(
          (h) =>
              h.versionId == versionId &&
              h.bookNumber == bookNumber &&
              h.chapter == chapter &&
              h.verse == verse &&
              h.overlapsRange(startWord, endWord),
        )
        .toList(growable: false);
    if (affected.isEmpty) return;
    _remember();
    // Conserva las partes del resaltado que quedan fuera del rango borrado.
    final replacements = <StudyWordHighlight>[];
    for (final h in affected) {
      if (h.startWord < startWord) {
        replacements.add(h.copyWith(id: _nextId(), endWord: startWord));
      }
      if (endWord < h.endWord) {
        replacements.add(h.copyWith(id: _nextId(), startWord: endWord));
      }
    }
    final affectedIds = affected.map((h) => h.id).toSet();
    _commit([
      for (final h in current)
        if (!affectedIds.contains(h.id)) h,
      ...replacements,
    ]);
  }

  @override
  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    _redoStack.add(List<StudyWordHighlight>.from(_highlights.value));
    final previous = _undoStack.removeLast();
    _updateHistory();
    _commit(previous);
  }

  @override
  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    _undoStack.add(List<StudyWordHighlight>.from(_highlights.value));
    final next = _redoStack.removeLast();
    _updateHistory();
    _commit(next);
  }

  void dispose() {
    _highlights.dispose();
    _canUndo.dispose();
    _canRedo.dispose();
  }
}
