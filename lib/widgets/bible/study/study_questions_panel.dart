import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/study_chapter_answers.dart';
import '../../../theme/bible_reader_theme.dart';

/// Panel derecho del Modo Estudio: 6 preguntas con autosave.
class StudyQuestionsPanel extends StatelessWidget {
  final BibleReaderThemeData theme;
  final Map<String, TextEditingController> controllers;
  final TextEditingController generalNotesController;
  final void Function(String questionId, String value) onChanged;
  final ValueChanged<String> onGeneralNotesChanged;
  final Future<void> Function() onManualSave;
  final Future<void> Function() onExportPdf;
  final VoidCallback onPickSavedStudy;
  final VoidCallback onPickRange;
  final VoidCallback onPickVersions;
  final VoidCallback onSwapVersions;
  final String reference;
  final String rangeLabel;
  final String versionsLabel;

  const StudyQuestionsPanel({
    super.key,
    required this.theme,
    required this.controllers,
    required this.generalNotesController,
    required this.onChanged,
    required this.onGeneralNotesChanged,
    required this.onManualSave,
    required this.onExportPdf,
    required this.onPickSavedStudy,
    required this.onPickRange,
    required this.onPickVersions,
    required this.onSwapVersions,
    required this.reference,
    required this.rangeLabel,
    required this.versionsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tus respuestas · $reference',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onPickSavedStudy,
                    icon: const Icon(Icons.folder_open_outlined, size: 17),
                    label: const Text('Estudios guardados'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.accent,
                      side: BorderSide(color: t.accent.withOpacity(0.5)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickRange,
                    icon: const Icon(Icons.format_list_numbered, size: 17),
                    label: Text('Rango: $rangeLabel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.accent,
                      side: BorderSide(color: t.accent.withOpacity(0.5)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onPickVersions,
                    icon: const Icon(Icons.compare_arrows, size: 17),
                    label: Text('Versiones: $versionsLabel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.accent,
                      side: BorderSide(color: t.accent.withOpacity(0.5)),
                    ),
                  ),
                  IconButton.outlined(
                    tooltip: 'Intercambiar versiones',
                    onPressed: onSwapVersions,
                    icon: const Icon(Icons.swap_vert, size: 18),
                    color: t.accent,
                    style: IconButton.styleFrom(
                      side: BorderSide(color: t.accent.withOpacity(0.5)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await onManualSave();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Estudio guardado'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_outlined, size: 17),
                    label: const Text('Guardar progreso'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await onExportPdf();
                    },
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
                    label: const Text('Exportar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: t.accent,
                      foregroundColor: t.background,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: kStudyQuestions.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (_, i) {
              if (i == 0) {
                return _GeneralNotesCard(
                  controller: generalNotesController,
                  onChanged: onGeneralNotesChanged,
                  theme: t,
                );
              }
              final q = kStudyQuestions[i - 1];
              return _QuestionCard(
                index: i,
                question: q,
                controller: controllers[q.id]!,
                onChanged: (v) => onChanged(q.id, v),
                theme: t,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GeneralNotesCard extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final BibleReaderThemeData theme;

  const _GeneralNotesCard({
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
            minLines: 4,
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
            minLines: 3,
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
