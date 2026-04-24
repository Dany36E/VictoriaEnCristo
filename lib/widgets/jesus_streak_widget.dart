/// ═══════════════════════════════════════════════════════════════════════════
/// JESUS STREAK WIDGET - Widget de racha con sprite de Jesús estilo Duolingo
/// Muestra sprite animado de Jesús, fondo dinámico y sistema de racha
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/jesus_widget_service.dart';

class JesusStreakWidget extends StatelessWidget {
  final int streakDays;
  final bool completedToday;
  final bool isNewUser;
  final bool isLoading;
  final bool checkinDone;
  final VoidCallback onRegisterVictory;
  final VoidCallback? onTapCard;

  const JesusStreakWidget({
    super.key,
    required this.streakDays,
    required this.completedToday,
    required this.isNewUser,
    this.isLoading = false,
    this.checkinDone = false,
    required this.onRegisterVictory,
    this.onTapCard,
  });

  @override
  Widget build(BuildContext context) {
    final service = JesusWidgetService.I;
    final spritePath = service.getSprite(
      streakDays: streakDays,
      completedToday: completedToday,
      isNewUser: isNewUser,
    );
    final bgPath = service.getBackground(streakDays: streakDays);
    final streakColor = service.getStreakColor(streakDays);
    final message = service.getMessage(
      streakDays: streakDays,
      completedToday: completedToday,
      isNewUser: isNewUser,
    );

    return Semantics(
      button: true,
      label: completedToday
          ? 'Racha actual: $streakDays días. Victoria de hoy ya registrada.'
          : 'Registrar victoria de hoy. Racha actual: $streakDays días.',
      child: GestureDetector(
        onTap: onRegisterVictory,
        child: Container(
          height: 240,
          margin: const EdgeInsets.only(top: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: streakColor.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ─── CAPA 1: Fondo dinámico ───
              Image.asset(
                bgPath,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (context, error, stackTrace) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        streakColor.withOpacity(0.3),
                        const Color(0xFF0A0A12),
                      ],
                    ),
                  ),
                ),
              ),

              // ─── CAPA 2: Overlay oscuro degradado ───
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.1),
                      Colors.black.withOpacity(0.3),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),

              // ─── CAPA 3: Contenido ───
              Row(
                children: [
                  // ─── Sprite de Jesús (izquierda) ───
                  SizedBox(
                    width: 150,
                    child: Transform.translate(
                      offset: const Offset(0, -20),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Image.asset(
                          spritePath,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white24,
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideY(
                          begin: 0.1,
                          end: 0,
                          duration: 500.ms,
                          curve: Curves.easeOutBack,
                        ),
                  ),

                  // ─── Info de racha (derecha) ───
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(4, 20, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Streak counter
                          _buildStreakCounter(streakColor),

                          const SizedBox(height: 8),

                          // Mensaje motivacional
                          Text(
                            message,
                            style: GoogleFonts.manrope(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                              height: 1.3,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const Spacer(),

                          // Botón de acción
                          _buildActionButton(streakColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // ─── CAPA 4: Borde sutil ───
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: streakColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAK COUNTER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildStreakCounter(Color streakColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (isLoading)
          SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(streakColor),
            ),
          )
        else ...[
          // Icono de fuego
          Icon(
            streakDays > 0 ? Icons.local_fire_department : Icons.wb_sunny_rounded,
            color: streakColor,
            size: 28,
          ),
          const SizedBox(width: 6),
          // Número grande (se adapta si tiene 4+ dígitos)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                isNewUser ? '0' : '$streakDays',
                style: GoogleFonts.cinzel(
                  fontSize: streakDays >= 1000
                      ? 30.0
                      : streakDays >= 100
                          ? 36.0
                          : (streakDays >= 10 ? 42.0 : 48.0),
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1,
                ),
                maxLines: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Label
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    streakDays == 1 ? 'DÍA' : 'DÍAS',
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: streakDays >= 10 ? 0.5 : 1.5,
                      color: streakColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (streakDays < 100 && !(completedToday && streakDays >= 10))
                    Text(
                      'DE VICTORIA',
                      style: GoogleFonts.manrope(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ],

        // Badge "Hoy ✓"
        if (completedToday && !isLoading) ...[
          const SizedBox(width: 4),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: streakDays >= 100 ? 6 : 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFF4CAF50).withOpacity(0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, size: 12, color: Color(0xFF4CAF50)),
                if (streakDays < 100) ...[
                  const SizedBox(width: 3),
                  const Text(
                    'Hoy',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ],
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 300.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 300.ms,
              ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTION BUTTON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildActionButton(Color streakColor) {
    final hour = DateTime.now().hour;
    final canRegister = !completedToday && hour >= 18;
    final badgeText = JesusWidgetService.I.getBadgeText(
      completedToday: completedToday,
      isNewUser: isNewUser,
      checkinDone: checkinDone,
    );
    // En ventana de registro usar CTA directa; completado → progreso
    final label = completedToday
        ? 'Ver mi progreso'
        : canRegister
            ? 'Registrar victoria'
            : badgeText;
    final icon = completedToday
        ? Icons.insights_rounded
        : canRegister
            ? Icons.shield_outlined
            : hour < 5
                ? Icons.nightlight_round
                : hour < 12
                    ? Icons.wb_sunny_outlined
                    : hour < 18
                        ? Icons.shield_outlined
                        : Icons.shield_outlined;

    return GestureDetector(
      onTap: isLoading ? null : onRegisterVictory,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37).withOpacity(0.15),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.5),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: const Color(0xFFD4AF37),
              size: 16,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFD4AF37),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }


}
