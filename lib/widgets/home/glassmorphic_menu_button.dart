import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';

/// Tipo de animación del icono dentro del botón glassmórfico.
enum IconAnimationType { shimmer, heartbeat, rotate, drawUp, pulse }

/// Botón principal de navegación con efecto glassmorphic + borde de neón
/// degradado y micro-animaciones de icono.
///
/// Se extrajo de `home_screen.dart` para reutilizarlo en las sub-pantallas de
/// categoría (Vida Espiritual, Crecimiento Espiritual, Hermanos en Cristo) y
/// evitar duplicar ~250 líneas de UI por pantalla.
class GlassmorphicMenuButton extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final IconAnimationType animationType;
  final int index;
  final VoidCallback onTap;
  final double height;

  const GlassmorphicMenuButton({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.animationType,
    required this.index,
    required this.onTap,
    this.height = 115,
  });

  @override
  State<GlassmorphicMenuButton> createState() => _GlassmorphicMenuButtonState();
}

class _GlassmorphicMenuButtonState extends State<GlassmorphicMenuButton>
    with TickerProviderStateMixin {

  bool _isPressed = false;

  late AnimationController _iconAnimationController;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    switch (widget.animationType) {
      case IconAnimationType.shimmer:
        _shimmerController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1500),
        );
        Future.delayed(Duration(milliseconds: widget.index * 200), () {
          if (mounted) {
            _shimmerController.forward().then((_) {
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted) {
                  _shimmerController.reset();
                  _shimmerController.forward();
                }
              });
            });
          }
        });
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 1),
        );
        break;
      case IconAnimationType.heartbeat:
        _shimmerController = AnimationController(
          vsync: this,
          duration: Duration.zero,
        );
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 800),
        )..repeat(reverse: true);
        break;
      case IconAnimationType.rotate:
        _shimmerController = AnimationController(
          vsync: this,
          duration: Duration.zero,
        );
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(seconds: 10),
        )..repeat();
        break;
      case IconAnimationType.drawUp:
        _shimmerController = AnimationController(
          vsync: this,
          duration: Duration.zero,
        );
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1200),
        );
        Future.delayed(Duration(milliseconds: 400 + widget.index * 100), () {
          if (mounted) _iconAnimationController.forward();
        });
        break;
      case IconAnimationType.pulse:
        _shimmerController = AnimationController(
          vsync: this,
          duration: Duration.zero,
        );
        _iconAnimationController = AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        )..repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ── Tema papel ─────────────────────────────────────────────────────────

  /// Ícono del kit (assets/vec/iconos) equivalente a cada ícono de Material
  /// que usan los menús; los que no estén aquí van rellenos en su círculo.
  static final Map<IconData, String> _iconosKit = {
    Icons.wb_sunny_outlined: 'orar',
    Icons.trending_up_rounded: 'biblia',
    Icons.groups_rounded: 'personas',
    Icons.school_rounded: 'idea',
    Icons.menu_book: 'biblia',
    Icons.menu_book_outlined: 'cruz',
    Icons.local_movies_rounded: 'cine',
    Icons.shield: 'escudo',
    Icons.forum_rounded: 'mensaje',
    Icons.admin_panel_settings_rounded: 'candado',
    Icons.map_outlined: 'orar',
    Icons.auto_stories_rounded: 'sol',
    Icons.show_chart: 'palomita',
  };

  static List<Color> get _coloresKit => [
    VecColores.terracota,
    VecColores.azul,
    VecColores.verde,
    VecColores.mostaza,
    VecColores.noche,
  ];

  /// Tarjeta de papel con cinta, círculo de color con el ícono del kit y
  /// título en Lilita One; se hunde un poco al tocarla.
  Widget _buildPapel() {
    final color = _coloresKit[widget.index % _coloresKit.length];
    final iconoKit = _iconosKit[widget.icon];
    final par = widget.index.isEven;
    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.subtitle}',
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onTap();
      },
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: PopIn(
          retraso: Duration(milliseconds: 80 * widget.index),
          child: AnimatedSlide(
            offset: Offset(0, _isPressed ? 0.03 : 0),
            duration: const Duration(milliseconds: 110),
            child: TarjetaPapel(
              giro: par ? -1 : 1,
              cintaDerecha: !par,
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: LayoutBuilder(
                builder: (context, c) {
                  final icono = CirculoIcono(
                    iconoVec: iconoKit,
                    icono: widget.icon,
                    color: color,
                    tamano: 58,
                    giro: par ? -4 : 4,
                  );
                  final textos = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontFamily: VecFuentes.titulo,
                          fontSize: 22,
                          height: 1.05,
                          color: VecColores.tinta,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 18,
                          height: 1.2,
                          color: VecColores.gris,
                        ),
                      ),
                    ],
                  );
                  // En los hubs van dos por fila: ícono arriba, texto abajo.
                  if (c.maxWidth < 240) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [icono, const SizedBox(height: 12), textos],
                    );
                  }
                  return Row(
                    children: [
                      icono,
                      const SizedBox(width: 16),
                      Expanded(child: textos),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _buildPapel();
  }
}

/// Pintor del borde de neón degradado (mantiene el estilo visual original).
class NeonGradientBorderPainter extends CustomPainter {
  final Color accentColor;
  final bool isHovered;

  NeonGradientBorderPainter({
    required this.accentColor,
    required this.isHovered,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    final gradient = SweepGradient(
      center: Alignment.topLeft,
      startAngle: 0,
      endAngle: math.pi * 2,
      colors: [
        accentColor.withValues(alpha: isHovered ? 0.9 : 0.65),
        accentColor.withValues(alpha: isHovered ? 0.55 : 0.35),
        accentColor.withValues(alpha: isHovered ? 0.30 : 0.18),
        accentColor.withValues(alpha: isHovered ? 0.22 : 0.12),
        accentColor.withValues(alpha: isHovered ? 0.30 : 0.18),
        accentColor.withValues(alpha: isHovered ? 0.45 : 0.28),
      ],
      stops: const [0.0, 0.12, 0.28, 0.5, 0.78, 1.0],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isHovered ? 1.2 : 0.8;
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(NeonGradientBorderPainter oldDelegate) {
    return oldDelegate.accentColor != accentColor ||
        oldDelegate.isHovered != isHovered;
  }
}
