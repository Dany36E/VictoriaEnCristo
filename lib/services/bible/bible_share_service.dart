import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../models/bible/bible_verse.dart';
import '../../theme/app_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE SHARE SERVICE
/// Compartir versículos como texto o imagen con 7 plantillas premium.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleShareService {
  BibleShareService._();

  /// Compartir como texto plano
  static Future<void> shareAsText(BibleVerse verse) async {
    final text = '"${verse.text}"\n— ${verse.reference} (${verse.version})';
    await Share.share(text);
  }

  /// Compartir como imagen usando un GlobalKey del widget renderizado
  static Future<void> shareAsImage(GlobalKey repaintKey) async {
    try {
      final boundary = repaintKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/victoria_verse.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Victoria en Cristo',
      );
    } catch (e) {
      debugPrint('📖 [SHARE] Error sharing image: $e');
    }
  }

  /// Calcula el fontSize adaptativo según longitud del texto y tamaño
  static double adaptiveFontSize(String text, ShareDimension dim) {
    final len = text.length;
    final base = dim == ShareDimension.square
        ? 20.0
        : dim == ShareDimension.story
            ? 22.0
            : 18.0;
    if (len > 300) return base - 6;
    if (len > 150) return base - 3;
    return base;
  }

  /// Dimensiones de la imagen
  static Size dimensionSize(ShareDimension dim) {
    switch (dim) {
      case ShareDimension.square:
        return const Size(400, 400);
      case ShareDimension.story:
        return const Size(360, 640);
      case ShareDimension.landscape:
        return const Size(640, 360);
    }
  }

  /// Construir widget de plantilla para captura
  static Widget buildTemplate({
    required ShareTemplate template,
    required BibleVerse verse,
    ShareDimension dimension = ShareDimension.square,
    bool showLogo = true,
    bool showVersion = true,
    TextAlign textAlign = TextAlign.center,
  }) {
    final size = dimensionSize(dimension);
    final fontSize = adaptiveFontSize(verse.text, dimension);

    return SizedBox(
      width: size.width,
      height: size.height,
      child: _TemplateWidget(
        template: template,
        verse: verse,
        fontSize: fontSize,
        showLogo: showLogo,
        showVersion: showVersion,
        textAlign: textAlign,
      ),
    );
  }
}

/// 7 plantillas de compartir
enum ShareTemplate {
  minimalDark('Minimalista Oscuro', Color(0xFF111111)),
  editorialLight('Editorial Claro', Color(0xFFFAF8F3)),
  parchment('Pergamino', Color(0xFFF5EFE0)),
  midnight('Medianoche', Color(0xFF0D1B2A)),
  sepiaWarm('Sepia Cálido', Color(0xFF3E2B1C)),
  pastelLavender('Pastel Lavanda', Color(0xFFE8DEF8)),
  royal('Real', Color(0xFF311B92));

  final String displayName;
  final Color previewColor;
  const ShareTemplate(this.displayName, this.previewColor);

  bool get isDark =>
      this == minimalDark ||
      this == midnight ||
      this == sepiaWarm ||
      this == royal;
}

/// Dimensiones de imagen
enum ShareDimension {
  square('1:1'),
  story('9:16'),
  landscape('16:9');

  final String label;
  const ShareDimension(this.label);
}

// ══════════════════════════════════════════════════════════════════════════
// UNIFIED TEMPLATE WIDGET
// ══════════════════════════════════════════════════════════════════════════

class _TemplateWidget extends StatelessWidget {
  final ShareTemplate template;
  final BibleVerse verse;
  final double fontSize;
  final bool showLogo;
  final bool showVersion;
  final TextAlign textAlign;

  const _TemplateWidget({
    required this.template,
    required this.verse,
    required this.fontSize,
    required this.showLogo,
    required this.showVersion,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    switch (template) {
      case ShareTemplate.minimalDark:
        return _buildMinimalDark();
      case ShareTemplate.editorialLight:
        return _buildEditorialLight();
      case ShareTemplate.parchment:
        return _buildParchment();
      case ShareTemplate.midnight:
        return _buildMidnight();
      case ShareTemplate.sepiaWarm:
        return _buildSepiaWarm();
      case ShareTemplate.pastelLavender:
        return _buildPastelLavender();
      case ShareTemplate.royal:
        return _buildRoyal();
    }
  }

  Widget _wrapContainer({
    required BoxDecoration decoration,
    required List<Widget> children,
  }) {
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: textAlign == TextAlign.left
            ? CrossAxisAlignment.start
            : textAlign == TextAlign.right
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
        children: children,
      ),
    );
  }

  Widget _buildLogoText(Color color) {
    if (!showLogo) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Text(
        'VICTORIA EN CRISTO',
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 8,
          letterSpacing: 4.0,
          color: color,
        ),
      ),
    );
  }

  Widget _buildVersionText(Color color) {
    if (!showVersion) return const SizedBox.shrink();
    return Text(
      verse.version,
      style: TextStyle(
        fontFamily: 'Manrope',
        fontSize: 10,
        letterSpacing: 2.0,
        color: color,
      ),
    );
  }

  // ── 1. Minimalista Oscuro ──
  Widget _buildMinimalDark() {
    return _wrapContainer(
      decoration: const BoxDecoration(color: Color(0xFF111111)),
      children: [
        Container(
          width: 24,
          height: 2,
          color: Colors.white24,
        ),
        const SizedBox(height: 20),
        Text(
          verse.text,
          style: TextStyle(
            fontFamily: 'CrimsonPro',
            fontSize: fontSize,
            color: Colors.white,
            height: 1.7,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 16),
        Text(
          verse.reference,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white38,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        _buildVersionText(Colors.white24),
        _buildLogoText(Colors.white12),
      ],
    );
  }

  // ── 2. Editorial Claro ──
  Widget _buildEditorialLight() {
    const textColor = Color(0xFF1A1A1A);
    return _wrapContainer(
      decoration: const BoxDecoration(color: Color(0xFFFAF8F3)),
      children: [
        Text(
          '✦',
          style: TextStyle(
            fontSize: 18,
            color: AppDesignSystem.goldDark,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          verse.text,
          style: TextStyle(
            fontFamily: 'CrimsonPro',
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            color: textColor,
            height: 1.7,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 20),
        Text(
          verse.reference,
          style: const TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: textColor,
          ),
        ),
        const SizedBox(height: 4),
        _buildVersionText(textColor.withOpacity(0.4)),
        _buildLogoText(textColor.withOpacity(0.2)),
      ],
    );
  }

  // ── 3. Pergamino ──
  Widget _buildParchment() {
    return _wrapContainer(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBF5), Color(0xFFF5EFE0)],
        ),
      ),
      children: [
        Text(
          '✦',
          style: TextStyle(fontSize: 24, color: AppDesignSystem.goldDark),
        ),
        const SizedBox(height: 16),
        Text(
          verse.text,
          style: TextStyle(
            fontFamily: 'CrimsonPro',
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            color: AppDesignSystem.midnight,
            height: 1.7,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 20),
        Text(
          verse.reference,
          style: const TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppDesignSystem.midnight,
            letterSpacing: 1.5,
          ),
        ),
        _buildVersionText(AppDesignSystem.midnight.withOpacity(0.5)),
        _buildLogoText(AppDesignSystem.midnight.withOpacity(0.15)),
      ],
    );
  }

  // ── 4. Medianoche ──
  Widget _buildMidnight() {
    return _wrapContainer(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
        ),
      ),
      children: [
        const Icon(Icons.format_quote,
            color: AppDesignSystem.gold, size: 32),
        const SizedBox(height: 16),
        Text(
          verse.text,
          style: TextStyle(
            fontFamily: 'CrimsonPro',
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            height: 1.7,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 20),
        Container(width: 40, height: 2, color: AppDesignSystem.gold),
        const SizedBox(height: 12),
        Text(
          verse.reference,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: AppDesignSystem.gold,
          ),
        ),
        const SizedBox(height: 4),
        _buildVersionText(Colors.white30),
        _buildLogoText(Colors.white.withOpacity(0.15)),
      ],
    );
  }

  // ── 5. Sepia Cálido ──
  Widget _buildSepiaWarm() {
    const warm = Color(0xFFF5E6C8);
    return _wrapContainer(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3E2B1C), Color(0xFF2A1A0E)],
        ),
      ),
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 1, color: warm.withOpacity(0.4)),
            const SizedBox(width: 8),
            Text('✝', style: TextStyle(color: warm, fontSize: 16)),
            const SizedBox(width: 8),
            Container(width: 30, height: 1, color: warm.withOpacity(0.4)),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          verse.text,
          style: TextStyle(
            fontFamily: 'CrimsonPro',
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            color: warm,
            height: 1.7,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 20),
        Text(
          verse.reference,
          style: TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: warm.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 4),
        _buildVersionText(warm.withOpacity(0.4)),
        _buildLogoText(warm.withOpacity(0.2)),
      ],
    );
  }

  // ── 6. Pastel Lavanda ──
  Widget _buildPastelLavender() {
    const textColor = Color(0xFF2E1065);
    return _wrapContainer(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF3E8FF), Color(0xFFE8DEF8)],
        ),
      ),
      children: [
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: textColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          verse.text,
          style: TextStyle(
            fontFamily: 'CrimsonPro',
            fontSize: fontSize,
            color: textColor,
            height: 1.7,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 20),
        Text(
          verse.reference,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: textColor.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 4),
        _buildVersionText(textColor.withOpacity(0.35)),
        _buildLogoText(textColor.withOpacity(0.15)),
      ],
    );
  }

  // ── 7. Real ──
  Widget _buildRoyal() {
    return _wrapContainer(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF311B92), Color(0xFF4A148C)],
        ),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
      ),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 1, color: AppDesignSystem.gold),
            const SizedBox(width: 8),
            const Icon(Icons.auto_awesome,
                color: AppDesignSystem.gold, size: 16),
            const SizedBox(width: 8),
            Container(width: 30, height: 1, color: AppDesignSystem.gold),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          verse.text,
          style: TextStyle(
            fontFamily: 'CrimsonPro',
            fontSize: fontSize,
            fontStyle: FontStyle.italic,
            color: Colors.white,
            height: 1.7,
          ),
          textAlign: textAlign,
        ),
        const SizedBox(height: 20),
        Text(
          verse.reference,
          style: const TextStyle(
            fontFamily: 'Cinzel',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 2.0,
            color: AppDesignSystem.goldLight,
          ),
        ),
        const SizedBox(height: 4),
        _buildVersionText(Colors.white30),
        _buildLogoText(Colors.white.withOpacity(0.2)),
      ],
    );
  }
}
