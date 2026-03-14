import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../theme/app_theme.dart';

/// ============================================================================
/// PREMIUM CARD - Elevated glass card with subtle animations
/// ============================================================================

class PremiumCard extends StatefulWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final List<BoxShadow>? shadow;
  final Color? backgroundColor;
  final Gradient? gradient;
  final bool enableHaptics;
  final double? borderRadius;

  const PremiumCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.shadow,
    this.backgroundColor,
    this.gradient,
    this.enableHaptics = true,
    this.borderRadius,
  });

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _controller.forward();
      if (widget.enableHaptics) {
        AppDesignSystem.hapticLight();
      }
    }
  }

  void _onTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTapDown: widget.onTap != null ? _onTapDown : null,
      onTapUp: widget.onTap != null ? _onTapUp : null,
      onTapCancel: widget.onTap != null ? _onTapCancel : null,
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              margin: widget.margin,
              padding: widget.padding ??
                  const EdgeInsets.all(AppDesignSystem.spacingM),
              decoration: BoxDecoration(
                color: widget.gradient == null
                    ? (widget.backgroundColor ??
                        (isDark
                            ? AppDesignSystem.midnightLight
                            : AppDesignSystem.pureWhite))
                    : null,
                gradient: widget.gradient,
                borderRadius: BorderRadius.circular(
                    widget.borderRadius ?? AppDesignSystem.radiusM),
                border: Border.all(
                  color: isDark
                      ? AppDesignSystem.pureWhite.withOpacity(0.08)
                      : AppDesignSystem.midnight.withOpacity(0.06),
                  width: 1,
                ),
                boxShadow: widget.shadow ??
                    (isDark ? null : AppDesignSystem.shadowSoft),
              ),
              child: widget.child,
            ),
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// SCRIPTURE CARD - Beautiful verse display with sacred styling
/// ============================================================================

class ScriptureCard extends StatelessWidget {
  final String verse;
  final String reference;
  final VoidCallback? onTap;
  final bool showShareButton;
  final VoidCallback? onShare;

  const ScriptureCard({
    super.key,
    required this.verse,
    required this.reference,
    this.onTap,
    this.showShareButton = false,
    this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quote mark
          Icon(
            Icons.format_quote,
            color: AppDesignSystem.gold.withOpacity(0.4),
            size: 32,
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          
          // Verse text
          Text(
            verse,
            style: AppDesignSystem.scripture(
              context,
              color: isDark ? AppDesignSystem.pureWhite : null,
            ),
          ),
          
          const SizedBox(height: AppDesignSystem.spacingM),
          
          // Reference and share button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDesignSystem.spacingM,
                  vertical: AppDesignSystem.spacingS,
                ),
                decoration: BoxDecoration(
                  color: AppDesignSystem.goldSubtle,
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
                ),
                child: Text(
                  reference,
                  style: AppDesignSystem.scriptureReference(context),
                ),
              ),
              if (showShareButton)
                IconButton(
                  onPressed: () {
                    AppDesignSystem.hapticLight();
                    onShare?.call();
                  },
                  icon: Icon(
                    Icons.share_outlined,
                    color: isDark
                        ? AppDesignSystem.coolGray
                        : AppDesignSystem.midnightLight,
                    size: 20,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// ANIMATED LIST ITEM - For staggered list animations
/// ============================================================================

class AnimatedListItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration? delay;

  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay,
  });

  @override
  Widget build(BuildContext context) {
    return child
        .animate(delay: delay ?? (AppDesignSystem.staggerDelay * index))
        .fadeIn(duration: AppDesignSystem.durationMedium)
        .slideY(
          begin: 0.1,
          end: 0,
          duration: AppDesignSystem.durationMedium,
          curve: AppDesignSystem.curveDefault,
        );
  }
}

/// ============================================================================
/// SECTION HEADER - Elegant section titles
/// ============================================================================

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool useSacredFont;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.useSacredFont = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingM,
        vertical: AppDesignSystem.spacingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: useSacredFont
                    ? AppDesignSystem.displaySmall(
                        context,
                        color: isDark ? AppDesignSystem.pureWhite : null,
                      )
                    : AppDesignSystem.headlineMedium(
                        context,
                        color: isDark ? AppDesignSystem.pureWhite : null,
                      ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: AppDesignSystem.spacingXS),
                Text(
                  subtitle!,
                  style: AppDesignSystem.labelMedium(context),
                ),
              ],
            ],
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// ============================================================================
/// GOLDEN DIVIDER - Elegant separator
/// ============================================================================

class GoldenDivider extends StatelessWidget {
  final double? width;
  final EdgeInsets? margin;

  const GoldenDivider({
    super.key,
    this.width,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(vertical: AppDesignSystem.spacingM),
      width: width ?? 60,
      height: 2,
      decoration: BoxDecoration(
        gradient: AppDesignSystem.goldShimmer,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

/// ============================================================================
/// PREMIUM ICON BUTTON - Circular button with haptics
/// ============================================================================

class PremiumIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double? size;
  final List<BoxShadow>? shadow;
  final bool isEmergency;

  const PremiumIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size,
    this.shadow,
    this.isEmergency = false,
  });

  @override
  State<PremiumIconButton> createState() => _PremiumIconButtonState();
}

class _PremiumIconButtonState extends State<PremiumIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final buttonSize = widget.size ?? 56.0;
    
    return GestureDetector(
      onTapDown: (_) {
        _controller.forward();
        AppDesignSystem.hapticMedium();
      },
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: buttonSize,
              height: buttonSize,
              decoration: BoxDecoration(
                color: widget.backgroundColor ??
                    (widget.isEmergency
                        ? AppDesignSystem.struggle
                        : (isDark
                            ? AppDesignSystem.gold
                            : AppDesignSystem.midnight)),
                shape: BoxShape.circle,
                boxShadow: widget.shadow ??
                    (widget.isEmergency
                        ? AppDesignSystem.shadowStruggle
                        : AppDesignSystem.shadowMedium),
              ),
              child: Icon(
                widget.icon,
                color: widget.iconColor ??
                    (widget.isEmergency
                        ? AppDesignSystem.pureWhite
                        : (isDark
                            ? AppDesignSystem.midnight
                            : AppDesignSystem.pureWhite)),
                size: buttonSize * 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// ============================================================================
/// VICTORY PROGRESS RING - Circular progress with gold accent
/// ============================================================================

class VictoryProgressRing extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Widget? child;

  const VictoryProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 8,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: strokeWidth,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                isDark
                    ? AppDesignSystem.pureWhite.withOpacity(0.1)
                    : AppDesignSystem.midnight.withOpacity(0.1),
              ),
            ),
          ),
          // Progress ring
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0 ? AppDesignSystem.victory : AppDesignSystem.gold,
              ),
            ),
          ),
          // Center content
          if (child != null) child!,
        ],
      ),
    );
  }
}

/// ============================================================================
/// SHIMMER LOADING - Premium loading placeholder
/// ============================================================================

class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final double? borderRadius;

  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark
            ? AppDesignSystem.midnightLight
            : AppDesignSystem.warmGray,
        borderRadius: BorderRadius.circular(borderRadius ?? AppDesignSystem.radiusS),
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1500),
          color: isDark
              ? AppDesignSystem.pureWhite.withOpacity(0.1)
              : AppDesignSystem.pureWhite.withOpacity(0.5),
        );
  }
}

/// ============================================================================
/// FLOATING ACTION SECTION - Bottom action area with glass effect
/// ============================================================================

class FloatingActionSection extends StatelessWidget {
  final Widget child;
  final double? height;

  const FloatingActionSection({
    super.key,
    required this.child,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: height,
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: (isDark
                    ? AppDesignSystem.midnight
                    : AppDesignSystem.pureWhite)
                .withOpacity(0.9),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? AppDesignSystem.pureWhite.withOpacity(0.08)
                    : AppDesignSystem.midnight.withOpacity(0.06),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// ============================================================================
/// MOOD CHIP - Selectable mood indicator
/// ============================================================================

class MoodChip extends StatelessWidget {
  final String emoji;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const MoodChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        AppDesignSystem.hapticSelection();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppDesignSystem.durationFast,
        curve: AppDesignSystem.curveDefault,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppDesignSystem.goldSubtle
              : (isDark
                  ? AppDesignSystem.midnightLight
                  : AppDesignSystem.warmGray.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
          border: Border.all(
            color: isSelected
                ? AppDesignSystem.gold
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: AppDesignSystem.spacingS),
            Text(
              label,
              style: AppDesignSystem.labelMedium(
                context,
                color: isSelected
                    ? AppDesignSystem.gold
                    : (isDark
                        ? AppDesignSystem.coolGray
                        : AppDesignSystem.midnightLight),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ============================================================================
/// STREAK BADGE - Daily streak indicator
/// ============================================================================

class StreakBadge extends StatelessWidget {
  final int days;
  final bool isActive;

  const StreakBadge({
    super.key,
    required this.days,
    this.isActive = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingM,
        vertical: AppDesignSystem.spacingS,
      ),
      decoration: BoxDecoration(
        gradient: isActive ? AppDesignSystem.goldShimmer : null,
        color: isActive ? null : AppDesignSystem.coolGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        boxShadow: isActive ? AppDesignSystem.shadowGold : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.local_fire_department,
            color: isActive ? AppDesignSystem.midnight : AppDesignSystem.coolGray,
            size: 18,
          ),
          const SizedBox(width: AppDesignSystem.spacingXS),
          Text(
            '$days días',
            style: AppDesignSystem.labelLarge(
              context,
              color: isActive ? AppDesignSystem.midnight : AppDesignSystem.coolGray,
            ),
          ),
        ],
      ),
    );
  }
}

/// ============================================================================
/// EMPTY STATE - Beautiful empty state placeholder
/// ============================================================================

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppDesignSystem.goldSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: AppDesignSystem.gold,
              ),
            ),
            const SizedBox(height: AppDesignSystem.spacingL),
            Text(
              title,
              style: AppDesignSystem.headlineMedium(
                context,
                color: isDark ? AppDesignSystem.pureWhite : null,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                subtitle!,
                style: AppDesignSystem.bodyMedium(context),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              action!,
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: AppDesignSystem.durationMedium)
        .scale(
          begin: const Offset(0.9, 0.9),
          end: const Offset(1, 1),
          duration: AppDesignSystem.durationMedium,
          curve: AppDesignSystem.curveDefault,
        );
  }
}
