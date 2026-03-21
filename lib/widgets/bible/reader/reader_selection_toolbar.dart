import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../models/bible/highlight.dart';
import '../../../theme/bible_reader_theme.dart';
import '../full_color_picker_sheet.dart';

class ReaderSelectionToolbar extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;
  final VoidCallback onShare;

  const ReaderSelectionToolbar({
    super.key,
    required this.theme,
    required this.controller,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final iconColor = t.isDark ? Colors.white70 : const Color(0xFF1A1A1A);
    final count = controller.selectedVerseNumbers.length;

    return Container(
      height: 44,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: t.toolbarBg,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.3 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: controller.multiSelectShowColors
          ? _buildColorPicker(t)
          : Row(
              children: [
                GestureDetector(
                  onTap: controller.exitSelectionMode,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Icon(Icons.close, color: iconColor, size: 20),
                  ),
                ),
                GestureDetector(
                  onTap: () => controller.setMultiSelectShowColors(true),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(Icons.format_paint_outlined,
                        color: iconColor, size: 20),
                  ),
                ),
                const Spacer(),
                Text(
                  '$count versículo${count == 1 ? '' : 's'}',
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: controller.copyAllSelected,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(Icons.content_copy_outlined,
                        color: iconColor, size: 20),
                  ),
                ),
                GestureDetector(
                  onTap: onShare,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(Icons.share_outlined,
                        color: iconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
    );
  }

  Widget _buildColorPicker(BibleReaderThemeData t) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GestureDetector(
          onTap: () => controller.setMultiSelectShowColors(false),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Icon(Icons.arrow_back_ios_new,
                color: t.isDark ? Colors.white54 : Colors.black38, size: 16),
          ),
        ),
        ...HighlightColors.defaults.map((color) {
          return Semantics(
            label: 'Color de resaltado',
            button: true,
            child: GestureDetector(
              onTap: () => controller
                  .applyColorToSelected(HighlightColors.toHex(color)),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
        Semantics(
          label: 'Color personalizado',
          button: true,
          child: Builder(builder: (context) {
            return GestureDetector(
              onTap: () async {
                final color = await showModalBottomSheet<Color>(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => FullColorPickerSheet(theme: t),
                );
                if (color != null) {
                  controller
                      .applyColorToSelected(HighlightColors.toHex(color));
                }
              },
              child: Container(
                width: 26,
                height: 26,
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
            );
          }),
        ),
      ],
    );
  }
}
