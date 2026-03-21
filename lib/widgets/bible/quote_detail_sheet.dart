import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/ot_quote.dart';
import '../../theme/bible_reader_theme.dart';

/// Bottom sheet que muestra una cita del AT en el NT lado a lado.
class QuoteDetailSheet extends StatelessWidget {
  final OTQuote quote;
  final BibleReaderThemeData theme;
  final void Function(int bookNumber, String bookName, int chapter)? onNavigate;

  const QuoteDetailSheet({
    super.key,
    required this.quote,
    required this.theme,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.3,
      maxChildSize: 0.85,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.format_quote, color: t.accent, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Cita del Antiguo Testamento',
                          style: GoogleFonts.cinzel(
                            color: t.textSecondary.withOpacity(0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        _buildQuoteTypeBadge(t),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
              Divider(height: 1, color: t.textSecondary.withOpacity(0.1)),
              // Two-column comparison
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // OT side
                    Expanded(
                      child: _buildQuoteSide(
                        t,
                        label: 'Antiguo Testamento',
                        reference: quote.otReference,
                        text: quote.otText,
                        color: const Color(0xFFFF7043),
                        isOT: true,
                      ),
                    ),
                    // Divider arrow
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 30),
                      child: Icon(Icons.arrow_forward,
                          color: t.textSecondary.withOpacity(0.3), size: 20),
                    ),
                    // NT side
                    Expanded(
                      child: _buildQuoteSide(
                        t,
                        label: 'Nuevo Testamento',
                        reference: quote.ntReference,
                        text: quote.ntText,
                        color: const Color(0xFF42A5F5),
                        isOT: false,
                      ),
                    ),
                  ],
                ),
              ),
              // Context / Significance
              if (quote.context.isNotEmpty || quote.significance.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(
                          height: 1,
                          color: t.textSecondary.withOpacity(0.1)),
                      const SizedBox(height: 12),
                      if (quote.context.isNotEmpty) ...[
                        Text(
                          'Contexto',
                          style: GoogleFonts.cinzel(
                            color: t.textSecondary.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quote.context,
                          style: GoogleFonts.manrope(
                            color: t.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (quote.significance.isNotEmpty) ...[
                        Text(
                          'Significado',
                          style: GoogleFonts.cinzel(
                            color: t.textSecondary.withOpacity(0.5),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          quote.significance,
                          style: GoogleFonts.manrope(
                            color: t.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuoteSide(
    BibleReaderThemeData t, {
    required String label,
    required String reference,
    required String text,
    required Color color,
    required bool isOT,
  }) {
    return GestureDetector(
      onTap: () {
        final parsed = _parseOsisRef(reference);
        if (parsed != null) {
          onNavigate?.call(
              parsed['bookNumber'] as int,
              parsed['bookName'] as String,
              parsed['chapter'] as int);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.manrope(
                color: color,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatOsisRef(reference),
              style: GoogleFonts.manrope(
                color: t.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: GoogleFonts.crimsonPro(
                color: t.textSecondary,
                fontSize: 14,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ir al pasaje',
                  style: GoogleFonts.manrope(
                    color: color.withOpacity(0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: color.withOpacity(0.4), size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteTypeBadge(BibleReaderThemeData t) {
    String label;
    Color color;
    switch (quote.quoteType) {
      case QuoteType.direct:
        label = 'Cita directa';
        color = const Color(0xFF66BB6A);
        break;
      case QuoteType.paraphrase:
        label = 'Paráfrasis';
        color = const Color(0xFFFFA726);
        break;
      case QuoteType.allusion:
        label = 'Alusión';
        color = const Color(0xFF42A5F5);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.manrope(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatOsisRef(String osis) {
    // GEN.3.15 → Génesis 3:15, MAT.1.23 → Mateo 1:23
    final parts = osis.split('.');
    if (parts.length < 3) return osis;
    final bookName = _osisToSpanish[parts[0]] ?? parts[0];
    final rest = parts.sublist(1).join(':');
    return '$bookName $rest';
  }

  Map<String, dynamic>? _parseOsisRef(String osis) {
    final parts = osis.split('.');
    if (parts.length < 3) return null;
    final bookNum = _osisToNumber[parts[0]];
    if (bookNum == null) return null;
    return {
      'bookNumber': bookNum,
      'bookName': _osisToSpanish[parts[0]] ?? parts[0],
      'chapter': int.tryParse(parts[1]) ?? 1,
    };
  }

  static const _osisToNumber = <String, int>{
    'GEN': 1, 'EXO': 2, 'LEV': 3, 'NUM': 4, 'DEU': 5,
    'JOS': 6, 'JDG': 7, 'RUT': 8, '1SA': 9, '2SA': 10,
    '1KI': 11, '2KI': 12, '1CH': 13, '2CH': 14, 'EZR': 15,
    'NEH': 16, 'EST': 17, 'JOB': 18, 'PSA': 19, 'PRO': 20,
    'ECC': 21, 'SNG': 22, 'ISA': 23, 'JER': 24, 'LAM': 25,
    'EZK': 26, 'DAN': 27, 'HOS': 28, 'JOL': 29, 'AMO': 30,
    'OBA': 31, 'JON': 32, 'MIC': 33, 'NAM': 34, 'HAB': 35,
    'ZEP': 36, 'HAG': 37, 'ZEC': 38, 'MAL': 39,
    'MAT': 40, 'MRK': 41, 'LUK': 42, 'JHN': 43, 'ACT': 44,
    'ROM': 45, '1CO': 46, '2CO': 47, 'GAL': 48, 'EPH': 49,
    'PHP': 50, 'COL': 51, '1TH': 52, '2TH': 53, '1TI': 54,
    '2TI': 55, 'TIT': 56, 'PHM': 57, 'HEB': 58, 'JAS': 59,
    '1PE': 60, '2PE': 61, '1JN': 62, '2JN': 63, '3JN': 64,
    'JUD': 65, 'REV': 66,
  };

  static const _osisToSpanish = <String, String>{
    'GEN': 'Génesis', 'EXO': 'Éxodo', 'LEV': 'Levítico', 'NUM': 'Números',
    'DEU': 'Deuteronomio', 'JOS': 'Josué', 'JDG': 'Jueces', 'RUT': 'Rut',
    '1SA': '1 Samuel', '2SA': '2 Samuel', '1KI': '1 Reyes', '2KI': '2 Reyes',
    '1CH': '1 Crónicas', '2CH': '2 Crónicas', 'EZR': 'Esdras',
    'NEH': 'Nehemías', 'EST': 'Ester', 'JOB': 'Job', 'PSA': 'Salmos',
    'PRO': 'Proverbios', 'ECC': 'Eclesiastés', 'SNG': 'Cantares',
    'ISA': 'Isaías', 'JER': 'Jeremías', 'LAM': 'Lamentaciones',
    'EZK': 'Ezequiel', 'DAN': 'Daniel', 'HOS': 'Oseas', 'JOL': 'Joel',
    'AMO': 'Amós', 'OBA': 'Abdías', 'JON': 'Jonás', 'MIC': 'Miqueas',
    'NAM': 'Nahúm', 'HAB': 'Habacuc', 'ZEP': 'Sofonías', 'HAG': 'Hageo',
    'ZEC': 'Zacarías', 'MAL': 'Malaquías',
    'MAT': 'Mateo', 'MRK': 'Marcos', 'LUK': 'Lucas', 'JHN': 'Juan',
    'ACT': 'Hechos', 'ROM': 'Romanos', '1CO': '1 Corintios',
    '2CO': '2 Corintios', 'GAL': 'Gálatas', 'EPH': 'Efesios',
    'PHP': 'Filipenses', 'COL': 'Colosenses', '1TH': '1 Tesalonicenses',
    '2TH': '2 Tesalonicenses', '1TI': '1 Timoteo', '2TI': '2 Timoteo',
    'TIT': 'Tito', 'PHM': 'Filemón', 'HEB': 'Hebreos', 'JAS': 'Santiago',
    '1PE': '1 Pedro', '2PE': '2 Pedro', '1JN': '1 Juan', '2JN': '2 Juan',
    '3JN': '3 Juan', 'JUD': 'Judas', 'REV': 'Apocalipsis',
  };
}
