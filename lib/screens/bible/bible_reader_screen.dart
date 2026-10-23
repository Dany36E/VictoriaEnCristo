import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../controllers/bible_reader_controller.dart';
import '../../models/bible/bible_version.dart';
import '../../services/audio_engine.dart';
import '../../services/bible/bible_tts_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/audio_player_bar.dart';
import '../../widgets/bible/contextual_header.dart';
import '../../widgets/bible/version_selector_sheet.dart';
import '../../widgets/bible/reader/reader_search_overlay.dart';
import '../../widgets/bible/reader/reader_typography_panel.dart';
import '../../widgets/bible/reader/reader_chapter_selector.dart';
import '../../widgets/bible/reader/reader_content_view.dart';
import '../../widgets/bible/reader/reader_toolbar_overlay.dart';
import '../../widgets/bible/reader/reader_verse_locator.dart';
import '../../widgets/bible/reader/version_copyright.dart';
import 'reading_history_screen.dart';
import 'bible_parallel_screen.dart';
import 'chapter_selector_screen.dart';
import 'book_introduction_screen.dart';

class BibleReaderScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleVersion version;
  /// Versículo al que se lleva el lector al abrir (exacto).
  final int? initialVerse;

  /// Resaltar un instante [initialVerse] al llegar. «Continuar leyendo» lo
  /// desactiva: solo devuelve a la persona a donde iba.
  final bool highlightInitialVerse;

  const BibleReaderScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.version,
    this.initialVerse,
    this.highlightInitialVerse = true,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  late final BibleReaderController _ctrl;
  // keepScrollOffset: false → al cambiar de capítulo no se «restaura» el
  // desplazamiento del anterior; la posición la decide el controlador.
  final _scrollController = ScrollController(keepScrollOffset: false);
  final _locator = ReaderVerseLocator();
  int _handledLoadGeneration = 0;
  Timer? _visibleVerseDebounce;
  bool _programmaticScroll = false;

  /// Alto de la cabecera flotante que tapa el inicio del texto.
  static const double _headerInset = 64;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  late PageController _pageController;
  bool _pageAnimating = false;

  @override
  void initState() {
    super.initState();
    debugPrint('🟢 [BibleReader] initState start');
    // ensureStudyMode inicializa también StudyModeService: así los subrayados
    // palabra-por-palabra se ven Y se pueden crear desde la lectura normal.
    unawaited(UserScopedServices.I.ensureStudyMode());
    AudioEngine.I.switchBgmContext(BgmContext.bible);
    debugPrint('🟢 [BibleReader] after switchBgmContext');
    _ctrl = BibleReaderController(
      bookNumber: widget.bookNumber,
      bookName: widget.bookName,
      chapter: widget.chapter,
      version: widget.version,
      initialVerse: widget.initialVerse,
      highlightInitialVerse: widget.highlightInitialVerse,
    );
    debugPrint('🟢 [BibleReader] after controller create');
    _ctrl.addListener(_onControllerChanged);
    _scrollController.addListener(_onScroll);
    _pageController = PageController(
      initialPage: 1, // center page = current chapter
      viewportFraction: 0.92,
    );
    _ctrl.audioVerseIndex.addListener(_onTtsVerseChanged);
    _ctrl.onAudioChapterFinished = _onAudioChapterFinished;
    debugPrint('🟢 [BibleReader] initState end');
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    if (!_ctrl.loading && _ctrl.loadGeneration != _handledLoadGeneration) {
      _handledLoadGeneration = _ctrl.loadGeneration;
      WidgetsBinding.instance.addPostFrameCallback((_) => _applyPendingScroll());
    }
  }

  /// Tras cargar un capítulo: ir al versículo pedido (con resalte) o a donde
  /// se quedó la persona; si no hay ninguno, al inicio.
  Future<void> _applyPendingScroll() async {
    if (!mounted || !_scrollController.hasClients) return;
    final pending = _ctrl.takePendingScroll();
    if (pending == null) {
      _scrollController.jumpTo(0);
      return;
    }
    _programmaticScroll = true;
    try {
      await _locator.scrollToVerse(
        _scrollController,
        pending.verse,
        topInset: _headerInset,
        duration: pending.flash
            ? const Duration(milliseconds: 450)
            : Duration.zero,
      );
    } finally {
      _programmaticScroll = false;
    }
    if (!mounted) return;
    if (pending.flash) _ctrl.flash(pending.verse);
    _reportVisibleVerse();
  }

  void _onScroll() {
    _ctrl.onScroll(_scrollController.offset);
    if (_programmaticScroll) return;
    _visibleVerseDebounce?.cancel();
    _visibleVerseDebounce = Timer(
      const Duration(milliseconds: 600),
      _reportVisibleVerse,
    );
  }

  /// Recuerda el versículo visible para «Continuar leyendo» y para reabrir
  /// el capítulo en el mismo punto.
  void _reportVisibleVerse() {
    if (!mounted || _ctrl.loading) return;
    final verse = _locator.firstVisibleVerse(
      _scrollController,
      topInset: _headerInset,
    );
    if (verse != null) _ctrl.reportVisibleVerse(verse);
  }

  void _onVersionChanged() {
    _ctrl.onVersionChanged(
      keepVerse: _locator.firstVisibleVerse(
        _scrollController,
        topInset: _headerInset,
      ),
    );
  }

  /// Al terminar el audio de un capítulo (auto-avance activado): pasa al
  /// siguiente capítulo o libro. false = fin de la Biblia.
  bool _onAudioChapterFinished() {
    if (_ctrl.goToNextChapter()) return true;
    final next = _ctrl.getNextBook();
    if (next == null) return false;
    _goToBook(next.number, next.name, 1);
    return true;
  }

  /// Número de versículo (no índice) para un índice de la lista cargada.
  int? _verseNumberAt(int index) =>
      index >= 0 && index < _ctrl.verses.length
      ? _ctrl.verses[index].verse
      : null;

  void _onTtsVerseChanged() {
    final verse = _ctrl.audioVerseNumber.value;
    if (verse == null || !_scrollController.hasClients) return;
    _locator.scrollToVerse(
      _scrollController,
      verse,
      topInset: _headerInset + 40, // deja ver la barra de audio
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _visibleVerseDebounce?.cancel();
    _reportVisibleVerse();
    _ctrl.audioVerseIndex.removeListener(_onTtsVerseChanged);
    _ctrl.onAudioChapterFinished = null;
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToBook(int bookNumber, String bookName, int chapter, [int? verse]) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) => BibleReaderScreen(
          bookNumber: bookNumber,
          bookName: bookName,
          chapter: chapter,
          version: _ctrl.currentVersion,
          initialVerse: verse,
        ),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (ctx, a, sa, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _goToNextBook() {
    final next = _ctrl.getNextBook();
    if (next == null) return;
    _goToBook(next.number, next.name, 1);
  }

  /// Último capítulo del libro anterior (desde el capítulo 1).
  void _goToPreviousBook() {
    final prev = _ctrl.getPreviousBook();
    if (prev == null) return;
    _goToBook(prev.number, prev.name, prev.totalChapters);
  }

  void _goToNext() {
    if (!_ctrl.goToNextChapter()) _goToNextBook();
  }

  void _goToPrevious() {
    if (!_ctrl.goToPreviousChapter()) _goToPreviousBook();
  }

  void _openChapterSelector() {
    final book = _ctrl.allBooks
        .where((b) => b.number == widget.bookNumber)
        .firstOrNull;
    if (book == null) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) =>
            ChapterSelectorScreen(book: book, version: _ctrl.currentVersion),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (ctx, a, sa, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _scrollToMatch(int matchIdx) {
    if (matchIdx < 0 || matchIdx >= _ctrl.searchMatchIndices.length) return;
    final verse = _verseNumberAt(_ctrl.searchMatchIndices[matchIdx]);
    if (verse == null) return;
    _locator.scrollToVerse(
      _scrollController,
      verse,
      topInset: _headerInset + 72, // debajo de la barra de búsqueda
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
        SystemChrome.setSystemUIOverlayStyle(
          t.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        return Scaffold(
          backgroundColor: t.pageBg,
          body: GestureDetector(
            onTap: () {
              if (_ctrl.inWordSelection) {
                _ctrl.exitWordSelection();
              } else if (_ctrl.hasSelection) {
                _ctrl.clearSelection();
              } else if (_ctrl.showTypography) {
                _ctrl.closeTypography();
              } else {
                _ctrl.toggleHeaderOpacity();
              }
            },
            child: SafeArea(
              child: Stack(
                children: [
                  _ctrl.loading
                      ? Center(
                          child: CircularProgressIndicator(
                            color: t.accent,
                            strokeWidth: 1.5,
                          ),
                        )
                      : _ctrl.loadError != null
                      ? _buildLoadError(t)
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: 3, // prev | current | next
                          onPageChanged: (page) {
                            if (_pageAnimating) return;
                            _pageAnimating = true;
                            if (page == 0) {
                              _goToPrevious();
                            } else if (page == 2) {
                              _goToNext();
                            }
                            // Reset to center page after navigation
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (_pageController.hasClients) {
                                _pageController.jumpToPage(1);
                              }
                              _pageAnimating = false;
                            });
                            // Safety timeout: nunca bloquear swipe > 2s
                            Future.delayed(const Duration(seconds: 2), () {
                              if (_pageAnimating) _pageAnimating = false;
                            });
                          },
                          itemBuilder: (context, pageIndex) {
                            if (pageIndex != 1) {
                              // Peek page - show faded label
                              final isPrev = pageIndex == 0;
                              final label = isPrev
                                  ? (_ctrl.currentChapter > 1
                                        ? 'Cap. ${_ctrl.currentChapter - 1}'
                                        : (_ctrl.getPreviousBook() != null
                                              ? 'Libro anterior'
                                              : ''))
                                  : (_ctrl.currentChapter < _ctrl.totalChapters
                                        ? 'Cap. ${_ctrl.currentChapter + 1}'
                                        : (_ctrl.getNextBook() != null
                                              ? 'Siguiente libro'
                                              : ''));
                              return Center(
                                child: Text(
                                  label,
                                  style: AppFonts.manrope(
                                    color: t.textoTenue(0.3),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            // Current chapter page
                            return ReaderContentView(
                              theme: t,
                              controller: _ctrl,
                              scrollController: _scrollController,
                              locator: _locator,
                              onGoToPrevious: _goToPrevious,
                              onGoToNext: _goToNext,
                              onBottomNavBookTap: (_, _, _) =>
                                  _openChapterSelector(),
                            );
                          },
                        ),
                  if (!_ctrl.loading && _ctrl.loadError == null)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        ignoring: _ctrl.headerOpacity < 0.1,
                        child: AnimatedOpacity(
                          opacity: _ctrl.headerOpacity,
                          duration: const Duration(milliseconds: 100),
                          child: _buildHeader(t),
                        ),
                      ),
                    ),
                  if (_ctrl.showTypography) ...[
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: _ctrl.closeTypography,
                        behavior: HitTestBehavior.opaque,
                        child: const ColoredBox(color: Colors.transparent),
                      ),
                    ),
                    ReaderTypographyPanel(
                      theme: t,
                      onClose: _ctrl.closeTypography,
                    ),
                  ],
                  if (_ctrl.showSearch)
                    ReaderSearchOverlay(
                      theme: t,
                      controller: _ctrl,
                      searchController: _searchController,
                      searchFocusNode: _searchFocusNode,
                      onScrollToMatch: _scrollToMatch,
                    ),
                  if (_ctrl.ttsActive && !_ctrl.loading)
                    Positioned(
                      top: 44,
                      left: 0,
                      right: 0,
                      child: AudioPlayerBar(
                        theme: t,
                        bookChapter:
                            '${widget.bookName} ${_ctrl.currentChapter}',
                        isRealAudio: _ctrl.realAudioActive,
                        verseNumber: _ctrl.audioVerseNumber,
                        onPlayPause: _ctrl.toggleAudioPause,
                        onClose: () => setState(() => _ctrl.stopAllAudio()),
                      ),
                    ),
                  if (_ctrl.isSelecting && !_ctrl.loading)
                    ReaderToolbarOverlay(
                      theme: t,
                      controller: _ctrl,
                      onShare: () {
                        Share.share(_ctrl.buildSelectedVersesText());
                        _ctrl.clearSelection();
                      },
                    ),
                  // Navegador de capítulo fijo abajo (‹ Libro Cap › + audio),
                  // estilo YouVersion. Se oculta durante la selección de
                  // versículos/palabras para no chocar con la barra de
                  // selección, que usa la misma posición (bottom: 16).
                  if (!_ctrl.loading &&
                      _ctrl.loadError == null &&
                      !_ctrl.isSelecting)
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: _buildChapterNavigator(t),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Estado de error al cargar la versión o el capítulo (antes: pantalla en
  /// blanco). Permite reintentar o elegir otra versión.
  Widget _buildLoadError(BibleReaderThemeData t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.menu_book_outlined, size: 48, color: t.accent),
            const SizedBox(height: 16),
            Text(
              '${widget.bookName} ${_ctrl.currentChapter}',
              textAlign: TextAlign.center,
              style: AppFonts.lora(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _ctrl.loadError ?? '',
              textAlign: TextAlign.center,
              style: AppFonts.manrope(color: t.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _ctrl.loadChapter,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.sobreAcento,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => showVersionSelectorSheet(
                    context,
                    onChanged: _onVersionChanged,
                  ),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('Cambiar versión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: t.textPrimary,
                    minimumSize: const Size(48, 48),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.maybePop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: t.textSecondary,
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Text('Volver'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Barra flotante fija abajo: ▶ audio | ‹ | Libro Cap (tap → selector) | ›.
  /// Reemplaza al indicador "peek" anterior (texto tenue no interactivo) por
  /// un control real y descubrible, como el navegador inferior de YouVersion.
  Widget _buildChapterNavigator(BibleReaderThemeData t) {
    final hasPrev = _ctrl.currentChapter > 1 || _ctrl.getPreviousBook() != null;
    final hasNext =
        _ctrl.currentChapter < _ctrl.totalChapters ||
        _ctrl.getNextBook() != null;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildNavPlayButton(t),
            const SizedBox(width: 2),
            _buildNavArrow(
              t,
              Icons.chevron_left,
              hasPrev,
              _goToPrevious,
              'Capítulo anterior',
            ),
            GestureDetector(
              onTap: () => showBookChapterSelector(
                context,
                _ctrl,
                onGoToBook: _goToBook,
                onGoToChapter: _ctrl.goToChapter,
              ),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  '${widget.bookName} ${_ctrl.currentChapter}',
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _buildNavArrow(
              t,
              Icons.chevron_right,
              hasNext,
              _goToNext,
              'Capítulo siguiente',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavArrow(
    BibleReaderThemeData t,
    IconData icon,
    bool enabled,
    VoidCallback onTap,
    String label,
  ) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          // 22 + 2×13 = 48 px de área táctil.
          padding: const EdgeInsets.all(13),
          child: Icon(
            icon,
            size: 22,
            color: enabled
                ? t.textSecondary
                : t.textSecondary.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }

  Widget _buildNavPlayButton(BibleReaderThemeData t) {
    return Semantics(
      button: true,
      label: _ctrl.ttsActive ? 'Detener audio' : 'Reproducir audio',
      child: GestureDetector(
        onTap: () => _handleAudioTap(t),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
          child: Icon(
            _ctrl.ttsActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
            color: t.sobreAcento,
            size: 20,
          ),
        ),
      ),
    );
  }

  /// Lógica compartida del botón de audio (header y navegador inferior).
  void _handleAudioTap(BibleReaderThemeData t) {
    if (_ctrl.ttsActive) {
      _ctrl.toggleTts();
    } else if (_ctrl.studyModeEnabled && _ctrl.guzikChapter != null) {
      _showAudioModeSelector(t);
    } else {
      _ctrl.toggleTts();
    }
  }

  void _showAudioModeSelector(BibleReaderThemeData t) {
    showModalBottomSheet(
      context: context,
      backgroundColor: t.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Modo de lectura',
                style: AppFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              _buildModeOption(
                ctx,
                t,
                TtsReadMode.verseOnly,
                Icons.menu_book_outlined,
                'Solo versículos',
                'Lee solo el texto bíblico',
              ),
              _buildModeOption(
                ctx,
                t,
                TtsReadMode.both,
                Icons.auto_stories,
                'Versículos + Comentario',
                'Alterna texto bíblico con comentario Guzik',
              ),
              _buildModeOption(
                ctx,
                t,
                TtsReadMode.annotationOnly,
                Icons.article_outlined,
                'Solo comentario',
                'Lee solo el comentario de David Guzik',
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModeOption(
    BuildContext ctx,
    BibleReaderThemeData t,
    TtsReadMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    return ListTile(
      leading: Icon(icon, color: t.accent),
      title: Text(
        title,
        style: AppFonts.manrope(
          color: t.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppFonts.manrope(color: t.textSecondary, fontSize: 12),
      ),
      onTap: () {
        Navigator.pop(ctx);
        _ctrl.toggleTts(mode: mode);
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    return ContextualHeader(
      title: '${widget.bookName} ${_ctrl.currentChapter}',
      theme: t,
      onBack: () => Navigator.pop(context),
      onTitleTap: () => showBookChapterSelector(
        context,
        _ctrl,
        onGoToBook: _goToBook,
        onGoToChapter: _ctrl.goToChapter,
      ),
      versionLabel: _ctrl.currentVersion.shortName,
      onVersionTap: () => showVersionSelectorSheet(
        context,
        onChanged: _onVersionChanged,
      ),
      onTypographyTap: _ctrl.toggleTypography,
      typographyActive: _ctrl.showTypography,
      contextualActions: [
        ContextualAction(
          icon: _ctrl.studyModeEnabled
              ? Icons.auto_stories
              : Icons.auto_stories_outlined,
          label: 'Estudio',
          isActive: _ctrl.studyModeEnabled,
          onTap: _ctrl.toggleStudyMode,
        ),
        ContextualAction(
          icon: _ctrl.ttsActive
              ? Icons.stop_rounded
              : Icons.headphones_outlined,
          label: 'Audio',
          isActive: _ctrl.ttsActive,
          onTap: () => _handleAudioTap(t),
        ),
        ContextualAction(
          icon: Icons.search,
          label: 'Buscar',
          onTap: () {
            _ctrl.toggleSearch();
            if (_ctrl.showSearch) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _searchFocusNode.requestFocus();
              });
            }
          },
        ),
      ],
      moreActions: [
        MoreMenuItem(
          icon: Icons.view_column_outlined,
          label: 'Vista paralela',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BibleParallelScreen(
                  bookNumber: widget.bookNumber,
                  bookName: widget.bookName,
                  chapter: _ctrl.currentChapter,
                  primaryVersion: _ctrl.currentVersion,
                ),
              ),
            );
          },
        ),
        MoreMenuItem(
          icon: Icons.history,
          label: 'Historial de lectura',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ReadingHistoryScreen()),
            );
          },
        ),
        MoreMenuItem(
          icon: Icons.copyright_outlined,
          label: 'Acerca de esta versión',
          onTap: () => showVersionInfoSheet(context, _ctrl.currentVersion, t),
        ),
        MoreMenuItem(
          icon: Icons.auto_stories_outlined,
          label: 'Introducción al libro',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookIntroductionScreen(
                  bookNumber: widget.bookNumber,
                  bookName: widget.bookName,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
