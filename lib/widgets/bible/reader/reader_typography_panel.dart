import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../theme/bible_reader_theme.dart';

class ReaderTypographyPanel extends StatelessWidget {
  final BibleReaderThemeData theme;
  final VoidCallback onClose;

  const ReaderTypographyPanel({
    super.key,
    required this.theme,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Positioned(
      top: 44,
      left: 0,
      right: 0,
      child: GestureDetector(
        onVerticalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0) < -200) onClose();
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
          decoration: BoxDecoration(
            color: t.surface.withOpacity(0.98),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(t.isDark ? 0.3 : 0.05),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TIPOGRAFÍA',
                    style: GoogleFonts.manrope(
                      color: t.textSecondary.withOpacity(0.5),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child:
                          Icon(Icons.close, color: t.textSecondary, size: 20),
                    ),
                  ),
                ],
              ),
              ValueListenableBuilder<double>(
                valueListenable: BibleUserDataService.I.fontSizeNotifier,
                builder: (context, size, _) {
                  return Row(
                    children: [
                      Text('A',
                          style: GoogleFonts.lora(
                              color: t.textSecondary, fontSize: 14)),
                      Expanded(
                        child: Semantics(
                          label: 'Tamaño de fuente',
                          value: '${size.toInt()} puntos',
                          child: Slider(
                            value: size,
                            min: 14,
                            max: 28,
                            divisions: 7,
                            activeColor: t.accent,
                            inactiveColor: t.textSecondary.withOpacity(0.2),
                            onChanged: (v) =>
                                BibleUserDataService.I.setFontSize(v),
                          ),
                        ),
                      ),
                      Text('A',
                          style: GoogleFonts.lora(
                              color: t.textSecondary, fontSize: 26)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder<String>(
                valueListenable: BibleUserDataService.I.readerThemeNotifier,
                builder: (context, currentId, _) {
                  final migrated = BibleReaderThemeData.migrateId(currentId);
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: BibleReaderThemeData.all.map((theme) {
                      final isActive = theme.id == migrated;
                      return Semantics(
                        label: 'Tema ${theme.name}',
                        button: true,
                        selected: isActive,
                        child: GestureDetector(
                          onTap: () => BibleUserDataService.I
                              .setReaderTheme(theme.id),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: theme.swatchColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive
                                    ? t.accent
                                    : t.textSecondary.withOpacity(0.2),
                                width: isActive ? 2.5 : 1,
                              ),
                            ),
                            child: isActive
                                ? Icon(Icons.check,
                                    color: theme.isDark
                                        ? Colors.white70
                                        : Colors.black54,
                                    size: 14)
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
