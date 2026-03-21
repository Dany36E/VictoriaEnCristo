import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/highlight.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bible_share_service.dart';
import '../../services/bible/recent_colors_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../screens/bible/template_picker_screen.dart';
import '../../screens/bible/verse_compare_screen.dart';
import '../../screens/wall/wall_composer_screen.dart';
import 'bible_action_grid.dart';
import 'concordance_sheet.dart';
import 'full_color_picker_sheet.dart';
import 'note_editor_sheet.dart';
import 'prayer_sheet.dart';
import 'verse_study_sheet.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// VERSE ACTIONS TOOLBAR — Rediseño 2 niveles
///
/// NIVEL 1: 4 acciones primarias (Subrayar, Guardar, Copiar, Más...)
/// NIVEL 2: Grid 3×3 de acciones secundarias (bottom sheet)
///
/// Filosofía: "Menos opciones visibles = más decisiones tomadas"
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
        height: BibleReaderThemeData.toolbarHeight,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: t.toolbarBg,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            top: BorderSide(
              color: t.textSecondary.withOpacity(0.1),
              width: 0.5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(t.isDark ? 0.3 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _showColors ? _buildColorPicker(t) : _buildPrimaryActions(t),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NIVEL 1 — 4 acciones primarias
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPrimaryActions(BibleReaderThemeData t) {
    final data = BibleUserDataService.I;
    final isSaved = data.isVerseSaved(
        widget.verse.bookNumber, widget.verse.chapter, widget.verse.verse);
    final hasHighlight =
        data.highlightsNotifier.value.containsKey(widget.verse.uniqueKey);
    final iconColor = t.isDark ? Colors.white70 : const Color(0xFF1A1A1A);
    final activeColor = t.accent;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Subrayar
        _ToolbarIcon(
          icon: Icons.format_paint_outlined,
          color: hasHighlight ? activeColor : iconColor,
          onTap: () => setState(() => _showColors = true),
        ),
        // 2. Guardar
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
        // 3. Copiar
        _ToolbarIcon(
          icon: Icons.content_copy_outlined,
          color: iconColor,
          onTap: () {
            Clipboard.setData(ClipboardData(
              text:
                  '${widget.verse.text}\n— ${widget.verse.reference} (${widget.verse.version})',
            ));
            _dismiss();
          },
        ),
        // 4. Más...
        _ToolbarIcon(
          icon: Icons.more_horiz,
          color: iconColor,
          onTap: () => _showSecondaryActions(context),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NIVEL 2 — Grid de acciones secundarias (bottom sheet)
  // ═══════════════════════════════════════════════════════════════════════

  void _showSecondaryActions(BuildContext context) {
    HapticFeedback.lightImpact();
    final t = widget.theme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BibleActionGrid(
        title: 'Acciones',
        theme: t,
        actions: [
          BibleAction(
            icon: Icons.share_outlined,
            label: 'Compartir',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              BibleShareService.shareAsText(widget.verse);
            },
          ),
          BibleAction(
            icon: Icons.edit_note,
            label: 'Nota',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => NoteEditorSheet(verse: widget.verse),
              );
            },
          ),
          BibleAction(
            icon: Icons.volunteer_activism,
            label: 'Oración',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => PrayerSheet(verse: widget.verse),
              );
            },
          ),
          BibleAction(
            icon: Icons.image_outlined,
            label: 'Imagen',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TemplatePickerScreen(verse: widget.verse),
                ),
              );
            },
          ),
          BibleAction(
            icon: Icons.compare_arrows,
            label: 'Comparar',
            onTap: () {
              Navigator.pop(context);
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
          BibleAction(
            icon: Icons.school_outlined,
            label: 'Estudio',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              VerseStudySheet.show(context, widget.verse);
            },
          ),
          BibleAction(
            icon: Icons.link,
            label: 'Referencias',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              VerseStudySheet.show(context, widget.verse, initialTab: 3);
            },
          ),
          BibleAction(
            icon: Icons.account_tree_outlined,
            label: 'Concordancia',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              final words = widget.verse.text.split(RegExp(r'\s+'));
              final word = words.firstWhere(
                (w) => w.length > 3,
                orElse: () => words.isNotEmpty ? words.first : '',
              );
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                isScrollControlled: true,
                builder: (_) => ConcordanceSheet(
                  initialWord: word,
                  version: BibleVersion.fromId(widget.verse.version),
                  theme: widget.theme,
                ),
              );
            },
          ),
          BibleAction(
            icon: Icons.campaign_outlined,
            label: 'Al Muro',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WallComposerScreen(
                    preloadedVerse: widget.verse,
                  ),
                ),
              );
            },
          ),
          BibleAction(
            icon: Icons.auto_stories_outlined,
            label: 'Comentario',
            onTap: () {
              Navigator.pop(context);
              _dismiss();
              VerseStudySheet.show(context, widget.verse, initialTab: 4);
            },
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // COLOR PICKER (inline, reemplaza acciones primarias)
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildColorPicker(BibleReaderThemeData t) {
    final data = BibleUserDataService.I;
    final currentHighlight =
        data.highlightsNotifier.value[widget.verse.uniqueKey];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ToolbarIcon(
          icon: Icons.arrow_back_ios_new,
          color: t.isDark ? Colors.white54 : Colors.black38,
          size: 16,
          onTap: () => setState(() => _showColors = false),
        ),
        ...HighlightColors.defaults.map((color) {
          final hex = HighlightColors.toHex(color);
          final isActive = currentHighlight?.colorHex == hex;
          return Semantics(
            label: 'Color de resaltado',
            button: true,
            selected: isActive,
            child: GestureDetector(
            onTap: () {
              RecentColorsService.I.addRecentColor(hex);
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
          ),
          );
        }),
        Semantics(
          label: 'Color personalizado',
          button: true,
          child: GestureDetector(
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
              final hex = HighlightColors.toHex(color);
              RecentColorsService.I.addRecentColor(hex);
              data.addHighlight(
                bookNumber: widget.verse.bookNumber,
                chapter: widget.verse.chapter,
                verse: widget.verse.verse,
                colorHex: hex,
              );
              _dismiss();
            }
          },
          child: Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
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
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(icon, color: color, size: size),
      ),
    );
  }
}
