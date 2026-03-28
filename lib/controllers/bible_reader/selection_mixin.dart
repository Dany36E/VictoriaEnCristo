import 'package:flutter/services.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/recent_colors_service.dart';
import 'reader_state.dart';

/// Gestión de selección de versículos (tap, long-press, multi-select).
mixin SelectionMixin on ReaderState {
  // ── Single select ──

  void tapVerse(int index) {
    final verse = verses[index];
    if (isSelectionMode) {
      if (selectedVerseNumbers.contains(verse.verse)) {
        selectedVerseNumbers.remove(verse.verse);
        if (selectedVerseNumbers.isEmpty) isSelectionMode = false;
      } else {
        selectedVerseNumbers.add(verse.verse);
      }
    } else if (selectedVerseIndex == index) {
      HapticFeedback.lightImpact();
      isSelectionMode = true;
      selectedVerseNumbers.add(verse.verse);
      selectedVerseIndex = null;
    } else {
      selectedVerseIndex = index;
    }
    notifyListeners();
  }

  void longPressVerse(int index) {
    if (!isSelectionMode) {
      HapticFeedback.mediumImpact();
      isSelectionMode = true;
      selectedVerseNumbers.add(verses[index].verse);
      selectedVerseIndex = null;
      notifyListeners();
    }
  }

  void clearSelection() {
    selectedVerseIndex = null;
    notifyListeners();
  }

  void exitSelectionMode() {
    isSelectionMode = false;
    selectedVerseNumbers.clear();
    notifyListeners();
  }

  // ── Multi-select actions ──

  void setMultiSelectShowColors(bool value) {
    multiSelectShowColors = value;
    notifyListeners();
  }

  void applyColorToSelected(String hex) {
    RecentColorsService.I.addRecentColor(hex);
    final data = BibleUserDataService.I;
    for (final verseNum in selectedVerseNumbers) {
      data.addHighlight(
        bookNumber: bookNumber,
        chapter: currentChapter,
        verse: verseNum,
        colorHex: hex,
      );
    }
    multiSelectShowColors = false;
    exitSelectionMode();
  }

  String buildSelectedVersesText() {
    final sorted = selectedVerseNumbers.toList()..sort();
    if (sorted.isEmpty) return '';
    final buf = StringBuffer();
    for (final num in sorted) {
      final v = verses.where((v) => v.verse == num).firstOrNull;
      if (v != null) buf.write('$num ${v.text} ');
    }
    final first = sorted.first;
    final last = sorted.last;
    final ref = first == last
        ? '$bookName $currentChapter:$first'
        : '$bookName $currentChapter:$first-$last';
    buf.write('\n— $ref (${currentVersion.shortName})');
    return buf.toString().trim();
  }

  void copyAllSelected() {
    Clipboard.setData(ClipboardData(text: buildSelectedVersesText()));
    HapticFeedback.lightImpact();
    exitSelectionMode();
  }
}
