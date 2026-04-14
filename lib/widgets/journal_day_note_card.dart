/// ═══════════════════════════════════════════════════════════════════════════
/// JOURNAL DAY NOTE CARD - Nota del Diario del Día
/// Diseño amigable y cálido
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/journal_service.dart';
import '../services/feedback_engine.dart';

class JournalDayNoteCard extends StatelessWidget {
  final DateTime selectedDate;
  final JournalEntry? entry;
  final bool isLoading;
  final VoidCallback onTapEdit;
  final VoidCallback onTapCreate;

  static const Color _gold = Color(0xFFD4A853);
  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textMuted = Color(0xFF8A8A9A);
  static const Color _warmBg = Color(0xFF1A1520);

  const JournalDayNoteCard({
    super.key,
    required this.selectedDate,
    required this.entry,
    required this.isLoading,
    required this.onTapEdit,
    required this.onTapCreate,
  });

  bool get _isToday {
    final now = DateTime.now();
    return selectedDate.year == now.year &&
           selectedDate.month == now.month &&
           selectedDate.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _warmBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          if (isLoading)
            _buildLoadingState()
          else if (entry != null)
            _buildEntryContent()
          else
            _buildEmptyState(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildHeader() {
    const dayNames = [
      '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    const monthNames = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];

    final dateStr = '${dayNames[selectedDate.weekday]} ${selectedDate.day} de ${monthNames[selectedDate.month]}';

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: Text('📖', style: TextStyle(fontSize: 20)),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi diario',
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Text(
                dateStr,
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: _textMuted.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _gold.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryContent() {
    final content = entry!.content;
    final snippet = content.length > 140
        ? '${content.substring(0, 140)}...'
        : content;

    final hour = entry!.date.hour.toString().padLeft(2, '0');
    final minute = entry!.date.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry!.mood.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      JournalService.moodEmojis[entry!.mood] ?? '📝',
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      JournalService.moodLabels[entry!.mood] ?? '',
                      style: GoogleFonts.manrope(
                        fontSize: 13,
                        color: _gold.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '🕐 $timeStr',
                      style: GoogleFonts.manrope(
                        fontSize: 11,
                        color: _textMuted.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              Text(
                snippet,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  color: _textPrimary.withOpacity(0.85),
                  height: 1.55,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          emoji: '✏️',
          label: 'Ver / Editar',
          onTap: () {
            FeedbackEngine.I.select();
            onTapEdit();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Text('📝', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 8),
              Text(
                _isToday ? '¿Cómo te fue hoy?' : 'Sin entrada este día',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textMuted.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isToday ? 'Escribe sobre tu día' : 'Puedes agregar una reflexión',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: _textMuted.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          emoji: '✍️',
          label: 'Escribir entrada',
          onTap: () {
            FeedbackEngine.I.select();
            onTapCreate();
          },
          isPrimary: true,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String emoji,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 46,
        decoration: BoxDecoration(
          color: isPrimary
              ? _gold.withOpacity(0.15)
              : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isPrimary
                ? _gold.withOpacity(0.3)
                : Colors.white.withOpacity(0.10),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? _gold : _textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
