import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../services/journal_service.dart';

/// Utilidad para exportar entradas del diario como archivo de texto.
class JournalExport {
  JournalExport._();

  static const _moodLabels = {
    'victory': '🏆 Victoria',
    'struggle': '⚔️ Lucha',
    'neutral': '🤍 Neutral',
    'grateful': '🙏 Gratitud',
  };

  /// Exporta todas las entradas del diario como archivo .txt
  /// y abre el diálogo nativo de compartir.
  static Future<void> exportAndShare(
    BuildContext context,
    List<JournalEntry> entries,
  ) async {
    if (entries.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('       MI DIARIO — Victoria en Cristo');
    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln();
    buffer.writeln('Entradas: ${entries.length}');
    buffer.writeln('Exportado: ${_formatDate(DateTime.now())}');
    buffer.writeln();

    // Ordenar por fecha (más antiguo primero)
    final sorted = List<JournalEntry>.from(entries)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final entry in sorted) {
      buffer.writeln('───────────────────────────────────────');
      buffer.writeln('📅 ${_formatDate(entry.date)}');
      buffer.writeln('Estado: ${_moodLabels[entry.mood] ?? entry.mood}');
      if (entry.hadVictory) buffer.writeln('✅ Victoria');
      if (entry.triggers.isNotEmpty) {
        buffer.writeln('Gatillos: ${entry.triggers.join(', ')}');
      }
      if (entry.verseOfDay != null && entry.verseOfDay!.isNotEmpty) {
        buffer.writeln('Versículo: ${entry.verseOfDay}');
      }
      buffer.writeln();
      buffer.writeln(entry.content);
      buffer.writeln();
    }

    buffer.writeln('═══════════════════════════════════════');
    buffer.writeln('    Generado por Victoria en Cristo');
    buffer.writeln('═══════════════════════════════════════');

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/mi_diario_victoria.txt');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Mi Diario — Victoria en Cristo',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al exportar: $e')),
        );
      }
    }
  }

  static String _formatDate(DateTime date) {
    const months = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${date.day} de ${months[date.month]} ${date.year}';
  }
}
