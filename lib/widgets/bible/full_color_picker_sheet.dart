import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// FULL COLOR PICKER SHEET
/// 3 capas: barra de hue, cuadrado SV, preview + aplicar.
/// ═══════════════════════════════════════════════════════════════════════════
class FullColorPickerSheet extends StatefulWidget {
  final Color? initialColor;
  final BibleReaderThemeData theme;

  const FullColorPickerSheet({
    super.key,
    this.initialColor,
    required this.theme,
  });

  @override
  State<FullColorPickerSheet> createState() => _FullColorPickerSheetState();
}

class _FullColorPickerSheetState extends State<FullColorPickerSheet> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = widget.initialColor != null
        ? HSVColor.fromColor(widget.initialColor!)
        : const HSVColor.fromAHSV(1, 210, 0.7, 0.9);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final selectedColor = _hsv.toColor();
    final lum = selectedColor.computeLuminance();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewPadding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            child: Container(
              width: 36,
              height: 2,
              decoration: BoxDecoration(
                color: t.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),

          // Title
          Text(
            'Color personalizado',
            style: GoogleFonts.manrope(
              color: t.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),

          // SV Square
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _SVSquare(
              hue: _hsv.hue,
              saturation: _hsv.saturation,
              value: _hsv.value,
              onChanged: (s, v) => setState(() {
                _hsv = _hsv.withSaturation(s).withValue(v);
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Hue bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _HueBar(
              hue: _hsv.hue,
              onChanged: (h) => setState(() {
                _hsv = _hsv.withHue(h);
              }),
            ),
          ),
          const SizedBox(height: 20),

          // Preview + Apply
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Preview circle
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: t.textSecondary.withOpacity(0.2),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Aa',
                      style: GoogleFonts.lora(
                        color: lum > 0.5 ? Colors.black87 : Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Apply button
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, selectedColor),
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: t.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Aplicar',
                        style: GoogleFonts.manrope(
                          color: t.accent.computeLuminance() > 0.5
                              ? Colors.black87
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// HUE BAR — Horizontal gradient 0-360°
// ═══════════════════════════════════════════════════════════════════════════
class _HueBar extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HueBar({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition.dx, width),
          onPanUpdate: (d) => _update(d.localPosition.dx, width),
          child: SizedBox(
            height: 28,
            child: Stack(
              children: [
                // Gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
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
                // Thumb
                Positioned(
                  left: (hue / 360 * width) - 10,
                  top: 0,
                  child: Container(
                    width: 20,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _update(double dx, double width) {
    final h = (dx / width * 360).clamp(0.0, 360.0);
    onChanged(h);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SV SQUARE — Saturation (X) × Value/Brightness (Y)
// ═══════════════════════════════════════════════════════════════════════════
class _SVSquare extends StatelessWidget {
  final double hue;
  final double saturation;
  final double value;
  final void Function(double saturation, double value) onChanged;

  const _SVSquare({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;
        return GestureDetector(
          onPanDown: (d) => _update(d.localPosition, size),
          onPanUpdate: (d) => _update(d.localPosition, size),
          child: SizedBox(
            width: size,
            height: size * 0.6,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _SVPainter(hue: hue),
                  ),
                ),
                // Thumb
                Positioned(
                  left: saturation * size - 10,
                  top: (1 - value) * size * 0.6 - 10,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _update(Offset pos, double size) {
    final s = (pos.dx / size).clamp(0.0, 1.0);
    final v = (1 - pos.dy / (size * 0.6)).clamp(0.0, 1.0);
    onChanged(s, v);
  }
}

class _SVPainter extends CustomPainter {
  final double hue;

  _SVPainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Horizontal: white → hue at full saturation
    final hueColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();
    final satGrad = LinearGradient(
      colors: [Colors.white, hueColor],
    );
    canvas.drawRect(rect, Paint()..shader = satGrad.createShader(rect));

    // Vertical: transparent → black
    final valGrad = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    );
    canvas.drawRect(rect, Paint()..shader = valGrad.createShader(rect));
  }

  @override
  bool shouldRepaint(_SVPainter old) => old.hue != hue;
}
