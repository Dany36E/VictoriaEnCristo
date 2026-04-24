/// ═══════════════════════════════════════════════════════════════════════════
/// ErrorRetryWidget - Estado de error estandarizado con retry
/// Usado por pantallas que cargan datos async y pueden fallar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

class ErrorRetryWidget extends StatelessWidget {
  final String? title;
  final String? message;
  final Object? error;
  final VoidCallback? onRetry;
  final IconData icon;
  final bool compact;

  const ErrorRetryWidget({
    super.key,
    this.title,
    this.message,
    this.error,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
    this.compact = false,
  });

  /// Variante común para errores de red.
  const ErrorRetryWidget.network({
    super.key,
    this.onRetry,
    this.error,
    this.compact = false,
  })  : title = 'Sin conexión',
        message =
            'No pudimos conectarnos. Revisa tu internet e inténtalo de nuevo.',
        icon = Icons.wifi_off_rounded;

  /// Variante común para errores genéricos.
  const ErrorRetryWidget.generic({
    super.key,
    this.onRetry,
    this.error,
    this.compact = false,
  })  : title = 'Algo salió mal',
        message = 'Inténtalo de nuevo en un momento.',
        icon = Icons.error_outline_rounded;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final padding = compact
        ? const EdgeInsets.all(AppDesignSystem.spacingM)
        : const EdgeInsets.all(AppDesignSystem.spacingL);

    return Center(
      child: Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 40 : 64,
              color: t.textSecondary.withOpacity(0.6),
            ),
            const SizedBox(height: AppDesignSystem.spacingM),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: compact
                    ? AppDesignSystem.labelLarge(context, color: t.textPrimary)
                    : AppDesignSystem.headlineSmall(context, color: t.textPrimary),
              ),
            if (message != null) ...[
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(
                  context,
                  color: t.textSecondary,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              PremiumButton(
                onPressed: onRetry!,
                backgroundColor: AppDesignSystem.gold,
                child: Text(
                  'Reintentar',
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: AppDesignSystem.midnightDeep,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de vacío con ilustración y CTA opcional.
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.auto_awesome_rounded,
    this.ctaLabel,
    this.onCta,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppDesignSystem.gold.withOpacity(0.8)),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
            ),
            if (message != null) ...[
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(
                  context,
                  color: t.textSecondary,
                ),
              ),
            ],
            if (ctaLabel != null && onCta != null) ...[
              const SizedBox(height: AppDesignSystem.spacingL),
              PremiumButton(
                onPressed: onCta!,
                backgroundColor: AppDesignSystem.gold,
                child: Text(
                  ctaLabel!,
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: AppDesignSystem.midnightDeep,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
