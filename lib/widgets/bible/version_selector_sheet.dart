import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_version.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_download_service.dart';
import '../../theme/bible_reader_theme.dart';

/// Sheet editorial para selección de versión bíblica.
/// DraggableScrollableSheet con estilo premium.
void showVersionSelectorSheet(BuildContext context, {VoidCallback? onChanged}) {
  final themeId = BibleUserDataService.I.readerThemeNotifier.value;
  final t = BibleReaderThemeData.fromId(
    BibleReaderThemeData.migrateId(themeId),
  );

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.45,
        maxChildSize: 0.6,
        minChildSize: 0.3,
        builder: (context, scrollCtrl) {
          return Container(
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                // Handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 16),
                  child: Container(
                    width: 36,
                    height: 2,
                    decoration: BoxDecoration(
                      color: t.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
                // Label
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'VERSIÓN',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withValues(alpha: 0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.0,
                    ),
                  ),
                ),
                // List
                Expanded(
                  child: ValueListenableBuilder<BibleVersion>(
                    valueListenable:
                        BibleUserDataService.I.preferredVersionNotifier,
                    builder: (context, current, _) {
                      return ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        children: [
                          for (final language in BibleLanguage.values) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 4, bottom: 8),
                              child: Text(
                                language.label.toUpperCase(),
                                style: GoogleFonts.manrope(
                                  color: t.accent.withValues(alpha: 0.75),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.6,
                                ),
                              ),
                            ),
                            ...BibleVersion.forLanguage(language).map((v) {
                              final isCurrent = v == current;
                              final isAvailable = BibleDownloadService.I
                                  .isAvailable(v);
                              final canDownload = BibleDownloadService.I
                                  .canDownload(v);
                              final needsAuthorizedSource =
                                  !isAvailable && !canDownload;
                              return GestureDetector(
                                onTap: () async {
                                  if (needsAuthorizedSource) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${v.shortName} requiere una fuente autorizada antes de poder usarse.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (!isAvailable) {
                                    final ok = await BibleDownloadService.I
                                        .downloadVersion(v);
                                    if (!ok) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${v.shortName} aún no está disponible para descarga.',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }
                                  }
                                  await BibleUserDataService.I
                                      .setPreferredVersion(v);
                                  if (context.mounted) Navigator.pop(context);
                                  onChanged?.call();
                                },
                                child: SizedBox(
                                  height: 48,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          v.displayName,
                                          style: GoogleFonts.lora(
                                            color: needsAuthorizedSource
                                                ? t.textSecondary.withValues(
                                                    alpha: 0.55,
                                                  )
                                                : t.textPrimary,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 7,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isCurrent
                                              ? t.accent.withValues(alpha: 0.12)
                                              : t.textSecondary.withValues(
                                                  alpha: 0.08,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          '${v.shortName} · ${v.language.code.toUpperCase()}',
                                          style: GoogleFonts.manrope(
                                            color: isCurrent
                                                ? t.accent
                                                : t.textSecondary.withValues(
                                                    alpha: 0.65,
                                                  ),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.check,
                                          color: t.accent,
                                          size: 16,
                                        ),
                                      ] else if (needsAuthorizedSource) ...[
                                        const SizedBox(width: 8),
                                        Icon(
                                          Icons.lock_outline_rounded,
                                          color: t.textSecondary.withValues(
                                            alpha: 0.5,
                                          ),
                                          size: 15,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
