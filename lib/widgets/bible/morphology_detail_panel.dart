import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/interlinear_word.dart';
import '../../models/bible/strong_lexicon_entry.dart';
import '../../screens/bible/bible_search_screen.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/strong_lexicon_service.dart';
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
      BibleUserDataService.I.readerThemeNotifier.value,
    ),
  );

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
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        decoration: BoxDecoration(
          color: t.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: t.accent.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    _buildWordHeader(),
                    if (morph != null) _buildMorphGrid(morph),
                    if (word.morphCode.isNotEmpty) _buildRawCode(),
                    _buildLexicon(context),
                    _buildOccurrencesButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
            Icon(
              Icons.translate,
              size: 14,
              color: t.accent.withValues(alpha: 0.5),
            ),
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
        border: Border.all(color: t.accent.withValues(alpha: 0.2)),
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
        textStyle: GoogleFonts.manrope(color: t.background, fontSize: 12),
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
          Icon(
            Icons.code,
            size: 14,
            color: t.textPrimary.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 6),
          Text(
            word.morphCode,
            style: TextStyle(
              fontFamily: 'monospace',
              color: t.textPrimary.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildLexicon(BuildContext context) {
    return FutureBuilder<List<StrongLexiconEntry>>(
      future: StrongLexiconService.I.resolveWord(word, isHebrew: isOT),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: t.accent.withValues(alpha: 0.6),
                strokeWidth: 1.5,
              ),
            ),
          );
        }
        final entries = snapshot.data ?? const <StrongLexiconEntry>[];
        if (entries.isEmpty) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Text(
              'Esta forma no tiene todavía un vínculo Strong inequívoco. Aun así puedes buscar todas sus apariciones por la palabra original.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.55),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'LÉXICO STRONG LOCAL',
                style: GoogleFonts.cinzel(
                  color: t.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              ...entries.take(3).map(_buildLexiconEntry),
              Text(
                'Definiciones históricas en inglés. Fuente: Open Scriptures; disponibles sin conexión.',
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withValues(alpha: 0.4),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLexiconEntry(StrongLexiconEntry entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: t.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: t.accent, width: 2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                entry.strongNumber,
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.transliteration.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.transliteration,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.manrope(
                      color: t.textPrimary.withValues(alpha: 0.65),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (entry.definition.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              entry.definition,
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.82),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          if (entry.biblicalUsage.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              'Uso KJV: ${entry.biblicalUsage}',
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.5),
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOccurrencesButton(BuildContext context) {
    final query = (word.lemma?.isNotEmpty == true)
        ? word.lemma!
        : word.originalWord;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: t.accent,
            foregroundColor: t.background,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute(
                builder: (_) => BibleSearchScreen(
                  initialAdvanced: true,
                  initialQuery: query,
                ),
              ),
            );
          },
          icon: const Icon(Icons.manage_search, size: 18),
          label: Text(
            'Ver todas sus apariciones',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

class _MorphItem {
  final String label;
  final String value;
  const _MorphItem(this.label, this.value);
}
