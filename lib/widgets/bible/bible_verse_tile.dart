import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/highlight.dart';

/// Tile reutilizable para mostrar un versículo bíblico con highlight.
class BibleVerseTile extends StatelessWidget {
  final BibleVerse verse;
  final Highlight? highlight;
  final bool hasNote;
  final bool isSaved;
  final double fontSize;
  final BibleReaderThemeData? theme;
  final VoidCallback? onTap;

  const BibleVerseTile({
    super.key,
    required this.verse,
    this.highlight,
    this.hasNote = false,
    this.isSaved = false,
    this.fontSize = 20.0,
    this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme ?? BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 2),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: highlight != null
            ? BoxDecoration(
                color: highlight!.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              )
            : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 28,
              child: Text(
                '${verse.verse}',
                style: GoogleFonts.manrope(
                  color: t.accent.withOpacity(0.6),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: verse.text,
                  style: GoogleFonts.crimsonPro(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: fontSize,
                    height: 1.7,
                  ),
                  children: [
                    if (hasNote)
                      WidgetSpan(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.note, color: t.accent, size: 14),
                        ),
                      ),
                    if (isSaved)
                      WidgetSpan(
                        child: Padding(
                          padding: EdgeInsets.only(left: 4),
                          child: Icon(Icons.bookmark, color: t.accent, size: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
