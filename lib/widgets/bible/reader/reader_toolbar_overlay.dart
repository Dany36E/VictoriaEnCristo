import 'package:flutter/material.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../theme/bible_reader_theme.dart';
import '../verse_actions_sheet.dart';
import 'reader_selection_toolbar.dart';

class ReaderToolbarOverlay extends StatefulWidget {
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
  State<ReaderToolbarOverlay> createState() => _ReaderToolbarOverlayState();
}

class _ReaderToolbarOverlayState extends State<ReaderToolbarOverlay> {
  bool _sheetOpen = false;

  @override
  Widget build(BuildContext context) {
    // Multi-select mode → show selection toolbar in stack
    if (widget.controller.isSelectionMode) {
      _sheetOpen = false;
      return Positioned(
        bottom: 16, left: 0, right: 0,
        child: ReaderSelectionToolbar(
          theme: widget.theme,
          controller: widget.controller,
          onShare: widget.onShare,
        ),
      );
    }

    final idx = widget.controller.selectedVerseIndex;
    if (idx == null || idx >= widget.controller.verses.length) {
      _sheetOpen = false;
      return const SizedBox.shrink();
    }

    // Single verse selected → show bottom sheet once
    if (!_sheetOpen) {
      _sheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showVerseActionsSheet(
          context: context,
          verse: widget.controller.verses[idx],
          theme: widget.theme,
          onDismiss: () {
            _sheetOpen = false;
            widget.controller.clearSelection();
          },
        );
      });
    }
    return const SizedBox.shrink();
  }
}
