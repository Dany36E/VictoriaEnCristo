/// ═══════════════════════════════════════════════════════════════════════════
/// JOURNAL DAY NOTE CARD - Nota del Diario del Día
/// Muestra el snippet del diario para la fecha seleccionada
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/journal_service.dart';
import '../services/feedback_engine.dart';

/// Card que muestra el snippet del diario para un día específico
class JournalDayNoteCard extends StatelessWidget {
  final DateTime selectedDate;
  final JournalEntry? entry;
  final bool isLoading;
  final VoidCallback onTapEdit;
  final VoidCallback onTapCreate;
  
  // Design constants
  static const Color _midnight = Color(0xFF0A0A12);
  static const Color _midnightLight = Color(0xFF121225);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFE8C872);
  static const Color _pearlGray = Color(0xFF9E9E9E);
  static const Color _cardBg = Color(0xFF1A1A2E);
  
  const JournalDayNoteCard({
    super.key,
    required this.selectedDate,
    required this.entry,
    required this.isLoading,
    required this.onTapEdit,
    required this.onTapCreate,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_midnightLight, _midnight],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _gold.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),
          const SizedBox(height: 12),
          
          // Content
          if (isLoading)
            _buildLoadingState()
          else if (entry != null)
            _buildEntryContent()
          else
            _buildEmptyState(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms, delay: 100.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildHeader() {
    final dayNames = [
      '', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    final monthNames = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    
    final dateStr = '${dayNames[selectedDate.weekday]} ${selectedDate.day} de ${monthNames[selectedDate.month]}';
    
    return Row(
      children: [
        // Icono de diario
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.book_rounded,
            color: _gold,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        
        // Título y fecha
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [_gold, _goldLight],
                ).createShader(bounds),
                child: const Text(
                  'Mi Diario',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  color: _pearlGray.withOpacity(0.7),
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
      height: 80,
      decoration: BoxDecoration(
        color: _cardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _gold.withOpacity(0.6),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEntryContent() {
    // Generar snippet (máx 140 caracteres o 3 líneas)
    final content = entry!.content;
    final snippet = content.length > 140 
        ? '${content.substring(0, 140)}...'
        : content;
    
    // Formatear hora
    final hour = entry!.date.hour.toString().padLeft(2, '0');
    final minute = entry!.date.minute.toString().padLeft(2, '0');
    final timeStr = '$hour:$minute';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Nota tipo papel
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _cardBg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _gold.withOpacity(0.1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mood emoji si existe
              if (entry!.mood.isNotEmpty) ...[
                Row(
                  children: [
                    Text(
                      JournalService.moodEmojis[entry!.mood] ?? '📝',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      JournalService.moodLabels[entry!.mood] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: _gold.withOpacity(0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        color: _pearlGray.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // Contenido
              Text(
                snippet,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.85),
                  height: 1.5,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Botón ver/editar
        _buildActionButton(
          icon: Icons.edit_rounded,
          label: 'Ver / Editar entrada',
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
        // Estado vacío elegante
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: _cardBg.withOpacity(0.4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _pearlGray.withOpacity(0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.notes_rounded,
                size: 32,
                color: _pearlGray.withOpacity(0.3),
              ),
              const SizedBox(height: 8),
              Text(
                'Sin entrada este día',
                style: TextStyle(
                  fontSize: 14,
                  color: _pearlGray.withOpacity(0.5),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Botón crear entrada
        _buildActionButton(
          icon: Icons.add_rounded,
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
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isPrimary 
              ? const LinearGradient(
                  colors: [_gold, _goldLight],
                )
              : null,
          color: isPrimary ? null : _cardBg.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _gold.withOpacity(isPrimary ? 0.0 : 0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? _midnight : _gold,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isPrimary ? _midnight : _gold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
