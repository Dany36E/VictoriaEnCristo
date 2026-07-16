import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../models/bible/bible_verse.dart';
import '../../../models/bible/highlight.dart';
import '../../../theme/bible_reader_theme.dart';
import '../full_color_picker_sheet.dart';
import '../note_editor_sheet.dart';
import '../verse_actions_sheet.dart';

/// Barra compacta de acciones que aparece al seleccionar versículos
/// (estilo YouVersion): no tapa el texto, no bloquea el scroll y ofrece
/// las acciones frecuentes a un toque — colores de subrayado primero.
/// Todo lo demás (imagen, estudio, oración, muro...) vive detrás de "Más".
class VerseSelectionBar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;
  final VoidCallback onShare;

  const VerseSelectionBar({
    super.key,
    required this.theme,
    required this.controller,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
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
          _buildHeader(t),
          _buildActionsRow(context, t),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ── Fila 1: referencia + cerrar ──
  Widget _buildHeader(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.only(left: 14, right: 2, top: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              controller.selectionReference,
              style: GoogleFonts.manrope(
                color: t.accent,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Semantics(
            label: 'Cerrar selección',
            button: true,
            child: GestureDetector(
              onTap: controller.clearSelection,
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

  // ── Fila 2: colores | acciones (deslizable horizontal) ──
  Widget _buildActionsRow(BuildContext context, BibleReaderThemeData t) {
    return SizedBox(
      height: 52,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            ...HighlightColors.defaults.map((c) => _colorDot(t, c)),
            _customColorDot(context, t),
            if (controller.selectionHasHighlight) _removeColorDot(t),
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 10),
              color: t.textSecondary.withValues(alpha: 0.15),
            ),
            _actionBtn(
              t,
              Icons.edit_outlined,
              'Palabra',
              controller.enterWordSelectionFromSelection,
            ),
            _actionBtn(
              t,
              Icons.bookmark_outline,
              'Guardar',
              controller.toggleSavedForSelected,
            ),
            _actionBtn(
              t,
              Icons.edit_note_outlined,
              'Nota',
              () => _openNote(context, t),
            ),
            _actionBtn(
              t,
              Icons.content_copy_outlined,
              'Copiar',
              controller.copyAllSelected,
            ),
            _actionBtn(t, Icons.share_outlined, 'Compartir', onShare),
            _actionBtn(t, Icons.more_horiz, 'Más', () => _openMore(context, t)),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(BibleReaderThemeData t, Color color) {
    return Semantics(
      label: 'Subrayar con color',
      button: true,
      child: GestureDetector(
        onTap: () =>
            controller.applyColorToSelected(HighlightColors.toHex(color)),
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.10),
            ),
          ),
        ),
      ),
    );
  }

  Widget _customColorDot(BuildContext context, BibleReaderThemeData t) {
    return Semantics(
      label: 'Color personalizado',
      button: true,
      child: GestureDetector(
        onTap: () async {
          final color = await showModalBottomSheet<Color>(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (_) => FullColorPickerSheet(theme: t),
          );
          if (color != null) {
            controller.applyColorToSelected(HighlightColors.toHex(color));
          }
        },
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: SweepGradient(
              colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _removeColorDot(BibleReaderThemeData t) {
    return Semantics(
      label: 'Quitar subrayado',
      button: true,
      child: GestureDetector(
        onTap: controller.removeHighlightFromSelected,
        child: Container(
          width: 30,
          height: 30,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: t.textSecondary.withValues(alpha: 0.4),
            ),
          ),
          child: Icon(
            Icons.format_color_reset_outlined,
            size: 16,
            color: t.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(
    BibleReaderThemeData t,
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return Semantics(
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: t.textPrimary.withValues(alpha: 0.85)),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: t.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Acciones que operan sobre el primer versículo seleccionado ──

  void _openNote(BuildContext context, BibleReaderThemeData t) {
    final verse = _firstSelectedVerse();
    if (verse == null) return;
    controller.clearSelection();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => NoteEditorSheet(verse: verse, theme: t),
    );
  }

  void _openMore(BuildContext context, BibleReaderThemeData t) {
    final verse = _firstSelectedVerse();
    if (verse == null) return;
    showVerseActionsSheet(
      context: context,
      verse: verse,
      theme: t,
      onDismiss: controller.clearSelection,
    );
  }

  BibleVerse? _firstSelectedVerse() {
    final sorted = controller.selectedVerseNumbers.toList()..sort();
    if (sorted.isEmpty) return null;
    return controller.verses
        .where((v) => v.verse == sorted.first)
        .firstOrNull;
  }
}
