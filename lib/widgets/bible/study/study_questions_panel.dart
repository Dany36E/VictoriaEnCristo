import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/study_chapter_answers.dart';
import '../../../theme/bible_reader_theme.dart';

/// Panel derecho del Modo Estudio: preguntas, notas y cierre con autosave.
class StudyQuestionsPanel extends StatelessWidget {
  final BibleReaderThemeData theme;
  final Map<String, TextEditingController> controllers;
  final TextEditingController generalNotesController;
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
  final VoidCallback onPickVersions;
  final VoidCallback onSwapVersions;
  final VoidCallback onOpenTextSettings;
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
    required this.onPickVersions,
    required this.onSwapVersions,
    required this.onOpenTextSettings,
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
            style: GoogleFonts.lora(color: t.textPrimary, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Ej. Jesús quiere sanarte y darte vida nueva.',
              hintStyle: GoogleFonts.lora(color: t.textSecondary.withOpacity(0.5), fontSize: 14),
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
                color: selectedVerses.isEmpty ? t.textSecondary.withOpacity(0.65) : t.accent,
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
        color: selected ? t.accent.withOpacity(0.68) : t.textSecondary.withOpacity(0.16),
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
    required this.onPickVersions,
    required this.onSwapVersions,
    required this.onOpenTextSettings,
    required this.onManualSave,
    required this.onExportPdf,
  });

  Future<void> _handleMenuAction(BuildContext context, _StudyPanelAction action) async {
    switch (action) {
      case _StudyPanelAction.savedStudies:
        onPickSavedStudy();
        break;
      case _StudyPanelAction.saveProgress:
        await onManualSave();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estudio guardado'), duration: Duration(seconds: 1)),
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
        color: t.isDark ? Colors.white.withOpacity(0.025) : Colors.black.withOpacity(0.02),
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
                icon: roomMode ? Icons.menu_book_outlined : Icons.compare_arrows,
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

class _GeneralNotesCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final BibleReaderThemeData theme;

  const _GeneralNotesCard({required this.controller, required this.onChanged, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
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
          TextField(
            controller: controller,
            onChanged: onChanged,
            maxLines: null,
            minLines: 3,
            style: GoogleFonts.lora(color: t.textPrimary, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Escribe notas libres de este estudio…',
              hintStyle: GoogleFonts.lora(color: t.textSecondary.withOpacity(0.5), fontSize: 14),
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
        color: t.isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
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
            style: GoogleFonts.lora(color: t.textPrimary, fontSize: 14, height: 1.5),
            decoration: InputDecoration(
              hintText: 'Escribe tu respuesta…',
              hintStyle: GoogleFonts.lora(color: t.textSecondary.withOpacity(0.5), fontSize: 14),
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
