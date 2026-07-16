import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../models/bible/study_word_highlight.dart';
import '../../../theme/bible_reader_theme.dart';

/// Barra inferior del "modo palabra": aparece cuando el usuario está
/// subrayando palabra por palabra dentro de un versículo. Muestra los colores
/// de subrayado granular y un contador de palabras seleccionadas.
///
/// Reutiliza StudyWordHighlight (mismo subrayado que Modo Estudio / Apuntes),
/// pero aquí los colores se muestran sin la jerga del método inductivo.
class WordSelectionBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;

  const WordSelectionBar({
    super.key,
    required this.theme,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final count = controller.selectedWords.length;
    final hasWords = count > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: t.toolbarBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.textSecondary.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: t.isDark ? 0.35 : 0.10),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(t, count, hasWords),
          _buildColorsRow(t, hasWords),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildHeader(BibleReaderThemeData t, int count, bool hasWords) {
    final label = hasWords
        ? '$count palabra${count == 1 ? '' : 's'} · toca un color'
        : 'Toca las palabras a subrayar';
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 2, top: 2),
      child: Row(
        children: [
          Icon(Icons.edit_outlined, size: 15, color: t.accent),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.manrope(
                color: t.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Seleccionar todo el versículo
          Semantics(
            label: 'Seleccionar todo el versículo',
            button: true,
            child: GestureDetector(
              onTap: controller.selectAllWords,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Text(
                  'Todo',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Semantics(
            label: 'Salir del modo palabra',
            button: true,
            child: GestureDetector(
              onTap: controller.exitWordSelection,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: t.textSecondary.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorsRow(BibleReaderThemeData t, bool hasWords) {
    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            ...StudyHighlightCode.values.map((c) => _colorDot(t, c, hasWords)),
            if (controller.currentWordVerseHasHighlights) ...[
              Container(
                width: 1,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: t.textSecondary.withValues(alpha: 0.15),
              ),
              _removeDot(t),
            ],
          ],
        ),
      ),
    );
  }

  Widget _colorDot(
    BibleReaderThemeData t,
    StudyHighlightCode code,
    bool enabled,
  ) {
    return Semantics(
      label: 'Subrayar palabras',
      button: true,
      child: GestureDetector(
        onTap: enabled ? () => controller.applyWordColor(code) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.35,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: code.color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _removeDot(BibleReaderThemeData t) {
    return Semantics(
      label: 'Quitar subrayado del versículo',
      button: true,
      child: GestureDetector(
        onTap: controller.clearWordHighlightsForCurrent,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: t.textSecondary.withValues(alpha: 0.4)),
          ),
          child: Icon(
            Icons.format_color_reset_outlined,
            size: 17,
            color: t.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
