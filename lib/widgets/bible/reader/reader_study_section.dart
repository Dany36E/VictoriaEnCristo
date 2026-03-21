import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../controllers/bible_reader_controller.dart';
import '../../../theme/bible_reader_theme.dart';

class ReaderStudyBanner extends StatelessWidget {
  final BibleReaderThemeData theme;
  const ReaderStudyBanner({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD4AF37).withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFD4AF37).withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_stories,
                color: Color(0xFFD4AF37), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Modo Estudio · David Guzik · Enduring Word',
                style: GoogleFonts.manrope(
                  color: const Color(0xFFD4AF37).withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ReaderAnnotationBlock extends StatelessWidget {
  final int sectionIndex;
  final BibleReaderThemeData theme;
  final double fontSize;
  final BibleReaderController controller;

  const ReaderAnnotationBlock({
    super.key,
    required this.sectionIndex,
    required this.theme,
    required this.fontSize,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    if (controller.guzikChapter == null ||
        sectionIndex >= controller.guzikChapter!.sections.length) {
      return const SizedBox.shrink();
    }

    final section = controller.guzikChapter!.sections[sectionIndex];
    final isCollapsed = controller.collapsedSections.contains(sectionIndex);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.isDark
              ? Colors.white.withOpacity(0.04)
              : Colors.black.withOpacity(0.03),
          border: Border(
            left: BorderSide(
              color: const Color(0xFFD4AF37).withOpacity(0.6),
              width: 3,
            ),
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(6),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => controller.toggleAnnotationCollapse(sectionIndex),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        section.heading,
                        style: GoogleFonts.manrope(
                          color: const Color(0xFFD4AF37),
                          fontSize: (fontSize - 2).clamp(9.0, 26.0),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    Icon(
                      isCollapsed ? Icons.expand_more : Icons.expand_less,
                      color: theme.textSecondary.withOpacity(0.3),
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
            if (!isCollapsed)
              ...section.paragraphs.map((p) => Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Text(
                      p,
                      style: GoogleFonts.lora(
                        color: theme.textPrimary.withOpacity(0.88),
                        fontSize: (fontSize - 1).clamp(10.0, 27.0),
                        height: 1.7,
                      ),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}

class ReaderGuzikAttribution extends StatelessWidget {
  final BibleReaderThemeData theme;
  const ReaderGuzikAttribution({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse('https://es.enduringword.com/'),
          mode: LaunchMode.externalApplication,
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.isDark
                ? Colors.white.withOpacity(0.03)
                : Colors.black.withOpacity(0.02),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.15),
            ),
          ),
          child: Column(
            children: [
              Text(
                '©1996–present The Enduring Word Bible Commentary\n'
                'by David Guzik – enduringword.com',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: theme.textSecondary.withOpacity(0.5),
                  fontSize: 10,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Used with permission.',
                style: GoogleFonts.manrope(
                  color: theme.textSecondary.withOpacity(0.35),
                  fontSize: 9,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
