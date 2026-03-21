import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/bible/dictionary_entry.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';

/// Small bottom sheet que muestra una entrada del diccionario bíblico.
class DictionarySheet extends StatelessWidget {
  final DictionaryEntry entry;

  const DictionarySheet({super.key, required this.entry});

  BibleReaderThemeData get t => BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
          BibleUserDataService.I.readerThemeNotifier.value));

  static void show(BuildContext context, DictionaryEntry entry) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.85,
        minChildSize: 0.3,
        builder: (ctx, scroll) => DictionarySheet(entry: entry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: t.accent.withValues(alpha: 0.3)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHandle(),
            const SizedBox(height: 12),
            _buildHeader(),
            const SizedBox(height: 16),
            _buildDefinition(),
            if (entry.references.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildReferences(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: t.accent.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  Widget _buildHeader() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.term,
                  style: GoogleFonts.cinzel(
                    color: t.accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: t.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    entry.source,
                    style: GoogleFonts.manrope(
                      color: t.accent.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.menu_book_outlined,
              color: t.accent.withValues(alpha: 0.4), size: 28),
        ],
      );

  Widget _buildDefinition() => Column(
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
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.surface.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              entry.definition,
              style: GoogleFonts.manrope(
                color: t.textPrimary.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ),
        ],
      );

  Widget _buildReferences() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REFERENCIAS',
            style: GoogleFonts.cinzel(
              color: t.accent.withValues(alpha: 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entry.references.map((ref) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
}
