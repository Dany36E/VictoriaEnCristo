import 'package:flutter/material.dart';
import '../../../theme/app_fonts.dart';
import '../../../services/bible/bible_user_data_service.dart';
import '../../../theme/bible_reader_theme.dart';
import 'selector_letra_lectura.dart';
import '../../selector_modo_papel.dart';

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
            color: t.surface.withValues(alpha: 0.98),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
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
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.5),
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
                          style: AppFonts.lora(
                              color: t.textSecondary, fontSize: 14)),
                      Expanded(
                        child: Semantics(
                          label: 'Tamaño de fuente',
                          value: '${size.toInt()} puntos',
                          child: Slider(
                            value: size.clamp(
                              BibleUserDataService.minFontSize,
                              BibleUserDataService.maxFontSize,
                            ),
                            min: BibleUserDataService.minFontSize,
                            max: BibleUserDataService.maxFontSize,
                            divisions: BibleUserDataService.fontSizeDivisions,
                            activeColor: t.accent,
                            inactiveColor: t.textSecondary.withValues(alpha: 0.2),
                            onChanged: (v) =>
                                BibleUserDataService.I.setFontSize(v),
                          ),
                        ),
                      ),
                      Text('A',
                          style: AppFonts.lora(
                              color: t.textSecondary, fontSize: 26)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              SelectorLetraLectura(theme: t),
              const SizedBox(height: 16),
              // Claro, oscuro o automático: el lector va en el papel de la app.
              const SelectorModoPapel(),
            ],
          ),
        ),
      ),
    );
  }
}
