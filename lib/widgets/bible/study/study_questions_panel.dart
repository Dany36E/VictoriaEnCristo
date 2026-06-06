import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/rich_note_document.dart';
import '../../../models/bible/study_chapter_answers.dart';
import '../../../theme/bible_reader_theme.dart';
import '../sermon/sermon_rich_text_controller.dart';

/// Panel derecho del Modo Estudio: preguntas, notas y cierre con autosave.
class StudyQuestionsPanel extends StatelessWidget {
  final BibleReaderThemeData theme;
  final Map<String, TextEditingController> controllers;
  final SermonRichTextController generalNotesController;
  final TextEditingController hopeMessageController;
  final List<int> mainVerseNumbers;
  final Set<int> selectedMainVerses;
  final String mainVerseReference;
  final void Function(String questionId, String value) onChanged;
  final ValueChanged<String> onGeneralNotesChanged;
  final ValueChanged<String> onHopeMessageChanged;
  final void Function(int verseNumber, bool selected) onMainVerseToggled;
  final Future<void> Function() onManualSave;
  final Future<void> Function() onExportPdf;
  final VoidCallback onPickSavedStudy;
  final VoidCallback onPickRange;
  final VoidCallback onAddPassage;
  final VoidCallback onPickVersions;
  final VoidCallback onSwapVersions;
  final VoidCallback onOpenTextSettings;
  final String generalNotesSaveStatusLabel;
  final bool canGeneralNotesUndo;
  final bool canGeneralNotesRedo;
  final VoidCallback onGeneralNotesUndo;
  final VoidCallback onGeneralNotesRedo;
  final String reference;
  final String rangeLabel;
  final String versionsLabel;
  final bool roomMode;

  const StudyQuestionsPanel({
    super.key,
    required this.theme,
    required this.controllers,
    required this.generalNotesController,
    required this.hopeMessageController,
    required this.mainVerseNumbers,
    required this.selectedMainVerses,
    required this.mainVerseReference,
    required this.onChanged,
    required this.onGeneralNotesChanged,
    required this.onHopeMessageChanged,
    required this.onMainVerseToggled,
    required this.onManualSave,
    required this.onExportPdf,
    required this.onPickSavedStudy,
    required this.onPickRange,
    required this.onAddPassage,
    required this.onPickVersions,
    required this.onSwapVersions,
    required this.onOpenTextSettings,
    required this.generalNotesSaveStatusLabel,
    required this.canGeneralNotesUndo,
    required this.canGeneralNotesRedo,
    required this.onGeneralNotesUndo,
    required this.onGeneralNotesRedo,
    required this.reference,
    required this.rangeLabel,
    required this.versionsLabel,
    this.roomMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: kStudyQuestions.length + 3,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (_, i) {
        if (i == 0) {
          return _QuestionsToolbar(
            theme: t,
            reference: reference,
            rangeLabel: rangeLabel,
            versionsLabel: versionsLabel,
            roomMode: roomMode,
            onPickSavedStudy: onPickSavedStudy,
            onPickRange: onPickRange,
            onAddPassage: onAddPassage,
            onPickVersions: onPickVersions,
            onSwapVersions: onSwapVersions,
            onOpenTextSettings: onOpenTextSettings,
            onManualSave: onManualSave,
            onExportPdf: onExportPdf,
          );
        }
        if (i == 1) {
          return _GeneralNotesCard(
            controller: generalNotesController,
            onChanged: onGeneralNotesChanged,
            theme: t,
            saveStatusLabel: generalNotesSaveStatusLabel,
            canUndo: canGeneralNotesUndo,
            canRedo: canGeneralNotesRedo,
            onUndo: onGeneralNotesUndo,
            onRedo: onGeneralNotesRedo,
          );
        }
        if (i == kStudyQuestions.length + 2) {
          return _HopeMessageCard(
            controller: hopeMessageController,
            onChanged: onHopeMessageChanged,
            verseNumbers: mainVerseNumbers,
            selectedVerses: selectedMainVerses,
            mainVerseReference: mainVerseReference,
            onVerseToggled: onMainVerseToggled,
            theme: t,
          );
        }
        final q = kStudyQuestions[i - 2];
        return _QuestionCard(
          index: i - 1,
          question: q,
          controller: controllers[q.id]!,
          onChanged: (v) => onChanged(q.id, v),
          theme: t,
        );
      },
    );
  }
}

class _HopeMessageCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<int> verseNumbers;
  final Set<int> selectedVerses;
  final String mainVerseReference;
  final void Function(int verseNumber, bool selected) onVerseToggled;
  final BibleReaderThemeData theme;

  const _HopeMessageCard({
    required this.controller,
    required this.onChanged,
    required this.verseNumbers,
    required this.selectedVerses,
    required this.mainVerseReference,
    required this.onVerseToggled,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(t.isDark ? 0.08 : 0.10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.accent.withOpacity(0.22), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.wb_sunny_outlined, color: t.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Mensaje de esperanza',
                  style: GoogleFonts.lora(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Resume la esperanza central que Dios te muestra en este texto.',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.65),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            minLines: 3,
            style: GoogleFonts.lora(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Ej. Jesús quiere sanarte y darte vida nueva.',
              hintStyle: GoogleFonts.lora(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: 14,
              ),
              filled: true,
              fillColor: t.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.textSecondary.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.textSecondary.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.accent, width: 1.2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.bookmark_border, color: t.accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verso Principal',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Selecciona uno o varios versículos que sostienen ese mensaje.',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.62),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          _VerseChips(
            theme: t,
            verseNumbers: verseNumbers,
            selectedVerses: selectedVerses,
            onVerseToggled: onVerseToggled,
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: t.background.withOpacity(t.isDark ? 0.62 : 0.82),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.textSecondary.withOpacity(0.10)),
            ),
            child: Text(
              mainVerseReference,
              style: GoogleFonts.manrope(
                color: selectedVerses.isEmpty
                    ? t.textSecondary.withOpacity(0.65)
                    : t.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseChips extends StatelessWidget {
  final BibleReaderThemeData theme;
  final List<int> verseNumbers;
  final Set<int> selectedVerses;
  final void Function(int verseNumber, bool selected) onVerseToggled;

  const _VerseChips({
    required this.theme,
    required this.verseNumbers,
    required this.selectedVerses,
    required this.onVerseToggled,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    if (verseNumbers.isEmpty) {
      return Text(
        'No hay versículos cargados para seleccionar.',
        style: GoogleFonts.manrope(
          color: t.textSecondary.withOpacity(0.62),
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      );
    }
    final chips = Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final verseNumber in verseNumbers)
          _MainVerseChip(
            theme: t,
            verseNumber: verseNumber,
            selected: selectedVerses.contains(verseNumber),
            onSelected: (selected) => onVerseToggled(verseNumber, selected),
          ),
      ],
    );
    if (verseNumbers.length <= 36) return chips;
    return SizedBox(height: 132, child: SingleChildScrollView(child: chips));
  }
}

class _MainVerseChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final int verseNumber;
  final bool selected;
  final ValueChanged<bool> onSelected;

  const _MainVerseChip({
    required this.theme,
    required this.verseNumber,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return FilterChip(
      label: Text('$verseNumber'),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      backgroundColor: t.background,
      selectedColor: t.accent.withOpacity(t.isDark ? 0.24 : 0.18),
      side: BorderSide(
        color: selected
            ? t.accent.withOpacity(0.68)
            : t.textSecondary.withOpacity(0.16),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      labelStyle: GoogleFonts.manrope(
        color: selected ? t.accent : t.textPrimary,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    );
  }
}

enum _StudyPanelAction { savedStudies, saveProgress, exportPdf }

class _QuestionsToolbar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String reference;
  final String rangeLabel;
  final String versionsLabel;
  final bool roomMode;
  final VoidCallback onPickSavedStudy;
  final VoidCallback onPickRange;
  final VoidCallback onAddPassage;
  final VoidCallback onPickVersions;
  final VoidCallback onSwapVersions;
  final VoidCallback onOpenTextSettings;
  final Future<void> Function() onManualSave;
  final Future<void> Function() onExportPdf;

  const _QuestionsToolbar({
    required this.theme,
    required this.reference,
    required this.rangeLabel,
    required this.versionsLabel,
    required this.roomMode,
    required this.onPickSavedStudy,
    required this.onPickRange,
    required this.onAddPassage,
    required this.onPickVersions,
    required this.onSwapVersions,
    required this.onOpenTextSettings,
    required this.onManualSave,
    required this.onExportPdf,
  });

  Future<void> _handleMenuAction(
    BuildContext context,
    _StudyPanelAction action,
  ) async {
    switch (action) {
      case _StudyPanelAction.savedStudies:
        onPickSavedStudy();
        break;
      case _StudyPanelAction.saveProgress:
        await onManualSave();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Estudio guardado'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        break;
      case _StudyPanelAction.exportPdf:
        await onExportPdf();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      decoration: BoxDecoration(
        color: t.isDark
            ? Colors.white.withOpacity(0.025)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.textSecondary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tus respuestas · $reference',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.75),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              PopupMenuButton<_StudyPanelAction>(
                tooltip: 'Más acciones',
                color: t.surface,
                icon: Icon(Icons.more_horiz, color: t.accent, size: 22),
                onSelected: (action) async {
                  await _handleMenuAction(context, action);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: _StudyPanelAction.savedStudies,
                    child: Text('Estudios guardados'),
                  ),
                  const PopupMenuItem(
                    value: _StudyPanelAction.saveProgress,
                    child: Text('Guardar progreso'),
                  ),
                  const PopupMenuItem(
                    value: _StudyPanelAction.exportPdf,
                    child: Text('Exportar PDF'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _QuestionToolChip(
                theme: t,
                icon: Icons.text_fields,
                label: 'Texto y colores',
                onTap: onOpenTextSettings,
                emphasized: true,
              ),
              _QuestionToolChip(
                theme: t,
                icon: Icons.format_list_numbered,
                label: 'Rango: $rangeLabel',
                onTap: onPickRange,
              ),
              _QuestionToolChip(
                theme: t,
                icon: Icons.add_location_alt_outlined,
                label: 'Añadir pasaje',
                onTap: onAddPassage,
              ),
              _QuestionToolChip(
                theme: t,
                icon: roomMode
                    ? Icons.menu_book_outlined
                    : Icons.compare_arrows,
                label: versionsLabel,
                onTap: roomMode ? null : onPickVersions,
              ),
              if (!roomMode)
                _QuestionIconChip(
                  theme: t,
                  tooltip: 'Intercambiar versiones',
                  icon: Icons.swap_vert,
                  onTap: onSwapVersions,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionToolChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool emphasized;

  const _QuestionToolChip({
    required this.theme,
    required this.icon,
    required this.label,
    required this.onTap,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final disabled = onTap == null;
    final foreground = emphasized
        ? t.background
        : disabled
        ? t.textSecondary.withOpacity(0.72)
        : t.accent;
    final background = emphasized
        ? t.accent
        : disabled
        ? t.textSecondary.withOpacity(t.isDark ? 0.09 : 0.06)
        : t.accent.withOpacity(t.isDark ? 0.10 : 0.07);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: t.accent.withOpacity(0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionIconChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _QuestionIconChip({
    required this.theme,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.accent.withOpacity(t.isDark ? 0.10 : 0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: t.accent.withOpacity(0.24)),
          ),
          child: Icon(icon, size: 17, color: t.accent),
        ),
      ),
    );
  }
}

class _GeneralNotesCard extends StatefulWidget {
  final SermonRichTextController controller;
  final ValueChanged<String> onChanged;
  final BibleReaderThemeData theme;
  final String saveStatusLabel;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;

  const _GeneralNotesCard({
    required this.controller,
    required this.onChanged,
    required this.theme,
    required this.saveStatusLabel,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
  });

  @override
  State<_GeneralNotesCard> createState() => _GeneralNotesCardState();
}

class _GeneralNotesCardState extends State<_GeneralNotesCard> {
  final _spellCheckService = DefaultSpellCheckService();
  final Set<String> _ignoredTokens = <String>{};
  Timer? _spellCheckDebounce;
  List<SuggestionSpan> _spellSuggestions = const <SuggestionSpan>[];
  String _lastText = '';
  TextSelection _lastSelection = const TextSelection.collapsed(offset: -1);

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    _lastSelection = widget.controller.selection;
    widget.controller.addListener(_onControllerChanged);
    _scheduleSpellCheck();
  }

  @override
  void didUpdateWidget(covariant _GeneralNotesCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_onControllerChanged);
    _lastText = widget.controller.text;
    _lastSelection = widget.controller.selection;
    widget.controller.addListener(_onControllerChanged);
    _scheduleSpellCheck();
  }

  @override
  void dispose() {
    _spellCheckDebounce?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    final textChanged = _lastText != widget.controller.text;
    final selectionChanged = _lastSelection != widget.controller.selection;
    if (!textChanged && !selectionChanged) return;
    _lastText = widget.controller.text;
    _lastSelection = widget.controller.selection;
    if (textChanged) {
      widget.onChanged(widget.controller.text);
      _scheduleSpellCheck();
    }
    if (mounted) setState(() {});
  }

  void _scheduleSpellCheck() {
    _spellCheckDebounce?.cancel();
    _spellCheckDebounce = Timer(
      const Duration(milliseconds: 420),
      _runSpellCheck,
    );
  }

  Future<void> _runSpellCheck() async {
    final text = widget.controller.text;
    if (text.trim().isEmpty) {
      _spellSuggestions = const <SuggestionSpan>[];
      widget.controller.updateSpellSuggestions(const <SuggestionSpan>[]);
      if (mounted) setState(() {});
      return;
    }
    try {
      final results = await _spellCheckService.fetchSpellCheckSuggestions(
        const Locale('es'),
        text,
      );
      if (!mounted || text != widget.controller.text) return;
      _spellSuggestions = (results ?? const <SuggestionSpan>[])
          .where((suggestion) {
            final token = _normalizedSuggestionToken(suggestion);
            return token.isNotEmpty && !_ignoredTokens.contains(token);
          })
          .toList(growable: false);
      widget.controller.updateSpellSuggestions(_spellSuggestions);
      setState(() {});
    } catch (_) {
      _spellSuggestions = const <SuggestionSpan>[];
      widget.controller.updateSpellSuggestions(const <SuggestionSpan>[]);
      if (mounted) setState(() {});
    }
  }

  String _normalizedSuggestionToken(SuggestionSpan suggestion) {
    final token = _studySuggestionLabel(widget.controller, suggestion)
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n');
    return token.replaceAll(RegExp(r'^[^a-z0-9]+|[^a-z0-9]+$'), '');
  }

  SuggestionSpan? _activeSuggestion() {
    final selection = widget.controller.selection;
    if (!selection.isValid) return null;
    final cursor = selection.extentOffset;
    for (final suggestion in _spellSuggestions) {
      if (cursor >= suggestion.range.start && cursor <= suggestion.range.end) {
        return suggestion;
      }
    }
    return null;
  }

  void _replaceSuggestion(SuggestionSpan suggestion, String replacement) {
    final text = widget.controller.text;
    final start = suggestion.range.start.clamp(0, text.length);
    final end = suggestion.range.end.clamp(start, text.length);
    final next = text.replaceRange(start, end, replacement);
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
    widget.onChanged(next);
    _scheduleSpellCheck();
  }

  void _ignoreSuggestion(SuggestionSpan suggestion) {
    final token = _normalizedSuggestionToken(suggestion);
    if (token.isEmpty) return;
    setState(() {
      _ignoredTokens.add(token);
      _spellSuggestions = _spellSuggestions
          .where((item) => _normalizedSuggestionToken(item) != token)
          .toList(growable: false);
      widget.controller.updateSpellSuggestions(_spellSuggestions);
    });
  }

  void _applyFormat(RichNoteFormat format, {double? fontSize}) {
    widget.controller.applyFormat(format, fontSize: fontSize);
    widget.onChanged(widget.controller.text);
    if (mounted) setState(() {});
  }

  Future<void> _openSizeSheet() async {
    final size = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudyNotesFontSheet(theme: widget.theme),
    );
    if (size == null) return;
    _applyFormat(RichNoteFormat.size, fontSize: size);
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final activeSuggestion = _activeSuggestion();
    final items = List<ContextMenuButtonItem>.from(
      editableTextState.contextMenuButtonItems,
    );
    if (activeSuggestion != null) {
      final replacements = activeSuggestion.suggestions.take(3).toList();
      for (var i = replacements.length - 1; i >= 0; i--) {
        final replacement = replacements[i];
        items.insert(
          0,
          ContextMenuButtonItem(
            label: 'Cambiar a "$replacement"',
            onPressed: () {
              editableTextState.hideToolbar();
              _replaceSuggestion(activeSuggestion, replacement);
            },
          ),
        );
      }
      items.insert(
        replacements.length,
        ContextMenuButtonItem(
          label: 'Omitir palabra',
          onPressed: () {
            editableTextState.hideToolbar();
            _ignoreSuggestion(activeSuggestion);
          },
        ),
      );
    }
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final activeSuggestion = _activeSuggestion();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(t.isDark ? 0.07 : 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.accent.withOpacity(0.18), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notes_outlined, color: t.accent, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Notas generales',
                  style: GoogleFonts.lora(
                    color: t.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ideas libres, resumen, observaciones, acuerdos del grupo o pendientes para revisar.',
            style: GoogleFonts.manrope(
              color: t.textSecondary.withOpacity(0.65),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecciona texto para darle formato.',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.66),
                        fontSize: 11.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StudySaveStatusChip(
                      theme: t,
                      label: widget.saveStatusLabel,
                    ),
                  ],
                ),
              ),
              _StudyRichFormatIcon(
                theme: t,
                tooltip: 'Deshacer',
                icon: Icons.undo,
                enabled: widget.canUndo,
                onTap: widget.onUndo,
              ),
              _StudyRichFormatIcon(
                theme: t,
                tooltip: 'Rehacer',
                icon: Icons.redo,
                enabled: widget.canRedo,
                onTap: widget.onRedo,
              ),
              _StudyRichFormatIcon(
                theme: t,
                tooltip: 'Negrita',
                icon: Icons.format_bold,
                onTap: () => _applyFormat(RichNoteFormat.bold),
              ),
              _StudyRichFormatIcon(
                theme: t,
                tooltip: 'Subrayado',
                icon: Icons.format_underlined,
                onTap: () => _applyFormat(RichNoteFormat.underline),
              ),
              _StudyRichFormatIcon(
                theme: t,
                tooltip: 'Tamano de texto',
                icon: Icons.format_size,
                onTap: _openSizeSheet,
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: widget.controller,
            maxLines: null,
            minLines: 3,
            hintLocales: const [Locale('es')],
            contextMenuBuilder: _buildContextMenu,
            style: GoogleFonts.lora(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Escribe notas libres de este estudio…',
              hintStyle: GoogleFonts.lora(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: 14,
              ),
              filled: true,
              fillColor: t.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.textSecondary.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.textSecondary.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.accent, width: 1.2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child:
                activeSuggestion != null &&
                    activeSuggestion.suggestions.isNotEmpty
                ? _StudySpellingSuggestionBar(
                    key: ValueKey(
                      '${activeSuggestion.range.start}:${activeSuggestion.range.end}',
                    ),
                    theme: t,
                    token: _studySuggestionLabel(
                      widget.controller,
                      activeSuggestion,
                    ),
                    replacement: activeSuggestion.suggestions.first,
                    onReplace: () => _replaceSuggestion(
                      activeSuggestion,
                      activeSuggestion.suggestions.first,
                    ),
                    onIgnore: () => _ignoreSuggestion(activeSuggestion),
                  )
                : _StudyGeneralNotesHint(
                    key: const ValueKey('study_notes_hint'),
                    theme: t,
                  ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _StudyNotesFormatToolbar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final VoidCallback onBold;
  final VoidCallback onUnderline;
  final ValueChanged<double> onSize;

  const _StudyNotesFormatToolbar({
    required this.theme,
    required this.onBold,
    required this.onUnderline,
    required this.onSize,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FormatButton(
          theme: t,
          tooltip: 'Negrita',
          icon: Icons.format_bold,
          onTap: onBold,
        ),
        _FormatButton(
          theme: t,
          tooltip: 'Subrayado',
          icon: Icons.format_underlined,
          onTap: onUnderline,
        ),
        _FormatSizeButton(theme: t, label: '14', onTap: () => onSize(14)),
        _FormatSizeButton(theme: t, label: '18', onTap: () => onSize(18)),
        _FormatSizeButton(theme: t, label: '22', onTap: () => onSize(22)),
      ],
    );
  }
}

class _FormatButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  const _FormatButton({
    required this.theme,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.accent.withOpacity(0.28)),
          ),
          child: Icon(icon, color: t.accent, size: 18),
        ),
      ),
    );
  }
}

class _FormatSizeButton extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String label;
  final VoidCallback onTap;

  const _FormatSizeButton({
    required this.theme,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Tooltip(
      message: 'Tamaño $label',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.accent.withOpacity(0.28)),
          ),
          child: Text(
            label,
            style: GoogleFonts.manrope(
              color: t.accent,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _StudyNotesPreview extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String source;

  const _StudyNotesPreview({required this.theme, required this.source});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final segments = richNoteSegments(source);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.background.withOpacity(t.isDark ? 0.62 : 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: t.textSecondary.withOpacity(0.10)),
      ),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.lora(
            color: t.textPrimary,
            fontSize: 14,
            height: 1.5,
          ),
          children: [
            for (final segment in segments)
              TextSpan(
                text: segment.text,
                style: TextStyle(
                  fontSize: segment.fontSize,
                  fontWeight: segment.bold
                      ? FontWeight.w800
                      : FontWeight.normal,
                  decoration: segment.underline
                      ? TextDecoration.underline
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StudyRichFormatIcon extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String tooltip;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StudyRichFormatIcon({
    required this.theme,
    required this.tooltip,
    required this.icon,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final color = enabled ? t.accent : t.textSecondary.withOpacity(0.45);
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, color: color, size: 18),
    );
  }
}

class _StudySaveStatusChip extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String label;

  const _StudySaveStatusChip({required this.theme, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final saving = label.startsWith('Guardando');
    final pending = label.startsWith('Cambios');
    final color = saving
        ? const Color(0xFFC78D1B)
        : pending
        ? const Color(0xFFD64045)
        : t.accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(t.isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StudyNotesFontSheet extends StatelessWidget {
  final BibleReaderThemeData theme;

  const _StudyNotesFontSheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const sizes = <double>[14, 18, 22];
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
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
                  color: t.textSecondary.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tamano del texto',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona una parte de la nota y despues elige el tamano que quieras aplicar.',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.72),
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            for (final size in sizes) ...[
              _StudyNotesFontTile(
                theme: t,
                size: size,
                preview: size == 14
                    ? 'Texto base'
                    : size == 18
                    ? 'Enfasis intermedio'
                    : 'Enfasis fuerte',
                onTap: () => Navigator.pop(context, size),
              ),
              if (size != sizes.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _StudyNotesFontTile extends StatelessWidget {
  final BibleReaderThemeData theme;
  final double size;
  final String preview;
  final VoidCallback onTap;

  const _StudyNotesFontTile({
    required this.theme,
    required this.size,
    required this.preview,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.background.withOpacity(t.isDark ? 0.28 : 0.60),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.textSecondary.withOpacity(0.10)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                size.toInt().toString(),
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview,
                    style: GoogleFonts.lora(
                      color: t.textPrimary,
                      fontSize: size,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Aplicar a la seleccion actual',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.72),
                      fontSize: 11.5,
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

String _studySuggestionLabel(
  TextEditingController controller,
  SuggestionSpan suggestion,
) {
  final text = controller.text;
  final start = suggestion.range.start.clamp(0, text.length);
  final end = suggestion.range.end.clamp(start, text.length);
  return text.substring(start, end);
}

class _StudySpellingSuggestionBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final String token;
  final String replacement;
  final VoidCallback onReplace;
  final VoidCallback onIgnore;

  const _StudySpellingSuggestionBar({
    super.key,
    required this.theme,
    required this.token,
    required this.replacement,
    required this.onReplace,
    required this.onIgnore,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    const highlight = Color(0xFFD64045);
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight.withOpacity(t.isDark ? 0.16 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight.withOpacity(0.26)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: highlight.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.spellcheck, color: highlight, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  token,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sugerencia: $replacement',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.76),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onIgnore,
            style: TextButton.styleFrom(
              foregroundColor: t.textSecondary,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text('Omitir'),
          ),
          const SizedBox(width: 4),
          FilledButton.tonal(
            onPressed: onReplace,
            style: FilledButton.styleFrom(
              backgroundColor: highlight.withOpacity(t.isDark ? 0.18 : 0.10),
              foregroundColor: highlight,
              visualDensity: VisualDensity.compact,
              minimumSize: const Size(0, 34),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Corregir'),
          ),
        ],
      ),
    );
  }
}

class _StudyGeneralNotesHint extends StatelessWidget {
  final BibleReaderThemeData theme;

  const _StudyGeneralNotesHint({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: t.background.withOpacity(t.isDark ? 0.28 : 0.65),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.textSecondary.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.edit_note_outlined, color: t.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ahora tus notas generales usan formato real dentro del editor. Las palabras dudosas se subrayan en rojo y puedes corregirlas desde el menu o la sugerencia contextual.',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.76),
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int index;
  final StudyQuestion question;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final BibleReaderThemeData theme;

  const _QuestionCard({
    required this.index,
    required this.question,
    required this.controller,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.isDark
            ? Colors.white.withOpacity(0.04)
            : Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.textSecondary.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: GoogleFonts.cinzel(
                    color: t.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.prompt,
                  style: GoogleFonts.lora(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 34),
            child: Text(
              question.hint,
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.6),
                fontSize: 11,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            minLines: 2,
            style: GoogleFonts.lora(
              color: t.textPrimary,
              fontSize: 14,
              height: 1.5,
            ),
            decoration: InputDecoration(
              hintText: 'Escribe tu respuesta…',
              hintStyle: GoogleFonts.lora(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: 14,
              ),
              filled: true,
              fillColor: t.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.textSecondary.withOpacity(0.1)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.textSecondary.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: t.accent, width: 1.2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
        ],
      ),
    );
  }
}
