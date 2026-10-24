import 'package:flutter/material.dart';

import '../../models/bible/strong_lexicon_entry.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';

/// Textos de atribución del diccionario de Strong en español.
abstract final class StrongLexiconCredits {
  static const String base =
      'Diccionario de Strong (1890), dominio público. Traducción propia al español.';
  static const String hebrew =
      'Texto fuente digital: Open Scriptures Hebrew Bible/Strong\'s (CC BY-SA 4.0); '
      'esta traducción se comparte bajo la misma licencia.';
  static const String greek = 'Texto fuente: strongs-dictionary-xml (CC0).';

  /// Atribución para las entradas mostradas: hebreo, griego o ambos.
  static String forEntries(Iterable<StrongLexiconEntry> entries) {
    final hasHebrew = entries.any((e) => e.strongNumber.startsWith('H'));
    final hasGreek = entries.any((e) => e.strongNumber.startsWith('G'));
    return forLanguages(hebrew: hasHebrew, greek: hasGreek);
  }

  static String forLanguages({required bool hebrew, required bool greek}) {
    return <String>[
      base,
      if (hebrew) StrongLexiconCredits.hebrew,
      if (greek) StrongLexiconCredits.greek,
    ].join(' ');
  }
}

/// Ficha de una entrada del diccionario de Strong: número, lema,
/// transliteración, etimología, definición y equivalentes de la KJV.
class StrongEntryCard extends StatelessWidget {
  final StrongLexiconEntry entry;
  final BibleReaderThemeData theme;
  final bool showDerivation;
  final VoidCallback? onTap;

  const StrongEntryCard({
    super.key,
    required this.entry,
    required this.theme,
    this.showDerivation = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final card = Container(
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
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                entry.strongNumber,
                style: AppFonts.manrope(
                  color: t.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (entry.lemma.isNotEmpty)
                Text(
                  entry.lemma,
                  textDirection: entry.strongNumber.startsWith('H')
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (entry.transliteration.isNotEmpty)
                Text(
                  entry.transliteration,
                  style: AppFonts.manrope(
                    color: t.textoTenue(0.75),
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
          if (showDerivation && entry.derivation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              entry.derivation,
              style: AppFonts.manrope(
                color: t.textoTenue(0.75),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
          if (entry.definition.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(
              entry.definition,
              style: AppFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.85),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
          if (entry.biblicalUsage.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Equivalentes en la KJV: ',
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: entry.biblicalUsage),
                ],
              ),
              style: AppFonts.manrope(
                color: t.textoTenue(0.8),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: 'Buscar apariciones de ${entry.strongNumber}',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

/// Leyenda de las marcas de Strong y atribución del diccionario.
class StrongLexiconFootnote extends StatelessWidget {
  final Iterable<StrongLexiconEntry> entries;
  final BibleReaderThemeData theme;

  const StrongLexiconFootnote({
    super.key,
    required this.entries,
    required this.theme,
  });

  /// true si alguna entrada usa × o + en sus equivalentes.
  static bool needsLegend(Iterable<StrongLexiconEntry> entries) => entries.any(
    (e) => e.biblicalUsage.contains('×') || e.biblicalUsage.contains('+'),
  );

  @override
  Widget build(BuildContext context) {
    final style = AppFonts.manrope(
      color: theme.textoTenue(0.7),
      fontSize: 10,
      height: 1.4,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (needsLegend(entries)) ...[
          Text(
            '× modismo: la KJV traduce la palabra con un giro idiomático. '
            '+ frase: la palabra forma parte de una expresión más larga.',
            style: style,
          ),
          const SizedBox(height: 4),
        ],
        Text(StrongLexiconCredits.forEntries(entries), style: style),
      ],
    );
  }
}
