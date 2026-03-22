import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bible/bible_book.dart';
import '../models/bible/bible_verse.dart';
import '../models/bible/bible_version.dart';
import '../services/bible/bible_parser_service.dart';
import '../services/bible/bible_reading_stats_service.dart';
import '../services/bible/bible_search_service.dart';
import '../services/bible/bible_audio_service.dart';
import '../services/bible/bible_tts_service.dart';
import '../services/bible/bible_user_data_service.dart';
import '../services/audio_engine.dart';
import '../services/bible/recent_colors_service.dart';
import '../services/bible/enduring_word_service.dart';
import '../services/bible/book_intro_service.dart';
import '../services/bible/gospel_harmony_service.dart';
import '../services/bible/ot_quotes_service.dart';

// Study mode item types for verse/annotation interleaving
enum StudyItemType { banner, verse, annotation, attribution }

class StudyItem {
  final StudyItemType type;
  final int index;
  const StudyItem(this.type, [this.index = -1]);
}

class BibleReaderController extends ChangeNotifier {
  final int bookNumber;
  final String bookName;
  BibleVersion currentVersion;
  int currentChapter;

  BibleReaderController({
    required this.bookNumber,
    required this.bookName,
    required int chapter,
    required BibleVersion version,
  })  : currentChapter = chapter,
        currentVersion = version {
    _redLettersEnabled = BibleUserDataService.I.redLettersEnabledNotifier.value;
    BibleUserDataService.I.redLettersEnabledNotifier.addListener(_onRedLetterChanged);
    loadChapter();
    SharedPreferences.getInstance().then((prefs) {
      final enabled = prefs.getBool('bible_study_mode_enabled') ?? false;
      if (enabled) {
        _studyModeEnabled = true;
        notifyListeners();
        _loadGuzikCommentary();
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STATE
  // ═══════════════════════════════════════════════════════════════════════

  List<BibleVerse> verses = [];
  bool loading = true;
  int totalChapters = 1;
  List<BibleBook> allBooks = [];

  // UI state
  int? selectedVerseIndex;
  double headerOpacity = 1.0;
  double _lastScrollOffset = 0;
  bool showTypography = false;

  // Multi-select
  bool isSelectionMode = false;
  final Set<int> selectedVerseNumbers = {};
  bool multiSelectShowColors = false;

  void setMultiSelectShowColors(bool value) {
    multiSelectShowColors = value;
    notifyListeners();
  }

  // Search
  bool showSearch = false;
  String searchQuery = '';
  List<int> searchMatchIndices = [];
  int currentMatchIndex = -1;

  // Audio (real + TTS)
  bool ttsActive = false;
  bool realAudioActive = false;
  bool _audioListenerAttached = false;

  // Red letters
  bool _redLettersEnabled = true;
  bool get redLettersEnabled => _redLettersEnabled;

  // Chapter intro
  String? chapterIntro;

  // Biblical connection indicators
  Set<int> harmonyVerses = {};
  Set<int> quoteVerses = {};

  // Study mode (Guzik)
  bool _studyModeEnabled = false;
  bool get studyModeEnabled => _studyModeEnabled;
  EWChapterCommentary? guzikChapter;
  List<StudyItem> studyItems = [];
  final Set<int> collapsedSections = {};

  // ═══════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════

  /// True si cualquier audio está activo (real o TTS).
  bool get isAnyAudioActive => ttsActive || realAudioActive;

  @override
  void dispose() {
    BibleTtsService.I.stop();
    BibleAudioService.I.stop();
    _detachAudioListener();
    BibleUserDataService.I.redLettersEnabledNotifier.removeListener(_onRedLetterChanged);
    super.dispose();
  }

  void _attachAudioListener() {
    if (_audioListenerAttached) return;
    BibleAudioService.I.state.addListener(_onRealAudioStateChanged);
    _audioListenerAttached = true;
  }

  void _detachAudioListener() {
    if (!_audioListenerAttached) return;
    BibleAudioService.I.state.removeListener(_onRealAudioStateChanged);
    _audioListenerAttached = false;
  }

  void _onRedLetterChanged() {
    _redLettersEnabled = BibleUserDataService.I.redLettersEnabledNotifier.value;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SCROLL HEADER
  // ═══════════════════════════════════════════════════════════════════════

  void onScroll(double offset) {
    final delta = offset - _lastScrollOffset;
    _lastScrollOffset = offset;

    double newOpacity = headerOpacity;
    if (delta > 0 && offset > 20) {
      newOpacity = (headerOpacity - 0.08).clamp(0.0, 1.0);
    } else if (delta < -2) {
      newOpacity = (headerOpacity + 0.12).clamp(0.0, 1.0);
    }

    if (newOpacity != headerOpacity) {
      headerOpacity = newOpacity;
      notifyListeners();
    }
  }

  void toggleHeaderOpacity() {
    headerOpacity = headerOpacity > 0.5 ? 0.0 : 1.0;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CHAPTER LOADING
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> loadChapter() async {
    loading = true;
    selectedVerseIndex = null;
    isSelectionMode = false;
    multiSelectShowColors = false;
    selectedVerseNumbers.clear();
    searchMatchIndices = [];
    currentMatchIndex = -1;
    guzikChapter = null;
    studyItems = [];
    collapsedSections.clear();
    notifyListeners();

    try {
      final books = await BibleParserService.I.getBooks(currentVersion);
      allBooks = books;
      final book = books.where((b) => b.number == bookNumber).firstOrNull;
      if (book != null) totalChapters = book.totalChapters;

      final loadedVerses = await BibleParserService.I.getChapter(
        version: currentVersion,
        bookNumber: bookNumber,
        chapter: currentChapter,
      );

      verses = loadedVerses;
      loading = false;
      headerOpacity = 1.0;
      notifyListeners();

      // Load chapter intro
      BookIntroService.instance
          .getChapterIntro(bookNumber, currentChapter)
          .then((intro) {
        chapterIntro = intro;
        notifyListeners();
      });

      _loadConnectionIndicators();

      // Precache adjacent chapters
      if (currentChapter < totalChapters) {
        unawaited(BibleParserService.I.getChapter(
          version: currentVersion,
          bookNumber: bookNumber,
          chapter: currentChapter + 1,
        ));
      }
      if (currentChapter > 1) {
        unawaited(BibleParserService.I.getChapter(
          version: currentVersion,
          bookNumber: bookNumber,
          chapter: currentChapter - 1,
        ));
      }

      // Re-run search if active
      if (showSearch && searchQuery.length >= 2) {
        runInReaderSearch(searchQuery);
      }

      // Log chapter read
      BibleReadingStatsService.I.logChapterRead(
        bookNumber: bookNumber,
        chapter: currentChapter,
      );

      // Persist last-read position
      SharedPreferences.getInstance().then((prefs) {
        prefs.setInt('lastReadBookNumber', bookNumber);
        prefs.setString('lastReadBookName', bookName);
        prefs.setInt('lastReadChapter', currentChapter);
      });

      // Reload commentary if study mode active
      if (_studyModeEnabled) {
        _loadGuzikCommentary();
      }
    } catch (e, st) {
      debugPrint('[BibleReader] Error en loadChapter: $e');
      debugPrint(st.toString());
      loading = false;
      verses = [];
      notifyListeners();
    }
  }

  void goToChapter(int chapter) {
    if (chapter < 1 || chapter > totalChapters) return;
    currentChapter = chapter;
    loadChapter();
  }

  BibleBook? getNextBook() {
    if (allBooks.isEmpty) return null;
    final idx = allBooks.indexWhere((b) => b.number == bookNumber);
    if (idx < 0 || idx >= allBooks.length - 1) return null;
    return allBooks[idx + 1];
  }

  // ═══════════════════════════════════════════════════════════════════════
  // VERSE SELECTION
  // ═══════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════
  // MULTI-SELECT ACTIONS
  // ═══════════════════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════════════════
  // SEARCH
  // ═══════════════════════════════════════════════════════════════════════

  void runInReaderSearch(String query) {
    searchQuery = query;
    searchMatchIndices = [];
    currentMatchIndex = -1;

    if (query.trim().length < 2) {
      notifyListeners();
      return;
    }

    final normalizedQuery = BibleSearchService.normalize(query);
    final matches = <int>[];
    for (int i = 0; i < verses.length; i++) {
      if (BibleSearchService.normalize(verses[i].text)
          .contains(normalizedQuery)) {
        matches.add(i);
      }
    }
    searchMatchIndices = matches;
    currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    notifyListeners();
  }

  void goToMatch(int matchIdx) {
    if (matchIdx < 0 || matchIdx >= searchMatchIndices.length) return;
    currentMatchIndex = matchIdx;
    notifyListeners();
  }

  void closeSearch() {
    showSearch = false;
    searchQuery = '';
    searchMatchIndices = [];
    currentMatchIndex = -1;
    notifyListeners();
  }

  void toggleSearch() {
    showSearch = !showSearch;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TTS
  // ═══════════════════════════════════════════════════════════════════════

  /// Toggle audio: detiene si está activo, o inicia (real → TTS fallback).
  Future<void> toggleTts({TtsReadMode? mode}) async {
    // Si audio real activo, detener
    if (realAudioActive) {
      await BibleAudioService.I.stop();
      realAudioActive = false;
      notifyListeners();
      return;
    }
    // Si TTS activo, detener
    if (ttsActive) {
      BibleTtsService.I.stop();
      ttsActive = false;
      notifyListeners();
      return;
    }

    // Si modo estudio con Guzik y se pide modo específico → TTS directo
    if (mode != null) {
      // Asegurar que guzikChapter esté cargado si se necesita
      if (mode != TtsReadMode.verseOnly &&
          studyModeEnabled && guzikChapter == null) {
        await _loadGuzikCommentary();
      }
      _startTtsWithMode(mode);
      return;
    }

    // Pausar BGM
    final engine = AudioEngine.I;
    if (engine.bgmState.value == BgmPlaybackState.playing) {
      await engine.pauseBgm();
    }

    // Intentar audio real primero
    final success = await BibleAudioService.I.playChapter(
      bookNumber: bookNumber,
      chapter: currentChapter,
    );

    if (success) {
      realAudioActive = true;
      ttsActive = true; // Para UI compatibility
      notifyListeners();
      // Escuchar cuando termina
      _attachAudioListener();
    } else {
      // Fallback a TTS
      debugPrint('[Audio] No real audio available, using TTS fallback');
      BibleTtsService.I.startReading(verses);
      ttsActive = true;
      notifyListeners();
    }
  }

  void _onRealAudioStateChanged() {
    if (BibleAudioService.I.state.value == AudioBibleState.idle &&
        realAudioActive) {
      realAudioActive = false;
      ttsActive = false;
      _detachAudioListener();
      notifyListeners();
    }
  }

  /// Detiene todo audio (real y TTS).
  Future<void> stopAllAudio() async {
    if (realAudioActive) {
      await BibleAudioService.I.stop();
      _detachAudioListener();
      realAudioActive = false;
    }
    BibleTtsService.I.stop();
    ttsActive = false;
    notifyListeners();
  }

  void _startTtsWithMode(TtsReadMode mode) {
    final queue = _buildTtsQueue(mode);
    BibleTtsService.I.startReadingQueue(queue, mode: mode);
    ttsActive = true;
    notifyListeners();
  }

  List<TtsQueueItem> _buildTtsQueue(TtsReadMode mode) {
    final queue = <TtsQueueItem>[];

    if (mode == TtsReadMode.verseOnly || guzikChapter == null) {
      for (int i = 0; i < verses.length; i++) {
        queue.add(TtsQueueItem(verses[i].text.trim(), i));
      }
    } else if (mode == TtsReadMode.annotationOnly) {
      for (final section in guzikChapter!.sections) {
        _addSectionToQueue(queue, section);
      }
    } else {
      // both: interleave using studyItems
      for (final item in studyItems) {
        switch (item.type) {
          case StudyItemType.verse:
            final v = verses[item.index];
            queue.add(TtsQueueItem(v.text.trim(), item.index));
          case StudyItemType.annotation:
            final section = guzikChapter!.sections[item.index];
            _addSectionToQueue(queue, section);
          case StudyItemType.banner:
          case StudyItemType.attribution:
            break;
        }
      }
    }

    return queue;
  }

  /// Agrega una sección Guzik a la cola TTS como items individuales
  /// por párrafo (evita textos > 4000 chars que fallan en Samsung TTS).
  void _addSectionToQueue(List<TtsQueueItem> queue, EWSection section) {
    if (section.heading.isNotEmpty) {
      queue.add(TtsQueueItem(section.heading, -1));
    }
    for (final paragraph in section.paragraphs) {
      final trimmed = paragraph.trim();
      if (trimmed.isEmpty) continue;
      // Seguridad extra: partir párrafos muy largos en oraciones
      if (trimmed.length > 3000) {
        final chunks = _splitLongText(trimmed, 2500);
        for (final chunk in chunks) {
          queue.add(TtsQueueItem(chunk, -1));
        }
      } else {
        queue.add(TtsQueueItem(trimmed, -1));
      }
    }
  }

  /// Parte texto largo en chunks por punto+espacio, respetando maxLen.
  static List<String> _splitLongText(String text, int maxLen) {
    final chunks = <String>[];
    var remaining = text;
    while (remaining.length > maxLen) {
      var splitAt = remaining.lastIndexOf('. ', maxLen);
      if (splitAt <= 0) splitAt = remaining.lastIndexOf(' ', maxLen);
      if (splitAt <= 0) splitAt = maxLen;
      chunks.add(remaining.substring(0, splitAt + 1).trim());
      remaining = remaining.substring(splitAt + 1).trim();
    }
    if (remaining.isNotEmpty) chunks.add(remaining);
    return chunks;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY
  // ═══════════════════════════════════════════════════════════════════════

  void toggleTypography() {
    showTypography = !showTypography;
    notifyListeners();
  }

  void closeTypography() {
    showTypography = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STUDY MODE (Guzik)
  // ═══════════════════════════════════════════════════════════════════════

  void toggleStudyMode() {
    final wasEnabled = _studyModeEnabled;
    _studyModeEnabled = !wasEnabled;
    if (!_studyModeEnabled) {
      studyItems = [];
    } else if (guzikChapter != null) {
      _buildStudyItems();
    }
    notifyListeners();

    if (_studyModeEnabled && guzikChapter == null) {
      _loadGuzikCommentary();
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('bible_study_mode_enabled', _studyModeEnabled);
    });
  }

  Future<void> _loadGuzikCommentary() async {
    final commentary = await EnduringWordService.instance
        .getChapterCommentary(bookNumber, currentChapter);
    if (commentary == null || commentary.isEmpty) {
      guzikChapter = null;
      studyItems = [];
      _studyModeEnabled = false;
      notifyListeners();
      SharedPreferences.getInstance().then((prefs) {
        prefs.setBool('bible_study_mode_enabled', false);
      });
      return;
    }
    guzikChapter = commentary;
    collapsedSections.clear();
    _buildStudyItems();
    notifyListeners();
  }

  /// Returns true if no Guzik commentary was available (for snackbar).
  bool get guzikUnavailable =>
      _studyModeEnabled == false && guzikChapter == null && studyItems.isEmpty;

  static final _verseRangeRegex = RegExp(r'\((\d+)(?:\s*-\s*(\d+))?\)');

  void _buildStudyItems() {
    if (!_studyModeEnabled || guzikChapter == null ||
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

  // ═══════════════════════════════════════════════════════════════════════
  // BIBLICAL CONNECTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _loadConnectionIndicators() async {
    final book = bookNumber;
    final ch = currentChapter;
    final newHarmony = <int>{};
    final newQuotes = <int>{};

    try {
      if (book >= 40 && book <= 43) {
        final sections = await GospelHarmonyService.instance
            .getSectionsForReference(book, ch);
        for (final _ in sections) {
          newHarmony.add(1);
        }
      }

      final ntQuotes =
          await OTQuotesService.instance.getForNTReference(book, ch);
      for (final q in ntQuotes) {
        final v = _parseVerseFromOsis(q.ntReference);
        if (v != null) newQuotes.add(v);
      }
      final otQuotes =
          await OTQuotesService.instance.getForOTReference(book, ch);
      for (final q in otQuotes) {
        final v = _parseVerseFromOsis(q.otReference);
        if (v != null) newQuotes.add(v);
      }
    } catch (e) {
      debugPrint('[BibleReader] _loadConnectionIndicators error: $e');
    }

    harmonyVerses = newHarmony;
    quoteVerses = newQuotes;
    notifyListeners();
  }

  int? _parseVerseFromOsis(String osis) {
    final parts = osis.split('.');
    if (parts.length >= 3) return int.tryParse(parts[2]);
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // VERSION
  // ═══════════════════════════════════════════════════════════════════════

  void onVersionChanged() {
    currentVersion = BibleUserDataService.I.preferredVersionNotifier.value;
    loadChapter();
  }
}
