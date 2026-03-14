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
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
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
                      color: t.textSecondary.withOpacity(0.3),
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
                      color: t.textSecondary.withOpacity(0.5),
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
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        children: BibleVersion.values.map((v) {
                          final isCurrent = v == current;
                          return GestureDetector(
                            onTap: () async {
                              if (!BibleDownloadService.I.isDownloaded(v)) {
                                await BibleDownloadService.I
                                    .downloadVersion(v);
                              }
                              BibleUserDataService.I
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
                                        color: t.textPrimary,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    v.shortName,
                                    style: GoogleFonts.manrope(
                                      color: isCurrent
                                          ? t.accent
                                          : t.textSecondary
                                              .withOpacity(0.6),
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 8),
                                    Icon(Icons.check,
                                        color: t.accent, size: 16),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
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
