import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/dictionary_entry.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';

/// Pantalla de detalle de una entrada del diccionario bíblico.
class BibleDictionaryDetailScreen extends StatelessWidget {
  final DictionaryEntry entry;

  const BibleDictionaryDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(BibleReaderThemeData.migrateId(BibleUserDataService.I.readerThemeNotifier.value));
    return Scaffold(
      backgroundColor: t.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context, t)),
            SliverToBoxAdapter(child: _buildDefinition(t)),
            if (entry.references.isNotEmpty)
              SliverToBoxAdapter(child: _buildReferences(t)),
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BibleReaderThemeData t) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new,
                      color:
                          t.textPrimary.withValues(alpha: 0.7),
                      size: 20),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.source,
                    style: GoogleFonts.manrope(
                      color: t.accent.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.term,
                    style: GoogleFonts.cinzel(
                      color: t.accent,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 14,
                          color:
                              t.accent.withValues(alpha: 0.4)),
                      const SizedBox(width: 4),
                      Text(
                        'Diccionario Bíblico',
                        style: GoogleFonts.manrope(
                          color: t.textPrimary
                              .withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildDefinition(BibleReaderThemeData t) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DEFINICIÓN',
              style: GoogleFonts.cinzel(
                color: t.accent.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: t.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                entry.definition,
                style: GoogleFonts.manrope(
                  color: t.textPrimary.withValues(alpha: 0.85),
                  fontSize: 15,
                  height: 1.7,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildReferences(BibleReaderThemeData t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'REFERENCIAS BÍBLICAS',
              style: GoogleFonts.cinzel(
                color: t.accent.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.references.map((ref) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: t.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    ref,
                    style: GoogleFonts.manrope(
                      color: t.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}
