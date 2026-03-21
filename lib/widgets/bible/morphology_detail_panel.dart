import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/interlinear_word.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../utils/grammar_glossary.dart';

/// Panel de detalle morfológico para una palabra interlineal.
/// Se muestra al tocar una palabra en la vista interlineal.
class MorphologyDetailPanel extends StatelessWidget {
  final InterlinearWord word;
  final bool isOT; // true = hebreo, false = griego

  const MorphologyDetailPanel({
    super.key,
    required this.word,
    required this.isOT,
  });

  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  static void show(BuildContext context, InterlinearWord word, bool isOT) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MorphologyDetailPanel(word: word, isOT: isOT),
    );
  }

  @override
  Widget build(BuildContext context) {
    final morph = word.morphAnalysis;
    return Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: t.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHandle(),
          _buildWordHeader(),
          if (morph != null) _buildMorphGrid(morph),
          if (word.morphCode.isNotEmpty) _buildRawCode(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12, bottom: 4),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildWordHeader() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            Text(
              word.originalWord,
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 32,
                color: t.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (word.lemma != null && word.lemma!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Lema: ${word.lemma}',
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            if (word.hasStrong) ...[
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  word.strongNumber!,
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            if (word.gloss.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                word.gloss,
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withValues(alpha: 0.6),
                  fontSize: 13,
                ),
              ),
            ],
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.translate, size: 14,
                    color: t.accent.withValues(alpha: 0.5)),
                const SizedBox(width: 4),
                Text(
                  isOT ? 'Hebreo' : 'Griego',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildMorphGrid(MorphAnalysis morph) {
    final items = <_MorphItem>[];
    items.add(_MorphItem('Categoría', morph.partOfSpeech));
    if (morph.tense != null) items.add(_MorphItem('Tiempo', morph.tense!));
    if (morph.voice != null) items.add(_MorphItem('Voz', morph.voice!));
    if (morph.mood != null) items.add(_MorphItem('Modo', morph.mood!));
    if (morph.person != null) items.add(_MorphItem('Persona', morph.person!));
    if (morph.grammaticalNumber != null) {
      items.add(_MorphItem('Número', morph.grammaticalNumber!));
    }
    if (morph.gender != null) items.add(_MorphItem('Género', morph.gender!));
    if (morph.grammaticalCase != null) {
      items.add(_MorphItem('Caso', morph.grammaticalCase!));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items
            .map((item) => _buildMorphChip(item.label, item.value))
            .toList(),
      ),
    );
  }

  Widget _buildMorphChip(String label, String value) {
    final tooltip = GrammarGlossary.explain(value.toLowerCase());
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: t.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.cinzel(
              color: t.accent.withValues(alpha: 0.6),
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: GoogleFonts.manrope(
              color: t.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    if (tooltip != null) {
      return Tooltip(
        message: tooltip,
        preferBelow: false,
        textStyle: GoogleFonts.manrope(
          color: t.background,
          fontSize: 12,
        ),
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: chip,
      );
    }
    return chip;
  }

  Widget _buildRawCode() => Padding(
        padding: const EdgeInsets.only(top: 12, left: 20, right: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: t.surface.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.code, size: 14,
                  color: t.textPrimary.withValues(alpha: 0.3)),
              const SizedBox(width: 6),
              Text(
                word.morphCode,
                style: GoogleFonts.sourceCodePro(
                  color: t.textPrimary.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
}

class _MorphItem {
  final String label;
  final String value;
  const _MorphItem(this.label, this.value);
}
