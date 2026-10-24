import 'package:flutter/material.dart';

import '../../../models/bible/bible_version.dart';
import '../../../theme/app_fonts.dart';
import '../../../theme/bible_reader_theme.dart';

/// Línea de derechos de autor al final de cada capítulo. Al tocarla se abre
/// la ficha de la versión.
class ReaderCopyrightFooter extends StatelessWidget {
  final BibleVersion version;
  final BibleReaderThemeData theme;

  const ReaderCopyrightFooter({
    super.key,
    required this.version,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Semantics(
      button: true,
      label: 'Derechos de autor de ${version.displayName}. Ver detalles.',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => showVersionInfoSheet(context, version, t),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
            child: Text(
              version.copyright,
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                color: t.textoTenue(0.55),
                fontSize: 11,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ficha de la versión: nombre, abreviatura y aviso de derechos de autor.
Future<void> showVersionInfoSheet(
  BuildContext context,
  BibleVersion version,
  BibleReaderThemeData t,
) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: t.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'ACERCA DE ESTA VERSIÓN',
              style: AppFonts.manrope(
                color: t.textoTenue(0.6),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${version.displayName} (${version.shareAbbreviation})',
              style: AppFonts.lora(
                color: t.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              version.copyright,
              style: AppFonts.manrope(
                color: t.textPrimary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Al compartir un versículo se incluye la abreviatura '
              '${version.shareAbbreviation} para identificar la traducción.',
              style: AppFonts.manrope(
                color: t.textoTenue(0.7),
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
