import 'package:flutter/material.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../theme/bible_reader_theme.dart';
import '../verse_actions_toolbar.dart';
import 'reader_selection_toolbar.dart';

class ReaderToolbarOverlay extends StatelessWidget {
  final BibleReaderThemeData theme;
  final BibleReaderController controller;
  final VoidCallback onShare;

  const ReaderToolbarOverlay({
    super.key,
    required this.theme,
    required this.controller,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.isSelectionMode) {
      return Positioned(
        bottom: 16, left: 0, right: 0,
        child: ReaderSelectionToolbar(
          theme: theme,
          controller: controller,
          onShare: onShare,
        ),
      );
    }
    if (controller.selectedVerseIndex == null ||
        controller.selectedVerseIndex! >= controller.verses.length) {
      return const SizedBox.shrink();
    }
    return Positioned(
      bottom: 16, left: 0, right: 0,
      child: VerseActionsToolbar(
        verse: controller.verses[controller.selectedVerseIndex!],
        theme: theme,
        onDismiss: controller.clearSelection,
      ),
    );
  }
}
