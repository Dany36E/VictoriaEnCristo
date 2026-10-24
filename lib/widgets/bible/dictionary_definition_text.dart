import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../models/bible/dictionary_entry.dart';
import '../../screens/bible/bible_dictionary_detail_screen.dart';
import '../../services/bible/bible_dictionary_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import '../../utils/bible_navigation_helper.dart';

/// Abre el lector en la referencia de Easton («GEN.2.7»). False si no es válida.
bool openDictionaryRef(BuildContext context, String raw) {
  final ref = DictionaryRef.parse(raw);
  if (ref == null) return false;
  BibleNavigationHelper.navigateTo(
    context,
    bookNumber: ref.start.bookNumber,
    bookName: ref.start.bookName,
    chapter: ref.start.chapter,
    verse: ref.start.verse,
  );
  return true;
}

/// Abre otra entrada del diccionario (enlaces «Véase»).
void openDictionaryEntry(BuildContext context, String id) {
  final entry = BibleDictionaryService.instance.byId(id);
  if (entry == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => BibleDictionaryDetailScreen(entry: entry),
    ),
  );
}

/// Definición con los marcadores convertidos en enlaces: las citas
/// (`[[GEN.2.7|Gn 2:7]]`) abren el lector y los «Véase»
/// (`[[VER:e0054|ABRAHAM]]`) abren la entrada relacionada.
class DictionaryDefinitionText extends StatefulWidget {
  final DictionaryEntry entry;
  final BibleReaderThemeData theme;
  final TextStyle style;

  const DictionaryDefinitionText({
    super.key,
    required this.entry,
    required this.theme,
    required this.style,
  });

  @override
  State<DictionaryDefinitionText> createState() =>
      _DictionaryDefinitionTextState();
}

class _DictionaryDefinitionTextState extends State<DictionaryDefinitionText> {
  final List<TapGestureRecognizer> _recognizers = [];

  void _clear() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  TapGestureRecognizer _tap(VoidCallback onTap) {
    final r = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(r);
    return r;
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final t = widget.theme;
    final text = widget.entry.definition;
    final link = widget.style.copyWith(
      color: t.accent,
      fontWeight: FontWeight.w600,
    );
    final spans = <InlineSpan>[];
    var last = 0;
    for (final m in DictionaryEntry.markerPattern.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final target = m.group(1)!;
      final label = m.group(2)!;
      if (target.startsWith('VER:')) {
        final id = target.substring(4);
        final exists = BibleDictionaryService.instance.byId(id) != null;
        spans.add(
          TextSpan(
            text: label,
            style: exists
                ? link.copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: t.accent.withValues(alpha: 0.6),
                  )
                : null,
            recognizer: exists
                ? _tap(() => openDictionaryEntry(context, id))
                : null,
          ),
        );
      } else if (DictionaryRef.parse(target) != null) {
        spans.add(
          TextSpan(
            text: label,
            style: link,
            recognizer: _tap(() => openDictionaryRef(context, target)),
          ),
        );
      } else {
        spans.add(TextSpan(text: label));
      }
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(style: widget.style, children: spans));
  }
}

/// Fichas de referencias bíblicas («Génesis 2:7») que abren el lector.
class DictionaryReferenceChips extends StatelessWidget {
  final List<String> references;
  final BibleReaderThemeData theme;
  final double fontSize;

  const DictionaryReferenceChips({
    super.key,
    required this.references,
    required this.theme,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final refs = [for (final r in references) ?DictionaryRef.parse(r)];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final ref in refs)
          Material(
            color: t.accent.withValues(alpha: 0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: t.accent.withValues(alpha: 0.25)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => openDictionaryRef(context, ref.raw),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Text(
                  ref.label,
                  style: AppFonts.manrope(
                    color: t.accent,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
