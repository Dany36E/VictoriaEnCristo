import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../models/bible/bible_verse.dart';
import '../../services/bible/bible_share_service.dart';
import '../../screens/bible/template_picker_screen.dart';

/// Bottom sheet con opciones de compartir (texto o imagen).
class ShareOptionsSheet extends StatelessWidget {
  final BibleVerse verse;
  const ShareOptionsSheet({super.key, required this.verse});

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'COMPARTIR',
                style: GoogleFonts.cinzel(
                  color: t.accent,
                  fontSize: 16,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _ShareOption(
                      icon: Icons.text_fields,
                      label: 'Como Texto',
                      onTap: () {
                        Navigator.pop(context);
                        BibleShareService.shareAsText(verse);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ShareOption(
                      icon: Icons.image_outlined,
                      label: 'Como Imagen',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TemplatePickerScreen(verse: verse),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShareOption({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.accent.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Icon(icon, color: t.accent, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
