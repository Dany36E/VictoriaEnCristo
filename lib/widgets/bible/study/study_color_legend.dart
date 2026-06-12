import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/bible/study_word_highlight.dart';
import '../../../theme/bible_reader_theme.dart';

/// Leyenda compacta y persistente con el código de colores del Modo Estudio.
///
/// Diseñada para vivir como pie/strip en `StudyReadingPanel` y como sección
/// del overlay de bienvenida.
class StudyColorLegend extends StatelessWidget {
  final BibleReaderThemeData theme;
  final bool compact;

  const StudyColorLegend({
    super.key,
    required this.theme,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final spacing = compact ? 6.0 : 8.0;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: StudyHighlightCode.values.map((c) {
        final color = c.color;
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 10,
            vertical: compact ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: t.isDark ? 0.18 : 0.18),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.65), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 8 : 10,
                height: compact ? 8 : 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: compact ? 6 : 8),
              Text(
                c.label,
                style: GoogleFonts.manrope(
                  color: t.textPrimary,
                  fontSize: compact ? 10.5 : 11.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
