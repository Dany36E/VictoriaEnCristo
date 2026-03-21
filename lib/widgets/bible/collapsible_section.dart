import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/bible_reader_theme.dart';

/// Sección colapsable reutilizable con persistencia opcional.
/// Usa AnimatedSize para transición suave al expandir/colapsar.
class CollapsibleSection extends StatefulWidget {
  final String title;
  final bool initiallyExpanded;
  final String? persistKey;
  final Widget child;
  final BibleReaderThemeData theme;

  const CollapsibleSection({
    super.key,
    required this.title,
    this.initiallyExpanded = false,
    this.persistKey,
    required this.child,
    required this.theme,
  });

  @override
  State<CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<CollapsibleSection>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _iconCtrl;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _iconCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _expanded ? 1.0 : 0.0,
    );
    if (widget.persistKey != null) _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(widget.persistKey!);
    if (saved != null && mounted) {
      setState(() => _expanded = saved);
      if (_expanded) _iconCtrl.forward();
    }
  }

  Future<void> _saveState() async {
    if (widget.persistKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(widget.persistKey!, _expanded);
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _iconCtrl.forward();
    } else {
      _iconCtrl.reverse();
    }
    _saveState();
  }

  @override
  void dispose() {
    _iconCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.6),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                RotationTransition(
                  turns: Tween(begin: 0.0, end: 0.5).animate(
                    CurvedAnimation(parent: _iconCtrl, curve: Curves.easeOut),
                  ),
                  child: Icon(
                    Icons.expand_more,
                    color: t.textSecondary.withOpacity(0.4),
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _expanded
              ? widget.child
              : const SizedBox(width: double.infinity, height: 0),
        ),
      ],
    );
  }
}
