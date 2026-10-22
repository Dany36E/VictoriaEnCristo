import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';

import '../../models/bible/interlinear_word.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/interlinear_service.dart';
import '../../services/bible/strong_lexicon_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../utils/gloss_translations.dart';
import 'morphology_detail_panel.dart';
import 'contextual_study_tutorial.dart';

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
      BibleUserDataService.I.readerThemeNotifier.value,
    ),
  );

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
                style: AppFonts.manrope(
                  fontSize: 10,
                  color: t.textPrimary.withValues(alpha: 0.45),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],

            // Strong number
            const SizedBox(height: 3),
            _StrongBadge(word: word, isOT: isOT, theme: t),

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
              style: AppFonts.manrope(
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
                style: AppFonts.manrope(
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

class _StrongBadge extends StatelessWidget {
  final InterlinearWord word;
  final bool isOT;
  final BibleReaderThemeData theme;

  const _StrongBadge({
    required this.word,
    required this.isOT,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (word.hasStrong) return _badge(word.strongNumber!);
    return FutureBuilder(
      future: StrongLexiconService.I.resolveWord(word, isHebrew: isOT),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? const [];
        if (entries.isEmpty) return const SizedBox(height: 13);
        return _badge(entries.first.strongNumber);
      },
    );
  }

  Widget _badge(String strongNumber) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(
      color: theme.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      strongNumber,
      style: AppFonts.manrope(
        fontSize: 9,
        color: theme.accent.withValues(alpha: 0.7),
        fontWeight: FontWeight.w600,
      ),
    ),
  );
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
      BibleUserDataService.I.readerThemeNotifier.value,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final isOT = InterlinearService.isOT(bookNumber);
    final words = interlinearVerse.words;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        ContextualStudyTutorial(
          tutorialId: 'interlinear',
          title: 'Cómo leer el Interlineal',
          summary: 'Del texto original a Strong y a todas sus apariciones.',
          theme: t,
          steps: const [
            StudyTutorialStep(
              'Palabra original',
              'Cada bloque conserva la forma que aparece en este versículo; puede cambiar según su función gramatical.',
            ),
            StudyTutorialStep(
              'Lema y Strong',
              'Toca la palabra para ver la forma de diccionario y el número Strong local cuando el vínculo es inequívoco.',
            ),
            StudyTutorialStep(
              'Morfología',
              'Tiempo, voz, caso, género y número explican qué hace la palabra en esta oración; no reemplazan el contexto.',
            ),
            StudyTutorialStep(
              'Todas las apariciones',
              'Desde el detalle abre la concordancia original para localizar la misma forma, lema o número en otros versículos.',
            ),
          ],
        ),
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
                style: AppFonts.cinzel(
                  color: t.accent.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                verseText,
                style: AppFonts.manrope(
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
              style: AppFonts.cinzel(
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
            Icon(
              Icons.touch_app,
              size: 13,
              color: t.textPrimary.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 6),
            Text(
              'Toca cualquier palabra para ver el análisis completo',
              style: AppFonts.manrope(
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
