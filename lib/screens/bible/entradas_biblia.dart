import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_download_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import 'sermon_notes_mode_screen.dart';
import 'sermon_notes_saved_screen.dart';
import 'study_mode_screen.dart';

/// Pasaje desde el que se abren Estudio y Apuntes: la última lectura guardada
/// (o Génesis 1) en la versión preferida, si ya está disponible.
class PosicionLectura {
  final int libro;
  final String nombreLibro;
  final int capitulo;
  final BibleVersion version;

  const PosicionLectura({
    required this.libro,
    required this.nombreLibro,
    required this.capitulo,
    required this.version,
  });

  static Future<PosicionLectura> ultima() async {
    await UserScopedServices.I.ensureBible();
    final version = BibleDownloadService.I.bestAvailableVersion(
      BibleUserDataService.I.preferredVersionNotifier.value,
    );
    var libro = 1, capitulo = 1;
    var nombreLibro = 'Génesis';
    try {
      final prefs = await SharedPreferences.getInstance();
      final bn = prefs.getInt('lastReadBookNumber');
      final name = prefs.getString('lastReadBookName');
      final ch = prefs.getInt('lastReadChapter');
      if (bn != null && name != null && ch != null) {
        libro = bn;
        nombreLibro = name;
        capitulo = ch;
      }
    } catch (e) {
      debugPrint('[EntradasBiblia] Error en SharedPreferences: $e');
    }
    return PosicionLectura(
      libro: libro,
      nombreLibro: nombreLibro,
      capitulo: capitulo,
      version: version,
    );
  }
}

/// Entradas a Modo Estudio y a Apuntes de predicación. Las comparten la
/// pantalla de la Biblia, los atajos de Inicio y el widget de atajos.
class EntradasBiblia {
  const EntradasBiblia._();

  static BibleReaderThemeData _temaLector() => BibleReaderThemeData.fromId(
    BibleReaderThemeData.migrateId(
      BibleUserDataService.I.readerThemeNotifier.value,
    ),
  );

  /// Muestra las opciones de Modo Estudio (nuevo, guardados, con amigos) y
  /// abre la elegida.
  static Future<void> abrirEstudio(BuildContext context) async {
    final action = await showModalBottomSheet<_StudyEntryAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _StudyEntrySheet(theme: _temaLector()),
    );
    if (action == null) return;
    final pos = await PosicionLectura.ultima();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudyModeScreen(
          bookNumber: pos.libro,
          bookName: pos.nombreLibro,
          chapter: pos.capitulo,
          version: pos.version,
          openSetupOnStart: action == _StudyEntryAction.newStudy,
          openSavedStudiesOnStart: action == _StudyEntryAction.savedStudies,
          openRoomDialogOnStart: action == _StudyEntryAction.friendsStudy,
        ),
      ),
    );
  }

  /// Muestra las opciones de Apuntes (nuevo apunte, guardados) y abre la
  /// elegida.
  static Future<void> abrirApuntes(BuildContext context) async {
    final action = await showModalBottomSheet<_SermonEntryAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SermonEntrySheet(theme: _temaLector()),
    );
    if (action == null || !context.mounted) return;
    if (action == _SermonEntryAction.savedNotes) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SermonNotesSavedScreen()),
      );
      return;
    }
    final pos = await PosicionLectura.ultima();
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SermonNotesModeScreen(
          bookNumber: pos.libro,
          bookName: pos.nombreLibro,
          chapter: pos.capitulo,
          version: pos.version,
        ),
      ),
    );
  }
}

enum _StudyEntryAction { newStudy, savedStudies, friendsStudy }

enum _SermonEntryAction { newNote, savedNotes }

class _StudyEntrySheet extends StatelessWidget {
  final BibleReaderThemeData theme;

  const _StudyEntrySheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: t.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Modo Estudio',
              style: AppFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _StudyEntryTile(
              icon: Icons.add_circle_outline,
              title: 'Empezar nuevo estudio',
              subtitle: 'Elegir pasaje, rango y versiones.',
              theme: t,
              onTap: () => Navigator.pop(context, _StudyEntryAction.newStudy),
            ),
            const SizedBox(height: 8),
            _StudyEntryTile(
              icon: Icons.folder_open_outlined,
              title: 'Estudios guardados',
              subtitle: 'Continuar respuestas y notas anteriores.',
              theme: t,
              onTap: () =>
                  Navigator.pop(context, _StudyEntryAction.savedStudies),
            ),
            const SizedBox(height: 8),
            _StudyEntryTile(
              icon: Icons.groups_outlined,
              title: 'Estudio con amigos',
              subtitle: 'Crear o unirte a una sala. Lean juntos en '
                  'distintas versiones y rotándolas.',
              theme: t,
              onTap: () =>
                  Navigator.pop(context, _StudyEntryAction.friendsStudy),
            ),
          ],
        ),
      ),
    );
  }
}

class _SermonEntrySheet extends StatelessWidget {
  final BibleReaderThemeData theme;

  const _SermonEntrySheet({required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 3,
                decoration: BoxDecoration(
                  color: t.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Apuntes de predicación',
              style: AppFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _StudyEntryTile(
              icon: Icons.add_circle_outline,
              title: 'Nuevo apunte',
              subtitle: 'Abrir lectura y tomar notas de la predicación.',
              theme: t,
              onTap: () => Navigator.pop(context, _SermonEntryAction.newNote),
            ),
            const SizedBox(height: 8),
            _StudyEntryTile(
              icon: Icons.folder_open_outlined,
              title: 'Apuntes guardados',
              subtitle: 'Buscar por pastor, fecha, título o pasaje.',
              theme: t,
              onTap: () =>
                  Navigator.pop(context, _SermonEntryAction.savedNotes),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudyEntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final BibleReaderThemeData theme;
  final VoidCallback onTap;

  const _StudyEntryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: t.oscuro
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.09)),
        ),
        child: Row(
          children: [
            Icon(icon, color: t.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.7),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: t.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
