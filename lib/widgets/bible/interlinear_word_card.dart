import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/interlinear_word.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/interlinear_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../utils/gloss_translations.dart';
import 'morphology_detail_panel.dart';

/// Tarjeta vertical para una palabra interlineal.
/// Muestra: palabra original → transliteración → Strong# → traducción → morfología.
class InterlinearWordCard extends StatelessWidget {
  final InterlinearWord word;
  final bool isOT;

  const InterlinearWordCard({
    super.key,
    required this.word,
    required this.isOT,
  });

  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  @override
  Widget build(BuildContext context) {
    final spanishGloss = word.gloss.isNotEmpty
        ? translateGloss(word.gloss, isOT: isOT)
        : '—';
    final morph = word.morphAnalysis;

    return GestureDetector(
      onTap: () => MorphologyDetailPanel.show(context, word, isOT),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: t.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: t.accent.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Palabra original (griego/hebreo)
            Text(
              word.originalWord,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 17,
                color: t.accent,
                fontWeight: FontWeight.w700,
              ),
            ),

            // Transliteración (lema si existe)
            if (word.lemma != null && word.lemma!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                word.lemma!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 10,
                  color: t.textPrimary.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Strong number
            if (word.hasStrong) ...[
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  word.strongNumber!,
                  style: GoogleFonts.manrope(
                    fontSize: 9,
                    color: t.accent.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            // Separador
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Container(
                height: 1,
                color: t.accent.withValues(alpha: 0.15),
              ),
            ),

            // Traducción al español
            Text(
              spanishGloss,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.manrope(
                fontSize: 12,
                color: t.textPrimary.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),

            // Morfología resumida
            if (morph != null) ...[
              const SizedBox(height: 3),
              Text(
                morph.partOfSpeech,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: t.textPrimary.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Sección completa de vista interlineal mejorada para el VerseStudySheet.
/// Muestra texto en español arriba, luego tarjetas de palabras originales.
class InterlinearSection extends StatelessWidget {
  final InterlinearVerse interlinearVerse;
  final int bookNumber;
  final String verseText;
  final String versionLabel;
  final ScrollController? scrollController;

  const InterlinearSection({
    super.key,
    required this.interlinearVerse,
    required this.bookNumber,
    required this.verseText,
    required this.versionLabel,
    this.scrollController,
  });

  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  @override
  Widget build(BuildContext context) {
    final isOT = InterlinearService.isOT(bookNumber);
    final words = interlinearVerse.words;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        // Texto en español
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TEXTO EN ESPAÑOL ($versionLabel)',
                style: GoogleFonts.cinzel(
                  color: t.accent.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                verseText,
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withValues(alpha: 0.8),
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Indicador de idioma original
        Row(
          children: [
            Icon(
              isOT ? Icons.translate : Icons.language,
              size: 14,
              color: t.accent.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 6),
            Text(
              isOT
                  ? 'TEXTO ORIGINAL EN HEBREO (OSHB)'
                  : 'TEXTO ORIGINAL EN GRIEGO (SBLGNT)',
              style: GoogleFonts.cinzel(
                color: t.accent.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Grilla de tarjetas
        Wrap(
          spacing: 8,
          runSpacing: 8,
          textDirection: isOT ? TextDirection.rtl : TextDirection.ltr,
          children: words
              .map((w) => InterlinearWordCard(word: w, isOT: isOT))
              .toList(),
        ),

        const SizedBox(height: 16),

        // Nota inferior
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app,
                size: 13, color: t.textPrimary.withValues(alpha: 0.3)),
            const SizedBox(width: 6),
            Text(
              'Toca cualquier palabra para ver el análisis completo',
              style: GoogleFonts.manrope(
                fontSize: 11,
                color: t.textPrimary.withValues(alpha: 0.35),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}
