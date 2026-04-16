import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/verse_collection.dart';
import '../../services/bible/collection_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// COLLECTION DETAIL SCREEN — Versículos de una colección.
/// ═══════════════════════════════════════════════════════════════════════════
class CollectionDetailScreen extends StatelessWidget {
  final VerseCollection collection;

  const CollectionDetailScreen({super.key, required this.collection});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (context, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );

        SystemChrome.setSystemUIOverlayStyle(
          t.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );

        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios,
                            color: t.textSecondary, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(collection.emoji,
                                    style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    collection.name,
                                    style: GoogleFonts.cinzel(
                                      color: t.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (collection.description != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  collection.description!,
                                  style: GoogleFonts.manrope(
                                    color: t.textSecondary.withOpacity(0.5),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Live list
                Expanded(
                  child: ValueListenableBuilder<List<VerseCollection>>(
                    valueListenable:
                        CollectionService.I.collectionsNotifier,
                    builder: (context, allCollections, _) {
                      // Find latest version of this collection
                      final current = allCollections
                          .where((c) => c.id == collection.id)
                          .firstOrNull;
                      final verses = current?.verses ?? collection.verses;

                      if (verses.isEmpty) {
                        return Center(
                          child: Text(
                            'Colección vacía',
                            style: GoogleFonts.manrope(
                              color: t.textSecondary.withOpacity(0.4),
                              fontSize: 14,
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: verses.length,
                        itemBuilder: (ctx, idx) {
                          final v = verses[idx];
                          return _buildVerseTile(context, t, v);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildVerseTile(
      BuildContext context, BibleReaderThemeData t, VerseRef v) {
    return Dismissible(
      key: ValueKey(v.uniqueKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child:
            const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
      ),
      onDismissed: (_) {
        CollectionService.I.removeVerse(
          collectionId: collection.id,
          verseKey: v.uniqueKey,
        );
      },
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (c, a1, a2) => BibleReaderScreen(
                bookNumber: v.bookNumber,
                bookName: v.bookName,
                chapter: v.chapter,
                version: BibleUserDataService.I.preferredVersionNotifier.value,
              ),
              transitionDuration: const Duration(milliseconds: 150),
              transitionsBuilder: (ctx, a, sa, child) =>
                  FadeTransition(opacity: a, child: child),
            ),
          );
        },
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${v.reference} — ${v.version}',
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.5),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                v.text,
                style: GoogleFonts.lora(
                  color: t.textPrimary,
                  fontSize: 15,
                  height: 1.6,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
