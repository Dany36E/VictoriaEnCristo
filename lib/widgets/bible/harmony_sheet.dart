import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/harmony_section.dart';
import '../../theme/bible_reader_theme.dart';

/// Bottom sheet que muestra un evento de armonía con columnas por evangelio.
class HarmonySheet extends StatelessWidget {
  final HarmonySection section;
  final BibleReaderThemeData theme;
  final void Function(int bookNumber, String bookName, int chapter)? onNavigate;

  const HarmonySheet({
    super.key,
    required this.section,
    required this.theme,
    this.onNavigate,
  });

  static const _gospels = [
    {'key': 'matthew', 'abbr': 'Mt', 'book': 40, 'name': 'Mateo'},
    {'key': 'mark', 'abbr': 'Mr', 'book': 41, 'name': 'Marcos'},
    {'key': 'luke', 'abbr': 'Lc', 'book': 42, 'name': 'Lucas'},
    {'key': 'john', 'abbr': 'Jn', 'book': 43, 'name': 'Juan'},
  ];

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.25,
      maxChildSize: 0.75,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20),
            ],
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.zero,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.grid_view_rounded,
                            color: t.accent, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Armonía de los Evangelios',
                            style: GoogleFonts.cinzel(
                              color: t.textSecondary.withOpacity(0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      section.title,
                      style: GoogleFonts.cinzel(
                        color: t.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        section.category,
                        style: GoogleFonts.manrope(
                          color: t.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: t.textSecondary.withOpacity(0.1)),
              // Gospel columns
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: _gospels.map((g) {
                    final ref = section.references[g['key'] as String];
                    final hasRef = ref != null && ref.isNotEmpty;
                    return Expanded(
                      child: _buildGospelColumn(t, g, ref, hasRef),
                    );
                  }).toList(),
                ),
              ),
              // Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '${section.gospelCount} de 4 evangelios narran este evento',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary.withOpacity(0.4),
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGospelColumn(BibleReaderThemeData t, Map<String, Object> g,
      String? ref, bool hasRef) {
    final abbr = g['abbr'] as String;
    final bookNum = g['book'] as int;
    final bookName = g['name'] as String;

    return GestureDetector(
      onTap: hasRef
          ? () {
              final chapter = _parseChapterFromOsis(ref!);
              if (chapter != null) {
                onNavigate?.call(bookNum, bookName, chapter);
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: hasRef
              ? t.accent.withOpacity(0.08)
              : t.textSecondary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasRef
                ? t.accent.withOpacity(0.2)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Text(
              abbr,
              style: GoogleFonts.cinzel(
                color: hasRef ? t.accent : t.textSecondary.withOpacity(0.3),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            if (hasRef)
              Text(
                _formatOsisRef(ref!),
                style: GoogleFonts.manrope(
                  color: t.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                '—',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.2),
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Convierte OSIS ref (e.g. MAT.5.1-7.29 o MAT.3.13-17) a display.
  String _formatOsisRef(String osis) {
    // Remove book prefix
    final parts = osis.split('.');
    if (parts.length < 3) return osis;
    final chVerse = parts.sublist(1).join(':');
    return chVerse.replaceFirst(':', ':').replaceAll('.', ':');
  }

  int? _parseChapterFromOsis(String osis) {
    final parts = osis.split('.');
    if (parts.length >= 2) return int.tryParse(parts[1]);
    return null;
  }
}
