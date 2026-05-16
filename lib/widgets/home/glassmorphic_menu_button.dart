import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
  static const Color _surfaceTop = Color(0xDD1B263B);
  static const Color _surfaceBottom = Color(0xE6050A12);

  bool _isHovered = false;
  bool _isPressed = false;

  late AnimationController _iconAnimationController;
  late AnimationController _shimmerController;
  late Animation<double> _iconAnimation;

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
        _iconAnimation = Tween<double>(
          begin: 1.0,
          end: 1.0,
        ).animate(_iconAnimationController);
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
        _iconAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
          CurvedAnimation(
            parent: _iconAnimationController,
            curve: Curves.easeInOutSine,
          ),
        );
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
        _iconAnimation = Tween<double>(
          begin: 0,
          end: 2 * math.pi,
        ).animate(_iconAnimationController);
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
        _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _iconAnimationController,
            curve: Curves.easeOutCubic,
          ),
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
        _iconAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
          CurvedAnimation(
            parent: _iconAnimationController,
            curve: Curves.easeInOut,
          ),
        );
        break;
    }
  }

  @override
  void dispose() {
    _iconAnimationController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) => setState(() => _isPressed = false),
            onTapCancel: () => setState(() => _isPressed = false),
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onTap();
            },
            child: AnimatedScale(
              scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                height: widget.height,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: _isPressed || _isHovered
                              ? [
                                  Color.alphaBlend(
                                    widget.accentColor.withOpacity(0.22),
                                    _surfaceTop,
                                  ),
                                  Color.alphaBlend(
                                    widget.accentColor.withOpacity(0.10),
                                    _surfaceBottom,
                                  ),
                                ]
                              : [_surfaceTop, _surfaceBottom],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CustomPaint(
                        painter: NeonGradientBorderPainter(
                          accentColor: widget.accentColor,
                          isHovered: _isHovered,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildAnimatedIcon(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.subtitle,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontWeight: FontWeight.w500,
                                            letterSpacing: 0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 11,
                                        color: Colors.white.withOpacity(0.5),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(
          delay: Duration(milliseconds: 300 + (widget.index * 100)),
          duration: const Duration(milliseconds: 500),
        )
        .slideY(
          begin: 0.2,
          end: 0,
          curve: Curves.easeOutCubic,
          delay: Duration(milliseconds: 300 + (widget.index * 100)),
        );
  }

  Widget _buildAnimatedIcon() {
    const double iconSize = 28;
    Widget iconWidget = Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: widget.accentColor.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
          BoxShadow(
            color: widget.accentColor.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(widget.icon, color: widget.accentColor, size: iconSize),
    );
    switch (widget.animationType) {
      case IconAnimationType.shimmer:
        return AnimatedBuilder(
          animation: _shimmerController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.6),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      widget.accentColor,
                      Colors.white,
                      widget.accentColor,
                    ],
                    stops: [
                      (_shimmerController.value - 0.3).clamp(0.0, 1.0),
                      _shimmerController.value,
                      (_shimmerController.value + 0.3).clamp(0.0, 1.0),
                    ],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.srcIn,
                child: Icon(widget.icon, color: Colors.white, size: iconSize),
              ),
            );
          },
        );
      case IconAnimationType.heartbeat:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _iconAnimation.value,
              child: iconWidget,
            );
          },
        );
      case IconAnimationType.rotate:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Transform.rotate(
              angle: _iconAnimation.value,
              child: iconWidget,
            );
          },
        );
      case IconAnimationType.drawUp:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: _iconAnimation.value,
              child: Transform.translate(
                offset: Offset(0, 8 * (1 - _iconAnimation.value)),
                child: iconWidget,
              ),
            );
          },
        );
      case IconAnimationType.pulse:
        return AnimatedBuilder(
          animation: _iconAnimation,
          builder: (context, child) {
            return Opacity(
              opacity: 0.7 + (_iconAnimation.value * 0.3),
              child: iconWidget,
            );
          },
        );
    }
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
        accentColor.withOpacity(isHovered ? 0.9 : 0.65),
        accentColor.withOpacity(isHovered ? 0.55 : 0.35),
        accentColor.withOpacity(isHovered ? 0.30 : 0.18),
        accentColor.withOpacity(isHovered ? 0.22 : 0.12),
        accentColor.withOpacity(isHovered ? 0.30 : 0.18),
        accentColor.withOpacity(isHovered ? 0.45 : 0.28),
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
