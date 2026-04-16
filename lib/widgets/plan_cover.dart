import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';
import '../models/plan.dart';
import '../models/plan_metadata.dart';
import '../models/content_enums.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN COVER - Portadas Premium Generadas
/// Genera covers tipo "editorial" con arte, textura y tipografía
/// Sin dependencia de imágenes externas
/// ═══════════════════════════════════════════════════════════════════════════

class PlanCover extends StatelessWidget {
  final Plan plan;
  final double? width;
  final double? height;
  final bool showTitle;
  final bool showBadge;
  final BorderRadius? borderRadius;
  
  const PlanCover({
    super.key,
    required this.plan,
    this.width,
    this.height,
    this.showTitle = false,
    this.showBadge = false,
    this.borderRadius,
  });
  
  /// Factory para thumbnail cuadrado (lista)
  factory PlanCover.thumbnail({
    required Plan plan,
    double size = 80,
    BorderRadius? borderRadius,
  }) {
    return PlanCover(
      plan: plan,
      width: size,
      height: size,
      showTitle: false,
      showBadge: false,
      borderRadius: borderRadius ?? BorderRadius.circular(12),
    );
  }
  
  /// Factory para header grande (detalle)
  factory PlanCover.header({
    required Plan plan,
    double? height,
  }) {
    return PlanCover(
      plan: plan,
      height: height ?? 280,
      showTitle: true,
      showBadge: true,
      borderRadius: BorderRadius.zero,
    );
  }
  
  /// Factory para card poster (carrusel)
  factory PlanCover.poster({
    required Plan plan,
    double width = 140,
    double height = 200,
  }) {
    return PlanCover(
      plan: plan,
      width: width,
      height: height,
      showTitle: true,
      showBadge: true,
      borderRadius: BorderRadius.circular(12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coverPath = plan.coverImagePath;
    final hasCover = coverPath.isNotEmpty && 
                     coverPath.startsWith('assets/') && 
                     !coverPath.contains('default');
    
    Widget content;
    
    if (hasCover) {
      // Usar imagen real con overlay
      content = _buildRealCover(coverPath);
    } else {
      // Generar cover premium
      content = _buildGeneratedCover(context);
    }
    
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(
        width: width,
        height: height,
        child: content,
      ),
    );
  }
  
  Widget _buildRealCover(String path) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          path,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildGeneratedCoverFallback(),
        ),
        // Overlay oscuro sutil
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.7),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
        if (showTitle) _buildTitleOverlay(),
        if (showBadge) _buildBadgeOverlay(),
      ],
    );
  }
  
  Widget _buildGeneratedCover(BuildContext context) {
    return _GeneratedCoverContent(
      plan: plan,
      showTitle: showTitle,
      showBadge: showBadge,
    );
  }
  
  Widget _buildGeneratedCoverFallback() {
    return _GeneratedCoverContent(
      plan: plan,
      showTitle: showTitle,
      showBadge: showBadge,
    );
  }
  
  Widget _buildTitleOverlay() {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              height: 1.2,
              shadows: [
                Shadow(color: Colors.black54, blurRadius: 4),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  Widget _buildBadgeOverlay() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${plan.durationDays} días',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// GENERATED COVER CONTENT - Arte generado para cada plan
/// ═══════════════════════════════════════════════════════════════════════════

class _GeneratedCoverContent extends StatelessWidget {
  final Plan plan;
  final bool showTitle;
  final bool showBadge;
  
  const _GeneratedCoverContent({
    required this.plan,
    required this.showTitle,
    required this.showBadge,
  });
  
  @override
  Widget build(BuildContext context) {
    final palette = _getPalette();
    final iconData = _getIcon();
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.primary,
            palette.secondary,
            palette.tertiary,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Textura de ruido (patrón sutil)
          _buildNoiseTexture(palette),
          
          // Elementos decorativos geométricos
          _buildDecorativeElements(palette),
          
          // Icono central grande
          _buildCentralIcon(iconData, palette),
          
          // Gradiente oscuro inferior
          _buildBottomGradient(),
          
          // Badge de duración
          if (showBadge) _buildDurationBadge(),
          
          // Título si se requiere
          if (showTitle) _buildTitle(),
        ],
      ),
    );
  }
  
  Widget _buildNoiseTexture(_CoverPalette palette) {
    // Patrón de puntos sutiles para textura
    return CustomPaint(
      painter: _NoisePainter(
        color: Colors.white.withOpacity(0.03),
        seed: plan.id.hashCode,
      ),
    );
  }
  
  Widget _buildDecorativeElements(_CoverPalette palette) {
    final hash = plan.id.hashCode;
    final random = math.Random(hash);
    
    return Stack(
      children: [
        // Círculo grande desenfocado
        Positioned(
          top: -30 + (random.nextDouble() * 60),
          right: -40 + (random.nextDouble() * 80),
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.accent.withOpacity(0.1),
            ),
          ),
        ),
        // Líneas diagonales sutiles
        Positioned(
          bottom: 40,
          left: -20,
          child: Transform.rotate(
            angle: -0.3,
            child: Container(
              width: 100,
              height: 2,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        // Otro círculo
        Positioned(
          bottom: -50 + (random.nextDouble() * 40),
          left: -30 + (random.nextDouble() * 60),
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: palette.accent.withOpacity(0.15),
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCentralIcon(IconData icon, _CoverPalette palette) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 40,
          color: palette.accent.withOpacity(0.6),
        ),
      ),
    );
  }
  
  Widget _buildBottomGradient() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              Colors.black.withOpacity(0.5),
              Colors.black.withOpacity(0.8),
            ],
            stops: const [0.0, 0.4, 0.7, 1.0],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDurationBadge() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${plan.durationDays}d',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  
  Widget _buildTitle() {
    return Positioned(
      left: 10,
      right: 10,
      bottom: 10,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plan.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              height: 1.2,
              shadows: [
                Shadow(color: Colors.black87, blurRadius: 4),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
  
  _CoverPalette _getPalette() {
    // Paletas oscuras premium por tipo de plan
    switch (plan.metadata.planType) {
      case PlanType.giantFocused:
        return const _CoverPalette(
          primary: Color(0xFF1A1A2E),
          secondary: Color(0xFF16213E),
          tertiary: Color(0xFF0F3460),
          accent: AppDesignSystem.gold,
        );
      case PlanType.emotionalRegulation:
        return const _CoverPalette(
          primary: Color(0xFF0D1B2A),
          secondary: Color(0xFF1B263B),
          tertiary: Color(0xFF415A77),
          accent: Color(0xFF778DA9),
        );
      case PlanType.relapseRecovery:
        return const _CoverPalette(
          primary: Color(0xFF2D132C),
          secondary: Color(0xFF801336),
          tertiary: Color(0xFFC72C41),
          accent: Color(0xFFEE4540),
        );
      case PlanType.scriptureDepth:
        return const _CoverPalette(
          primary: Color(0xFF1A1A2E),
          secondary: Color(0xFF0F4C5C),
          tertiary: Color(0xFF5F0A87),
          accent: Color(0xFFA7489B),
        );
      case PlanType.newInFaith:
        return const _CoverPalette(
          primary: Color(0xFF1B2631),
          secondary: Color(0xFF212F3D),
          tertiary: Color(0xFF2E4053),
          accent: AppDesignSystem.gold,
        );
      case PlanType.discipleship:
        return const _CoverPalette(
          primary: Color(0xFF0B3D0B),
          secondary: Color(0xFF155D27),
          tertiary: Color(0xFF1A7431),
          accent: Color(0xFF2DC653),
        );
    }
  }
  
  IconData _getIcon() {
    // Iconos por tipo de plan
    switch (plan.metadata.planType) {
      case PlanType.giantFocused:
        // Variar por giant principal
        if (plan.metadata.giants.isNotEmpty) {
          switch (plan.metadata.giants.first) {
            case GiantId.digital:
              return Icons.phonelink_off_outlined;
            case GiantId.sexual:
              return Icons.shield_outlined;
            case GiantId.health:
              return Icons.favorite_outline;
            case GiantId.substances:
              return Icons.block_outlined;
            case GiantId.mental:
              return Icons.psychology_outlined;
            case GiantId.emotions:
              return Icons.self_improvement_outlined;
          }
        }
        return Icons.shield_outlined;
      case PlanType.emotionalRegulation:
        return Icons.spa_outlined;
      case PlanType.relapseRecovery:
        return Icons.refresh_outlined;
      case PlanType.scriptureDepth:
        return Icons.menu_book_outlined;
      case PlanType.newInFaith:
        return Icons.child_care_outlined;
      case PlanType.discipleship:
        return Icons.school_outlined;
    }
  }
}

/// Paleta de colores para covers
class _CoverPalette {
  final Color primary;
  final Color secondary;
  final Color tertiary;
  final Color accent;
  
  const _CoverPalette({
    required this.primary,
    required this.secondary,
    required this.tertiary,
    required this.accent,
  });
}

/// Painter para textura de ruido sutil
class _NoisePainter extends CustomPainter {
  final Color color;
  final int seed;
  
  _NoisePainter({required this.color, required this.seed});
  
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    final paint = Paint()..color = color;
    
    // Dibujar puntos aleatorios
    for (var i = 0; i < 50; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 0.5;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) => false;
}
