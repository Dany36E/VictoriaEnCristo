import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../theme/bible_reader_theme.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_download_service.dart';

/// Pantalla de ajustes de la Biblia: versión preferida, tamaño de fuente, tema.
class BibleSettingsScreen extends StatelessWidget {
  const BibleSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnightDeep,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.midnight,
        elevation: 0,
        title: Text(
          'AJUSTES',
          style: GoogleFonts.cinzel(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: AppDesignSystem.gold,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Versión preferida ──
          _SettingsSection(title: 'VERSIÓN POR DEFECTO'),
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
                            ? AppDesignSystem.gold.withOpacity(0.1)
                            : Colors.white.withOpacity(0.04),
                        borderRadius:
                            BorderRadius.circular(AppDesignSystem.radiusS),
                        border: selected
                            ? Border.all(
                                color: AppDesignSystem.gold.withOpacity(0.3))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            color: selected
                                ? AppDesignSystem.gold
                                : Colors.white24,
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
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                                Text(
                                  v.shortName,
                                  style: GoogleFonts.manrope(
                                    color: Colors.white38,
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
          _SettingsSection(title: 'TAMAÑO DE FUENTE'),
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
                      color: Colors.white.withOpacity(0.04),
                      borderRadius:
                          BorderRadius.circular(AppDesignSystem.radiusM),
                    ),
                    child: Text(
                      'Porque de tal manera amó Dios al mundo, que ha dado a su Hijo unigénito...',
                      style: GoogleFonts.crimsonPro(
                        color: Colors.white70,
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
                              color: Colors.white38, fontSize: 14)),
                      Expanded(
                        child: Slider(
                          value: fontSize,
                          min: 14,
                          max: 32,
                          divisions: 9,
                          activeColor: AppDesignSystem.gold,
                          inactiveColor: Colors.white12,
                          label: '${fontSize.toInt()}',
                          onChanged: (v) =>
                              BibleUserDataService.I.setFontSize(v),
                        ),
                      ),
                      Text('A',
                          style: GoogleFonts.crimsonPro(
                              color: Colors.white70, fontSize: 28)),
                    ],
                  ),
                  Text(
                    '${fontSize.toInt()} pt',
                    style: GoogleFonts.manrope(
                      color: Colors.white38,
                      fontSize: 12,
                    ),
                  ),
                ],
              );
            },
          ),

          const SizedBox(height: 24),

          // ── Tema del lector ──
          _SettingsSection(title: 'TEMA DEL LECTOR'),
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
                          BorderRadius.circular(AppDesignSystem.radiusM),
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
                      return GestureDetector(
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
                                      ? AppDesignSystem.gold
                                      : Colors.white24,
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
                                    ? AppDesignSystem.gold
                                    : Colors.white54,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── Descargas offline ──
          _SettingsSection(title: 'DESCARGAS OFFLINE'),
          _DownloadsSection(),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// DOWNLOADS SECTION
// ══════════════════════════════════════════════════════════════════════════

class _DownloadsSection extends StatelessWidget {
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
                    color: AppDesignSystem.gold.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                    border: Border.all(color: AppDesignSystem.gold.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_done_rounded,
                          color: AppDesignSystem.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$downloadedCount de ${BibleVersion.values.length} versiones descargadas',
                          style: GoogleFonts.manrope(
                            color: Colors.white70,
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
                              color: AppDesignSystem.gold,
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
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
                    ),
                    child: Row(
                      children: [
                        // Ícono de estado
                        _buildStateIcon(state, isDownloadingThis),
                        const SizedBox(width: 12),
                        // Nombre y subtítulo
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                version.displayName,
                                style: GoogleFonts.manrope(
                                  color: Colors.white,
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
                                  color: Colors.white38,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Botón de acción
                        if (isDownloadingThis)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppDesignSystem.gold,
                            ),
                          )
                        else if (state == DownloadState.downloaded && !isBase)
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.white30, size: 20),
                            onPressed: () => _confirmDelete(context, version),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else if (state == DownloadState.notDownloaded)
                          IconButton(
                            icon: const Icon(Icons.download_rounded,
                                color: AppDesignSystem.gold, size: 22),
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

  Widget _buildStateIcon(DownloadState state, bool isDownloading) {
    if (isDownloading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppDesignSystem.gold,
        ),
      );
    }
    switch (state) {
      case DownloadState.downloaded:
        return const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20);
      case DownloadState.downloading:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppDesignSystem.gold,
          ),
        );
      case DownloadState.notDownloaded:
        return const Icon(Icons.cloud_download_outlined,
            color: Colors.white30, size: 20);
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
        backgroundColor: AppDesignSystem.midnight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Eliminar descarga',
          style: GoogleFonts.manrope(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          '¿Eliminar ${version.displayName} del almacenamiento local?\n\nPodrás descargarla de nuevo en cualquier momento.',
          style: GoogleFonts.manrope(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancelar',
              style: GoogleFonts.manrope(color: Colors.white54),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.manrope(
          color: AppDesignSystem.gold,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}
