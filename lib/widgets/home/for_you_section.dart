/// Sección "Para Ti Hoy" con versículo ancla y quick actions.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/content_enums.dart';
import '../../models/content_item.dart';
import '../../services/personalization_engine.dart';
import '../../theme/app_theme.dart';

class ForYouTodaySection extends StatelessWidget {
  final GiantId primaryGiant;
  final ScoredItem<VerseItem>? anchorVerse;
  final int battleVersesCount;
  final int prayersCount;
  final void Function(String reference) onTapVerse;
  final VoidCallback onTapVerses;
  final VoidCallback onTapPrayers;

  const ForYouTodaySection({
    super.key,
    required this.primaryGiant,
    required this.anchorVerse,
    required this.battleVersesCount,
    required this.prayersCount,
    required this.onTapVerse,
    required this.onTapVerses,
    required this.onTapPrayers,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDesignSystem.spacingS),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.2),
                borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                border: Border.all(
                  color: const Color(0xFFD4AF37).withOpacity(0.4),
                  width: 0.5,
                ),
              ),
              child: Text(
                primaryGiant.emoji,
                style: const TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PARA TI HOY',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  Text(
                    'Enfoque: ${primaryGiant.displayName}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

        const SizedBox(height: AppDesignSystem.spacingM),

        if (anchorVerse != null) _AnchorVerseCard(
          scoredVerse: anchorVerse!,
          onTap: () => onTapVerse(anchorVerse!.item.reference),
        ),

        const SizedBox(height: AppDesignSystem.spacingS),

        // Quick actions
        Row(
          children: [
            Expanded(
              child: _QuickActionChip(
                emoji: '📖',
                label: '$battleVersesCount Versículos',
                onTap: onTapVerses,
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            Expanded(
              child: _QuickActionChip(
                emoji: '🙏',
                label: '$prayersCount Oraciones',
                onTap: onTapPrayers,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
      ],
    );
  }
}

class _AnchorVerseCard extends StatelessWidget {
  final ScoredItem<VerseItem> scoredVerse;
  final VoidCallback onTap;

  const _AnchorVerseCard({required this.scoredVerse, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final verse = scoredVerse.item;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.12),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.anchor, color: Color(0xFFD4AF37), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Versículo ancla',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: const Color(0xFFD4AF37).withOpacity(0.9),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: Colors.white.withOpacity(0.4),
                ),
              ],
            ),
            const SizedBox(height: AppDesignSystem.spacingS),
            Text(
              '"${verse.title}"',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.white,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              verse.reference,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                scoredVerse.reason,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

class _QuickActionChip extends StatelessWidget {
  final String emoji;
  final String label;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.emoji,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        ),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
