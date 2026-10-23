import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_download_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/reading_history_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// HISTORIAL DE LECTURA
/// Pasajes visitados, del más reciente al más antiguo, con fecha y hora.
/// Tocar uno abre el lector en el versículo donde se quedó la persona.
/// ═══════════════════════════════════════════════════════════════════════════
class ReadingHistoryScreen extends StatefulWidget {
  const ReadingHistoryScreen({super.key});

  @override
  State<ReadingHistoryScreen> createState() => _ReadingHistoryScreenState();
}

class _ReadingHistoryScreenState extends State<ReadingHistoryScreen> {
  @override
  void initState() {
    super.initState();
    ReadingHistoryService.I.ensureLoaded();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
        SystemChrome.setSystemUIOverlayStyle(
          t.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        return Scaffold(
          backgroundColor: t.pageBg,
          body: SafeArea(
            child: ValueListenableBuilder<List<ReadingHistoryEntry>>(
              valueListenable: ReadingHistoryService.I.historyNotifier,
              builder: (context, history, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(t, history.isNotEmpty),
                  Expanded(
                    child: history.isEmpty
                        ? _buildEmpty(t)
                        : _buildList(t, history),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t, bool hasItems) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          Icon(Icons.history, color: t.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Historial',
              style: AppFonts.cinzel(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (hasItems)
            TextButton(
              onPressed: () => _confirmClear(t),
              style: TextButton.styleFrom(
                foregroundColor: t.accent,
                minimumSize: const Size(48, 48),
              ),
              child: const Text('Borrar'),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BibleReaderThemeData t) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          'Aquí aparecerán los capítulos que leas,\ndel más reciente al más antiguo.',
          textAlign: TextAlign.center,
          style: AppFonts.manrope(
            color: t.textoTenue(0.6),
            fontSize: 14,
            height: 1.6,
          ),
        ),
      ),
    );
  }

  Widget _buildList(BibleReaderThemeData t, List<ReadingHistoryEntry> history) {
    final hoy = DateTime.now();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      itemCount: history.length,
      itemBuilder: (context, i) {
        final e = history[i];
        final previous = i > 0 ? history[i - 1] : null;
        final day = formatDay(e.at, hoy);
        final showDay = previous == null || formatDay(previous.at, hoy) != day;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDay)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    day.toUpperCase(),
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.6),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ListTile(
              minVerticalPadding: 10,
              leading: Icon(Icons.menu_book_outlined, color: t.accent),
              title: Text(
                e.label,
                style: AppFonts.lora(
                  color: t.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                '${formatTime(e.at)} · ${BibleVersion.fromId(e.versionId).shortName}',
                style: AppFonts.manrope(color: t.textoTenue(0.6), fontSize: 12),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: t.textSecondary.withValues(alpha: 0.5),
              ),
              onTap: () => _open(e),
            ),
          ],
        );
      },
    );
  }

  void _open(ReadingHistoryEntry e) {
    final v = BibleVersion.fromId(e.versionId);
    final version = BibleDownloadService.I.isAvailable(v)
        ? v
        : BibleUserDataService.I.preferredVersionNotifier.value;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BibleReaderScreen(
          bookNumber: e.bookNumber,
          bookName: e.bookName,
          chapter: e.chapter,
          version: version,
          initialVerse: e.verse > 1 ? e.verse : null,
        ),
      ),
    );
  }

  Future<void> _confirmClear(BibleReaderThemeData t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(
          '¿Borrar el historial?',
          style: AppFonts.manrope(
            color: t.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Se quitará la lista de pasajes visitados. Tus versículos guardados, '
          'notas y resaltados no se tocan.',
          style: AppFonts.manrope(color: t.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(foregroundColor: t.textSecondary),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: t.accent),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (ok == true) await ReadingHistoryService.I.clearHistory();
  }

  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', //
    'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];

  /// «Hoy», «Ayer» o «3 de mayo de 2024».
  static String formatDay(DateTime d, DateTime hoy) {
    final dia = DateTime(d.year, d.month, d.day);
    final ref = DateTime(hoy.year, hoy.month, hoy.day);
    final diff = ref.difference(dia).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    final anio = d.year == hoy.year ? '' : ' de ${d.year}';
    return '${d.day} de ${_meses[d.month - 1]}$anio';
  }

  static String formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
