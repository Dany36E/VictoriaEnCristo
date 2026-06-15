import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/bible/study_room.dart';
import '../../services/bible/study_export_service.dart';
import '../../theme/bible_reader_theme.dart';

/// Pantalla de "exponer resultados" de una sala de estudio.
///
/// Es el momento de compartir lo que Dios habló: muestra los pasajes, los
/// participantes y el PDF combinado (idéntico para todos, generado con los
/// mismos datos de la sala). Cada quien lo abre en su dispositivo.
class StudyResultsScreen extends StatelessWidget {
  final StudyRoom room;
  final List<StudyParticipantBundle> participants;
  final List<String> passageLabels;
  final File pdfFile;
  final bool savedToDownloads;
  final BibleReaderThemeData theme;
  final VoidCallback onLeaveRoom;

  const StudyResultsScreen({
    super.key,
    required this.room,
    required this.participants,
    required this.passageLabels,
    required this.pdfFile,
    required this.savedToDownloads,
    required this.theme,
    required this.onLeaveRoom,
  });

  Future<void> _sharePdf() async {
    await Share.shareXFiles(
      [XFile(pdfFile.path, mimeType: 'application/pdf')],
      subject: 'Resultados del estudio en grupo',
      text: 'Esto es lo que Dios nos habló en nuestro estudio bíblico.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.background,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Resultados',
          style: GoogleFonts.cinzel(
            color: t.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            // Encabezado "tiempo de compartir"
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: t.accent.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: t.accent.withValues(alpha: 0.30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.volunteer_activism, color: t.accent, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Tiempo de compartir',
                        style: GoogleFonts.cinzel(
                          color: t.accent,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Compartan, uno por uno, lo que Dios les habló a través de '
                    'Su Palabra. Pueden seguir el mismo PDF de resultados '
                    'mientras conversan.',
                    style: GoogleFonts.manrope(
                      color: t.textPrimary.withValues(alpha: 0.85),
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(t, 'Pasajes estudiados'),
            const SizedBox(height: 8),
            ...passageLabels.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.menu_book_outlined, size: 15, color: t.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p,
                        style: GoogleFonts.manrope(
                          color: t.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            _sectionTitle(t, 'Participantes (${participants.length})'),
            const SizedBox(height: 8),
            ...participants.map(
              (p) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : Colors.black.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: t.textSecondary.withValues(alpha: 0.10),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: t.accent.withValues(alpha: 0.18),
                      child: Text(
                        _initials(p.displayName),
                        style: GoogleFonts.manrope(
                          color: t.accent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.displayName,
                        style: GoogleFonts.manrope(
                          color: t.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      p.currentVersionId,
                      style: GoogleFonts.manrope(
                        color: t.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _sharePdf,
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: t.isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.ios_share, size: 18),
              label: Text(
                'Compartir / abrir PDF',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
              ),
            ),
            if (savedToDownloads) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.download_done,
                    size: 16,
                    color: t.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'PDF guardado en Descargas:\n${pdfFile.path}',
                      style: GoogleFonts.manrope(
                        color: t.textSecondary,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                onLeaveRoom();
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: t.textSecondary,
                side: BorderSide(
                  color: t.textSecondary.withValues(alpha: 0.3),
                ),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout, size: 18),
              label: Text(
                'Salir de la sala',
                style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BibleReaderThemeData t, String text) => Text(
    text.toUpperCase(),
    style: GoogleFonts.manrope(
      color: t.accent,
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
    ),
  );

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }
}
