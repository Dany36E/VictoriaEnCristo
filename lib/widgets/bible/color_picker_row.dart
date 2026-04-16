import 'package:flutter/material.dart';
import '../../models/bible/highlight.dart';
import '../../services/bible/recent_colors_service.dart';

/// Fila de colores para resaltado rápido.
/// Muestra colores recientes + 6 predefinidos + botón para quitar highlight.
class ColorPickerRow extends StatefulWidget {
  final String? selectedColor;
  final void Function(String? colorHex) onColorSelected;

  const ColorPickerRow({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
  });

  @override
  State<ColorPickerRow> createState() => _ColorPickerRowState();
}

class _ColorPickerRowState extends State<ColorPickerRow> {
  List<String> _recentColors = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final colors = await RecentColorsService.I.getRecentColors();
    if (mounted) setState(() => _recentColors = colors);
  }

  void _onSelect(String hex) {
    RecentColorsService.I.addRecentColor(hex);
    widget.onColorSelected(hex);
    _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Recientes
          if (_recentColors.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Text(
                'RECIENTES',
                style: TextStyle(
                  color: Colors.white38,
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ..._recentColors.map((hex) {
              final color = HighlightColors.fromHex(hex);
              final isSelected = hex == widget.selectedColor;
              final isLight = ThemeData.estimateBrightnessForColor(color) ==
                  Brightness.light;
              return GestureDetector(
                onTap: () => _onSelect(hex),
                child: Container(
                  width: 26,
                  height: 26,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2.5)
                        : isLight
                            ? Border.all(color: Colors.grey.shade400, width: 0.5)
                            : null,
                  ),
                  child: isSelected
                      ? Icon(Icons.check,
                          color: isLight ? Colors.black54 : Colors.white70,
                          size: 14)
                      : null,
                ),
              );
            }),
            Container(
              width: 0.5,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white24,
            ),
          ],
          // 6 predefinidos
          ...HighlightColors.defaults.map((color) {
            final hex = HighlightColors.toHex(color);
            final isSelected = hex == widget.selectedColor;
            return GestureDetector(
              onTap: () => _onSelect(hex),
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
          // Quitar highlight
          if (widget.selectedColor != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => widget.onColorSelected(null),
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
      ),
    );
  }
}
