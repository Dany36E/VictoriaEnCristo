import 'package:flutter/foundation.dart';

import '../../models/bible/study_word_highlight.dart';

/// Abstraccion del almacen de resaltados que consume [StudyReadingPanel].
///
/// Permite que el Modo Estudio use el almacen global ([StudyModeService]) y que
/// el Modo Predicacion use uno propio por apunte ([SermonHighlightController]),
/// sin que el panel de lectura conozca la implementacion concreta.
abstract class ReadingHighlightStore {
  ValueListenable<List<StudyWordHighlight>> get highlightsListenable;
  ValueListenable<bool> get canUndoListenable;
  ValueListenable<bool> get canRedoListenable;

  Future<void> addHighlight({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required int startWord,
    required int endWord,
    required StudyHighlightCode code,
  });

  Future<void> clearRange({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required int startWord,
    required int endWord,
  });

  Future<void> undo();
  Future<void> redo();
}
