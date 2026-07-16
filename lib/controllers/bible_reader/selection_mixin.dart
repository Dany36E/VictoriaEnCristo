import 'package:flutter/services.dart';
import '../../models/bible/study_word_highlight.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/recent_colors_service.dart';
import '../../services/bible/study_mode_service.dart';
import 'reader_state.dart';

/// Gestión de selección de versículos.
///
/// Modelo unificado (estilo YouVersion): cada tap agrega o quita el
/// versículo del set de selección. No existe un "modo multi-selección"
/// aparte — con un versículo o con diez, la interacción es la misma y la
/// barra compacta de acciones aparece mientras haya algo seleccionado.
mixin SelectionMixin on ReaderState {
  void tapVerse(int index) {
    final verse = verses[index];
    if (selectedVerseNumbers.contains(verse.verse)) {
      selectedVerseNumbers.remove(verse.verse);
    } else {
      HapticFeedback.lightImpact();
      selectedVerseNumbers.add(verse.verse);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (selectedVerseNumbers.isEmpty) return;
    selectedVerseNumbers.clear();
    notifyListeners();
  }

  /// Alias histórico; ambos limpian la selección completa.
  void exitSelectionMode() => clearSelection();

  // ── Acciones sobre la selección ──

  void applyColorToSelected(String hex) {
    RecentColorsService.I.addRecentColor(hex);
    final data = BibleUserDataService.I;
    for (final verseNum in selectedVerseNumbers) {
      data.addHighlight(
        versionId: currentVersion.id,
        bookNumber: bookNumber,
        chapter: currentChapter,
        verse: verseNum,
        colorHex: hex,
      );
    }
    HapticFeedback.lightImpact();
    clearSelection();
  }

  void removeHighlightFromSelected() {
    final data = BibleUserDataService.I;
    for (final verseNum in selectedVerseNumbers) {
      data.removeHighlight(
        currentVersion.id,
        bookNumber,
        currentChapter,
        verseNum,
      );
    }
    HapticFeedback.lightImpact();
    clearSelection();
  }

  /// ¿Algún versículo seleccionado ya tiene subrayado? (para mostrar la
  /// opción de quitar color en la barra.)
  bool get selectionHasHighlight {
    final highlights = BibleUserDataService.I.highlightsNotifier.value;
    for (final verseNum in selectedVerseNumbers) {
      final v = verses.where((v) => v.verse == verseNum).firstOrNull;
      if (v != null && highlights.containsKey(v.fullKey)) return true;
    }
    return false;
  }

  /// Referencia legible de la selección, p. ej. "Génesis 1:3" o
  /// "Génesis 1:3-5" (rango) o "Génesis 1:3,7" (no contiguos).
  String get selectionReference {
    final sorted = selectedVerseNumbers.toList()..sort();
    if (sorted.isEmpty) return '';
    if (sorted.length == 1) {
      return '$bookName $currentChapter:${sorted.first}';
    }
    final contiguous =
        sorted.last - sorted.first == sorted.length - 1;
    if (contiguous) {
      return '$bookName $currentChapter:${sorted.first}-${sorted.last}';
    }
    return '$bookName $currentChapter:${sorted.join(',')}';
  }

  String buildSelectedVersesText() {
    final sorted = selectedVerseNumbers.toList()..sort();
    if (sorted.isEmpty) return '';
    final buf = StringBuffer();
    for (final num in sorted) {
      final v = verses.where((v) => v.verse == num).firstOrNull;
      if (v != null) buf.write('$num ${v.text} ');
    }
    buf.write('\n— $selectionReference (${currentVersion.shortName})');
    return buf.toString().trim();
  }

  void copyAllSelected() {
    Clipboard.setData(ClipboardData(text: buildSelectedVersesText()));
    HapticFeedback.lightImpact();
    clearSelection();
  }

  void toggleSavedForSelected() {
    final data = BibleUserDataService.I;
    for (final verseNum in selectedVerseNumbers) {
      final v = verses.where((v) => v.verse == verseNum).firstOrNull;
      if (v == null) continue;
      data.toggleSavedVerse(
        bookNumber: v.bookNumber,
        chapter: v.chapter,
        verse: v.verse,
        bookName: v.bookName,
        text: v.text,
        version: v.version,
      );
    }
    HapticFeedback.lightImpact();
    clearSelection();
  }

  // ── Selección palabra por palabra ─────────────────────────────────────
  // Reutiliza StudyWordHighlight (mismo subrayado granular que Modo Estudio),
  // pero accesible directo desde la lectura normal.

  /// Divide el texto de un versículo en tokens (índices de palabra) igual que
  /// el Modo Estudio, para que los índices [startWord, endWord) coincidan.
  List<String> _tokensFor(int verseNumber) {
    final v = verses.where((v) => v.verse == verseNumber).firstOrNull;
    if (v == null) return const [];
    return v.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  }

  /// Entra al modo palabra para un versículo concreto. Limpia la selección
  /// de versículos completos para no mezclar barras.
  void enterWordSelection(int verseNumber) {
    selectedVerseNumbers.clear();
    wordSelectionVerse = verseNumber;
    selectedWords.clear();
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  /// Atajo desde la barra de versículo: pasa el primer versículo seleccionado
  /// a modo palabra.
  void enterWordSelectionFromSelection() {
    if (selectedVerseNumbers.isEmpty) return;
    final first = (selectedVerseNumbers.toList()..sort()).first;
    enterWordSelection(first);
  }

  void toggleWord(int wordIndex) {
    if (selectedWords.contains(wordIndex)) {
      selectedWords.remove(wordIndex);
    } else {
      selectedWords.add(wordIndex);
    }
    HapticFeedback.selectionClick();
    notifyListeners();
  }

  void exitWordSelection() {
    if (wordSelectionVerse == null) return;
    wordSelectionVerse = null;
    selectedWords.clear();
    notifyListeners();
  }

  /// Agrupa los índices seleccionados en tramos contiguos y crea un
  /// StudyWordHighlight por cada tramo con el color elegido.
  Future<void> applyWordColor(StudyHighlightCode code) async {
    final verseNum = wordSelectionVerse;
    if (verseNum == null || selectedWords.isEmpty) return;

    final sorted = selectedWords.toList()..sort();
    final runs = <List<int>>[]; // cada run = [startWord, endWordExclusivo)
    int runStart = sorted.first;
    int prev = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i] == prev + 1) {
        prev = sorted[i];
      } else {
        runs.add([runStart, prev + 1]);
        runStart = sorted[i];
        prev = sorted[i];
      }
    }
    runs.add([runStart, prev + 1]);

    for (final run in runs) {
      await StudyModeService.I.addHighlight(
        versionId: currentVersion.id,
        bookNumber: bookNumber,
        chapter: currentChapter,
        verse: verseNum,
        startWord: run[0],
        endWord: run[1],
        code: code,
      );
    }
    HapticFeedback.lightImpact();
    exitWordSelection();
  }

  /// Quita todos los subrayados de palabra del versículo en modo palabra.
  Future<void> clearWordHighlightsForCurrent() async {
    final verseNum = wordSelectionVerse;
    if (verseNum == null) return;
    await StudyModeService.I.clearVerseHighlights(
      currentVersion.id,
      bookNumber,
      currentChapter,
      verseNum,
    );
    HapticFeedback.lightImpact();
    exitWordSelection();
  }

  /// ¿El versículo en modo palabra ya tiene algún subrayado granular?
  bool get currentWordVerseHasHighlights {
    final verseNum = wordSelectionVerse;
    if (verseNum == null) return false;
    return StudyModeService.I
        .highlightsForVerse(
          currentVersion.id,
          bookNumber,
          currentChapter,
          verseNum,
        )
        .isNotEmpty;
  }

  /// Cantidad de tokens del versículo activo (para "seleccionar todo").
  int get currentWordVerseTokenCount =>
      wordSelectionVerse == null ? 0 : _tokensFor(wordSelectionVerse!).length;

  void selectAllWords() {
    final n = currentWordVerseTokenCount;
    if (n == 0) return;
    selectedWords
      ..clear()
      ..addAll(List.generate(n, (i) => i));
    notifyListeners();
  }
}
