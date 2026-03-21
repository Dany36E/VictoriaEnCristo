import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_verse.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/treasury_service.dart';
import '../../theme/bible_reader_theme.dart';

/// Panel inline de referencias cruzadas para un versículo seleccionado.
/// Muestra pasajes relacionados con preview de texto, tap navega al versículo.
class CrossRefsPanel extends StatefulWidget {
  final BibleVerse verse;
  final BibleReaderThemeData theme;
  final void Function(int bookNumber, String bookName, int chapter) onNavigate;

  const CrossRefsPanel({
    super.key,
    required this.verse,
    required this.theme,
    required this.onNavigate,
  });

  @override
  State<CrossRefsPanel> createState() => _CrossRefsPanelState();
}

class _CrossRefsPanelState extends State<CrossRefsPanel> {
  List<_CrossRefEntry> _refs = [];
  bool _loading = true;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  @override
  void didUpdateWidget(covariant CrossRefsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.verse.uniqueKey != widget.verse.uniqueKey) {
      _loadRefs();
    }
  }

  Future<void> _loadRefs() async {
    setState(() { _loading = true; _expanded = false; });
    try {
      final rawRefs = await TreasuryService.instance.getCrossReferences(
        widget.verse.bookNumber,
        widget.verse.chapter,
        widget.verse.verse,
      );

      final version = BibleUserDataService.I.preferredVersionNotifier.value;

      // Parse and load preview text for first few refs
      final entries = <_CrossRefEntry>[];
      final refsToLoad = rawRefs.take(20).toList();

      for (final ref in refsToLoad) {
        final parsed = TreasuryService.parseReference(ref);
        if (parsed == null) continue;

        String? previewText;
        try {
          final verses = await BibleParserService.I.getChapter(
            version: version,
            bookNumber: parsed.bookNumber,
            chapter: parsed.chapter,
          );
          final match = verses.where((v) => v.verse == parsed.verse).firstOrNull;
          previewText = match?.text;
        } catch (_) {}

        entries.add(_CrossRefEntry(
          ref: ref,
          displayRef: TreasuryService.formatReference(ref),
          bookNumber: parsed.bookNumber,
          chapter: parsed.chapter,
          verse: parsed.verse,
          bookName: _getBookName(parsed.bookNumber),
          previewText: previewText,
        ));
      }

      if (mounted) {
        setState(() {
          _refs = entries;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _refs = []; _loading = false; });
    }
  }

  String _getBookName(int bookNumber) {
    const names = <int, String>{
      1: 'Génesis', 2: 'Éxodo', 3: 'Levítico', 4: 'Números',
      5: 'Deuteronomio', 6: 'Josué', 7: 'Jueces', 8: 'Rut',
      9: '1 Samuel', 10: '2 Samuel', 11: '1 Reyes', 12: '2 Reyes',
      13: '1 Crónicas', 14: '2 Crónicas', 15: 'Esdras', 16: 'Nehemías',
      17: 'Ester', 18: 'Job', 19: 'Salmos', 20: 'Proverbios',
      21: 'Eclesiastés', 22: 'Cantares', 23: 'Isaías', 24: 'Jeremías',
      25: 'Lamentaciones', 26: 'Ezequiel', 27: 'Daniel', 28: 'Oseas',
      29: 'Joel', 30: 'Amós', 31: 'Abdías', 32: 'Jonás',
      33: 'Miqueas', 34: 'Nahúm', 35: 'Habacuc', 36: 'Sofonías',
      37: 'Hageo', 38: 'Zacarías', 39: 'Malaquías', 40: 'Mateo',
      41: 'Marcos', 42: 'Lucas', 43: 'Juan', 44: 'Hechos',
      45: 'Romanos', 46: '1 Corintios', 47: '2 Corintios', 48: 'Gálatas',
      49: 'Efesios', 50: 'Filipenses', 51: 'Colosenses',
      52: '1 Tesalonicenses', 53: '2 Tesalonicenses', 54: '1 Timoteo',
      55: '2 Timoteo', 56: 'Tito', 57: 'Filemón', 58: 'Hebreos',
      59: 'Santiago', 60: '1 Pedro', 61: '2 Pedro', 62: '1 Juan',
      63: '2 Juan', 64: '3 Juan', 65: 'Judas', 66: 'Apocalipsis',
    };
    return names[bookNumber] ?? 'Libro $bookNumber';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    if (_loading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                color: t.accent.withOpacity(0.4), strokeWidth: 1.5),
            ),
            const SizedBox(width: 8),
            Text('Cargando referencias...',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.4), fontSize: 12)),
          ],
        ),
      );
    }

    if (_refs.isEmpty) return const SizedBox.shrink();

    final visibleRefs = _expanded ? _refs : _refs.take(3).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: t.isDark
            ? Colors.white.withOpacity(0.03)
            : Colors.black.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.textSecondary.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Icon(Icons.link, color: t.accent, size: 15),
                const SizedBox(width: 6),
                Text(
                  'REFERENCIAS CRUZADAS',
                  style: GoogleFonts.manrope(
                    color: t.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: t.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_refs.length}',
                    style: GoogleFonts.manrope(
                      color: t.accent, fontSize: 10, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Reference list
          ...visibleRefs.map((entry) => _buildRefTile(t, entry)),

          // Show more / less
          if (_refs.length > 3)
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded
                          ? 'Mostrar menos'
                          : 'Ver ${_refs.length - 3} más',
                      style: GoogleFonts.manrope(
                        color: t.accent.withOpacity(0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less : Icons.expand_more,
                      color: t.accent.withOpacity(0.7), size: 16,
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRefTile(BibleReaderThemeData t, _CrossRefEntry entry) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onNavigate(entry.bookNumber, entry.bookName, entry.chapter);
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reference badge
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                entry.displayRef,
                style: GoogleFonts.manrope(
                  color: t.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Preview text
            Expanded(
              child: Text(
                entry.previewText ?? '...',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lora(
                  color: t.textPrimary.withOpacity(0.7),
                  fontSize: 12.5,
                  height: 1.5,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                size: 16, color: t.textSecondary.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

class _CrossRefEntry {
  final String ref;
  final String displayRef;
  final int bookNumber;
  final int chapter;
  final int verse;
  final String bookName;
  final String? previewText;

  _CrossRefEntry({
    required this.ref,
    required this.displayRef,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.bookName,
    this.previewText,
  });
}
