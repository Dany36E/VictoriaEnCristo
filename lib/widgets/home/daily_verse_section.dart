/// Sección de versículo diario con tarjeta glassmorphic.
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/bible_verses.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class DailyVerseSection extends StatelessWidget {
  final BibleVerse dailyVerse;
  final void Function(String reference) onTapVerse;

  const DailyVerseSection({
    super.key,
    required this.dailyVerse,
    required this.onTapVerse,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final fg = t.textPrimary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingS),
              decoration: BoxDecoration(
                color: fg.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                border: Border.all(
                  color: fg.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.auto_stories_outlined,
                color: fg,
                size: 20,
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            Text(
              'VERSÍCULO DEL DÍA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: fg.withOpacity(0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppDesignSystem.spacingM),
        _ScriptureCard(
          dailyVerse: dailyVerse,
          onTap: () => onTapVerse(dailyVerse.reference),
        ),
      ],
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }
}

class _ScriptureCard extends StatelessWidget {
  final BibleVerse dailyVerse;
  final VoidCallback onTap;

  const _ScriptureCard({required this.dailyVerse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final fg = t.textPrimary;
    final glassOverlay = t.isDark ? Colors.white : Colors.black;
    return Semantics(
      button: true,
      label: 'Versículo del día: ${dailyVerse.reference}. Toca para leer en contexto',
      child: GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  glassOverlay.withOpacity(0.12),
                  glassOverlay.withOpacity(0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: fg.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  size: 32,
                  color: t.accent.withOpacity(0.7),
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                Text(
                  dailyVerse.verse,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    height: 1.6,
                    color: fg,
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 2,
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                    const SizedBox(width: AppDesignSystem.spacingS),
                    Text(
                      dailyVerse.reference,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: fg.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }
}
