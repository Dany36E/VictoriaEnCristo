import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/bible/bible_note.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'bible_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ALL NOTES SCREEN — Edición editorial premium
///
/// Sin AppBar, sin cards. Texto plano con swipe-to-delete.
/// Fechas relativas, búsqueda opcional.
/// ═══════════════════════════════════════════════════════════════════════════
class AllNotesScreen extends StatefulWidget {
  const AllNotesScreen({super.key});

  @override
  State<AllNotesScreen> createState() => _AllNotesScreenState();
}

class _AllNotesScreenState extends State<AllNotesScreen> {
  bool _searchMode = false;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

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
              children: [
                _buildHeader(t),
                Expanded(child: _buildBody(t)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BibleReaderThemeData t) {
    if (_searchMode) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: t.isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: GoogleFonts.manrope(
                      color: t.textPrimary, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Buscar en notas...',
                    hintStyle: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.4),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.toLowerCase()),
                ),
              ),
            ),
            IconButton(
              icon:
                  Icon(Icons.close, color: t.textSecondary, size: 20),
              onPressed: () {
                setState(() {
                  _searchMode = false;
                  _searchQuery = '';
                });
                _searchController.clear();
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Icon(Icons.arrow_back_ios,
                color: t.textSecondary, size: 18),
          ),
          const SizedBox(width: 12),
          Icon(Icons.sticky_note_2_outlined, color: t.accent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Notas',
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.search,
                color: t.textSecondary.withOpacity(0.6), size: 20),
            onPressed: () {
              setState(() => _searchMode = true);
              _searchFocus.requestFocus();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BibleReaderThemeData t) {
    return ValueListenableBuilder<Map<String, BibleNote>>(
      valueListenable: BibleUserDataService.I.notesNotifier,
      builder: (context, notesMap, _) {
        var notes = notesMap.values.toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        if (_searchQuery.isNotEmpty) {
          notes = notes
              .where((n) =>
                  n.text.toLowerCase().contains(_searchQuery) ||
                  n.reference.toLowerCase().contains(_searchQuery))
              .toList();
        }

        if (notes.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(
                _searchQuery.isNotEmpty
                    ? 'Sin resultados'
                    : 'Tus reflexiones sobre los\nversículos aparecerán aquí',
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: t.textSecondary.withOpacity(0.4),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return _buildNoteTile(note, t);
          },
        );
      },
    );
  }

  Widget _buildNoteTile(BibleNote note, BibleReaderThemeData t) {
    final version = BibleUserDataService.I.preferredVersionNotifier.value;

    return Dismissible(
      key: ValueKey(note.verseKey),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          'Eliminar',
          style: GoogleFonts.manrope(
            color: t.textSecondary.withOpacity(0.5),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      onDismissed: (_) {
        BibleUserDataService.I.deleteNote(
          note.bookNumber,
          note.chapter,
          note.verse,
        );
      },
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (c, a1, a2) => BibleReaderScreen(
              bookNumber: note.bookNumber,
              bookName: note.bookName,
              chapter: note.chapter,
              version: version,
            ),
            transitionDuration: const Duration(milliseconds: 150),
            transitionsBuilder: (ctx, a, sa, child) =>
                FadeTransition(opacity: a, child: child),
          ),
        ),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: t.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      note.reference.toUpperCase(),
                      style: GoogleFonts.manrope(
                        color: t.textSecondary.withOpacity(0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  Text(
                    _relativeDate(note.updatedAt),
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                note.text,
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

  String _relativeDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'ayer';
    if (diff.inDays < 7) return 'hace ${diff.inDays} días';
    if (diff.inDays < 30) return 'hace ${diff.inDays ~/ 7} sem';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
