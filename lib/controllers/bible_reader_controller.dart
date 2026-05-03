import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bible/bible_book.dart';
import '../models/bible/bible_version.dart';
import '../services/bible/bible_parser_service.dart';
import '../services/bible/bible_reading_stats_service.dart';
import '../services/bible/bible_user_data_service.dart';
import '../services/bible/book_intro_service.dart';
import '../services/bible/gospel_harmony_service.dart';
import '../services/bible/ot_quotes_service.dart';
import '../services/user_pref_cloud_sync_service.dart';

// Re-export mixins & shared types for callers that import from here
export 'bible_reader/reader_state.dart' show StudyItemType, StudyItem;
export 'bible_reader/selection_mixin.dart';
export 'bible_reader/audio_mixin.dart';
export 'bible_reader/search_mixin.dart';
export 'bible_reader/study_mixin.dart';

import 'bible_reader/reader_state.dart';
import 'bible_reader/selection_mixin.dart';
import 'bible_reader/audio_mixin.dart';
import 'bible_reader/search_mixin.dart';
import 'bible_reader/study_mixin.dart';

/// Controlador principal del lector bíblico.
/// La lógica está organizada en mixins por responsabilidad:
///   - [SelectionMixin] — selección de versículos y multi-select
///   - [AudioMixin]     — audio real + TTS fallback
///   - [SearchMixin]    — búsqueda dentro del capítulo
///   - [StudyMixin]     — modo estudio Guzik (Enduring Word)
class BibleReaderController extends ReaderState
    with SelectionMixin, AudioMixin, SearchMixin, StudyMixin {
  @override
  final int bookNumber;
  @override
  final String bookName;
  @override
  BibleVersion currentVersion;
  @override
  int currentChapter;

  BibleReaderController({
    required this.bookNumber,
    required this.bookName,
    required int chapter,
    required BibleVersion version,
  }) : currentChapter = chapter,
       currentVersion = version {
    redLettersEnabled = BibleUserDataService.I.redLettersEnabledNotifier.value;
    BibleUserDataService.I.redLettersEnabledNotifier.addListener(_onRedLetterChanged);
    loadChapter();
    SharedPreferences.getInstance()
        .then((prefs) {
          final enabled = prefs.getBool('bible_study_mode_enabled') ?? false;
          if (enabled) {
            setStudyModeEnabled(true);
            notifyListeners();
            loadGuzikCommentary();
          }
        })
        .catchError((e) {
          debugPrint('⚠️ [BibleReader] Error cargando prefs: $e');
        });
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SCROLL / HEADER
  // ═══════════════════════════════════════════════════════════════════════

  double _lastScrollOffset = 0;

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
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════

  @override
  void dispose() {
    disposeAudio();
    BibleUserDataService.I.redLettersEnabledNotifier.removeListener(_onRedLetterChanged);
    super.dispose();
  }

  void _onRedLetterChanged() {
    redLettersEnabled = BibleUserDataService.I.redLettersEnabledNotifier.value;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // CHAPTER LOADING
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> loadChapter() async {
    debugPrint('🟢 [BibleReader] loadChapter start: book=$bookNumber ch=$currentChapter');
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
      debugPrint('🟢 [BibleReader] verses loaded: ${verses.length}');

      // Load chapter intro
      BookIntroService.instance
          .getChapterIntro(bookNumber, currentChapter)
          .then((intro) {
            chapterIntro = intro;
            notifyListeners();
          })
          .catchError((e) {
            debugPrint('⚠️ [BibleReader] Error cargando intro: $e');
          });

      _loadConnectionIndicators();

      // Precache adjacent chapters
      if (currentChapter < totalChapters) {
        unawaited(
          BibleParserService.I.getChapter(
            version: currentVersion,
            bookNumber: bookNumber,
            chapter: currentChapter + 1,
          ),
        );
      }
      if (currentChapter > 1) {
        unawaited(
          BibleParserService.I.getChapter(
            version: currentVersion,
            bookNumber: bookNumber,
            chapter: currentChapter - 1,
          ),
        );
      }

      // Re-run search if active
      if (showSearch && searchQuery.length >= 2) {
        runInReaderSearch(searchQuery);
      }

      // Log chapter read
      BibleReadingStatsService.I.logChapterRead(bookNumber: bookNumber, chapter: currentChapter);
      debugPrint('🟢 [BibleReader] after logChapterRead');

      // Persist last-read position
      SharedPreferences.getInstance()
          .then((prefs) async {
            await Future.wait([
              prefs.setInt('lastReadBookNumber', bookNumber),
              prefs.setString('lastReadBookName', bookName),
              prefs.setInt('lastReadChapter', currentChapter),
            ]);
            UserPrefCloudSyncService.I.markDirty();
          })
          .catchError((e) {
            debugPrint('⚠️ [BibleReader] Error guardando posición: $e');
          });

      // Reload commentary if study mode active
      if (studyModeEnabled) {
        loadGuzikCommentary();
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
  // BIBLICAL CONNECTIONS
  // ═══════════════════════════════════════════════════════════════════════

  Future<void> _loadConnectionIndicators() async {
    final book = bookNumber;
    final ch = currentChapter;
    final newHarmony = <int>{};
    final newQuotes = <int>{};

    try {
      if (book >= 40 && book <= 43) {
        final sections = await GospelHarmonyService.instance.getSectionsForReference(book, ch);
        for (final _ in sections) {
          newHarmony.add(1);
        }
      }

      final ntQuotes = await OTQuotesService.instance.getForNTReference(book, ch);
      for (final q in ntQuotes) {
        final v = _parseVerseFromOsis(q.ntReference);
        if (v != null) newQuotes.add(v);
      }
      final otQuotes = await OTQuotesService.instance.getForOTReference(book, ch);
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
