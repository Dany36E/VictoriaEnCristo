import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../theme/bible_reader_theme.dart';

class ReaderSearchOverlay extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final void Function(int matchIdx) onScrollToMatch;

  const ReaderSearchOverlay({
    super.key,
    required this.theme,
    required this.controller,
    required this.searchController,
    required this.searchFocusNode,
    required this.onScrollToMatch,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final hasMatches = controller.searchMatchIndices.isNotEmpty;
    final matchText = hasMatches
        ? '${controller.currentMatchIndex + 1} de ${controller.searchMatchIndices.length}'
        : controller.searchQuery.length >= 2
            ? '0 resultados'
            : '';

    return Positioned(
      top: 44,
      left: 0,
      right: 0,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: t.surface.withOpacity(0.98),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: searchController,
                focusNode: searchFocusNode,
                style:
                    GoogleFonts.manrope(color: t.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Buscar en capítulo...',
                  hintStyle: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.4),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                textInputAction: TextInputAction.search,
                onChanged: controller.runInReaderSearch,
              ),
            ),
            if (matchText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  matchText,
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            if (hasMatches) ...[
              GestureDetector(
                onTap: () {
                  if (controller.currentMatchIndex > 0) {
                    controller.goToMatch(controller.currentMatchIndex - 1);
                    onScrollToMatch(controller.currentMatchIndex);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.keyboard_arrow_up,
                      color: controller.currentMatchIndex > 0
                          ? t.textSecondary
                          : t.textSecondary.withOpacity(0.2),
                      size: 20),
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (controller.currentMatchIndex <
                      controller.searchMatchIndices.length - 1) {
                    controller
                        .goToMatch(controller.currentMatchIndex + 1);
                    onScrollToMatch(controller.currentMatchIndex);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.keyboard_arrow_down,
                      color: controller.currentMatchIndex <
                              controller.searchMatchIndices.length - 1
                          ? t.textSecondary
                          : t.textSecondary.withOpacity(0.2),
                      size: 20),
                ),
              ),
            ],
            GestureDetector(
              onTap: () {
                searchController.clear();
                controller.closeSearch();
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(Icons.close,
                    color: t.textSecondary.withOpacity(0.5), size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
