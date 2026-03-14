import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/highlight.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_share_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../screens/bible/template_picker_screen.dart';
import '../../screens/bible/verse_compare_screen.dart';
import 'full_color_picker_sheet.dart';
import 'note_editor_sheet.dart';
import 'prayer_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// VERSE ACTIONS TOOLBAR
/// Toolbar flotante minimalista que aparece al seleccionar un versículo.
/// Sin cards, sin fondo pesado. Solo íconos pequeños en 44dp de alto.
/// Al tocar subrayar, muta en fila de color swatches inline.
/// ═══════════════════════════════════════════════════════════════════════════
class VerseActionsToolbar extends StatefulWidget {
  final BibleVerse verse;
  final BibleReaderThemeData theme;
  final VoidCallback onDismiss;

  const VerseActionsToolbar({
    super.key,
    required this.verse,
    required this.theme,
    required this.onDismiss,
  });

  @override
  State<VerseActionsToolbar> createState() => _VerseActionsToolbarState();
}

class _VerseActionsToolbarState extends State<VerseActionsToolbar>
    with SingleTickerProviderStateMixin {
  bool _showColors = false;
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  void _dismiss() {
    _fadeCtrl.reverse().then((_) => widget.onDismiss());
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: t.toolbarBg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(t.isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _showColors ? _buildColorPicker(t) : _buildActions(t),
      ),
    );
  }

  Widget _buildActions(BibleReaderThemeData t) {
    final data = BibleUserDataService.I;
    final isSaved = data.isVerseSaved(
        widget.verse.bookNumber, widget.verse.chapter, widget.verse.verse);
    final hasNote = data.notesNotifier.value.containsKey(widget.verse.uniqueKey);
    final hasPrayer = data.prayersNotifier.value.containsKey(widget.verse.uniqueKey);
    final hasHighlight = data.highlightsNotifier.value.containsKey(widget.verse.uniqueKey);
    final iconColor = t.isDark ? Colors.white70 : const Color(0xFF1A1A1A);
    final activeColor = t.accent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Subrayar
        _ToolbarIcon(
          icon: Icons.format_paint,
          color: hasHighlight ? activeColor : iconColor,
          onTap: () => setState(() => _showColors = true),
        ),
        // Guardar
        _ToolbarIcon(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
          color: isSaved ? activeColor : iconColor,
          onTap: () {
            data.toggleSavedVerse(
              bookNumber: widget.verse.bookNumber,
              chapter: widget.verse.chapter,
              verse: widget.verse.verse,
              bookName: widget.verse.bookName,
              text: widget.verse.text,
              version: widget.verse.version,
            );
            _dismiss();
          },
        ),
        // Copiar
        _ToolbarIcon(
          icon: Icons.content_copy,
          color: iconColor,
          onTap: () {
            Clipboard.setData(ClipboardData(
              text: '${widget.verse.text}\n— ${widget.verse.reference} (${widget.verse.version})',
            ));
            _dismiss();
          },
        ),
        // Compartir texto
        _ToolbarIcon(
          icon: Icons.share,
          color: iconColor,
          onTap: () {
            _dismiss();
            BibleShareService.shareAsText(widget.verse);
          },
        ),
        // Nota
        _ToolbarIcon(
          icon: Icons.edit_note,
          color: hasNote ? activeColor : iconColor,
          onTap: () {
            _dismiss();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => NoteEditorSheet(verse: widget.verse),
            );
          },
        ),
        // Oración
        _ToolbarIcon(
          icon: Icons.volunteer_activism,
          color: hasPrayer ? activeColor : iconColor,
          onTap: () {
            _dismiss();
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              isScrollControlled: true,
              builder: (_) => PrayerSheet(verse: widget.verse),
            );
          },
        ),
        // Comparar
        _ToolbarIcon(
          icon: Icons.compare_arrows,
          color: iconColor,
          onTap: () {
            _dismiss();
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
          },
        ),
        // Imagen
        _ToolbarIcon(
          icon: Icons.image_outlined,
          color: iconColor,
          onTap: () {
            _dismiss();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TemplatePickerScreen(verse: widget.verse),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildColorPicker(BibleReaderThemeData t) {
    final data = BibleUserDataService.I;
    final currentHighlight = data.highlightsNotifier.value[widget.verse.uniqueKey];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Back arrow
        _ToolbarIcon(
          icon: Icons.arrow_back_ios_new,
          color: t.isDark ? Colors.white54 : Colors.black38,
          size: 16,
          onTap: () => setState(() => _showColors = false),
        ),
        // 6 color swatches
        ...HighlightColors.defaults.map((color) {
          final hex = HighlightColors.toHex(color);
          final isActive = currentHighlight?.colorHex == hex;
          return GestureDetector(
            onTap: () {
              data.addHighlight(
                bookNumber: widget.verse.bookNumber,
                chapter: widget.verse.chapter,
                verse: widget.verse.verse,
                colorHex: hex,
              );
              _dismiss();
            },
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isActive
                    ? Border.all(color: t.accent, width: 2)
                    : null,
              ),
            ),
          );
        }),
        // Custom color button
        GestureDetector(
          onTap: () async {
            final color = await showModalBottomSheet<Color>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (_) => FullColorPickerSheet(
                initialColor: currentHighlight?.color,
                theme: t,
              ),
            );
            if (color != null) {
              data.addHighlight(
                bookNumber: widget.verse.bookNumber,
                chapter: widget.verse.chapter,
                verse: widget.verse.verse,
                colorHex: HighlightColors.toHex(color),
              );
              _dismiss();
            }
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const SweepGradient(
                colors: [
                  Color(0xFFFF0000),
                  Color(0xFFFFFF00),
                  Color(0xFF00FF00),
                  Color(0xFF00FFFF),
                  Color(0xFF0000FF),
                  Color(0xFFFF00FF),
                  Color(0xFFFF0000),
                ],
              ),
            ),
          ),
        ),
        // Remove highlight
        if (currentHighlight != null)
          _ToolbarIcon(
            icon: Icons.close,
            color: t.isDark ? Colors.white38 : Colors.black26,
            size: 18,
            onTap: () {
              data.removeHighlight(
                widget.verse.bookNumber,
                widget.verse.chapter,
                widget.verse.verse,
              );
              _dismiss();
            },
          ),
      ],
    );
  }
}

class _ToolbarIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final double size;

  const _ToolbarIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
