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
import '../services/bible/reading_history_service.dart';

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
    int? initialVerse,
    bool highlightInitialVerse = true,
  }) : currentChapter = chapter,
       currentVersion = version,
       _requestedVerse = initialVerse,
       _requestedFlash = highlightInitialVerse {
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
  // DESTINO DE SCROLL (versículo pedido / posición recordada)
  // ═══════════════════════════════════════════════════════════════════════

  /// Versículo pedido explícitamente por quien abrió el capítulo (búsqueda,
  /// guardados, historial…). Se resalta brevemente al llegar.
  int? _requestedVerse;
  bool _requestedFlash;

  /// Versículo al que la pantalla debe desplazarse tras cargar el capítulo
  /// (null = arriba). La pantalla lo consume con [takePendingScroll].
  int? _pendingScrollVerse;
  bool _pendingFlash = false;

  /// Se incrementa cada vez que termina de cargar un capítulo.
  int loadGeneration = 0;

  /// Versículo resaltado un instante tras navegar a él.
  final ValueNotifier<int?> flashVerse = ValueNotifier(null);
  Timer? _flashTimer;

  /// Error al cargar la versión/capítulo (null = sin error).
  String? loadError;

  /// Devuelve y limpia el destino pendiente: (versículo, resaltar).
  ({int verse, bool flash})? takePendingScroll() {
    final v = _pendingScrollVerse;
    if (v == null) return null;
    _pendingScrollVerse = null;
    final flash = _pendingFlash;
    _pendingFlash = false;
    return (verse: v, flash: flash);
  }

  void flash(int verse) {
    _flashTimer?.cancel();
    flashVerse.value = verse;
    _flashTimer = Timer(const Duration(milliseconds: 1800), () {
      flashVerse.value = null;
    });
  }

  /// Guarda el versículo visible como punto de lectura de este capítulo.
  void reportVisibleVerse(int verse) {
    if (loading || verses.isEmpty) return;
    ReadingHistoryService.I.updatePosition(
      bookNumber: bookNumber,
      bookName: bookName,
      chapter: currentChapter,
      versionId: currentVersion.id,
      verse: verse,
    );
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
    _flashTimer?.cancel();
    flashVerse.dispose();
    unawaited(ReadingHistoryService.I.flush());
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
    // Detiene el audio del capítulo anterior (y recuerda si debe seguir).
    audioBeforeChapterChange();
    loading = true;
    loadError = null;
    selectedVerseNumbers.clear();
    wordSelectionVerse = null;
    selectedWords.clear();
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

      if (loadedVerses.isEmpty) {
        throw StateError('Capítulo vacío: $bookNumber:$currentChapter');
      }

      // Destino: el versículo pedido o, si no, donde se quedó la persona.
      await ReadingHistoryService.I.ensureLoaded();
      final requested = _requestedVerse;
      _requestedVerse = null;
      final remembered = ReadingHistoryService.I.positionFor(
        currentVersion.id,
        bookNumber,
        currentChapter,
      );
      final lastVerse = loadedVerses.last.verse;
      final target = requested ?? remembered;
      _pendingScrollVerse = (target != null && target > 1)
          ? target.clamp(1, lastVerse)
          : null;
      _pendingFlash = requested != null && _requestedFlash;
      _requestedFlash = true;

      verses = loadedVerses;
      loading = false;
      headerOpacity = 1.0;
      loadGeneration++;
      notifyListeners();
      // Continúa la lectura en voz alta si venía sonando / auto-avance.
      audioAfterChapterLoaded();
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

      // Historial + «Continuar leyendo» (con versículo y versión).
      unawaited(
        ReadingHistoryService.I.recordVisit(
          bookNumber: bookNumber,
          bookName: bookName,
          chapter: currentChapter,
          versionId: currentVersion.id,
          verse: (requested ?? remembered ?? 1).clamp(1, lastVerse),
        ),
      );

      // Reload commentary if study mode active
      if (studyModeEnabled) {
        loadGuzikCommentary();
      }
    } catch (e, st) {
      debugPrint('[BibleReader] Error en loadChapter: $e');
      debugPrint(st.toString());
      loading = false;
      verses = [];
      loadError = e is StateError && '$e'.contains('requiere descarga')
          ? 'Esta versión necesita descargarse antes de leerla.'
          : 'No se pudo cargar ${currentVersion.shortName}.';
      notifyListeners();
    }
  }

  /// Va a [chapter] del libro actual; [verse] = versículo a mostrar.
  void goToChapter(int chapter, {int? verse}) {
    if (chapter < 1 || chapter > totalChapters) return;
    currentChapter = chapter;
    _requestedVerse = verse;
    _requestedFlash = true;
    loadChapter();
  }

  /// Avanza al capítulo siguiente del libro. Devuelve false si era el último
  /// (la pantalla abre entonces el libro siguiente). El capítulo terminado
  /// olvida su posición para empezar arriba la próxima vez.
  bool goToNextChapter() {
    ReadingHistoryService.I.clearPosition(
      currentVersion.id,
      bookNumber,
      currentChapter,
    );
    if (currentChapter >= totalChapters) return false;
    goToChapter(currentChapter + 1);
    return true;
  }

  /// Retrocede un capítulo. Devuelve false si estaba en el capítulo 1 (la
  /// pantalla abre entonces el último capítulo del libro anterior).
  bool goToPreviousChapter() {
    if (currentChapter <= 1) return false;
    goToChapter(currentChapter - 1);
    return true;
  }

  BibleBook? getNextBook() {
    if (allBooks.isEmpty) return null;
    final idx = allBooks.indexWhere((b) => b.number == bookNumber);
    if (idx < 0 || idx >= allBooks.length - 1) return null;
    return allBooks[idx + 1];
  }

  BibleBook? getPreviousBook() {
    if (allBooks.isEmpty) return null;
    final idx = allBooks.indexWhere((b) => b.number == bookNumber);
    if (idx <= 0) return null;
    return allBooks[idx - 1];
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

  /// Cambia a la versión preferida conservando el versículo [keepVerse]
  /// (el que se estaba leyendo), sin resaltarlo.
  void onVersionChanged({int? keepVerse}) {
    currentVersion = BibleUserDataService.I.preferredVersionNotifier.value;
    _requestedVerse = keepVerse;
    _requestedFlash = false;
    loadChapter();
  }
}
