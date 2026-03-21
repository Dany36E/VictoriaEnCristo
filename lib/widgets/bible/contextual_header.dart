import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';

/// Acción contextual para el panel desplegable del header.
class ContextualAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const ContextualAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });
}

/// Ítem del menú "más opciones" (···).
class MoreMenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const MoreMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Header contextual para BibleReaderScreen.
///
/// Estado reposo: ← | título (centrado) | ···
/// Al tap en ···: panel desplegable con contextualActions + PopupMenu de moreActions.
class ContextualHeader extends StatefulWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onTitleTap;
  final List<ContextualAction> contextualActions;
  final List<MoreMenuItem> moreActions;
  final BibleReaderThemeData theme;

  const ContextualHeader({
    super.key,
    required this.title,
    required this.onBack,
    required this.onTitleTap,
    required this.contextualActions,
    required this.moreActions,
    required this.theme,
  });

  @override
  State<ContextualHeader> createState() => _ContextualHeaderState();
}

class _ContextualHeaderState extends State<ContextualHeader>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _animCtrl;
  late Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animCtrl.forward();
    } else {
      _animCtrl.reverse();
    }
  }

  void collapse() {
    if (_expanded) {
      setState(() => _expanded = false);
      _animCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main header row: ← | title | ···
        Container(
          height: BibleReaderThemeData.toolbarHeight,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          color: t.background.withOpacity(0.95),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios,
                    color: t.textSecondary, size: 18),
                onPressed: widget.onBack,
                tooltip: 'Volver',
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: Semantics(
                  label: widget.title,
                  button: true,
                  hint: 'Toca para cambiar libro o capítulo',
                  child: GestureDetector(
                    onTap: widget.onTitleTap,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: Text(
                        widget.title,
                        key: ValueKey(widget.title),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          color: t.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _buildMoreButton(t),
            ],
          ),
        ),
        // Expandable panel
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1.0,
          child: Container(
            height: BibleReaderThemeData.toolbarHeight,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: t.surface.withOpacity(0.98),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.contextualActions.map((action) {
                return _ContextualActionButton(
                  action: action,
                  theme: t,
                  onCollapse: collapse,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMoreButton(BibleReaderThemeData t) {
    return PopupMenuButton<int>(
      icon: Icon(Icons.more_horiz,
          color: t.textSecondary.withOpacity(0.6), size: 20),
      color: t.surface,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusM),
      ),
      onSelected: (index) {
        if (index == -1) {
          _toggle();
        } else if (index >= 0 && index < widget.moreActions.length) {
          widget.moreActions[index].onTap();
        }
      },
      itemBuilder: (context) {
        final items = <PopupMenuEntry<int>>[
          PopupMenuItem<int>(
            value: -1,
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.tune,
                  color: t.textSecondary,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Text(
                  _expanded ? 'Ocultar panel' : 'Herramientas',
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ];
        if (widget.moreActions.isNotEmpty) {
          items.add(const PopupMenuDivider(height: 1));
        }
        for (int i = 0; i < widget.moreActions.length; i++) {
          final action = widget.moreActions[i];
          items.add(PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                Icon(action.icon, color: t.textSecondary, size: 18),
                const SizedBox(width: 12),
                Text(
                  action.label,
                  style: GoogleFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ));
        }
        return items;
      },
    );
  }
}

class _ContextualActionButton extends StatelessWidget {
  final ContextualAction action;
  final BibleReaderThemeData theme;
  final VoidCallback onCollapse;

  const _ContextualActionButton({
    required this.action,
    required this.theme,
    required this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: action.label,
      button: true,
      toggled: action.isActive,
      child: GestureDetector(
      onTap: () {
        onCollapse();
        action.onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              action.icon,
              color: action.isActive ? theme.accent : theme.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              action.label,
              style: GoogleFonts.manrope(
                color: action.isActive
                    ? theme.accent
                    : theme.textSecondary.withOpacity(0.6),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }
}
