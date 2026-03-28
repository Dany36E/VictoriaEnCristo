import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/share_template.dart';
import '../../screens/bible/template_picker_screen.dart';
import '../../screens/bible/verse_compare_screen.dart';
import '../../screens/wall/wall_composer_screen.dart';
import '../../services/bible/bible_share_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/share_cache_service.dart';
import '../../theme/bible_reader_theme.dart';
import 'color_picker_row.dart';
import 'note_editor_sheet.dart';
import 'prayer_sheet.dart';
import 'verse_study_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// VERSE ACTIONS SHEET — Unified bottom sheet
///
/// Secciones:
///   1. Preview del versículo
///   2. Colores de subrayado (inline, sin tap extra)
///   3. Previews horizontales de plantillas de imagen
///   4. Fila de estudio unificada (Interlineal, Comentario, Conexiones, Guzik)
///   5. Acciones rápidas (Guardar, Copiar, Nota, Texto, Oración, Muro)
/// ═══════════════════════════════════════════════════════════════════════════

void showVerseActionsSheet({
  required BuildContext context,
  required BibleVerse verse,
  required BibleReaderThemeData theme,
  required VoidCallback onDismiss,
}) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black26,
    builder: (_) => _VerseActionsSheet(verse: verse, theme: theme),
  ).whenComplete(onDismiss);
}

class _VerseActionsSheet extends StatefulWidget {
  final BibleVerse verse;
  final BibleReaderThemeData theme;

  const _VerseActionsSheet({required this.verse, required this.theme});

  @override
  State<_VerseActionsSheet> createState() => _VerseActionsSheetState();
}

class _VerseActionsSheetState extends State<_VerseActionsSheet> {
  bool _sharing = false;

  BibleUserDataService get _data => BibleUserDataService.I;
  BibleReaderThemeData get _t => widget.theme;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.80,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: _t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.zero,
          children: [
            _buildHandle(),
            _buildVersePreview(),
            _buildHighlightColors(),
            _buildImagePreviews(),
            _buildStudyRow(),
            _buildQuickActions(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Handle ──
  Widget _buildHandle() => Center(
        child: Container(
          margin: const EdgeInsets.only(top: 10, bottom: 4),
          width: 36,
          height: 3.5,
          decoration: BoxDecoration(
            color: _t.textSecondary.withOpacity(0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  // ── 1. Preview del versículo ──
  Widget _buildVersePreview() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.verse.reference} (${widget.verse.version})'
                  .toUpperCase(),
              style: GoogleFonts.manrope(
                fontSize: 10,
                color: _t.accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.verse.text,
              style: GoogleFonts.crimsonPro(
                fontSize: 14,
                color: _t.textPrimary.withOpacity(0.85),
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );

  // ── 2. Colores de subrayado ──
  Widget _buildHighlightColors() {
    final highlight =
        _data.highlightsNotifier.value[widget.verse.uniqueKey];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('SUBRAYAR'),
          const SizedBox(height: 8),
          ColorPickerRow(
            selectedColor: highlight?.colorHex,
            onColorSelected: (colorHex) {
              if (colorHex == null) {
                _data.removeHighlight(
                  widget.verse.bookNumber,
                  widget.verse.chapter,
                  widget.verse.verse,
                );
              } else {
                _data.addHighlight(
                  bookNumber: widget.verse.bookNumber,
                  chapter: widget.verse.chapter,
                  verse: widget.verse.verse,
                  colorHex: colorHex,
                );
              }
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  // ── 3. Previews horizontales de plantillas ──
  Widget _buildImagePreviews() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Row(
              children: [
                _sectionLabel('COMPARTIR IMAGEN'),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            TemplatePickerScreen(verse: widget.verse),
                      ),
                    );
                  },
                  child: Text(
                    'Ver todas →',
                    style: GoogleFonts.manrope(
                      fontSize: 10,
                      color: _t.accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kShareTemplates.length,
              itemBuilder: (_, i) => _buildTemplateThumbnail(i),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
            child: Text(
              'Toca para compartir  ·  Mantén para editar',
              style: GoogleFonts.manrope(
                fontSize: 9,
                color: _t.textSecondary.withOpacity(0.35),
              ),
            ),
          ),
        ],
      );

  Widget _buildTemplateThumbnail(int index) {
    final template = kShareTemplates[index];
    return GestureDetector(
      onTap: () => _shareWithTemplate(template),
      onLongPress: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TemplatePickerScreen(
              verse: widget.verse,
              initialTemplateIndex: index,
            ),
          ),
        );
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (template.backgroundAsset != null)
                Image.asset(
                  template.backgroundAsset!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: template.isDark
                        ? const Color(0xFF1A1A2E)
                        : const Color(0xFFF5E6C8),
                  ),
                )
              else
                Container(
                  color: template.isDark
                      ? const Color(0xFF1A1A2E)
                      : const Color(0xFFF5E6C8),
                ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: Text(
                  template.name,
                  style: GoogleFonts.manrope(
                    fontSize: 8,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareWithTemplate(ShareCardTemplate template) async {
    if (_sharing) return;
    setState(() => _sharing = true);

    try {
      // Intentar caché primero
      final cached = await ShareCacheService.I.getCachedCard(
        verseKey: widget.verse.uniqueKey,
        templateId: template.id,
      );

      if (cached != null) {
        Navigator.pop(context);
        await Share.shareXFiles(
          [XFile(cached.path)],
          text: 'Victoria en Cristo',
        );
        return;
      }

      // Sin caché → abrir TemplatePickerScreen con plantilla preseleccionada
      final idx = kShareTemplates.indexOf(template);
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TemplatePickerScreen(
            verse: widget.verse,
            initialTemplateIndex: idx >= 0 ? idx : 0,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[VerseActionsSheet] Error sharing: $e');
      if (mounted) setState(() => _sharing = false);
    }
  }

  // ── 4. Estudio unificado ──
  Widget _buildStudyRow() => Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('ESTUDIO'),
            const SizedBox(height: 8),
            Row(
              children: [
                _studyBtn(Icons.translate, 'Interlineal', 0),
                const SizedBox(width: 8),
                _studyBtn(Icons.auto_stories_outlined, 'Comentario', 1),
                const SizedBox(width: 8),
                _studyBtn(Icons.link, 'Conexiones', 2),
                const SizedBox(width: 8),
                _studyBtn(Icons.school_outlined, 'Guzik', 3),
              ],
            ),
          ],
        ),
      );

  Widget _studyBtn(IconData icon, String label, int tab) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          VerseStudySheet.show(context, widget.verse, initialTab: tab);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _t.accent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _t.accent.withOpacity(0.15)),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: _t.accent),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.manrope(
                  fontSize: 9,
                  color: _t.accent,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 5. Acciones rápidas ──
  Widget _buildQuickActions() {
    final isSaved = _data.isVerseSaved(
      widget.verse.bookNumber,
      widget.verse.chapter,
      widget.verse.verse,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          _quickBtn(
            isSaved ? Icons.bookmark : Icons.bookmark_outline,
            'Guardar',
            color: isSaved ? _t.accent : null,
            onTap: () {
              _data.toggleSavedVerse(
                bookNumber: widget.verse.bookNumber,
                chapter: widget.verse.chapter,
                verse: widget.verse.verse,
                bookName: widget.verse.bookName,
                text: widget.verse.text,
                version: widget.verse.version,
              );
              Navigator.pop(context);
            },
          ),
          _quickBtn(Icons.content_copy_outlined, 'Copiar', onTap: () {
            Clipboard.setData(ClipboardData(
              text:
                  '${widget.verse.text}\n— ${widget.verse.reference} (${widget.verse.version})',
            ));
            Navigator.pop(context);
          }),
          _quickBtn(Icons.edit_note_outlined, 'Nota', onTap: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => NoteEditorSheet(verse: widget.verse),
            );
          }),
          _quickBtn(Icons.share_outlined, 'Texto', onTap: () {
            Navigator.pop(context);
            BibleShareService.shareAsText(widget.verse);
          }),
          _quickBtn(Icons.volunteer_activism, 'Oración', onTap: () {
            Navigator.pop(context);
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => PrayerSheet(verse: widget.verse),
            );
          }),
          _quickBtn(Icons.compare_arrows, 'Comparar', onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VerseCompareScreen(
                  bookNumber: widget.verse.bookNumber,
                  bookName: widget.verse.bookName,
                  chapter: widget.verse.chapter,
                  verse: widget.verse.verse,
                ),
              ),
            );
          }),
          _quickBtn(Icons.campaign_outlined, 'Muro', onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => WallComposerScreen(
                  preloadedVerse: widget.verse,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _quickBtn(IconData icon, String label,
      {Color? color, VoidCallback? onTap}) {
    final c = color ?? _t.textSecondary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 22, color: c),
              const SizedBox(height: 3),
              Text(
                label,
                style: GoogleFonts.manrope(fontSize: 9, color: c),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ──
  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.manrope(
          fontSize: 9,
          color: _t.textSecondary.withOpacity(0.5),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
      );
}
