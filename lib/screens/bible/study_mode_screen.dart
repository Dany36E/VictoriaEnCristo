import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/study_chapter_answers.dart';
import '../../models/bible/study_room.dart';
import '../../models/bible/study_word_highlight.dart';
import '../../services/bible/bible_download_service.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/study_export_service.dart';
import '../../services/bible/study_mode_service.dart';
import '../../services/bible/study_room_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/study/study_chapter_picker.dart';
import '../../widgets/bible/study/study_onboarding_overlay.dart';
import '../../widgets/bible/study/study_reading_panel.dart';
import '../../widgets/bible/study/study_questions_panel.dart';
import '../../widgets/bible/study/study_room_banner.dart';
import '../../widgets/bible/study/study_room_dialogs.dart';

enum _StudyHeaderAction { passage, range, text, tutorial, room }

/// ═══════════════════════════════════════════════════════════════════════════
/// MODO ESTUDIO — Pantalla principal
///
/// Layout responsivo:
///   - Ancho ≥ 900 lp → split 50/50 (lectura | preguntas)
///   - Ancho < 900 lp → TabBar 2 secciones
///
/// Sincroniza con `StudyModeService`:
///   - Subrayados granulares + espejo a `BibleUserDataService` (lectura normal)
///   - Respuestas a 6 preguntas + espejo a `ChapterNoteService` (Notas)
/// ═══════════════════════════════════════════════════════════════════════════
class StudyModeScreen extends StatefulWidget {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final BibleVersion? version;
  final bool openRoomDialogOnStart;
  final bool openSetupOnStart;
  final bool openSavedStudiesOnStart;

  const StudyModeScreen({
    super.key,
    this.bookNumber = 1,
    this.bookName = 'Génesis',
    this.chapter = 1,
    this.version,
    this.openRoomDialogOnStart = false,
    this.openSetupOnStart = false,
    this.openSavedStudiesOnStart = false,
  });

  @override
  State<StudyModeScreen> createState() => _StudyModeScreenState();
}

class _StudyModeScreenState extends State<StudyModeScreen>
    with SingleTickerProviderStateMixin {
  late int _bookNumber;
  late String _bookName;
  late int _chapter;
  late BibleVersion _version;
  late BibleVersion _secondaryVersion;

  List<BibleBook> _books = const [];
  List<BibleVerse> _verses = const [];
  List<BibleVerse> _secondaryVerses = const [];
  bool _loading = true;

  late final TabController _tabController;
  Timer? _saveDebounce;
  bool _applyingRoomState = false;
  String? _lastRoomStateKey;
  String? _lastSwapStartPromptKey;
  final Map<String, String> _draftAnswers = {};
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _generalNotesController = TextEditingController();
  final TextEditingController _hopeMessageController = TextEditingController();
  final Set<int> _mainVerseNumbers = {};

  /// Identificador del estudio actualmente cargado en pantalla.
  /// - null  → no se ha seleccionado aún; al primer guardado se generará
  ///   un studyId fresco (un "nuevo estudio").
  /// - !=null → hidrata y guarda contra ese estudio específico.
  /// Permite tener varios estudios independientes del mismo capítulo.
  String? _currentStudyId;

  /// Resuelve el estudio actualmente cargado: prioriza `_currentStudyId`,
  /// con fallback al estudio más reciente del libro/capítulo cuando todavía
  /// no hay id (apertura legacy sin Setup).
  StudyChapterAnswers? _resolveCurrentStudy() {
    final byId = StudyModeService.I.answersForStudyId(_currentStudyId);
    if (byId != null) return byId;
    if (_currentStudyId != null) return null;
    return StudyModeService.I.answersFor(_bookNumber, _chapter);
  }

  @override
  void initState() {
    super.initState();
    _bookNumber = widget.bookNumber;
    _bookName = widget.bookName;
    _chapter = widget.chapter;
    _version = BibleDownloadService.I.bestAvailableVersion(
      widget.version ?? BibleUserDataService.I.preferredVersionNotifier.value,
    );
    _secondaryVersion = _defaultSecondaryVersion(_version);
    _tabController = TabController(length: 2, vsync: this);
    for (final q in kStudyQuestions) {
      _controllers[q.id] = TextEditingController();
    }
    StudyRoomService.I.currentRoomNotifier.addListener(_onRoomChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await UserScopedServices.I.ensureStudyMode();
    if (!mounted) return;
    if (widget.version == null) {
      _version = BibleDownloadService.I.bestAvailableVersion(
        BibleUserDataService.I.preferredVersionNotifier.value,
      );
      _secondaryVersion = _defaultSecondaryVersion(_version);
    }
    // Si el usuario entró con el flujo de "Nuevo estudio" (Setup), creamos
    // un studyId fresco para que las notas/respuestas sean independientes,
    // incluso si ya existe otro estudio del mismo capítulo.
    if (widget.openSetupOnStart && !widget.openSavedStudiesOnStart) {
      _currentStudyId = StudyChapterAnswers.generateStudyId();
    }
    await _loadChapter();
    _hydrateAnswers();
    // Onboarding (primer uso)
    final seen = await StudyModeService.I.hasSeenOnboarding();
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!seen) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const StudyOnboardingOverlay(),
        );
        await StudyModeService.I.markOnboardingSeen();
      }
      if (!mounted) return;
      if (widget.openSavedStudiesOnStart) {
        await _openSavedStudiesPicker();
      }
      if (!mounted) return;
      if (widget.openSetupOnStart) {
        await _openPicker();
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (mounted) await _openRangePicker();
        if (!mounted) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
        if (mounted) await _openVersionsPicker();
      }
      if (!mounted || !widget.openRoomDialogOnStart) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (mounted) await _openRoomDialog();
    });
  }

  Future<void> _loadChapter() async {
    setState(() => _loading = true);
    try {
      _version = BibleDownloadService.I.bestAvailableVersion(_version);
      if (!BibleDownloadService.I.isAvailable(_secondaryVersion) ||
          _secondaryVersion == _version) {
        _secondaryVersion = _defaultSecondaryVersion(_version);
      }
      _books = await BibleParserService.I.getBooks(_version);
      final verses = await BibleParserService.I.getChapter(
        version: _version,
        bookNumber: _bookNumber,
        chapter: _chapter,
      );
      final secondaryVerses = _secondaryVersion == _version
          ? const <BibleVerse>[]
          : await BibleParserService.I.getChapter(
              version: _secondaryVersion,
              bookNumber: _bookNumber,
              chapter: _chapter,
            );
      if (!mounted) return;
      setState(() {
        _verses = verses;
        _secondaryVerses = secondaryVerses;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[STUDY-MODE] load chapter error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  BibleVersion _defaultSecondaryVersion(BibleVersion primary) {
    return BibleDownloadService.I.bestAvailableSecondary(primary);
  }

  void _hydrateAnswers() {
    final study = _resolveCurrentStudy();
    // Si encontramos un estudio vía fallback legacy, adoptamos su studyId
    // para futuras escrituras (manteniendo la entrada existente en lugar de
    // crear duplicados).
    if (_currentStudyId == null && study != null) {
      _currentStudyId = study.chapterKey;
    }
    final existing = study?.answers ?? const <String, String>{};
    _draftAnswers
      ..clear()
      ..addAll(existing);
    for (final q in kStudyQuestions) {
      _controllers[q.id]!.text = existing[q.id] ?? '';
    }
    _generalNotesController.text = study?.generalNotes ?? '';
    _hopeMessageController.text = study?.hopeMessage ?? '';
    _mainVerseNumbers
      ..clear()
      ..addAll(study?.sortedMainVerses ?? const <int>[]);
  }

  void _onAnswerChanged(String questionId, String value) {
    _draftAnswers[questionId] = value;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _flushAnswers);
  }

  void _onGeneralNotesChanged(String value) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _flushAnswers);
  }

  void _onHopeMessageChanged(String value) {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _flushAnswers);
  }

  void _onMainVerseToggled(int verseNumber, bool selected) {
    setState(() {
      if (selected) {
        _mainVerseNumbers.add(verseNumber);
      } else {
        _mainVerseNumbers.remove(verseNumber);
      }
    });
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _flushAnswers);
  }

  Future<void> _flushAnswers() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final existing = _resolveCurrentStudy();
    final base =
        existing ??
        StudyChapterAnswers.empty(
          studyId: _currentStudyId,
          bookNumber: _bookNumber,
          bookName: _bookName,
          chapter: _chapter,
          versionId: _version.id,
        );
    // Aseguramos que `_currentStudyId` refleje el studyId que se va a
    // persistir (útil si veniámos sin id y empty() acaba de generar uno).
    _currentStudyId ??= base.studyId ?? base.chapterKey;
    final merged = _answersFromControllers();
    final updated = base.copyWith(
      answers: merged,
      generalNotes: _generalNotesController.text.trim(),
      hopeMessage: _hopeMessageController.text.trim(),
      mainVerses: _mainVerseNumbers.toList(),
      versionId: _version.id,
    );
    await StudyModeService.I.saveAnswers(updated);
    unawaited(StudyRoomService.I.publishAnswerSnapshot(updated));
  }

  Map<String, String> _answersFromControllers() {
    final out = <String, String>{};
    for (final q in kStudyQuestions) {
      final value = _controllers[q.id]?.text.trim() ?? '';
      if (value.isNotEmpty) out[q.id] = value;
    }
    return out;
  }

  StudyChapterAnswers _currentStudySnapshot() {
    final existing = _resolveCurrentStudy();
    final base =
        existing ??
        StudyChapterAnswers.empty(
          studyId: _currentStudyId,
          bookNumber: _bookNumber,
          bookName: _bookName,
          chapter: _chapter,
          versionId: _version.id,
        );
    return base.copyWith(
      answers: _answersFromControllers(),
      generalNotes: _generalNotesController.text.trim(),
      hopeMessage: _hopeMessageController.text.trim(),
      mainVerses: _mainVerseNumbers.toList(),
      versionId: _version.id,
    );
  }

  Future<void> _changeChapter(
    int bookNumber,
    String bookName,
    int chapter,
  ) async {
    await _flushAnswers();
    setState(() {
      _bookNumber = bookNumber;
      _bookName = bookName;
      _chapter = chapter;
      // Al cambiar de capítulo soltamos el studyId actual; `_hydrateAnswers`
      // lo adoptará del estudio más reciente del nuevo capítulo (o lo
      // dejará null si no existe, creando uno nuevo al primer guardado).
      _currentStudyId = null;
    });
    await _loadChapter();
    _hydrateAnswers();
  }

  Future<void> _openPicker() async {
    final result = await showModalBottomSheet<StudyPickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StudyChapterPicker(
        books: _books,
        currentBookNumber: _bookNumber,
        currentChapter: _chapter,
      ),
    );
    if (result != null) {
      await _changeChapter(result.bookNumber, result.bookName, result.chapter);
    }
  }

  Future<void> _openVersionsPicker() async {
    final result = await showModalBottomSheet<_VersionPairResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VersionPairSheet(
        initialPrimary: _version,
        initialSecondary: _secondaryVersion,
      ),
    );
    if (result == null) return;
    await _changeVersions(result.primary, result.secondary);
  }

  Future<void> _openSavedStudiesPicker() async {
    await _flushAnswers();
    if (!mounted) return;
    final studies = StudyModeService.I.answersNotifier.value.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final result = await showModalBottomSheet<StudyChapterAnswers>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SavedStudiesSheet(
        studies: studies,
        onDeleteStudy: _deleteSavedStudy,
      ),
    );
    if (result == null) return;
    await _openSavedStudy(result);
  }

  Future<void> _deleteSavedStudy(
    StudyChapterAnswers study, {
    required bool deleteHighlights,
  }) async {
    final deletingCurrent =
        study.bookNumber == _bookNumber && study.chapter == _chapter;
    await StudyModeService.I.deleteStudy(
      study,
      deleteHighlights: deleteHighlights,
    );
    if (!deletingCurrent || !mounted) return;
    _draftAnswers.clear();
    for (final controller in _controllers.values) {
      controller.clear();
    }
    _generalNotesController.clear();
    _hopeMessageController.clear();
    _mainVerseNumbers.clear();
    setState(() {});
  }

  Future<void> _openSavedStudy(StudyChapterAnswers study) async {
    await _flushAnswers();
    final primary = BibleDownloadService.I.bestAvailableVersion(
      BibleVersion.fromId(study.versionId),
    );
    final secondary = primary == _secondaryVersion
        ? _defaultSecondaryVersion(primary)
        : _secondaryVersion;
    setState(() {
      _bookNumber = study.bookNumber;
      _bookName = study.bookName;
      _chapter = study.chapter;
      _version = primary;
      _secondaryVersion = secondary;
      _currentStudyId = study.chapterKey;
    });
    await _loadChapter();
    _hydrateAnswers();
  }

  Future<void> _changeVersions(
    BibleVersion primary,
    BibleVersion secondary,
  ) async {
    await _flushAnswers();
    primary = BibleDownloadService.I.bestAvailableVersion(primary);
    if (!BibleDownloadService.I.isAvailable(secondary)) {
      secondary = _defaultSecondaryVersion(primary);
    }
    if (secondary == primary) {
      secondary = _defaultSecondaryVersion(primary);
    }
    setState(() {
      _version = primary;
      _secondaryVersion = secondary;
    });
    await _loadChapter();
    await _flushAnswers();
  }

  Future<void> _swapVersions() async {
    await _changeVersions(_secondaryVersion, _version);
  }

  void _onRoomChanged() {
    final room = StudyRoomService.I.currentRoomNotifier.value;
    if (room == null) {
      _lastRoomStateKey = null;
      _lastSwapStartPromptKey = null;
      if (mounted) setState(() {});
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final assignedVersionId = uid == null ? null : room.versionForUid(uid);
    final key = [
      room.code,
      room.bookNumber,
      room.chapter,
      room.startVerse ?? '',
      room.endVerse ?? '',
      assignedVersionId ?? '',
    ].join(':');
    _maybePromptStartSwapTimer(room);
    if (key == _lastRoomStateKey) return;
    _lastRoomStateKey = key;
    unawaited(_applyRoomState(room, assignedVersionId));
  }

  Future<void> _applyRoomState(
    StudyRoom room,
    String? assignedVersionId,
  ) async {
    if (_applyingRoomState || !mounted) return;
    _applyingRoomState = true;
    try {
      final primary = assignedVersionId == null
          ? _version
          : BibleVersion.fromId(assignedVersionId);
      final availablePrimary = BibleDownloadService.I.bestAvailableVersion(
        primary,
      );
      final secondary = availablePrimary == _secondaryVersion
          ? _defaultSecondaryVersion(availablePrimary)
          : _secondaryVersion;
      final passageChanged =
          room.bookNumber != _bookNumber ||
          room.bookName != _bookName ||
          room.chapter != _chapter;
      final versionsChanged =
          availablePrimary != _version || secondary != _secondaryVersion;

      if (passageChanged || versionsChanged) {
        await _flushAnswers();
        if (!mounted) return;
        setState(() {
          _bookNumber = room.bookNumber;
          _bookName = room.bookName;
          _chapter = room.chapter;
          _version = availablePrimary;
          _secondaryVersion = secondary;
        });
        await _loadChapter();
        _hydrateAnswers();
      }

      await StudyModeService.I.setStudyRange(
        studyId: _currentStudyId,
        bookNumber: room.bookNumber,
        bookName: room.bookName,
        chapter: room.chapter,
        versionId: availablePrimary.id,
        startVerse: room.startVerse,
        endVerse: room.endVerse,
      );
      unawaited(
        StudyRoomService.I.publishHighlights(
          StudyModeService.I.highlightsNotifier.value,
        ),
      );
      if (mounted) setState(() {});
    } finally {
      _applyingRoomState = false;
    }
  }

  void _maybePromptStartSwapTimer(StudyRoom room) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null ||
        room.hostUid != uid ||
        room.swapTimerActive ||
        room.memberOrder.length < 2) {
      if (room.swapTimerActive) _lastSwapStartPromptKey = null;
      return;
    }
    final promptKey = '${room.code}:${room.memberOrder.join('|')}';
    if (_lastSwapStartPromptKey == promptKey) return;
    _lastSwapStartPromptKey = promptKey;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final activeRoom = StudyRoomService.I.currentRoomNotifier.value;
      if (activeRoom == null ||
          activeRoom.code != room.code ||
          activeRoom.swapTimerActive) {
        return;
      }
      final start = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Iniciar timer de swap?'),
          content: Text(
            'Ya hay ${activeRoom.memberOrder.length} miembros en la sala. '
            'Puedes iniciar los ${activeRoom.swapIntervalMinutes} minutos ahora o esperar a alguien más.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Esperar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Iniciar timer'),
            ),
          ],
        ),
      );
      if (start != true || !mounted) return;
      await _startRoomSwapTimer();
    });
  }

  Future<void> _startRoomSwapTimer() async {
    try {
      await StudyRoomService.I.startSwapTimer();
      if (mounted) _showSnack('Timer de swap iniciado.');
    } catch (e) {
      if (mounted) _showSnack('No se pudo iniciar el timer: $e');
    }
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _flushAnswers(); // sin await — se ejecutará en background
    StudyRoomService.I.currentRoomNotifier.removeListener(_onRoomChanged);
    for (final c in _controllers.values) {
      c.dispose();
    }
    _generalNotesController.dispose();
    _hopeMessageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (_, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
        SystemChrome.setSystemUIOverlayStyle(
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                      color: t.accent,
                      strokeWidth: 1.5,
                    ),
                  )
                : LayoutBuilder(
                    builder: (ctx, c) {
                      final isWide = c.maxWidth >= 900;
                      return Column(
                        children: [
                          _buildHeader(t, isWide),
                          ValueListenableBuilder<StudyRoom?>(
                            valueListenable:
                                StudyRoomService.I.currentRoomNotifier,
                            builder: (_, room, _) {
                              if (room == null) return const SizedBox.shrink();
                              return StudyRoomBanner(
                                room: room,
                                theme: t,
                                onLeave: _confirmLeaveRoom,
                                onRotate: () => StudyRoomService.I.rotateNow(),
                                onStartTimer: _startRoomSwapTimer,
                                onVersionAssigned: _onAssignedVersionChanged,
                              );
                            },
                          ),
                          Expanded(
                            child: isWide ? _buildSplit(t) : _buildTabbed(t),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t, bool isWide) {
    if (!isWide) return _buildCompactHeader(t);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: t.textSecondary,
              size: 18,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _openPicker,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Modo Estudio',
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: isWide ? 18 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$_bookName $_chapter',
                          style: GoogleFonts.lora(
                            color: t.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.expand_more, color: t.accent, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tutorial',
            icon: Icon(
              Icons.help_outline,
              color: t.textSecondary.withOpacity(0.6),
              size: 20,
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const StudyOnboardingOverlay(),
            ),
          ),
          TextButton.icon(
            onPressed: () => _openTypographySheet(t),
            icon: Icon(Icons.text_fields, color: t.accent, size: 17),
            label: const Text('Texto y colores'),
            style: TextButton.styleFrom(
              foregroundColor: t.accent,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: t.accent.withOpacity(0.22)),
              ),
              textStyle: GoogleFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Estudiar con amigos',
            icon: Icon(Icons.groups_outlined, color: t.accent, size: 22),
            onPressed: _openRoomDialog,
          ),
          _buildRangeChip(t),
        ],
      ),
    );
  }

  Widget _buildCompactHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 2),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: t.textSecondary,
              size: 18,
            ),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _openPicker,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Modo Estudio',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$_bookName $_chapter · ${_rangeLabel()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _openTypographySheet(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.accent.withOpacity(0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.text_fields, color: t.accent, size: 16),
                  const SizedBox(width: 5),
                  Text(
                    'Texto',
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          PopupMenuButton<_StudyHeaderAction>(
            tooltip: 'Opciones de estudio',
            color: t.surface,
            icon: Icon(Icons.more_vert, color: t.textSecondary, size: 22),
            onSelected: (action) async {
              switch (action) {
                case _StudyHeaderAction.passage:
                  await _openPicker();
                  break;
                case _StudyHeaderAction.range:
                  await _openRangePicker();
                  break;
                case _StudyHeaderAction.text:
                  await _openTypographySheet(t);
                  break;
                case _StudyHeaderAction.tutorial:
                  if (!mounted) return;
                  await showDialog(
                    context: context,
                    builder: (_) => const StudyOnboardingOverlay(),
                  );
                  break;
                case _StudyHeaderAction.room:
                  await _openRoomDialog();
                  break;
              }
            },
            itemBuilder: (_) => [
              _headerMenuItem(t, _StudyHeaderAction.passage, 'Cambiar pasaje'),
              _headerMenuItem(t, _StudyHeaderAction.range, 'Elegir rango'),
              _headerMenuItem(t, _StudyHeaderAction.text, 'Texto y colores'),
              _headerMenuItem(t, _StudyHeaderAction.tutorial, 'Tutorial'),
              _headerMenuItem(t, _StudyHeaderAction.room, 'Sala de estudio'),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_StudyHeaderAction> _headerMenuItem(
    BibleReaderThemeData t,
    _StudyHeaderAction value,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Text(
        label,
        style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
      ),
    );
  }

  Widget _buildRangeChip(BibleReaderThemeData t) {
    return ValueListenableBuilder<Map<String, StudyChapterAnswers>>(
      valueListenable: StudyModeService.I.answersNotifier,
      builder: (_, map, _) {
        final answers = map['$_bookNumber:$_chapter'];
        final s = answers?.studyStartVerse;
        final e = answers?.studyEndVerse;
        final label = (s != null && e != null)
            ? (s == e ? 'v. $s' : 'v. $s–$e')
            : 'Capítulo';
        return GestureDetector(
          onTap: _openRangePicker,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.textSecondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (s != null && e != null)
                    ? t.accent.withOpacity(0.5)
                    : t.textSecondary.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.format_list_numbered,
                  color: t.textSecondary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openTypographySheet(BibleReaderThemeData t) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TypographySheet(theme: t),
    );
  }

  Future<void> _openRangePicker() async {
    final maxVerse = _verses.isEmpty ? 1 : _verses.last.verse;
    final current = _resolveCurrentStudy();
    final result = await showModalBottomSheet<_RangeResult?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VerseRangeSheet(
        maxVerse: maxVerse,
        initialStart: current?.studyStartVerse,
        initialEnd: current?.studyEndVerse,
      ),
    );
    if (result == null) return; // cancel
    // Aseguramos que la operación se aplique al estudio actual; si no hay
    // ninguno cargado aún, generamos un id fresco para que se cree un
    // estudio nuevo en vez de mutar el más reciente del capítulo.
    _currentStudyId ??= StudyChapterAnswers.generateStudyId();
    await StudyModeService.I.setStudyRange(
      studyId: _currentStudyId,
      bookNumber: _bookNumber,
      bookName: _bookName,
      chapter: _chapter,
      versionId: _version.id,
      startVerse: result.start,
      endVerse: result.end,
    );
    if (mounted) setState(() {});
  }

  String _rangeLabel() {
    final current = _resolveCurrentStudy();
    final s = current?.studyStartVerse;
    final e = current?.studyEndVerse;
    if (s == null || e == null) return 'Capítulo completo';
    return s == e ? 'v. $s' : 'v. $s-$e';
  }

  List<BibleVerse> _visibleVerses() {
    final current = _resolveCurrentStudy();
    final s = current?.studyStartVerse;
    final e = current?.studyEndVerse;
    if (s == null || e == null) return _verses;
    final lo = s < e ? s : e;
    final hi = s < e ? e : s;
    final filtered = _verses
        .where((v) => v.verse >= lo && v.verse <= hi)
        .toList(growable: false);
    return filtered.isEmpty ? _verses : filtered;
  }

  List<BibleVerse> _visibleSecondaryVerses() {
    final current = _resolveCurrentStudy();
    final s = current?.studyStartVerse;
    final e = current?.studyEndVerse;
    if (s == null || e == null) return _secondaryVerses;
    final lo = s < e ? s : e;
    final hi = s < e ? e : s;
    final filtered = _secondaryVerses
        .where((v) => v.verse >= lo && v.verse <= hi)
        .toList(growable: false);
    return filtered.isEmpty ? _secondaryVerses : filtered;
  }

  String _versionsLabel() {
    if (StudyRoomService.I.currentRoomNotifier.value != null) {
      return _version.shortName;
    }
    return '${_version.shortName} + ${_secondaryVersion.shortName}';
  }

  List<int> _mainVersePickerNumbers() {
    final numbers = _visibleVerses().map((v) => v.verse).toSet()
      ..addAll(_mainVerseNumbers);
    return numbers.toList()..sort();
  }

  String _mainVerseReferenceLabel() {
    final ranges = StudyChapterAnswers.verseRangesLabel(_mainVerseNumbers);
    if (ranges.isEmpty) return 'Sin seleccionar';
    return '$_bookName $_chapter:$ranges';
  }

  Future<void> _exportPdf() async {
    try {
      await _flushAnswers();
      final action = await _pickPdfExportAction();
      if (action == null) return;
      final study = _currentStudySnapshot();
      await StudyRoomService.I.publishAnswerSnapshot(study);
      await StudyRoomService.I.publishHighlights(
        StudyModeService.I.highlightsNotifier.value,
      );
      final room = StudyRoomService.I.currentRoomNotifier.value;
      final inRoom = room != null;
      late final File file;
      if (inRoom) {
        final participants = await _buildRoomParticipantBundles(room, study);
        final roomAnswers =
            StudyRoomService.I.roomAnswerSnapshotsNotifier.value;
        file = action == _PdfExportAction.share
            ? await StudyExportService.I.exportAndShareRoomStudy(
                study: study,
                participants: participants,
                roomAnswerSnapshots: roomAnswers,
              )
            : await StudyExportService.I.exportRoomStudyToPdf(
                study: study,
                participants: participants,
                roomAnswerSnapshots: roomAnswers,
                saveToDownloads: true,
              );
      } else {
        final highlights = StudyModeService.I.highlightsNotifier.value;
        file = action == _PdfExportAction.share
            ? await StudyExportService.I.exportAndShareStudy(
                study: study,
                chapterVerses: _verses,
                secondaryChapterVerses: _secondaryVerses,
                secondaryVersionId: _secondaryVersion.id,
                studyHighlights: highlights,
              )
            : await StudyExportService.I.exportStudyToPdf(
                study: study,
                chapterVerses: _verses,
                secondaryChapterVerses: _secondaryVerses,
                secondaryVersionId: _secondaryVersion.id,
                studyHighlights: highlights,
                saveToDownloads: true,
              );
      }
      if (!mounted) return;
      final label = action == _PdfExportAction.share
          ? 'PDF listo para compartir'
          : 'PDF guardado en Descargas';
      _showSnack('$label: ${file.path}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('No se pudo exportar el PDF: $e');
    }
  }

  Future<List<StudyParticipantBundle>> _buildRoomParticipantBundles(
    StudyRoom room,
    StudyChapterAnswers selfStudy,
  ) async {
    final selfUid = FirebaseAuth.instance.currentUser?.uid;
    final allHighlights = _roomPdfHighlights();
    final snapshotsByUid = {
      for (final snapshot
          in StudyRoomService.I.roomAnswerSnapshotsNotifier.value)
        snapshot.uid: snapshot,
    };

    // Versiones únicas a precargar (incluye versión asignada + versiones con
    // resaltados de cada participante).
    final neededVersions = <String>{};
    for (final member in room.members.values) {
      neededVersions.add(member.versionId);
    }
    for (final highlight in allHighlights) {
      neededVersions.add(highlight.versionId);
    }
    if (selfUid != null) {
      neededVersions.add(selfStudy.versionId);
    }

    final versionVerses = <String, List<BibleVerse>>{};
    await Future.wait(
      neededVersions.map((versionId) async {
        try {
          final verses = await BibleParserService.I.getChapter(
            version: BibleVersion.fromId(versionId),
            bookNumber: room.bookNumber,
            chapter: room.chapter,
          );
          versionVerses[versionId] = verses;
        } catch (e) {
          debugPrint('[STUDY-MODE] export load $versionId error: $e');
          versionVerses[versionId] = const [];
        }
      }),
    );

    final orderedUids = <String>[
      ...room.memberOrder.where(room.members.containsKey),
      for (final uid in room.members.keys)
        if (!room.memberOrder.contains(uid)) uid,
    ];

    final bundles = <StudyParticipantBundle>[];
    for (final uid in orderedUids) {
      final member = room.members[uid];
      if (member == null) continue;

      final userHighlights = allHighlights
          .where((h) => (h.ownerUid ?? selfUid) == uid)
          .toList(growable: false);
      final versionsFromHighlights = userHighlights
          .map((h) => h.versionId)
          .toSet();
      final orderedVersions = <String>[
        member.versionId,
        for (final v in versionsFromHighlights)
          if (v != member.versionId) v,
      ];

      final versions = <StudyParticipantVersion>[];
      for (final versionId in orderedVersions) {
        final highlightsForVersion = userHighlights
            .where((h) => h.versionId == versionId)
            .toList(growable: false);
        versions.add(
          StudyParticipantVersion(
            versionId: versionId,
            verses: versionVerses[versionId] ?? const [],
            highlights: highlightsForVersion,
          ),
        );
      }

      final isSelf = uid == selfUid;
      final snapshot = snapshotsByUid[uid];
      final answers = isSelf
          ? Map<String, String>.from(selfStudy.answers)
          : (snapshot?.answers ?? const <String, String>{});
      final hopeMessage = isSelf
          ? selfStudy.hopeMessage
          : (snapshot?.hopeMessage ?? '');
      final mainVerseReference = isSelf
          ? selfStudy.mainVerseReference
          : _buildMainVerseReference(room, snapshot);
      final generalNotes = isSelf
          ? selfStudy.generalNotes
          : (snapshot?.generalNotes ?? '');

      bundles.add(
        StudyParticipantBundle(
          uid: uid,
          displayName: member.displayName,
          versions: versions,
          answers: answers,
          hopeMessage: hopeMessage,
          mainVerseReference: mainVerseReference,
          generalNotes: generalNotes,
          currentVersionId: member.versionId,
        ),
      );
    }
    return bundles;
  }

  String _buildMainVerseReference(
    StudyRoom room,
    StudyRoomAnswerSnapshot? snapshot,
  ) {
    if (snapshot == null || snapshot.mainVerses.isEmpty) return '';
    final ranges = StudyChapterAnswers.verseRangesLabel(snapshot.mainVerses);
    if (ranges.isEmpty) return '';
    return '${room.bookName} ${room.chapter}:$ranges';
  }

  List<StudyWordHighlight> _roomPdfHighlights() {
    final byId = {
      for (final highlight in StudyRoomService.I.roomHighlightsNotifier.value)
        highlight.id: highlight,
    };
    for (final highlight in StudyModeService.I.highlightsNotifier.value) {
      byId.putIfAbsent(highlight.id, () => highlight);
    }
    return byId.values.toList(growable: false);
  }

  Future<_PdfExportAction?> _pickPdfExportAction() async {
    if (StudyExportService.I.shouldSaveToDownloadsByDefault) {
      return _PdfExportAction.downloads;
    }
    return showModalBottomSheet<_PdfExportAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _PdfExportActionSheet(),
    );
  }

  Future<void> _openRoomDialog() async {
    final current = StudyRoomService.I.currentRoomNotifier.value;
    if (current != null) {
      // Si ya está en una sala, ofrecer ver/salir.
      await showDialog(
        context: context,
        builder: (_) =>
            StudyRoomActiveDialog(room: current, onLeave: _confirmLeaveRoom),
      );
      return;
    }
    final action = await showDialog<StudyRoomDialogAction>(
      context: context,
      builder: (_) => const StudyRoomChoiceDialog(),
    );
    if (action == null || !mounted) return;

    if (action == StudyRoomDialogAction.create) {
      try {
        final current = _resolveCurrentStudy();
        final room = await StudyRoomService.I.createRoom(
          bookNumber: _bookNumber,
          bookName: _bookName,
          chapter: _chapter,
          versionId: _version.id,
          startVerse: current?.studyStartVerse,
          endVerse: current?.studyEndVerse,
        );
        _showSnack('Sala creada: ${room.code}');
      } catch (e) {
        _showSnack('No se pudo crear la sala: $e');
      }
    } else if (action == StudyRoomDialogAction.join) {
      final form = await showDialog<JoinRoomFormResult>(
        context: context,
        builder: (_) => JoinRoomDialog(currentVersionId: _version.id),
      );
      if (form == null || !mounted) return;
      try {
        await StudyRoomService.I.joinRoom(
          code: form.code,
          versionId: form.versionId,
        );
        _showSnack('Te uniste a la sala ${form.code.toUpperCase()}');
      } catch (e) {
        _showSnack('No se pudo unir: $e');
      }
    }
  }

  Future<void> _confirmLeaveRoom() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Salir de la sala?'),
        content: const Text(
          'Dejarás de recibir la rotación de traducciones. '
          'Puedes volver a entrar usando el código.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await StudyRoomService.I.leaveRoom();
      if (mounted) _showSnack('Saliste de la sala.');
    }
  }

  void _onAssignedVersionChanged(String versionId) {
    final v = BibleVersion.fromId(versionId);
    if (v == _version) return;
    final secondary = v == _secondaryVersion
        ? _defaultSecondaryVersion(v)
        : _secondaryVersion;
    unawaited(_changeVersions(v, secondary));
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildSplit(BibleReaderThemeData t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildReadingPanel(t)),
        Container(width: 1, color: t.textSecondary.withOpacity(0.12)),
        Expanded(child: _buildQuestionsPanel(t)),
      ],
    );
  }

  Widget _buildTabbed(BibleReaderThemeData t) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: t.accent,
          unselectedLabelColor: t.textSecondary,
          indicatorColor: t.accent,
          tabs: const [
            Tab(text: 'Lectura'),
            Tab(text: 'Preguntas'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildReadingPanel(t), _buildQuestionsPanel(t)],
          ),
        ),
      ],
    );
  }

  Widget _buildReadingPanel(BibleReaderThemeData t) {
    return StudyReadingPanel(
      key: ValueKey(
        'reading_${_bookNumber}_${_chapter}_${_version.id}_${_secondaryVersion.id}',
      ),
      theme: t,
      verses: _visibleVerses(),
      secondaryVerses: _visibleSecondaryVerses(),
      primaryVersion: _version,
      secondaryVersion: _secondaryVersion,
      bookNumber: _bookNumber,
      chapter: _chapter,
      showSecondary:
          StudyRoomService.I.currentRoomNotifier.value == null &&
          _secondaryVersion != _version &&
          _secondaryVerses.isNotEmpty,
    );
  }

  Widget _buildQuestionsPanel(BibleReaderThemeData t) {
    return StudyQuestionsPanel(
      theme: t,
      controllers: _controllers,
      generalNotesController: _generalNotesController,
      hopeMessageController: _hopeMessageController,
      mainVerseNumbers: _mainVersePickerNumbers(),
      selectedMainVerses: Set.unmodifiable(_mainVerseNumbers),
      mainVerseReference: _mainVerseReferenceLabel(),
      onChanged: _onAnswerChanged,
      onGeneralNotesChanged: _onGeneralNotesChanged,
      onHopeMessageChanged: _onHopeMessageChanged,
      onMainVerseToggled: _onMainVerseToggled,
      onManualSave: _flushAnswers,
      onExportPdf: _exportPdf,
      onPickSavedStudy: _openSavedStudiesPicker,
      onPickRange: _openRangePicker,
      onPickVersions: _openVersionsPicker,
      onSwapVersions: _swapVersions,
      onOpenTextSettings: () => _openTypographySheet(t),
      reference: '$_bookName $_chapter',
      rangeLabel: _rangeLabel(),
      versionsLabel: _versionsLabel(),
      roomMode: StudyRoomService.I.currentRoomNotifier.value != null,
    );
  }
}

/// Resultado emitido por el bottom sheet picker (libro/capítulo).
class StudyPickerResult {
  final int bookNumber;
  final String bookName;
  final int chapter;
  const StudyPickerResult(this.bookNumber, this.bookName, this.chapter);
}

enum _SavedStudyContentFilter { all, answered, notes, hope, mainVerse, ranged }

enum _SavedStudySort { updatedDesc, updatedAsc, reference }

enum _SavedStudyGrouping { recent, book }

class _SavedStudiesSheet extends StatefulWidget {
  final List<StudyChapterAnswers> studies;
  final Future<void> Function(
    StudyChapterAnswers study, {
    required bool deleteHighlights,
  })
  onDeleteStudy;

  const _SavedStudiesSheet({
    required this.studies,
    required this.onDeleteStudy,
  });

  @override
  State<_SavedStudiesSheet> createState() => _SavedStudiesSheetState();
}

class _SavedStudiesSheetState extends State<_SavedStudiesSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _chapterController = TextEditingController();
  final Set<String> _deletedKeys = {};
  final Set<String> _deletingKeys = {};

  int? _bookFilter;
  _SavedStudyContentFilter _contentFilter = _SavedStudyContentFilter.all;
  _SavedStudySort _sort = _SavedStudySort.updatedDesc;
  _SavedStudyGrouping _grouping = _SavedStudyGrouping.recent;

  @override
  void dispose() {
    _searchController.dispose();
    _chapterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );
    return ValueListenableBuilder<Map<String, StudyChapterAnswers>>(
      valueListenable: StudyModeService.I.answersNotifier,
      builder: (context, map, _) {
        final liveStudies = map.values.toList();
        final source = liveStudies.isEmpty && _deletedKeys.isEmpty
            ? widget.studies
            : liveStudies;
        final studies = source
            .where((study) => !_deletedKeys.contains(study.chapterKey))
            .toList(growable: false);
        final filtered = _filteredStudies(studies);
        final bookOptions = _bookOptions(studies);
        return DraggableScrollableSheet(
          initialChildSize: studies.isEmpty ? 0.36 : 0.86,
          minChildSize: 0.30,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          color: t.textSecondary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    _SavedStudiesHeader(
                      theme: t,
                      totalCount: studies.length,
                      filteredCount: filtered.length,
                    ),
                    if (studies.isNotEmpty)
                      _SavedStudiesFilters(
                        theme: t,
                        searchController: _searchController,
                        chapterController: _chapterController,
                        bookFilter: _bookFilter,
                        bookOptions: bookOptions,
                        contentFilter: _contentFilter,
                        sort: _sort,
                        grouping: _grouping,
                        onChanged: () => setState(() {}),
                        onBookChanged: (value) =>
                            setState(() => _bookFilter = value),
                        onContentFilterChanged: (value) =>
                            setState(() => _contentFilter = value),
                        onSortChanged: (value) => setState(() => _sort = value),
                        onGroupingChanged: (value) =>
                            setState(() => _grouping = value),
                      ),
                    Expanded(
                      child: studies.isEmpty
                          ? _SavedStudiesEmptyState(theme: t, filtered: false)
                          : filtered.isEmpty
                          ? _SavedStudiesEmptyState(theme: t, filtered: true)
                          : _SavedStudiesList(
                              studies: filtered,
                              grouping: _grouping,
                              theme: t,
                              scrollController: scrollController,
                              deletingKeys: _deletingKeys,
                              onOpen: (study) => Navigator.pop(context, study),
                              onDelete: _confirmDelete,
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<StudyChapterAnswers> _filteredStudies(
    List<StudyChapterAnswers> studies,
  ) {
    final query = _normalize(_searchController.text);
    final chapterText = _chapterController.text.trim();
    final chapter = int.tryParse(chapterText);
    final list = studies
        .where((study) {
          if (_bookFilter != null && study.bookNumber != _bookFilter) {
            return false;
          }
          if (chapter != null && study.chapter != chapter) return false;
          if (chapterText.isNotEmpty && chapter == null) return false;
          if (!_matchesContentFilter(study)) return false;
          if (query.isEmpty) return true;
          return _searchBlob(study).contains(query);
        })
        .toList(growable: false);

    list.sort((a, b) {
      switch (_sort) {
        case _SavedStudySort.updatedDesc:
          return b.updatedAt.compareTo(a.updatedAt);
        case _SavedStudySort.updatedAsc:
          return a.updatedAt.compareTo(b.updatedAt);
        case _SavedStudySort.reference:
          final byBook = a.bookNumber.compareTo(b.bookNumber);
          if (byBook != 0) return byBook;
          return a.chapter.compareTo(b.chapter);
      }
    });
    return list;
  }

  bool _matchesContentFilter(StudyChapterAnswers study) {
    switch (_contentFilter) {
      case _SavedStudyContentFilter.all:
        return true;
      case _SavedStudyContentFilter.answered:
        return study.answers.values.any((answer) => answer.trim().isNotEmpty);
      case _SavedStudyContentFilter.notes:
        return study.generalNotes.trim().isNotEmpty;
      case _SavedStudyContentFilter.hope:
        return study.hopeMessage.trim().isNotEmpty;
      case _SavedStudyContentFilter.mainVerse:
        return study.sortedMainVerses.isNotEmpty;
      case _SavedStudyContentFilter.ranged:
        return study.studyStartVerse != null && study.studyEndVerse != null;
    }
  }

  Map<int, String> _bookOptions(List<StudyChapterAnswers> studies) {
    final books = <int, String>{};
    for (final study in studies) {
      books.putIfAbsent(
        study.bookNumber,
        () => study.bookName.trim().isEmpty
            ? 'Libro ${study.bookNumber}'
            : study.bookName,
      );
    }
    return Map.fromEntries(
      books.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
  }

  String _searchBlob(StudyChapterAnswers study) {
    return _normalize(
      [
        study.reference,
        study.bookName,
        study.versionId,
        study.chapter.toString(),
        study.mainVerseReference,
        study.generalNotes,
        study.hopeMessage,
        ...study.answers.values,
      ].join(' '),
    );
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
  }

  Future<void> _confirmDelete(StudyChapterAnswers study) async {
    final choice = await showDialog<_DeleteStudyChoice>(
      context: context,
      builder: (_) => _DeleteStudyDialog(study: study),
    );
    if (choice == null || !mounted) return;
    setState(() => _deletingKeys.add(study.chapterKey));
    try {
      await widget.onDeleteStudy(
        study,
        deleteHighlights: choice.deleteHighlights,
      );
      _deletedKeys.add(study.chapterKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Estudio eliminado'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
      }
    } finally {
      if (mounted) setState(() => _deletingKeys.remove(study.chapterKey));
    }
  }
}

class _SavedStudiesHeader extends StatelessWidget {
  final BibleReaderThemeData theme;
  final int totalCount;
  final int filteredCount;

  const _SavedStudiesHeader({
    required this.theme,
    required this.totalCount,
    required this.filteredCount,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          Icon(Icons.folder_open_outlined, color: t.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estudios guardados',
                  style: GoogleFonts.cinzel(
                    color: t.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalCount == 0
                      ? 'Sin estudios todavía'
                      : '$filteredCount de $totalCount',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SavedStudiesFilters extends StatelessWidget {
  final BibleReaderThemeData theme;
  final TextEditingController searchController;
  final TextEditingController chapterController;
  final int? bookFilter;
  final Map<int, String> bookOptions;
  final _SavedStudyContentFilter contentFilter;
  final _SavedStudySort sort;
  final _SavedStudyGrouping grouping;
  final VoidCallback onChanged;
  final ValueChanged<int?> onBookChanged;
  final ValueChanged<_SavedStudyContentFilter> onContentFilterChanged;
  final ValueChanged<_SavedStudySort> onSortChanged;
  final ValueChanged<_SavedStudyGrouping> onGroupingChanged;

  const _SavedStudiesFilters({
    required this.theme,
    required this.searchController,
    required this.chapterController,
    required this.bookFilter,
    required this.bookOptions,
    required this.contentFilter,
    required this.sort,
    required this.grouping,
    required this.onChanged,
    required this.onBookChanged,
    required this.onContentFilterChanged,
    required this.onSortChanged,
    required this.onGroupingChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _searchField(t)),
              const SizedBox(width: 10),
              SizedBox(width: 98, child: _chapterField(t)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _BookFilterButton(
                theme: t,
                value: bookFilter,
                options: bookOptions,
                onChanged: onBookChanged,
              ),
              _SortFilterButton(
                theme: t,
                value: sort,
                onChanged: onSortChanged,
              ),
              _SavedFilterChoiceChip(
                theme: t,
                label: 'Recientes',
                selected: grouping == _SavedStudyGrouping.recent,
                icon: Icons.schedule_outlined,
                onTap: () => onGroupingChanged(_SavedStudyGrouping.recent),
              ),
              _SavedFilterChoiceChip(
                theme: t,
                label: 'Por libro',
                selected: grouping == _SavedStudyGrouping.book,
                icon: Icons.library_books_outlined,
                onTap: () => onGroupingChanged(_SavedStudyGrouping.book),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final filter in _SavedStudyContentFilter.values)
                _SavedFilterChoiceChip(
                  theme: t,
                  label: _contentFilterLabel(filter),
                  selected: contentFilter == filter,
                  icon: _contentFilterIcon(filter),
                  onTap: () => onContentFilterChanged(filter),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchField(BibleReaderThemeData t) {
    return TextField(
      controller: searchController,
      onChanged: (_) => onChanged(),
      style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        hintText: 'Buscar estudio, respuesta o nota',
        hintStyle: GoogleFonts.manrope(
          color: t.textSecondary.withOpacity(0.56),
          fontSize: 13,
        ),
        prefixIcon: Icon(Icons.search, color: t.textSecondary, size: 18),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar búsqueda',
                icon: Icon(Icons.close, color: t.textSecondary, size: 17),
                onPressed: () {
                  searchController.clear();
                  onChanged();
                },
              ),
        isDense: true,
        filled: true,
        fillColor: t.background.withOpacity(t.isDark ? 0.78 : 0.88),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: _inputBorder(t),
        enabledBorder: _inputBorder(t),
        focusedBorder: _inputBorder(t, focused: true),
      ),
    );
  }

  Widget _chapterField(BibleReaderThemeData t) {
    return TextField(
      controller: chapterController,
      onChanged: (_) => onChanged(),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      style: GoogleFonts.manrope(
        color: t.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
      decoration: InputDecoration(
        hintText: 'Cap.',
        hintStyle: GoogleFonts.manrope(
          color: t.textSecondary.withOpacity(0.56),
          fontSize: 12,
        ),
        prefixIcon: Icon(Icons.tag, color: t.textSecondary, size: 16),
        suffixIcon: chapterController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpiar capítulo',
                icon: Icon(Icons.close, color: t.textSecondary, size: 15),
                onPressed: () {
                  chapterController.clear();
                  onChanged();
                },
              ),
        isDense: true,
        filled: true,
        fillColor: t.background.withOpacity(t.isDark ? 0.78 : 0.88),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        border: _inputBorder(t),
        enabledBorder: _inputBorder(t),
        focusedBorder: _inputBorder(t, focused: true),
      ),
    );
  }

  OutlineInputBorder _inputBorder(
    BibleReaderThemeData t, {
    bool focused = false,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: focused
            ? t.accent.withOpacity(0.7)
            : t.textSecondary.withOpacity(0.14),
      ),
    );
  }

  String _contentFilterLabel(_SavedStudyContentFilter filter) {
    switch (filter) {
      case _SavedStudyContentFilter.all:
        return 'Todos';
      case _SavedStudyContentFilter.answered:
        return 'Respuestas';
      case _SavedStudyContentFilter.notes:
        return 'Notas';
      case _SavedStudyContentFilter.hope:
        return 'Esperanza';
      case _SavedStudyContentFilter.mainVerse:
        return 'Verso principal';
      case _SavedStudyContentFilter.ranged:
        return 'Con rango';
    }
  }

  IconData _contentFilterIcon(_SavedStudyContentFilter filter) {
    switch (filter) {
      case _SavedStudyContentFilter.all:
        return Icons.all_inclusive;
      case _SavedStudyContentFilter.answered:
        return Icons.question_answer_outlined;
      case _SavedStudyContentFilter.notes:
        return Icons.notes_outlined;
      case _SavedStudyContentFilter.hope:
        return Icons.wb_sunny_outlined;
      case _SavedStudyContentFilter.mainVerse:
        return Icons.bookmark_border;
      case _SavedStudyContentFilter.ranged:
        return Icons.format_list_numbered;
    }
  }
}

class _BookFilterButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final int? value;
  final Map<int, String> options;
  final ValueChanged<int?> onChanged;

  const _BookFilterButton({
    required this.theme,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final label = value == null
        ? 'Todos los libros'
        : options[value] ?? 'Libro $value';
    return PopupMenuButton<int?>(
      tooltip: 'Filtrar por libro',
      color: theme.surface,
      onSelected: onChanged,
      itemBuilder: (_) => [
        PopupMenuItem<int?>(
          value: null,
          child: Text(
            'Todos los libros',
            style: GoogleFonts.manrope(color: theme.textPrimary),
          ),
        ),
        for (final entry in options.entries)
          PopupMenuItem<int?>(
            value: entry.key,
            child: Text(
              entry.value,
              style: GoogleFonts.manrope(color: theme.textPrimary),
            ),
          ),
      ],
      child: _FilterButtonShell(
        theme: theme,
        icon: Icons.menu_book_outlined,
        label: label,
        selected: value != null,
      ),
    );
  }
}

class _SortFilterButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final _SavedStudySort value;
  final ValueChanged<_SavedStudySort> onChanged;

  const _SortFilterButton({
    required this.theme,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SavedStudySort>(
      tooltip: 'Ordenar estudios',
      color: theme.surface,
      onSelected: onChanged,
      itemBuilder: (_) => [
        _sortItem(_SavedStudySort.updatedDesc, 'Más recientes'),
        _sortItem(_SavedStudySort.updatedAsc, 'Más antiguos'),
        _sortItem(_SavedStudySort.reference, 'Libro y capítulo'),
      ],
      child: _FilterButtonShell(
        theme: theme,
        icon: Icons.sort,
        label: _sortLabel(value),
        selected: value != _SavedStudySort.updatedDesc,
      ),
    );
  }

  PopupMenuItem<_SavedStudySort> _sortItem(_SavedStudySort sort, String label) {
    return PopupMenuItem(
      value: sort,
      child: Text(label, style: GoogleFonts.manrope(color: theme.textPrimary)),
    );
  }

  String _sortLabel(_SavedStudySort sort) {
    switch (sort) {
      case _SavedStudySort.updatedDesc:
        return 'Más recientes';
      case _SavedStudySort.updatedAsc:
        return 'Más antiguos';
      case _SavedStudySort.reference:
        return 'Libro y capítulo';
    }
  }
}

class _FilterButtonShell extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;
  final bool selected;

  const _FilterButtonShell({
    required this.theme,
    required this.icon,
    required this.label,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: selected
            ? t.accent.withOpacity(0.13)
            : t.textSecondary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? t.accent.withOpacity(0.38)
              : t.textSecondary.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: selected ? t.accent : t.textSecondary, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                color: selected ? t.accent : t.textPrimary.withOpacity(0.78),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 3),
          Icon(
            Icons.expand_more,
            color: selected ? t.accent : t.textSecondary,
            size: 15,
          ),
        ],
      ),
    );
  }
}

class _SavedFilterChoiceChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  const _SavedFilterChoiceChip({
    required this.theme,
    required this.label,
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return FilterChip(
      label: Text(label),
      avatar: Icon(
        icon,
        size: 14,
        color: selected ? t.accent : t.textSecondary,
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      backgroundColor: t.textSecondary.withOpacity(0.06),
      selectedColor: t.accent.withOpacity(t.isDark ? 0.20 : 0.14),
      side: BorderSide(
        color: selected
            ? t.accent.withOpacity(0.5)
            : t.textSecondary.withOpacity(0.10),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      labelStyle: GoogleFonts.manrope(
        color: selected ? t.accent : t.textPrimary.withOpacity(0.76),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SavedStudiesEmptyState extends StatelessWidget {
  final BibleReaderThemeData theme;
  final bool filtered;

  const _SavedStudiesEmptyState({required this.theme, required this.filtered});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filtered ? Icons.search_off : Icons.folder_open_outlined,
              color: theme.textSecondary.withOpacity(0.42),
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No hay estudios con esos filtros.'
                  : 'Todavía no hay estudios guardados.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: theme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedStudiesList extends StatelessWidget {
  final List<StudyChapterAnswers> studies;
  final _SavedStudyGrouping grouping;
  final BibleReaderThemeData theme;
  final ScrollController scrollController;
  final Set<String> deletingKeys;
  final ValueChanged<StudyChapterAnswers> onOpen;
  final ValueChanged<StudyChapterAnswers> onDelete;

  const _SavedStudiesList({
    required this.studies,
    required this.grouping,
    required this.theme,
    required this.scrollController,
    required this.deletingKeys,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: grouping == _SavedStudyGrouping.book
          ? _bookGroupedChildren()
          : _flatChildren(),
    );
  }

  List<Widget> _flatChildren() {
    return [
      for (final study in studies) ...[
        _SavedStudyTile(
          study: study,
          theme: theme,
          deleting: deletingKeys.contains(study.chapterKey),
          onOpen: () => onOpen(study),
          onDelete: () => onDelete(study),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }

  List<Widget> _bookGroupedChildren() {
    final groups = <int, List<StudyChapterAnswers>>{};
    for (final study in studies) {
      groups.putIfAbsent(study.bookNumber, () => []).add(study);
    }
    final keys = groups.keys.toList()..sort();
    final children = <Widget>[];
    for (final key in keys) {
      final group = groups[key]!;
      group.sort((a, b) {
        final byChapter = a.chapter.compareTo(b.chapter);
        if (byChapter != 0) return byChapter;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      children.add(
        _SavedStudyGroupHeader(theme: theme, label: _bookLabel(group.first)),
      );
      for (final study in group) {
        children.add(
          _SavedStudyTile(
            study: study,
            theme: theme,
            deleting: deletingKeys.contains(study.chapterKey),
            onOpen: () => onOpen(study),
            onDelete: () => onDelete(study),
          ),
        );
        children.add(const SizedBox(height: 10));
      }
    }
    return children;
  }

  String _bookLabel(StudyChapterAnswers study) {
    return study.bookName.trim().isEmpty
        ? 'Libro ${study.bookNumber}'
        : study.bookName;
  }
}

class _SavedStudyGroupHeader extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String label;

  const _SavedStudyGroupHeader({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: theme.accent,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SavedStudyTile extends StatelessWidget {
  final StudyChapterAnswers study;
  final BibleReaderThemeData theme;
  final bool deleting;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _SavedStudyTile({
    required this.study,
    required this.theme,
    required this.deleting,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final answeredCount = study.answers.values
        .where((answer) => answer.trim().isNotEmpty)
        .length;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: deleting ? null : onOpen,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.textSecondary.withOpacity(0.09)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _referenceLabel(study),
                    style: GoogleFonts.lora(
                      color: t.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (deleting)
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      color: t.accent,
                      strokeWidth: 1.5,
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Eliminar estudio',
                    icon: Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent.withOpacity(0.78),
                    ),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints.tightFor(
                      width: 36,
                      height: 34,
                    ),
                    padding: EdgeInsets.zero,
                    onPressed: onDelete,
                  ),
                  Icon(Icons.chevron_right, color: t.textSecondary, size: 20),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StudyMiniChip(label: 'Cap. ${study.chapter}', theme: t),
                _StudyMiniChip(label: study.versionId, theme: t),
                _StudyMiniChip(label: '$answeredCount respuestas', theme: t),
                if (study.studyStartVerse != null &&
                    study.studyEndVerse != null)
                  _StudyMiniChip(label: _rangeChipLabel(study), theme: t),
                if (study.generalNotes.trim().isNotEmpty)
                  _StudyMiniChip(label: 'Notas', theme: t),
                if (study.hopeMessage.trim().isNotEmpty)
                  _StudyMiniChip(label: 'Esperanza', theme: t),
                if (study.sortedMainVerses.isNotEmpty)
                  _StudyMiniChip(label: 'Verso principal', theme: t),
                _StudyMiniChip(label: _date(study.updatedAt), theme: t),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _referenceLabel(StudyChapterAnswers study) {
    final bookName = study.bookName.trim().isEmpty
        ? 'Libro ${study.bookNumber}'
        : study.bookName;
    if (study.studyStartVerse != null && study.studyEndVerse != null) {
      if (study.studyStartVerse == study.studyEndVerse) {
        return '$bookName ${study.chapter}:${study.studyStartVerse}';
      }
      return '$bookName ${study.chapter}:${study.studyStartVerse}-${study.studyEndVerse}';
    }
    return '$bookName ${study.chapter}';
  }

  String _rangeChipLabel(StudyChapterAnswers study) {
    if (study.studyStartVerse == study.studyEndVerse) {
      return 'v. ${study.studyStartVerse}';
    }
    return 'v. ${study.studyStartVerse}-${study.studyEndVerse}';
  }

  String _date(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
  }
}

class _DeleteStudyChoice {
  final bool deleteHighlights;
  const _DeleteStudyChoice({required this.deleteHighlights});
}

class _DeleteStudyDialog extends StatefulWidget {
  final StudyChapterAnswers study;

  const _DeleteStudyDialog({required this.study});

  @override
  State<_DeleteStudyDialog> createState() => _DeleteStudyDialogState();
}

class _DeleteStudyDialogState extends State<_DeleteStudyDialog> {
  bool _deleteHighlights = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Eliminar estudio'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Se eliminará ${widget.study.reference} de tus estudios guardados.',
          ),
          const SizedBox(height: 10),
          CheckboxListTile(
            value: _deleteHighlights,
            onChanged: (value) =>
                setState(() => _deleteHighlights = value ?? false),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('También borrar subrayados de este capítulo'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.delete_outline, size: 17),
          label: const Text('Eliminar'),
          onPressed: () => Navigator.pop(
            context,
            _DeleteStudyChoice(deleteHighlights: _deleteHighlights),
          ),
        ),
      ],
    );
  }
}

class _StudyMiniChip extends StatelessWidget {
  final String label;
  final BibleReaderThemeData theme;

  const _StudyMiniChip({required this.label, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.textSecondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: t.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _PdfExportAction { share, downloads }

class _PdfExportActionSheet extends StatelessWidget {
  const _PdfExportActionSheet();

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exportar PDF',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _PdfActionTile(
              icon: Icons.ios_share_outlined,
              title: 'Compartir',
              subtitle: 'Enviar por WhatsApp, correo u otra app.',
              theme: t,
              onTap: () => Navigator.pop(context, _PdfExportAction.share),
            ),
            const SizedBox(height: 8),
            _PdfActionTile(
              icon: Icons.download_outlined,
              title: 'Guardar en Descargas',
              subtitle: 'Crear el archivo PDF en la carpeta de descargas.',
              theme: t,
              onTap: () => Navigator.pop(context, _PdfExportAction.downloads),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final BibleReaderThemeData theme;
  final VoidCallback onTap;

  const _PdfActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: t.isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.textSecondary.withOpacity(0.09)),
        ),
        child: Row(
          children: [
            Icon(icon, color: t.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      color: t.textSecondary,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionPairResult {
  final BibleVersion primary;
  final BibleVersion secondary;
  const _VersionPairResult(this.primary, this.secondary);
}

class _VersionPairSheet extends StatefulWidget {
  final BibleVersion initialPrimary;
  final BibleVersion initialSecondary;

  const _VersionPairSheet({
    required this.initialPrimary,
    required this.initialSecondary,
  });

  @override
  State<_VersionPairSheet> createState() => _VersionPairSheetState();
}

class _VersionPairSheetState extends State<_VersionPairSheet> {
  late BibleVersion _primary;
  late BibleVersion _secondary;

  @override
  void initState() {
    super.initState();
    _primary = widget.initialPrimary;
    _primary = BibleDownloadService.I.bestAvailableVersion(_primary);
    _secondary =
        widget.initialSecondary == _primary ||
            !BibleDownloadService.I.isAvailable(widget.initialSecondary)
        ? _fallbackSecondary(_primary)
        : widget.initialSecondary;
  }

  BibleVersion _fallbackSecondary(BibleVersion primary) {
    return BibleDownloadService.I.bestAvailableSecondary(primary);
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Versiones para estudiar',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Se recomienda leer el pasaje en dos traducciones. La primera '
              'mantiene tus subrayados; la segunda sirve para comparar.',
              style: GoogleFonts.manrope(
                color: t.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            _VersionDropdown(
              label: 'Versión 1',
              value: _primary,
              theme: t,
              onChanged: (next) => setState(() {
                _primary = next;
                if (_secondary == next) {
                  _secondary = _fallbackSecondary(next);
                }
              }),
            ),
            const SizedBox(height: 12),
            _VersionDropdown(
              label: 'Versión 2',
              value: _secondary,
              theme: t,
              exclude: _primary,
              onChanged: (next) => setState(() => _secondary = next),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(color: t.textSecondary),
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: t.accent,
                    foregroundColor: t.background,
                  ),
                  icon: const Icon(Icons.compare_arrows, size: 17),
                  label: Text(
                    '${_primary.shortName} + ${_secondary.shortName}',
                  ),
                  onPressed: () => Navigator.pop(
                    context,
                    _VersionPairResult(_primary, _secondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionDropdown extends StatelessWidget {
  final String label;
  final BibleVersion value;
  final BibleVersion? exclude;
  final BibleReaderThemeData theme;
  final ValueChanged<BibleVersion> onChanged;

  const _VersionDropdown({
    required this.label,
    required this.value,
    required this.theme,
    required this.onChanged,
    this.exclude,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final versions = BibleDownloadService.I.availableVersions
        .where((version) => version != exclude)
        .toList(growable: false);
    if (versions.isEmpty) {
      return TextFormField(
        enabled: false,
        initialValue: 'Descarga otra versión en Ajustes de Biblia',
        style: GoogleFonts.manrope(color: t.textSecondary, fontSize: 13),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.manrope(color: t.textSecondary),
          filled: true,
          fillColor: t.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.textSecondary.withOpacity(0.14)),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: t.textSecondary.withOpacity(0.14)),
          ),
        ),
      );
    }
    final effectiveValue = versions.contains(value) ? value : versions.first;
    return DropdownButtonFormField<BibleVersion>(
      value: effectiveValue,
      items: [
        for (final version in versions)
          DropdownMenuItem(
            value: version,
            child: Text('${version.shortName} · ${version.displayName}'),
          ),
      ],
      onChanged: (version) {
        if (version != null) onChanged(version);
      },
      dropdownColor: t.surface,
      style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.manrope(color: t.textSecondary),
        filled: true,
        fillColor: t.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.textSecondary.withOpacity(0.14)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.textSecondary.withOpacity(0.14)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: t.accent),
        ),
      ),
    );
  }
}

class _RangeResult {
  final int? start;
  final int? end;
  const _RangeResult(this.start, this.end);
}

/// Bottom sheet para elegir un rango de versículos a estudiar.
class _VerseRangeSheet extends StatefulWidget {
  final int maxVerse;
  final int? initialStart;
  final int? initialEnd;
  const _VerseRangeSheet({
    required this.maxVerse,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<_VerseRangeSheet> createState() => _VerseRangeSheetState();
}

class _VerseRangeSheetState extends State<_VerseRangeSheet> {
  late int _start;
  late int _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart ?? 1;
    _end = widget.initialEnd ?? widget.maxVerse;
    if (_end < _start) _end = _start;
  }

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 3,
              decoration: BoxDecoration(
                color: t.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Versículos a estudiar',
            style: GoogleFonts.cinzel(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Las respuestas, el mensaje de esperanza y el Verso Principal '
            'se mostrarán como nota en cada uno de los versículos seleccionados.',
            style: GoogleFonts.manrope(
              color: t.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _NumberPicker(
                  label: 'Desde',
                  value: _start,
                  min: 1,
                  max: widget.maxVerse,
                  theme: t,
                  onChanged: (v) => setState(() {
                    _start = v;
                    if (_end < _start) _end = _start;
                  }),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _NumberPicker(
                  label: 'Hasta',
                  value: _end,
                  min: _start,
                  max: widget.maxVerse,
                  theme: t,
                  onChanged: (v) => setState(() => _end = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              TextButton.icon(
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('Capítulo completo'),
                style: TextButton.styleFrom(foregroundColor: t.textSecondary),
                onPressed: () =>
                    Navigator.pop(context, const _RangeResult(null, null)),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.background,
                ),
                onPressed: () =>
                    Navigator.pop(context, _RangeResult(_start, _end)),
                child: Text(
                  _start == _end
                      ? 'Estudiar v. $_start'
                      : 'Estudiar v. $_start–$_end',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NumberPicker extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final BibleReaderThemeData theme;
  final ValueChanged<int> onChanged;
  const _NumberPicker({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.theme,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.manrope(
            color: t.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: t.textSecondary.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.remove, color: t.textSecondary, size: 18),
                onPressed: value > min ? () => onChanged(value - 1) : null,
              ),
              Expanded(
                child: Text(
                  '$value',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cinzel(
                    color: t.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.add, color: t.textSecondary, size: 18),
                onPressed: value < max ? () => onChanged(value + 1) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet con tamaño de letra y selector de tema, accesible desde el
/// header del Modo Estudio.
class _TypographySheet extends StatelessWidget {
  final BibleReaderThemeData theme;
  const _TypographySheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: t.textSecondary.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TEXTO Y COLORES',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<double>(
              valueListenable: BibleUserDataService.I.fontSizeNotifier,
              builder: (_, size, _) {
                return Row(
                  children: [
                    Text(
                      'A',
                      style: GoogleFonts.lora(
                        color: t.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        value: size,
                        min: 14,
                        max: 28,
                        divisions: 7,
                        activeColor: t.accent,
                        inactiveColor: t.textSecondary.withOpacity(0.2),
                        onChanged: (v) => BibleUserDataService.I.setFontSize(v),
                      ),
                    ),
                    Text(
                      'A',
                      style: GoogleFonts.lora(
                        color: t.textSecondary,
                        fontSize: 26,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'TEMA',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<String>(
              valueListenable: BibleUserDataService.I.readerThemeNotifier,
              builder: (_, currentId, _) {
                final migrated = BibleReaderThemeData.migrateId(currentId);
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: BibleReaderThemeData.all.map((th) {
                    final isActive = th.id == migrated;
                    return GestureDetector(
                      onTap: () => BibleUserDataService.I.setReaderTheme(th.id),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: th.swatchColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isActive
                                ? t.accent
                                : t.textSecondary.withOpacity(0.2),
                            width: isActive ? 2.5 : 1,
                          ),
                        ),
                        child: isActive
                            ? Icon(
                                Icons.check,
                                color: th.isDark
                                    ? Colors.white70
                                    : Colors.black54,
                                size: 16,
                              )
                            : null,
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
