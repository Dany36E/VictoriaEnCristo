import 'dart:async';

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
import '../../services/bible/study_mode_service.dart';
import '../../services/bible/study_room_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../widgets/bible/study/study_chapter_picker.dart';
import '../../widgets/bible/study/study_onboarding_overlay.dart';
import '../../widgets/bible/study/study_reading_panel.dart';
import '../../widgets/bible/study/study_questions_panel.dart';
import '../../widgets/bible/study/study_room_banner.dart';
import '../../widgets/bible/study/study_room_dialogs.dart';

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

  const StudyModeScreen({
    super.key,
    this.bookNumber = 1,
    this.bookName = 'Génesis',
    this.chapter = 1,
    this.version,
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

  List<BibleBook> _books = const [];
  List<BibleVerse> _verses = const [];
  bool _loading = true;

  late final TabController _tabController;
  Timer? _saveDebounce;
  final Map<String, String> _draftAnswers = {};
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _bookNumber = widget.bookNumber;
    _bookName = widget.bookName;
    _chapter = widget.chapter;
    _version = widget.version ??
        BibleUserDataService.I.preferredVersionNotifier.value;
    _tabController = TabController(length: 2, vsync: this);
    for (final q in kStudyQuestions) {
      _controllers[q.id] = TextEditingController();
    }
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _loadChapter();
    _hydrateAnswers();
    // Onboarding (primer uso)
    final seen = await StudyModeService.I.hasSeenOnboarding();
    if (!seen && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const StudyOnboardingOverlay(),
        ).then((_) => StudyModeService.I.markOnboardingSeen());
      });
    }
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
      if (!mounted) return;
      setState(() {
        _verses = verses;
        _loading = false;
      });
    } catch (e) {
      debugPrint('[STUDY-MODE] load chapter error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  void _hydrateAnswers() {
    final existing =
        StudyModeService.I.answersFor(_bookNumber, _chapter)?.answers ??
            const <String, String>{};
    _draftAnswers
      ..clear()
      ..addAll(existing);
    for (final q in kStudyQuestions) {
      _controllers[q.id]!.text = existing[q.id] ?? '';
    }
  }

  void _onAnswerChanged(String questionId, String value) {
    _draftAnswers[questionId] = value;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 700), _flushAnswers);
  }

  Future<void> _flushAnswers() async {
    final existing = StudyModeService.I.answersFor(_bookNumber, _chapter);
    final base = existing ??
        StudyChapterAnswers.empty(
          bookNumber: _bookNumber,
          bookName: _bookName,
          chapter: _chapter,
          versionId: _version.id,
        );
    final merged = <String, String>{...base.answers, ..._draftAnswers};
    await StudyModeService.I.saveAnswers(base.copyWith(answers: merged));
  }

  Future<void> _changeChapter(int bookNumber, String bookName, int chapter) async {
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

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _flushAnswers(); // sin await — se ejecutará en background
    for (final c in _controllers.values) {
      c.dispose();
    }
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
                        color: t.accent, strokeWidth: 1.5))
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
                                onRotate: () =>
                                    StudyRoomService.I.rotateNow(),
                                onVersionAssigned: _onAssignedVersionChanged,
                              );
                            },
                          ),
                          Expanded(
                            child: isWide
                                ? _buildSplit(t)
                                : _buildTabbed(t),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new,
                color: t.textSecondary, size: 18),
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
                        horizontal: 10, vertical: 4),
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
                        Icon(Icons.expand_more,
                            color: t.accent, size: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Tutorial',
            icon: Icon(Icons.help_outline,
                color: t.textSecondary.withOpacity(0.6), size: 20),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const StudyOnboardingOverlay(),
            ),
          ),
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
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                Icon(Icons.format_list_numbered,
                    color: t.textSecondary, size: 14),
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

  Future<void> _openRoomDialog() async {
    final current = StudyRoomService.I.currentRoomNotifier.value;
    if (current != null) {
      // Si ya está en una sala, ofrecer ver/salir.
      await showDialog(
        context: context,
        builder: (_) => StudyRoomActiveDialog(
          room: current,
          onLeave: _confirmLeaveRoom,
        ),
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
        final room = await StudyRoomService.I.createRoom(
          bookNumber: _bookNumber,
          bookName: _bookName,
          chapter: _chapter,
          versionId: _version.id,
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
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
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
    setState(() => _version = v);
    _loadChapter();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  Widget _buildSplit(BibleReaderThemeData t) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _buildReadingPanel(t)),
        Container(
          width: 1,
          color: t.textSecondary.withOpacity(0.12),
        ),
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
            children: [
              _buildReadingPanel(t),
              _buildQuestionsPanel(t),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadingPanel(BibleReaderThemeData t) {
    return StudyReadingPanel(
      key: ValueKey('reading_${_bookNumber}_$_chapter'),
      theme: t,
      verses: _verses,
      bookNumber: _bookNumber,
      chapter: _chapter,
    );
  }

  Widget _buildQuestionsPanel(BibleReaderThemeData t) {
    return StudyQuestionsPanel(
      theme: t,
      controllers: _controllers,
      onChanged: _onAnswerChanged,
      onManualSave: _flushAnswers,
      reference: '$_bookName $_chapter',
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
                style: TextButton.styleFrom(
                  foregroundColor: t.textSecondary,
                ),
                onPressed: () => Navigator.pop(
                  context,
                  const _RangeResult(null, null),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.background,
                ),
                onPressed: () => Navigator.pop(
                  context,
                  _RangeResult(_start, _end),
                ),
                child: Text(_start == _end
                    ? 'Estudiar v. $_start'
                    : 'Estudiar v. $_start–$_end'),
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
        Text(label,
            style: GoogleFonts.manrope(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6)),
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

