import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/typology.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// Detalle de una tipología: AT↔NT lado a lado con explicaciones.
class TypologyDetailScreen extends StatelessWidget {
  final Typology typology;

  const TypologyDetailScreen({super.key, required this.typology});

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value),
    );
    return Scaffold(
      backgroundColor: t.background,
      appBar: AppBar(
        backgroundColor: t.surface,
        title: Text(
          'Tipología',
          style: GoogleFonts.cinzel(
            color: t.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Title
          Text(
            typology.title,
            style: GoogleFonts.cinzel(
              color: t.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            typology.description,
            style: GoogleFonts.manrope(
              color: t.textPrimary.withOpacity(0.6),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          // Tags
          Wrap(
            spacing: 6,
            children: typology.tags
                .map((tag) => Chip(
                      label: Text(tag),
                      labelStyle: GoogleFonts.manrope(
                        color: t.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: t.accent.withOpacity(0.1),
                      side: BorderSide.none,
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          // AT side
          _buildTestamentSection(
            context,
            t,
            label: 'TIPO — Antiguo Testamento',
            ref: typology.oldTestament,
            color: const Color(0xFFFF7043),
            icon: Icons.history,
          ),
          // Arrow
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(Icons.arrow_downward,
                      color: t.accent.withOpacity(0.3), size: 24),
                  Text(
                    'Se cumple en',
                    style: GoogleFonts.manrope(
                      color: t.accent.withOpacity(0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // NT side
          _buildTestamentSection(
            context,
            t,
            label: 'ANTITIPO — Nuevo Testamento',
            ref: typology.newTestament,
            color: const Color(0xFF42A5F5),
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildTestamentSection(
    BuildContext context,
    BibleReaderThemeData t, {
    required String label,
    required TypologyRef ref,
    required Color color,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: () {
        final parsed = _parseOsis(ref.reference);
        if (parsed != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BibleReaderScreen(
                bookNumber: parsed['bookNumber'] as int,
                bookName: parsed['bookName'] as String,
                chapter: parsed['chapter'] as int,
                version: BibleUserDataService.I.preferredVersionNotifier.value,
                initialVerse: parsed['verse'] as int?,
              ),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 16),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatFullRef(ref.reference),
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ref.text,
              style: GoogleFonts.crimsonPro(
                color: t.textPrimary.withOpacity(0.7),
                fontSize: 16,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
            if (ref.aspect.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline,
                        color: color.withOpacity(0.6), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        ref.aspect,
                        style: GoogleFonts.manrope(
                          color: t.textPrimary.withOpacity(0.5),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Ir al pasaje',
                  style: GoogleFonts.manrope(
                    color: color.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: color.withOpacity(0.4), size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatFullRef(String osis) {
    final parts = osis.split('.');
    if (parts.length < 3) return osis;
    final book = _osisToSpanish[parts[0]] ?? parts[0];
    return '$book ${parts.sublist(1).join(':')}';
  }

  Map<String, dynamic>? _parseOsis(String osis) {
    final parts = osis.split('.');
    if (parts.length < 2) return null;
    final num = _osisToNumber[parts[0]];
    if (num == null) return null;
    return {
      'bookNumber': num,
      'bookName': _osisToSpanish[parts[0]] ?? parts[0],
      'chapter': int.tryParse(parts[1]) ?? 1,
      if (parts.length >= 3) 'verse': int.tryParse(parts[2]),
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
