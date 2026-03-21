import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/bible_reader_theme.dart';

/// Modelo de una acción para el grid.
class BibleAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const BibleAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// Grid reutilizable de acciones para bottom sheets y secciones colapsables.
/// Diseño: ícono 24dp + label 11sp, sin bordes, ripple dorado.
class BibleActionGrid extends StatelessWidget {
  final String? title;
  final List<BibleAction> actions;
  final int columns;
  final BibleReaderThemeData theme;

  const BibleActionGrid({
    super.key,
    this.title,
    required this.actions,
    this.columns = 3,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Handle bar
          Center(
            child: Container(
              width: 36,
              height: 2,
              decoration: BoxDecoration(
                color: t.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 14),
            Text(
              title!.toUpperCase(),
              style: GoogleFonts.manrope(
                color: t.textSecondary.withOpacity(0.5),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 8,
            childAspectRatio: 1.3,
            children: actions.map((action) {
              return _ActionCell(action: action, theme: t);
            }).toList(),
          ),
          ],
        ),
      ),
    );
  }
}

class _ActionCell extends StatelessWidget {
  final BibleAction action;
  final BibleReaderThemeData theme;

  const _ActionCell({required this.action, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Semantics(
        label: action.label,
        button: true,
        child: InkWell(
        borderRadius: BorderRadius.circular(BibleReaderThemeData.radiusS),
        splashColor: theme.accent.withOpacity(0.10),
        highlightColor: theme.accent.withOpacity(0.05),
        onTap: () {
          HapticFeedback.lightImpact();
          action.onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(action.icon, color: theme.textPrimary, size: 22),
            const SizedBox(height: 4),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: theme.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
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
}
