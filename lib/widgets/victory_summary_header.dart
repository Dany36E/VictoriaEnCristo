/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY SUMMARY HEADER - Cabecera de Resumen de Victorias
/// Diseño amigable y cálido · celebratorio
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme_data.dart';

class VictorySummaryHeader extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final int totalVictories;
  final bool isLoggedToday;
  final bool canRegisterToday;
  final VoidCallback onRegisterVictory;

  // Semantic color (stays fixed)
  static const Color _victory = Color(0xFF66BB6A);

  const VictorySummaryHeader({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalVictories,
    required this.isLoggedToday,
    required this.canRegisterToday,
    required this.onRegisterVictory,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            t.surface,
            t.surface.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: t.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Streak principal ───
          Row(
            children: [
              // Fire emoji grande
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Racha actual',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$currentStreak',
                          style: GoogleFonts.manrope(
                            fontSize: currentStreak >= 100 ? 38 : 48,
                            fontWeight: FontWeight.w800,
                            color: t.textPrimary,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          currentStreak == 1 ? 'día' : 'días',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ─── Stats en cards ───
          Row(
            children: [
              _buildStatCard(
                t: t,
                emoji: '🏆',
                label: 'Mejor racha',
                value: '$longestStreak',
              ),
              const SizedBox(width: 12),
              _buildStatCard(
                t: t,
                emoji: '⭐',
                label: 'Este año',
                value: '$totalVictories',
              ),
            ],
          ),

          const SizedBox(height: 18),

          // ─── Botón / Estado ───
          _buildRegisterButton(t),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildStatCard({
    required AppThemeData t,
    required String emoji,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: t.inputBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: t.textSecondary.withOpacity(0.7),
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: t.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterButton(AppThemeData t) {
    if (isLoggedToday) {
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: _victory.withOpacity(0.15),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _victory.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('✅', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              '¡Victoria registrada hoy!',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _victory,
              ),
            ),
          ],
        ),
      );
    }

    if (!canRegisterToday) {
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: t.inputBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.divider),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🕒', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              'Disponible después de las 6pm',
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: t.textSecondary.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: onRegisterVictory,
      child: Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [t.accent.withOpacity(0.3), t.accent.withOpacity(0.15)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.accent.withOpacity(0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚔️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Text(
              'Registrar victoria de hoy',
              style: GoogleFonts.manrope(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
