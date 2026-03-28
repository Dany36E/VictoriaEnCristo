import 'package:shared_preferences/shared_preferences.dart';
import '../../services/bible/enduring_word_service.dart';
import 'reader_state.dart';

/// Modo de estudio Guzik (Enduring Word) con interleaving de anotaciones.
mixin StudyMixin on ReaderState {
  static final _verseRangeRegex = RegExp(r'\((\d+)(?:\s*-\s*(\d+))?\)');

  void toggleStudyMode() {
    final wasEnabled = studyModeEnabled;
    setStudyModeEnabled(!wasEnabled);
    if (!studyModeEnabled) {
      studyItems = [];
    } else if (guzikChapter != null) {
      buildStudyItems();
    }
    notifyListeners();

    if (studyModeEnabled && guzikChapter == null) {
      loadGuzikCommentary();
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('bible_study_mode_enabled', studyModeEnabled);
    });
  }

  @override
  Future<void> loadGuzikCommentary() async {
    final commentary = await EnduringWordService.instance
        .getChapterCommentary(bookNumber, currentChapter);
    if (commentary == null || commentary.isEmpty) {
      guzikChapter = null;
      studyItems = [];
      setStudyModeEnabled(false);
      notifyListeners();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('bible_study_mode_enabled', false);
      });
      return;
    }
    guzikChapter = commentary;
    collapsedSections.clear();
    buildStudyItems();
    notifyListeners();
  }

  /// Returns true if no Guzik commentary was available.
  bool get guzikUnavailable =>
      !studyModeEnabled && guzikChapter == null && studyItems.isEmpty;

  @override
  void buildStudyItems() {
    if (!studyModeEnabled || guzikChapter == null ||
        guzikChapter!.isEmpty || verses.isEmpty) {
      studyItems = [];
      return;
    }

    final items = <StudyItem>[];
    final afterVerse = <int, List<int>>{};
    final introSections = <int>[];

    for (int i = 0; i < guzikChapter!.sections.length; i++) {
      final heading = guzikChapter!.sections[i].heading;
      final match = _verseRangeRegex.firstMatch(heading);
      if (match != null) {
        final end = match.group(2) != null
            ? int.parse(match.group(2)!)
            : int.parse(match.group(1)!);
        afterVerse.putIfAbsent(end, () => []).add(i);
      } else {
        introSections.add(i);
      }
    }

    items.add(const StudyItem(StudyItemType.banner));
    for (final si in introSections) {
      items.add(StudyItem(StudyItemType.annotation, si));
    }

    final lastVerseNum = verses.last.verse;
    for (int vi = 0; vi < verses.length; vi++) {
      items.add(StudyItem(StudyItemType.verse, vi));
      final vn = verses[vi].verse;
      if (afterVerse.containsKey(vn)) {
        for (final si in afterVerse[vn]!) {
          items.add(StudyItem(StudyItemType.annotation, si));
        }
      }
    }

    for (final entry in afterVerse.entries) {
      if (entry.key > lastVerseNum) {
        for (final si in entry.value) {
          items.add(StudyItem(StudyItemType.annotation, si));
        }
      }
    }

    items.add(const StudyItem(StudyItemType.attribution));
    studyItems = items;
  }

  void toggleAnnotationCollapse(int sectionIndex) {
    if (collapsedSections.contains(sectionIndex)) {
      collapsedSections.remove(sectionIndex);
    } else {
      collapsedSections.add(sectionIndex);
    }
    notifyListeners();
  }
}
