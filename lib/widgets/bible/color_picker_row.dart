import 'package:flutter/material.dart';
import '../../models/bible/highlight.dart';

/// Fila de colores para resaltado rápido.
/// Muestra 6 colores predefinidos + botón para quitar highlight.
class ColorPickerRow extends StatelessWidget {
  final String? selectedColor;
  final void Function(String? colorHex) onColorSelected;

  const ColorPickerRow({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 6 default colors
        ...HighlightColors.defaults.map((color) {
          final hex = HighlightColors.toHex(color);
          final isSelected = hex == selectedColor;
          return GestureDetector(
            onTap: () => onColorSelected(hex),
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: Colors.white, width: 3)
                    : null,
                boxShadow: isSelected
                    ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]
                    : null,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.black54, size: 18)
                  : null,
            ),
          );
        }),
        // Remove highlight
        if (selectedColor != null) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onColorSelected(null),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: const Icon(Icons.close, color: Colors.white38, size: 16),
            ),
          ),
        ],
      ],
    );
  }
}
