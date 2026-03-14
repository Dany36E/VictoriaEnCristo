import 'dart:math' show cos, sin;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/plan.dart';
import '../models/plan_metadata.dart';
import '../models/content_enums.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN CARD - VERSIÓN MODERNA
/// Tarjeta para mostrar planes con el modelo Plan actualizado
/// Soporta: grid view, list view, y carousel horizontal
/// ═══════════════════════════════════════════════════════════════════════════

enum PlanCardStyle {
  poster,     // Vertical poster (Netflix style) - para carousels
  gridTile,   // Cuadrado para grid 2x2
  listTile,   // Horizontal para listas
}

class PlanCard extends StatelessWidget {
  final Plan plan;
  final PlanProgress? progress;
  final VoidCallback onTap;
  final PlanCardStyle style;
  final double? width;
  final double? height;

  const PlanCard({
    super.key,
    required this.plan,
    this.progress,
    required this.onTap,
    this.style = PlanCardStyle.poster,
    this.width,
    this.height,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY CONSTRUCTORS
  // ═══════════════════════════════════════════════════════════════════════════

  factory PlanCard.poster({
    required Plan plan,
    PlanProgress? progress,
    required VoidCallback onTap,
    double width = 140,
    double height = 210,
  }) {
    return PlanCard(
      plan: plan,
      progress: progress,
      onTap: onTap,
      style: PlanCardStyle.poster,
      width: width,
      height: height,
    );
  }

  factory PlanCard.grid({
    required Plan plan,
    PlanProgress? progress,
    required VoidCallback onTap,
    double size = 165,
  }) {
    return PlanCard(
      plan: plan,
      progress: progress,
      onTap: onTap,
      style: PlanCardStyle.gridTile,
      width: size,
      height: size,
    );
  }

  factory PlanCard.list({
    required Plan plan,
    PlanProgress? progress,
    required VoidCallback onTap,
    double height = 100,
  }) {
    return PlanCard(
      plan: plan,
      progress: progress,
      onTap: onTap,
      style: PlanCardStyle.listTile,
      height: height,
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (style) {
      case PlanCardStyle.poster:
        return _buildPosterCard(context);
      case PlanCardStyle.gridTile:
        return _buildGridTile(context);
      case PlanCardStyle.listTile:
        return _buildListTile(context);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POSTER CARD (Vertical - Netflix Style)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPosterCard(BuildContext context) {
    final cardWidth = width ?? 140.0;
    final cardHeight = height ?? 210.0;
    final progressPercent = progress?.progressPercentage(plan.durationDays) ?? 0.0;
    final isStarted = progress != null && progress!.completedDays.isNotEmpty;
    final isCompleted = progressPercent >= 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              _buildCoverImage(),

              // Gradient Overlay
              _buildGradientOverlay(),

              // Progress Bar (if started)
              if (isStarted && !isCompleted)
                _buildProgressBar(progressPercent),

              // Difficulty Badge
              Positioned(
                top: 8,
                right: 8,
                child: _buildDifficultyBadge(context),
              ),

              // Completed Check
              if (isCompleted)
                _buildCompletedBadge(),

              // Content
              Positioned(
                left: 10,
                right: 10,
                bottom: 12,
                child: _buildPosterContent(context, isStarted, isCompleted),
              ),

              // Ripple Effect
              _buildRipple(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GRID TILE (Square)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildGridTile(BuildContext context) {
    final cardSize = width ?? 165.0;
    final progressPercent = progress?.progressPercentage(plan.durationDays) ?? 0.0;
    final isStarted = progress != null && progress!.completedDays.isNotEmpty;
    final isCompleted = progressPercent >= 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              _buildCoverImage(),

              // Gradient Overlay (más intenso para grid)
              _buildGradientOverlay(intensified: true),

              // Progress Ring en esquina
              if (isStarted && !isCompleted)
                Positioned(
                  top: 10,
                  right: 10,
                  child: _buildProgressRing(progressPercent),
                ),

              // Completed Badge
              if (isCompleted)
                _buildCompletedBadge(),

              // Difficulty Badge (abajo izquierda)
              Positioned(
                bottom: 10,
                left: 10,
                child: _buildDifficultyBadge(context, small: false),
              ),

              // Giants chips
              Positioned(
                top: 10,
                left: 10,
                right: isStarted ? 50 : 10,
                child: _buildGiantsRow(context),
              ),

              // Content
              Positioned(
                left: 50,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      plan.title,
                      style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.pureWhite).copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.durationLabel,
                      style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray).copyWith(
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              // Ripple
              _buildRipple(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIST TILE (Horizontal)
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildListTile(BuildContext context) {
    final cardHeight = height ?? 100.0;
    final progressPercent = progress?.progressPercentage(plan.durationDays) ?? 0.0;
    final isStarted = progress != null && progress!.completedDays.isNotEmpty;
    final isCompleted = progressPercent >= 1.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: cardHeight,
        decoration: BoxDecoration(
          color: AppDesignSystem.midnightLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted 
              ? AppDesignSystem.victory.withOpacity(0.3) 
              : AppDesignSystem.goldSubtle,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Cover Image (Square)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                bottomLeft: Radius.circular(11),
              ),
              child: SizedBox(
                width: cardHeight,
                height: cardHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCoverImage(),
                    if (isCompleted)
                      Container(
                        color: AppDesignSystem.victory.withOpacity(0.3),
                        child: const Center(
                          child: Icon(Icons.check_circle, color: AppDesignSystem.victory, size: 32),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Title
                    Text(
                      plan.title,
                      style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.pureWhite).copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    Text(
                      plan.subtitle,
                      style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Footer row
                    Row(
                      children: [
                        // Duration
                        Icon(Icons.calendar_today_outlined, size: 12, color: AppDesignSystem.gold),
                        const SizedBox(width: 4),
                        Text(
                          plan.durationLabel,
                          style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
                        ),
                        const SizedBox(width: 12),

                        // Time per day
                        Icon(Icons.access_time_outlined, size: 12, color: AppDesignSystem.gold),
                        const SizedBox(width: 4),
                        Text(
                          '${plan.minutesPerDay} min',
                          style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
                        ),

                        const Spacer(),

                        // Progress or status
                        if (isStarted && !isCompleted)
                          Text(
                            '${(progressPercent * 100).toInt()}%',
                            style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),

                    // Progress bar
                    if (isStarted && !isCompleted) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progressPercent,
                        backgroundColor: AppDesignSystem.midnight.withOpacity(0.5),
                        valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
                        minHeight: 3,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Arrow
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.chevron_right,
                color: AppDesignSystem.coolGray,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHARED COMPONENTS
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildCoverImage() {
    final imagePath = plan.coverImagePath;
    
    if (imagePath.startsWith('http')) {
      // Network image - usar placeholder simple sin cached_network_image
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          debugPrint('⚠️ Missing cover for planId=${plan.id} path=$imagePath');
          return _buildImagePlaceholder();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildImagePlaceholder(showLoading: true);
        },
      );
    } else if (imagePath.startsWith('assets/')) {
      // Asset image
      return Image.asset(
        imagePath,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          debugPrint('⚠️ Missing cover for planId=${plan.id} path=$imagePath');
          return _buildImagePlaceholder();
        },
      );
    } else {
      // Fallback placeholder
      debugPrint('⚠️ No cover defined for planId=${plan.id}');
      return _buildImagePlaceholder();
    }
  }

  Widget _buildImagePlaceholder({bool showLoading = false}) {
    // Generar colores únicos basados en planId para variedad visual
    final hash = plan.id.hashCode;
    
    // Paleta premium basada en gigante + variación por planId
    final baseColors = <GiantId, List<Color>>{
      GiantId.digital: [const Color(0xFF1A237E), const Color(0xFF3F51B5)],
      GiantId.sexual: [const Color(0xFF4A148C), const Color(0xFF9C27B0)],
      GiantId.health: [const Color(0xFFE65100), const Color(0xFFFF9800)],
      GiantId.substances: [const Color(0xFFB71C1C), const Color(0xFFF44336)],
      GiantId.mental: [const Color(0xFF1B5E20), const Color(0xFF4CAF50)],
      GiantId.emotions: [const Color(0xFF880E4F), const Color(0xFFE91E63)],
    };
    
    final primaryGiant = plan.metadata.giants.isNotEmpty 
        ? plan.metadata.giants.first 
        : GiantId.sexual;
    final colors = baseColors[primaryGiant] ?? [AppDesignSystem.midnight, AppDesignSystem.coolGray];
    
    // Variar ángulo del gradiente basado en hash para que cada plan sea diferente
    final angle = (hash % 360).toDouble() * 3.14159 / 180;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(cos(angle), sin(angle)),
          end: Alignment(-cos(angle), -sin(angle)),
          colors: [
            colors[0].withOpacity(0.9),
            colors[1].withOpacity(0.7),
            colors[0].withOpacity(0.6),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Patrón decorativo sutil
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              _getPlanTypeIcon(),
              color: Colors.white.withOpacity(0.08),
              size: 120,
            ),
          ),
          // Contenido central
          Center(
            child: showLoading
              ? SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppDesignSystem.gold.withOpacity(0.7)),
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getPlanTypeIcon(),
                      color: Colors.white.withOpacity(0.6),
                      size: 36,
                    ),
                    if (style == PlanCardStyle.poster) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${plan.durationDays} días',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
          ),
        ],
      ),
    );
  }

  IconData _getPlanTypeIcon() {
    switch (plan.metadata.planType) {
      case PlanType.newInFaith:
        return Icons.child_care_outlined;
      case PlanType.giantFocused:
        return Icons.local_hospital_outlined;
      case PlanType.scriptureDepth:
        return Icons.menu_book_outlined;
      case PlanType.emotionalRegulation:
        return Icons.spa_outlined;
      case PlanType.relapseRecovery:
        return Icons.refresh;
      case PlanType.discipleship:
        return Icons.auto_awesome;
    }
  }

  Widget _buildGradientOverlay({bool intensified = false}) {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.transparent,
              AppDesignSystem.midnightDeep.withOpacity(intensified ? 0.8 : 0.7),
              AppDesignSystem.midnightDeep.withOpacity(intensified ? 1.0 : 0.95),
            ],
            stops: const [0.0, 0.3, 0.7, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progressPercent) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: AppDesignSystem.midnightDeep.withOpacity(0.5),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
          ),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progressPercent.clamp(0.0, 1.0),
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppDesignSystem.goldShimmer,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressRing(double progressPercent) {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progressPercent.clamp(0.0, 1.0),
            strokeWidth: 3,
            backgroundColor: AppDesignSystem.midnight.withOpacity(0.5),
            valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
          ),
          Text(
            '${(progressPercent * 100).toInt()}',
            style: const TextStyle(
              color: AppDesignSystem.pureWhite,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyBadge(BuildContext context, {bool small = true}) {
    IconData icon;
    Color color;

    switch (plan.metadata.difficulty) {
      case PlanDifficulty.easy:
        icon = Icons.spa_outlined;
        color = AppDesignSystem.victory;
        break;
      case PlanDifficulty.medium:
        icon = Icons.local_fire_department_outlined;
        color = AppDesignSystem.hope;
        break;
      case PlanDifficulty.hard:
        icon = Icons.bolt;
        color = AppDesignSystem.struggle;
        break;
    }

    final size = small ? 26.0 : 30.0;
    final iconSize = small ? 14.0 : 18.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
  }

  Widget _buildCompletedBadge() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: AppDesignSystem.victory,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppDesignSystem.victory.withOpacity(0.5),
              blurRadius: 8,
            ),
          ],
        ),
        child: const Icon(
          Icons.check,
          color: Colors.white,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildGiantsRow(BuildContext context) {
    if (plan.metadata.giants.isEmpty) return const SizedBox.shrink();
    
    final giantColors = {
      GiantId.digital: const Color(0xFF3498DB),
      GiantId.sexual: const Color(0xFF8E44AD),
      GiantId.health: const Color(0xFFE67E22),
      GiantId.substances: const Color(0xFFC0392B),
      GiantId.mental: const Color(0xFF2C3E50),
      GiantId.emotions: const Color(0xFFE74C3C),
    };
    
    return Row(
      children: [
        for (var i = 0; i < plan.metadata.giants.length.clamp(0, 2); i++)
          Padding(
            padding: EdgeInsets.only(right: i < plan.metadata.giants.length - 1 ? 4 : 0),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: giantColors[plan.metadata.giants[i]] ?? AppDesignSystem.gold,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              ),
            ),
          ),
        if (plan.metadata.giants.length > 2)
          Text(
            '+${plan.metadata.giants.length - 2}',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildPosterContent(BuildContext context, bool isStarted, bool isCompleted) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title
        Text(
          plan.title,
          style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.pureWhite).copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            height: 1.2,
            shadows: [Shadow(color: Colors.black.withOpacity(0.8), blurRadius: 4)],
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),

        // Days info
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined, size: 10, color: AppDesignSystem.gold),
            const SizedBox(width: 4),
            Text(
              plan.durationLabel,
              style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray).copyWith(
                fontSize: 10,
              ),
            ),
            if (isStarted && !isCompleted) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Día ${progress!.currentDay}',
                  style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold).copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildRipple() {
    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: AppDesignSystem.gold.withOpacity(0.15),
          highlightColor: AppDesignSystem.gold.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
