import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'bible_parallel_screen.dart';
import 'chapter_selector_screen.dart';
import 'book_introduction_screen.dart';

class BibleReaderScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleVersion version;
  final int? initialVerse;

  const BibleReaderScreen({
    super.key,
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.version,
    this.initialVerse,
  });

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen> {
  late final BibleReaderController _ctrl;
  final _scrollController = ScrollController();
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
    );
    debugPrint('🟢 [BibleReader] after controller create');
    _ctrl.addListener(_onControllerChanged);
    _scrollController.addListener(_onScroll);
    if (widget.initialVerse != null) {
      _ctrl.addListener(_scrollToInitialVerse);
    }
    _pageController = PageController(
      initialPage: 1, // center page = current chapter
      viewportFraction: 0.92,
    );
    BibleTtsService.I.currentVerseIndex.addListener(_onTtsVerseChanged);
    debugPrint('🟢 [BibleReader] initState end');
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _scrollToInitialVerse() {
    if (_ctrl.loading || _ctrl.verses.isEmpty) return;
    _ctrl.removeListener(_scrollToInitialVerse);
    final verseIdx = (widget.initialVerse! - 1).clamp(
      0,
      _ctrl.verses.length - 1,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final fontSize = BibleUserDataService.I.fontSizeNotifier.value;
      final offset = 56.0 + 92.0 + (verseIdx * fontSize * 2.2);
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    });
  }

  void _onScroll() {
    _ctrl.onScroll(_scrollController.offset);
  }

  void _onTtsVerseChanged() {
    final idx = BibleTtsService.I.currentVerseIndex.value;
    if (idx < 0 || !_scrollController.hasClients) return;
    final fontSize = BibleUserDataService.I.fontSizeNotifier.value;
    final offset = 56.0 + 92.0 + (idx * fontSize * 2.2);
    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    BibleTtsService.I.currentVerseIndex.removeListener(_onTtsVerseChanged);
    _ctrl.removeListener(_onControllerChanged);
    _ctrl.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _goToBook(int bookNumber, String bookName, int chapter) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (c, a1, a2) => BibleReaderScreen(
          bookNumber: bookNumber,
          bookName: bookName,
          chapter: chapter,
          version: _ctrl.currentVersion,
        ),
        transitionDuration: const Duration(milliseconds: 150),
        transitionsBuilder: (ctx, a, sa, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _goToNextBook() {
    if (_ctrl.allBooks.isEmpty) return;
    final i = _ctrl.allBooks.indexWhere((b) => b.number == widget.bookNumber);
    if (i < 0 || i >= _ctrl.allBooks.length - 1) return;
    final next = _ctrl.allBooks[i + 1];
    _goToBook(next.number, next.name, 1);
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
    final verseIdx = _ctrl.searchMatchIndices[matchIdx];
    final fontSize = BibleUserDataService.I.fontSizeNotifier.value;
    final offset = 56.0 + 92.0 + (verseIdx * fontSize * 2.2);
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
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
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        return Scaffold(
          backgroundColor: t.background,
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
                      : PageView.builder(
                          controller: _pageController,
                          itemCount: 3, // prev | current | next
                          onPageChanged: (page) {
                            if (_pageAnimating) return;
                            _pageAnimating = true;
                            if (page == 0) {
                              // Swiped to previous chapter
                              _ctrl.goToChapter(_ctrl.currentChapter - 1);
                            } else if (page == 2) {
                              // Swiped to next chapter
                              if (_ctrl.currentChapter < _ctrl.totalChapters) {
                                _ctrl.goToChapter(_ctrl.currentChapter + 1);
                              } else {
                                _goToNextBook();
                              }
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
                                        : '')
                                  : (_ctrl.currentChapter < _ctrl.totalChapters
                                        ? 'Cap. ${_ctrl.currentChapter + 1}'
                                        : 'Siguiente libro');
                              return Center(
                                child: Text(
                                  label,
                                  style: GoogleFonts.manrope(
                                    color: t.textSecondary.withValues(alpha: 0.3),
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
                              onGoToNextBook: _goToNextBook,
                              onGoToBook: _goToBook,
                              onBottomNavBookTap: (_, _, _) =>
                                  _openChapterSelector(),
                            );
                          },
                        ),
                  if (!_ctrl.loading)
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
                  if (!_ctrl.loading && !_ctrl.isSelecting)
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

  /// Barra flotante fija abajo: ▶ audio | ‹ | Libro Cap (tap → selector) | ›.
  /// Reemplaza al indicador "peek" anterior (texto tenue no interactivo) por
  /// un control real y descubrible, como el navegador inferior de YouVersion.
  Widget _buildChapterNavigator(BibleReaderThemeData t) {
    final hasPrev = _ctrl.currentChapter > 1;
    final hasNext =
        _ctrl.currentChapter < _ctrl.totalChapters ||
        _ctrl.allBooks.indexWhere((b) => b.number == widget.bookNumber) <
            _ctrl.allBooks.length - 1;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: t.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: t.isDark ? 0.28 : 0.08),
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
            _buildNavArrow(t, Icons.chevron_left, hasPrev,
                () => _ctrl.goToChapter(_ctrl.currentChapter - 1)),
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
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            _buildNavArrow(t, Icons.chevron_right, hasNext, () {
              if (_ctrl.currentChapter < _ctrl.totalChapters) {
                _ctrl.goToChapter(_ctrl.currentChapter + 1);
              } else {
                _goToNextBook();
              }
            }),
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
  ) {
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(8),
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
            color: t.isDark ? Colors.black : Colors.white,
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
                style: GoogleFonts.manrope(
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
        style: GoogleFonts.manrope(
          color: t.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.manrope(color: t.textSecondary, fontSize: 12),
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
        onChanged: _ctrl.onVersionChanged,
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
