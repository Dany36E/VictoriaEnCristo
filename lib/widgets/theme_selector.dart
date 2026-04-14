import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme_data.dart';
import '../services/theme_service.dart';

/// Selector visual de temas — 9 swatches circulares reutilizable
/// Usado en Settings y Profile.
class ThemeSelectorWidget extends StatelessWidget {
  /// Si true, muestra nombres debajo de cada swatch
  final bool showLabels;

  /// Tamaño de cada swatch circular
  final double swatchSize;

  /// Callback opcional cuando se cambia el tema
  final VoidCallback? onChanged;

  const ThemeSelectorWidget({
    super.key,
    this.showLabels = true,
    this.swatchSize = 42,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ts = ThemeService();
    return ValueListenableBuilder<String>(
      valueListenable: ts.themeIdNotifier,
      builder: (context, currentId, _) {
        return Wrap(
          spacing: 12,
          runSpacing: showLabels ? 16 : 12,
          alignment: WrapAlignment.center,
          children: AppThemeData.all.map((theme) {
            final isActive = theme.id == currentId;
            return GestureDetector(
              onTap: () {
                ts.setTheme(theme.id);
                onChanged?.call();
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: swatchSize,
                    height: swatchSize,
                    decoration: BoxDecoration(
                      color: theme.scaffoldBg,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isActive
                            ? theme.accent
                            : (theme.isDark
                                ? Colors.white.withOpacity(0.2)
                                : Colors.black.withOpacity(0.12)),
                        width: isActive ? 2.5 : 1,
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: theme.accent.withOpacity(0.3),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: isActive
                        ? Icon(
                            Icons.check_rounded,
                            size: swatchSize * 0.45,
                            color: theme.isDark ? Colors.white : theme.accent,
                          )
                        : null,
                  ),
                  if (showLabels) ...[
                    const SizedBox(height: 4),
                    SizedBox(
                      width: swatchSize + 16,
                      child: Text(
                        theme.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.manrope(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: AppThemeData.of(context).textSecondary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
