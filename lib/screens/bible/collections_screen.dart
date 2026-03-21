import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/verse_collection.dart';
import '../../services/bible/collection_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'collection_detail_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// COLLECTIONS SCREEN — Lista de colecciones del usuario.
/// ═══════════════════════════════════════════════════════════════════════════
class CollectionsScreen extends StatelessWidget {
  const CollectionsScreen({super.key});

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
                        child: Text(
                          'Colecciones',
                          style: GoogleFonts.cinzel(
                            color: t.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.add,
                            color: t.accent, size: 22),
                        onPressed: () =>
                            _showCreateDialog(context, t),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // List
                Expanded(
                  child: ValueListenableBuilder<List<VerseCollection>>(
                    valueListenable:
                        CollectionService.I.collectionsNotifier,
                    builder: (context, collections, _) {
                      if (collections.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.collections_bookmark_outlined,
                                  color: t.textSecondary.withOpacity(0.3),
                                  size: 48),
                              const SizedBox(height: 12),
                              Text(
                                'Sin colecciones',
                                style: GoogleFonts.manrope(
                                  color:
                                      t.textSecondary.withOpacity(0.4),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () =>
                                    _showCreateDialog(context, t),
                                child: Text(
                                  'Crear primera colección',
                                  style: GoogleFonts.manrope(
                                    color: t.accent,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24),
                        itemCount: collections.length,
                        itemBuilder: (ctx, idx) {
                          final c = collections[idx];
                          return _buildCollectionTile(
                              context, t, c);
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

  Widget _buildCollectionTile(
      BuildContext context, BibleReaderThemeData t, VerseCollection c) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CollectionDetailScreen(collection: c),
        ),
      ),
      onLongPress: () => _showDeleteDialog(context, t, c),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Text(c.emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.name,
                    style: GoogleFonts.lora(
                      color: t.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                  if (c.description != null &&
                      c.description!.isNotEmpty)
                    Text(
                      c.description!,
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Text(
              '${c.verseCount}',
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, BibleReaderThemeData t) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final emojis = ['📖', '✝️', '🙏', '💪', '❤️', '🔥', '⭐', '🕊️'];
    String selectedEmoji = '📖';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nueva colección',
                    style: GoogleFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Emoji picker
                  Row(
                    children: emojis.map((e) {
                      final selected = e == selectedEmoji;
                      return GestureDetector(
                        onTap: () =>
                            setSheetState(() => selectedEmoji = e),
                        child: Container(
                          width: 36,
                          height: 36,
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? t.accent.withOpacity(0.2)
                                : Colors.transparent,
                          ),
                          alignment: Alignment.center,
                          child: Text(e,
                              style: const TextStyle(fontSize: 18)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    autofocus: true,
                    style: GoogleFonts.manrope(
                        color: t.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Nombre de la colección',
                      hintStyle: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.4),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  TextField(
                    controller: descCtrl,
                    style: GoogleFonts.manrope(
                        color: t.textSecondary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Descripción (opcional)',
                      hintStyle: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.3),
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () {
                        if (nameCtrl.text.trim().isEmpty) return;
                        CollectionService.I.createCollection(
                          name: nameCtrl.text.trim(),
                          description: descCtrl.text.trim().isEmpty
                              ? null
                              : descCtrl.text.trim(),
                          emoji: selectedEmoji,
                        );
                        Navigator.pop(ctx);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: t.accent,
                        foregroundColor: t.background,
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Crear',
                        style: GoogleFonts.manrope(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(
      BuildContext context, BibleReaderThemeData t, VerseCollection c) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text('Eliminar "${c.name}"?',
            style: GoogleFonts.manrope(color: t.textPrimary, fontSize: 16)),
        content: Text('Se eliminará la colección y todos sus versículos.',
            style: GoogleFonts.manrope(
                color: t.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: GoogleFonts.manrope(color: t.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              CollectionService.I.deleteCollection(c.id);
              Navigator.pop(ctx);
            },
            child: Text('Eliminar',
                style: GoogleFonts.manrope(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}
