import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/bible_reader_theme.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_download_service.dart';
import 'bible_dictionary_screen.dart';

/// Pantalla de ajustes de la Biblia: versión preferida, tamaño de fuente, tema.
class BibleSettingsScreen extends StatelessWidget {
  const BibleSettingsScreen({super.key});

  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        title: Text(
          'AJUSTES',
          style: GoogleFonts.cinzel(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: t.accent,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: t.textPrimary.withValues(alpha: 0.7), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Versión preferida ──
          const _SettingsSection(title: 'VERSIÓN POR DEFECTO'),
          ValueListenableBuilder<BibleVersion>(
            valueListenable: BibleUserDataService.I.preferredVersionNotifier,
            builder: (context, version, _) {
              return Column(
                children: BibleVersion.values.map((v) {
                  final selected = v == version;
                  return GestureDetector(
                    onTap: () => BibleUserDataService.I.setPreferredVersion(v),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? t.accent.withOpacity(0.1)
                            : t.textPrimary.withOpacity(0.04),
                        borderRadius:
                            BorderRadius.circular(10.0),
                        border: selected
                            ? Border.all(
                                color: t.accent.withOpacity(0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected
                                ? t.accent
                                : t.textSecondary.withOpacity(0.3),
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  v.displayName,
                                  style: GoogleFonts.manrope(
                                    color: t.textPrimary,
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  v.shortName,
                                  style: GoogleFonts.manrope(
                                    color: t.textSecondary.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Tamaño de fuente ──
          const _SettingsSection(title: 'TAMAÑO DE FUENTE'),
          ValueListenableBuilder<double>(
            valueListenable: BibleUserDataService.I.fontSizeNotifier,
            builder: (context, fontSize, _) {
              return Column(
                children: [
                  // Preview
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: t.textPrimary.withOpacity(0.04),
                      borderRadius:
                          BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      'Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito...',
                      style: GoogleFonts.crimsonPro(
                        color: t.textPrimary.withOpacity(0.7),
                        fontSize: fontSize,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Slider
                  Row(
                    children: [
                      Text('A',
                          style: GoogleFonts.crimsonPro(
                              color: t.textSecondary.withOpacity(0.5), fontSize: 14)),
                      Expanded(
                        child: Semantics(
                          label: 'Tamaño de fuente',
                          value: '${fontSize.toInt()} puntos',
                          child: Slider(
                          value: fontSize,
                          min: 14,
                          max: 32,
                          divisions: 9,
                          activeColor: t.accent,
                          inactiveColor: t.textSecondary.withOpacity(0.15),
                          label: '${fontSize.toInt()}',
                          onChanged: (v) =>
                              BibleUserDataService.I.setFontSize(v),
                        ),
                        ),
                      ),
                      Text('A',
                          style: GoogleFonts.crimsonPro(
                              color: t.textPrimary.withOpacity(0.7), fontSize: 28)),
                    ],
                  ),
                  Text(
                    '${fontSize.toInt()} pt',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Tema del lector ──
          const _SettingsSection(title: 'TEMA DEL LECTOR'),
          ValueListenableBuilder<String>(
            valueListenable: BibleUserDataService.I.readerThemeNotifier,
            builder: (context, rawTheme, _) {
              final currentId = BibleReaderThemeData.migrateId(rawTheme);
              final currentTheme = BibleReaderThemeData.fromId(currentId);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Preview
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: currentTheme.background,
                      borderRadius:
                          BorderRadius.circular(12.0),
                    ),
                    child: Text(
                      'Porque de tal manera amó Dios al mundo...',
                      style: GoogleFonts.lora(
                        color: currentTheme.textPrimary,
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        height: 1.7,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // 9 swatches in a Wrap
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: BibleReaderThemeData.all.map((theme) {
                      final isActive = theme.id == currentId;
                      return Semantics(
                        label: 'Tema ${theme.name}',
                        button: true,
                        selected: isActive,
                        child: GestureDetector(
                        onTap: () =>
                            BibleUserDataService.I.setReaderTheme(theme.id),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: theme.swatchColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isActive
                                      ? t.accent
                                      : t.textSecondary.withOpacity(0.3),
                                  width: isActive ? 2.5 : 1,
                                ),
                              ),
                              child: isActive
                                  ? Icon(Icons.check,
                                      color: theme.isDark
                                          ? Colors.white70
                                          : Colors.black54,
                                      size: 16)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              theme.name,
                              style: GoogleFonts.manrope(
                                color: isActive
                                    ? t.accent
                                    : t.textSecondary.withOpacity(0.6),
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Estudio bíblico local ──
          const _SettingsSection(title: 'ESTUDIO BÍBLICO'),
          ValueListenableBuilder<bool>(
            valueListenable: BibleUserDataService.I.redLettersEnabledNotifier,
            builder: (context, enabled, _) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: t.accent.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.format_color_text,
                        color: enabled
                            ? const Color(0xFFE57373)
                            : t.textPrimary.withValues(alpha: 0.4),
                        size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Palabras de Cristo en rojo',
                            style: GoogleFonts.manrope(
                              color: t.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Resalta las palabras de Jesús en los Evangelios',
                            style: GoogleFonts.manrope(
                              color: t.textPrimary
                                  .withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: enabled,
                      activeColor: const Color(0xFFE57373),
                      onChanged: (v) =>
                          BibleUserDataService.I.setRedLettersEnabled(v),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const BibleDictionaryScreen()),
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: t.surface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: t.accent.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          color: t.accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Diccionario Bíblico',
                              style: GoogleFonts.manrope(
                                color: t.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              'Easton + Hitchcock – Dominio público',
                              style: GoogleFonts.manrope(
                                color: t.textPrimary
                                    .withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right,
                          color:
                              t.textPrimary.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
              ),
            ),
          ),          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => launchUrl(
                  Uri.parse('https://es.enduringword.com/'),
                  mode: LaunchMode.externalApplication,
                ),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: t.surface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: t.accent.withValues(alpha: 0.1)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.auto_stories_outlined,
                          color: t.accent, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Análisis bíblico: David Guzik',
                              style: GoogleFonts.manrope(
                                color: t.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '©1996–present Enduring Word · Usado con permiso',
                              style: GoogleFonts.manrope(
                                color: t.textPrimary
                                    .withValues(alpha: 0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.open_in_new,
                          color:
                              t.textPrimary.withValues(alpha: 0.3),
                          size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),          const SizedBox(height: 24),

          // ── Descargas offline ──
          const _SettingsSection(title: 'DESCARGAS OFFLINE'),
          _DownloadsSection(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DOWNLOADS SECTION
// ═══════════════════════════════════════════════════════════════════════════

class _DownloadsSection extends StatelessWidget {
  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  @override
  Widget build(BuildContext context) {
    final dl = BibleDownloadService.I;

    return ValueListenableBuilder<Map<BibleVersion, DownloadState>>(
      valueListenable: dl.stateNotifier,
      builder: (context, states, _) {
        return ValueListenableBuilder<BibleVersion?>(
          valueListenable: dl.downloadingNotifier,
          builder: (context, downloading, _) {
            final downloadedCount =
                states.values.where((s) => s == DownloadState.downloaded).length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Resumen
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: t.accent.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10.0),
                    border: Border.all(color: t.accent.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.download_done_rounded,
                          color: t.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$downloadedCount de ${BibleVersion.values.length} versiones descargadas',
                          style: GoogleFonts.manrope(
                            color: t.textPrimary.withOpacity(0.7),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      if (downloadedCount < BibleVersion.values.length)
                        GestureDetector(
                          onTap: () => dl.downloadAll(),
                          child: Text(
                            'Descargar todo',
                            style: GoogleFonts.manrope(
                              color: t.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Lista de versiones
                ...BibleVersion.values.map((version) {
                  final state = states[version] ?? DownloadState.notDownloaded;
                  final isBase = version == BibleVersion.rvr1960;
                  final isDownloadingThis = downloading == version;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: t.textPrimary.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Row(
                      children: [
                        // Ícono de estado
                        _buildStateIcon(state, isDownloadingThis, t),
                        const SizedBox(width: 12),
                        // Nombre y subtítulo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                version.displayName,
                                style: GoogleFonts.manrope(
                                  color: t.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                isBase
                                    ? '${version.shortName} · Incluida'
                                    : state == DownloadState.downloaded
                                        ? '${version.shortName} · ~${_estimatedSize(version)}'
                                        : '${version.shortName} · ~5 MB',
                                style: GoogleFonts.manrope(
                                  color: t.textSecondary.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botón de acción
                        if (isDownloadingThis)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: t.accent,
                            ),
                          )
                        else if (state == DownloadState.downloaded && !isBase)
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                color: t.textSecondary.withOpacity(0.4), size: 20),
                            onPressed: () => _confirmDelete(context, version),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else if (state == DownloadState.notDownloaded)
                          IconButton(
                            icon: Icon(Icons.download_rounded,
                                color: t.accent, size: 22),
                            onPressed: () => dl.downloadVersion(version),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStateIcon(DownloadState state, bool isDownloading, BibleReaderThemeData t) {
    if (isDownloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: t.accent,
        ),
      );
    }
    switch (state) {
      case DownloadState.downloaded:
        return const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20);
      case DownloadState.downloading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: t.accent,
          ),
        );
      case DownloadState.notDownloaded:
        return Icon(Icons.cloud_download_outlined,
            color: t.textSecondary.withOpacity(0.4), size: 20);
    }
  }

  String _estimatedSize(BibleVersion version) {
    // Tamaños aproximados de cada XML
    switch (version) {
      case BibleVersion.rvr1960:
        return '4.7 MB';
      case BibleVersion.nvi:
        return '4.9 MB';
      case BibleVersion.lbla:
        return '4.8 MB';
      case BibleVersion.ntv:
        return '5.1 MB';
      case BibleVersion.tla:
        return '4.7 MB';
    }
  }

  void _confirmDelete(BuildContext context, BibleVersion version) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Eliminar descarga',
          style: GoogleFonts.manrope(
            color: t.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '¿Eliminar ${version.displayName} del almacenamiento local?\n\nPodrás descargarla de nuevo en cualquier momento.',
          style: GoogleFonts.manrope(color: t.textPrimary.withOpacity(0.7), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: t.textSecondary.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              BibleDownloadService.I.deleteVersion(version);
            },
            child: Text(
              'Eliminar',
              style: GoogleFonts.manrope(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  const _SettingsSection({required this.title});

  @override
  Widget build(BuildContext context) {
    final themeColor = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(
              BibleUserDataService.I.readerThemeNotifier.value),
        ).accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          color: themeColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
