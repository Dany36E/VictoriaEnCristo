import 'package:flutter/material.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../theme/bible_reader_theme.dart';
import 'verse_selection_bar.dart';
import 'word_selection_bar.dart';

/// Overlay que muestra la barra compacta de selección mientras haya
/// versículos (o palabras) seleccionados. Ya no abre ningún sheet
/// automáticamente: el menú completo solo aparece si el usuario toca "Más".
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
    final Widget bar;
    if (controller.inWordSelection) {
      bar = WordSelectionBar(theme: theme, controller: controller);
    } else if (controller.hasSelection) {
      bar = VerseSelectionBar(
        theme: theme,
        controller: controller,
        onShare: onShare,
      );
    } else {
      return const SizedBox.shrink();
    }
    return Positioned(bottom: 16, left: 0, right: 0, child: bar);
  }
}
