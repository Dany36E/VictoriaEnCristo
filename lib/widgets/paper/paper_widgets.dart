import 'package:flutter/material.dart';

import '../../theme/app_fonts.dart';
import '../../theme/app_theme_data.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PAPER WIDGETS — Piezas del estilo "Papel recortado"
/// ═══════════════════════════════════════════════════════════════════════════
///
/// PaperCard   → tarjeta crema con contorno blanco, leve giro y cinta opcional
/// StickerBadge→ círculo coral con número/texto ("#9")
/// PaperChip   → píldora de color con ícono ("En persona")
/// WashiTape   → tira de cinta adhesiva semitransparente
/// ═══════════════════════════════════════════════════════════════════════════

/// Tarjeta tipo recorte de papel.
class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Giro en grados (±1–2° da el efecto "pegado a mano").
  final double tiltDegrees;

  /// Muestra una cinta adhesiva en la esquina superior izquierda.
  final bool tape;
  final Color? color;

  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.tiltDegrees = 0,
    this.tape = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? PaperPalette.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: PaperPalette.sticker, width: 3),
        boxShadow: PaperPalette.stickerShadow,
      ),
      child: child,
    );

    return Transform.rotate(
      angle: tiltDegrees * 3.1415926535 / 180,
      child: tape
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                const Positioned(left: -10, top: -8, child: WashiTape()),
              ],
            )
          : card,
    );
  }
}

/// Insignia circular con contorno blanco (p. ej. "#9").
class StickerBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double size;

  const StickerBadge({
    super.key,
    required this.label,
    this.color = PaperPalette.coral,
    this.size = 48,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: PaperPalette.sticker, width: 3),
        boxShadow: PaperPalette.stickerShadow,
      ),
      child: FittedBox(
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Text(
            label,
            style: AppFonts.manrope(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Píldora de color con ícono opcional.
class PaperChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color foreground;

  const PaperChip({
    super.key,
    required this.label,
    this.icon,
    this.color = PaperPalette.teal,
    this.foreground = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PaperPalette.sticker, width: 2),
        boxShadow: PaperPalette.stickerShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppFonts.manrope(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tira de cinta adhesiva amarilla, ligeramente girada.
class WashiTape extends StatelessWidget {
  final double width;
  final Color color;

  const WashiTape({super.key, this.width = 56, this.color = PaperPalette.tape});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.6,
      child: Container(
        width: width,
        height: width * 0.32,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
