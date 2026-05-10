import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/bible_book.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/study_chapter_answers.dart';
import '../../models/bible/study_room.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/study_export_service.dart';
import '../../services/bible/study_mode_service.dart';
import '../../services/bible/study_room_service.dart';
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
  final Map<String, String> _draftAnswers = {};
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _generalNotesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bookNumber = widget.bookNumber;
    _bookName = widget.bookName;
    _chapter = widget.chapter;
    _version =
        widget.version ?? BibleUserDataService.I.preferredVersionNotifier.value;
    _secondaryVersion = _defaultSecondaryVersion(_version);
    _tabController = TabController(length: 2, vsync: this);
    for (final q in kStudyQuestions) {
      _controllers[q.id] = TextEditingController();
    }
    StudyRoomService.I.currentRoomNotifier.addListener(_onRoomChanged);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
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
      _books = await BibleParserService.I.getBooks(_version);
      final verses = await BibleParserService.I.getChapter(
        version: _version,
        bookNumber: _bookNumber,
        chapter: _chapter,
      );
      final secondaryVerses = await BibleParserService.I.getChapter(
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
    if (primary != BibleVersion.nvi) return BibleVersion.nvi;
    return BibleVersion.rvr1960;
  }

  void _hydrateAnswers() {
    final study = StudyModeService.I.answersFor(_bookNumber, _chapter);
    final existing = study?.answers ?? const <String, String>{};
    _draftAnswers
      ..clear()
      ..addAll(existing);
    for (final q in kStudyQuestions) {
      _controllers[q.id]!.text = existing[q.id] ?? '';
    }
    _generalNotesController.text = study?.generalNotes ?? '';
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

  Future<void> _flushAnswers() async {
    final existing = StudyModeService.I.answersFor(_bookNumber, _chapter);
    final base =
        existing ??
        StudyChapterAnswers.empty(
          bookNumber: _bookNumber,
          bookName: _bookName,
          chapter: _chapter,
          versionId: _version.id,
        );
    final merged = _answersFromControllers();
    await StudyModeService.I.saveAnswers(
      base.copyWith(
        answers: merged,
        generalNotes: _generalNotesController.text.trim(),
        versionId: _version.id,
      ),
    );
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
    final existing = StudyModeService.I.answersFor(_bookNumber, _chapter);
    final base =
        existing ??
        StudyChapterAnswers.empty(
          bookNumber: _bookNumber,
          bookName: _bookName,
          chapter: _chapter,
          versionId: _version.id,
        );
    return base.copyWith(
      answers: _answersFromControllers(),
      generalNotes: _generalNotesController.text.trim(),
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
      builder: (_) => _SavedStudiesSheet(studies: studies),
    );
    if (result == null) return;
    await _openSavedStudy(result);
  }

  Future<void> _openSavedStudy(StudyChapterAnswers study) async {
    await _flushAnswers();
    final primary = BibleVersion.fromId(study.versionId);
    final secondary = primary == _secondaryVersion
        ? _defaultSecondaryVersion(primary)
        : _secondaryVersion;
    setState(() {
      _bookNumber = study.bookNumber;
      _bookName = study.bookName;
      _chapter = study.chapter;
      _version = primary;
      _secondaryVersion = secondary;
    });
    await _loadChapter();
    _hydrateAnswers();
  }

  Future<void> _changeVersions(
    BibleVersion primary,
    BibleVersion secondary,
  ) async {
    await _flushAnswers();
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
      final secondary = primary == _secondaryVersion
          ? _defaultSecondaryVersion(primary)
          : _secondaryVersion;
      final passageChanged =
          room.bookNumber != _bookNumber ||
          room.bookName != _bookName ||
          room.chapter != _chapter;
      final versionsChanged =
          primary != _version || secondary != _secondaryVersion;

      if (passageChanged || versionsChanged) {
        await _flushAnswers();
        if (!mounted) return;
        setState(() {
          _bookNumber = room.bookNumber;
          _bookName = room.bookName;
          _chapter = room.chapter;
          _version = primary;
          _secondaryVersion = secondary;
        });
        await _loadChapter();
        _hydrateAnswers();
      }

      await StudyModeService.I.setStudyRange(
        bookNumber: room.bookNumber,
        bookName: room.bookName,
        chapter: room.chapter,
        versionId: primary.id,
        startVerse: room.startVerse,
        endVerse: room.endVerse,
      );
      if (mounted) setState(() {});
    } finally {
      _applyingRoomState = false;
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
    final current = StudyModeService.I.answersFor(_bookNumber, _chapter);
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
    await StudyModeService.I.setStudyRange(
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
    final current = StudyModeService.I.answersFor(_bookNumber, _chapter);
    final s = current?.studyStartVerse;
    final e = current?.studyEndVerse;
    if (s == null || e == null) return 'Capítulo completo';
    return s == e ? 'v. $s' : 'v. $s-$e';
  }

  List<BibleVerse> _visibleVerses() {
    final current = StudyModeService.I.answersFor(_bookNumber, _chapter);
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
    final current = StudyModeService.I.answersFor(_bookNumber, _chapter);
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
    return '${_version.shortName} + ${_secondaryVersion.shortName}';
  }

  Future<void> _exportPdf() async {
    try {
      await _flushAnswers();
      final action = await _pickPdfExportAction();
      if (action == null) return;
      final study = _currentStudySnapshot();
      final highlights = StudyModeService.I.highlightsNotifier.value;
      final file = action == _PdfExportAction.share
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
        final current = StudyModeService.I.answersFor(_bookNumber, _chapter);
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
    );
  }

  Widget _buildQuestionsPanel(BibleReaderThemeData t) {
    return StudyQuestionsPanel(
      theme: t,
      controllers: _controllers,
      generalNotesController: _generalNotesController,
      onChanged: _onAnswerChanged,
      onGeneralNotesChanged: _onGeneralNotesChanged,
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

class _SavedStudiesSheet extends StatelessWidget {
  final List<StudyChapterAnswers> studies;

  const _SavedStudiesSheet({required this.studies});

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );
    return DraggableScrollableSheet(
      initialChildSize: studies.isEmpty ? 0.34 : 0.72,
      minChildSize: 0.28,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      Icon(Icons.folder_open_outlined, color: t.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Estudios guardados',
                          style: GoogleFonts.cinzel(
                            color: t.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: studies.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              'Todavía no hay estudios guardados.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.manrope(
                                color: t.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: studies.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) =>
                              _SavedStudyTile(study: studies[i], theme: t),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SavedStudyTile extends StatelessWidget {
  final StudyChapterAnswers study;
  final BibleReaderThemeData theme;

  const _SavedStudyTile({required this.study, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final answeredCount = study.answers.values
        .where((answer) => answer.trim().isNotEmpty)
        .length;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => Navigator.pop(context, study),
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
                Icon(Icons.chevron_right, color: t.textSecondary, size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _StudyMiniChip(label: study.versionId, theme: t),
                _StudyMiniChip(label: '$answeredCount respuestas', theme: t),
                if (study.generalNotes.trim().isNotEmpty)
                  _StudyMiniChip(label: 'Notas', theme: t),
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

  String _date(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year}';
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
    _secondary = widget.initialSecondary == widget.initialPrimary
        ? _fallbackSecondary(widget.initialPrimary)
        : widget.initialSecondary;
  }

  BibleVersion _fallbackSecondary(BibleVersion primary) {
    if (primary != BibleVersion.nvi) return BibleVersion.nvi;
    return BibleVersion.rvr1960;
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
    final versions = BibleVersion.values
        .where((version) => version != exclude)
        .toList(growable: false);
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
            'Las respuestas de las 6 preguntas se mostrarán como nota '
            'en cada uno de los versículos seleccionados.',
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
