import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/theme_service.dart';
import '../../../theme/app_fonts.dart';
import '../../../theme/app_theme_data.dart';
import '../../../theme/bible_reader_theme.dart';
import '../../../vec/vec_tema.dart';

/// Elige la letra para leer versículos y apuntes en el tema papel: Lora
/// (por defecto) o la manuscrita del kit. En los demás temas no se muestra.
class SelectorLetraLectura extends StatelessWidget {
  final BibleReaderThemeData theme;

  const SelectorLetraLectura({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    if (!AppThemeData.of(context).isPaper) return const SizedBox.shrink();
    final t = theme;
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeService().lecturaManuscrita,
      builder: (context, manuscrita, _) {
        Widget opcion({
          required String nombre,
          required TextStyle estilo,
          required bool activa,
          required bool valor,
        }) {
          return Expanded(
            child: Semantics(
              button: true,
              selected: activa,
              label: 'Letra para leer: $nombre',
              child: Material(
                color: activa
                    ? t.accent.withValues(alpha: 0.16)
                    : t.textSecondary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ThemeService().setLecturaManuscrita(valor);
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: activa
                            ? t.accent
                            : t.textSecondary.withValues(alpha: 0.18),
                        width: activa ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: estilo.copyWith(color: t.textPrimary),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'LETRA PARA LEER',
              style: AppFonts.manrope(
                color: t.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                opcion(
                  nombre: 'Lora',
                  estilo: GoogleFonts.getFont('Lora', fontSize: 17),
                  activa: !manuscrita,
                  valor: false,
                ),
                const SizedBox(width: 10),
                opcion(
                  nombre: 'Manuscrita',
                  estilo: const TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 19,
                  ),
                  activa: manuscrita,
                  valor: true,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
