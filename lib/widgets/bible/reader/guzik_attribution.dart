import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/bible/enduring_word_service.dart';
import '../../../theme/app_fonts.dart';
import '../../../theme/bible_reader_theme.dart';

/// Atribución del comentario de David Guzik (Enduring Word). Única fuente
/// del texto: se usa en el modo estudio del lector, en la pantalla de
/// Enduring Word, en Ajustes y al compartir.
class GuzikAttribution {
  GuzikAttribution._();

  static const String text =
      'Comentario de David Guzik · © Enduring Word · '
      'Traducción al español de Enduring Word · enduringword.com';

  static const String url = 'https://es.enduringword.com/';

  static Future<void> openSite() =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  /// Texto para compartir UNA sección (no el capítulo completo), con la
  /// atribución y el enlace al final.
  static String shareTextFor(String reference, EWSection section) {
    final sb = StringBuffer();
    if (section.heading.trim().isNotEmpty) {
      sb.writeln(section.heading.trim());
      sb.writeln();
    }
    for (final p in section.paragraphs) {
      final t = p.trim();
      if (t.isEmpty) continue;
      sb.writeln(t);
      sb.writeln();
    }
    sb.writeln('— $reference');
    sb.writeln(text);
    sb.write(url);
    return sb.toString();
  }

  static Future<void> shareSection(String reference, EWSection section) =>
      Share.share(
        shareTextFor(reference, section),
        subject: 'Comentario de David Guzik · $reference',
      );
}

/// Tarjeta con la atribución y enlace a enduringword.com.
class GuzikAttributionCard extends StatelessWidget {
  final BibleReaderThemeData theme;
  const GuzikAttributionCard({super.key, required this.theme});

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Semantics(
        link: true,
        label: '${GuzikAttribution.text}. Abrir enduringword.com',
        excludeSemantics: true,
        child: InkWell(
          onTap: GuzikAttribution.openSite,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: t.oscuro
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: t.accent.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    GuzikAttribution.text,
                    textAlign: TextAlign.center,
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.6),
                      fontSize: 11,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.open_in_new, size: 16, color: t.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
