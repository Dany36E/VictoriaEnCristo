import 'package:flutter/material.dart';
import '../services/journal_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// Pantalla de detalle de una entrada
class JournalEntryDetail extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onDelete;

  const JournalEntryDetail({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  JournalService.moodEmojis[entry.mood] ?? '📝',
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatFullDate(entry.date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        JournalService.moodLabels[entry.mood] ?? '',
                        style: TextStyle(
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.hadVictory)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events, color: AppTheme.successColor),
                  ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Triggers
            if (entry.triggers.isNotEmpty) ...[
              Text(
                'Situaciones enfrentadas',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.triggers.map((trigger) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.emergencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      trigger,
                      style: TextStyle(
                        color: AppTheme.emergencyColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            
            // Contenido
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: t.cardBg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                entry.content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.7,
                  color: t.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar entrada?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: onDelete,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergencyColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    
    return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
  }
}
