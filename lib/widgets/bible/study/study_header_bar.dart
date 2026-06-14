import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/study_chapter_answers.dart';
import '../../../theme/bible_reader_theme.dart';
import 'study_onboarding_overlay.dart';

enum _StudyHeaderAction { passage, range, addPassage, text, tutorial, room }

class StudyHeaderBar extends StatelessWidget {
  const StudyHeaderBar({
    super.key,
    required this.theme,
    required this.isWide,
    required this.bookName,
    required this.chapter,
    required this.rangeLabel,
    required this.answersNotifier,
    required this.resolveCurrentStudy,
    required this.onBack,
    required this.onOpenPicker,
    required this.onOpenRangePicker,
    required this.onOpenAddPassagePicker,
    required this.onOpenTypographySheet,
    required this.onOpenRoomDialog,
  });

  final BibleReaderThemeData theme;
  final bool isWide;
  final String bookName;
  final int chapter;
  final String rangeLabel;
  final ValueListenable<Map<String, StudyChapterAnswers>> answersNotifier;
  final StudyChapterAnswers? Function() resolveCurrentStudy;
  final VoidCallback onBack;
  final VoidCallback onOpenPicker;
  final VoidCallback onOpenRangePicker;
  final VoidCallback onOpenAddPassagePicker;
  final void Function(BibleReaderThemeData) onOpenTypographySheet;
  final VoidCallback onOpenRoomDialog;

  @override
  Widget build(BuildContext context) {
    return isWide ? _buildWide(context) : _buildCompact(context);
  }

  Widget _buildWide(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: t.textSecondary, size: 18),
            onPressed: onBack,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onOpenPicker,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Modo Estudio',
                    style: GoogleFonts.cinzel(
                      color: t.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: t.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$bookName $chapter',
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
              color: t.textSecondary.withValues(alpha: 0.6),
              size: 20,
            ),
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const StudyOnboardingOverlay(),
            ),
          ),
          TextButton.icon(
            onPressed: () => onOpenTypographySheet(t),
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
                side: BorderSide(color: t.accent.withValues(alpha: 0.22)),
              ),
              textStyle: GoogleFonts.manrope(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Estudiar con amigos',
            icon: Icon(Icons.groups_outlined, color: t.accent, size: 22),
            onPressed: onOpenRoomDialog,
          ),
          _buildRangeChip(),
        ],
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 2),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.arrow_back_ios_new, color: t.textSecondary, size: 18),
            onPressed: onBack,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onOpenPicker,
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
                    '$bookName $chapter · $rangeLabel',
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
            onTap: () => onOpenTypographySheet(t),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: t.accent.withValues(alpha: 0.22)),
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
            onSelected: (action) {
              switch (action) {
                case _StudyHeaderAction.passage:
                  onOpenPicker();
                case _StudyHeaderAction.range:
                  onOpenRangePicker();
                case _StudyHeaderAction.addPassage:
                  onOpenAddPassagePicker();
                case _StudyHeaderAction.text:
                  onOpenTypographySheet(t);
                case _StudyHeaderAction.tutorial:
                  showDialog(context: context, builder: (_) => const StudyOnboardingOverlay());
                case _StudyHeaderAction.room:
                  onOpenRoomDialog();
              }
            },
            itemBuilder: (_) => [
              _menuItem(t, _StudyHeaderAction.passage, 'Cambiar pasaje'),
              _menuItem(t, _StudyHeaderAction.range, 'Elegir rango'),
              _menuItem(t, _StudyHeaderAction.addPassage, 'Añadir pasaje'),
              _menuItem(t, _StudyHeaderAction.text, 'Texto y colores'),
              _menuItem(t, _StudyHeaderAction.tutorial, 'Tutorial'),
              _menuItem(t, _StudyHeaderAction.room, 'Sala de estudio'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip() {
    final t = theme;
    return ValueListenableBuilder<Map<String, StudyChapterAnswers>>(
      valueListenable: answersNotifier,
      builder: (_, _, _) {
        final answers = resolveCurrentStudy();
        final s = answers?.studyStartVerse;
        final e = answers?.studyEndVerse;
        final hasExtras = answers?.additionalPassages.isNotEmpty == true;
        final label = hasExtras
            ? answers!.reference
            : (s != null && e != null)
            ? (s == e ? 'v. $s' : 'v. $s–$e')
            : 'Capítulo';
        return GestureDetector(
          onTap: onOpenRangePicker,
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: t.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (s != null && e != null) || hasExtras
                    ? t.accent.withValues(alpha: 0.5)
                    : t.textSecondary.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.format_list_numbered, color: t.textSecondary, size: 14),
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

  PopupMenuItem<_StudyHeaderAction> _menuItem(
    BibleReaderThemeData t,
    _StudyHeaderAction value,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Text(label, style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 13)),
    );
  }
}
