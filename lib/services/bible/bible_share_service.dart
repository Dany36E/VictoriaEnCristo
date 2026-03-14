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
/// Compartir versículos como texto o imagen con 5 plantillas.
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

  /// Construir widget de plantilla para captura
  static Widget buildTemplate({
    required ShareTemplate template,
    required BibleVerse verse,
    double fontSize = 20.0,
  }) {
    switch (template) {
      case ShareTemplate.midnight:
        return _MidnightTemplate(verse: verse, fontSize: fontSize);
      case ShareTemplate.parchment:
        return _ParchmentTemplate(verse: verse, fontSize: fontSize);
      case ShareTemplate.sunrise:
        return _SunriseTemplate(verse: verse, fontSize: fontSize);
      case ShareTemplate.royal:
        return _RoyalTemplate(verse: verse, fontSize: fontSize);
      case ShareTemplate.minimal:
        return _MinimalTemplate(verse: verse, fontSize: fontSize);
    }
  }
}

/// 5 plantillas de compartir
enum ShareTemplate {
  midnight('Medianoche', Color(0xFF0D1B2A)),
  parchment('Pergamino', Color(0xFFF5EFE0)),
  sunrise('Amanecer', Color(0xFF1A237E)),
  royal('Real', Color(0xFF311B92)),
  minimal('Minimalista', Color(0xFFFFFFFF));

  final String displayName;
  final Color previewColor;
  const ShareTemplate(this.displayName, this.previewColor);
}

// ══════════════════════════════════════════════════════════════════════════
// PLANTILLA WIDGETS
// ══════════════════════════════════════════════════════════════════════════

class _MidnightTemplate extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;
  const _MidnightTemplate({required this.verse, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.format_quote, color: AppDesignSystem.gold, size: 32),
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            width: 40,
            height: 2,
            color: AppDesignSystem.gold,
          ),
          const SizedBox(height: 12),
          Text(
            '${verse.reference} (${verse.version})',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: AppDesignSystem.gold,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'VICTORIA EN CRISTO',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 8,
              letterSpacing: 4.0,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParchmentTemplate extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;
  const _ParchmentTemplate({required this.verse, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFBF5), Color(0xFFF5EFE0)],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
            textAlign: TextAlign.center,
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
          Text(
            verse.version,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              color: AppDesignSystem.midnight.withOpacity(0.5),
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SunriseTemplate extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;
  const _SunriseTemplate({required this.verse, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFFFF8F00)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_outlined, color: Color(0xFFFFD54F), size: 28),
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
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            '— ${verse.reference} (${verse.version})',
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: Color(0xFFFFD54F),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoyalTemplate extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;
  const _RoyalTemplate({required this.verse, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF311B92), Color(0xFF4A148C)],
        ),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 30, height: 1, color: AppDesignSystem.gold),
              const SizedBox(width: 8),
              const Icon(Icons.auto_awesome, color: AppDesignSystem.gold, size: 16),
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
            textAlign: TextAlign.center,
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
          Text(
            verse.version,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10,
              letterSpacing: 3.0,
              color: Colors.white.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalTemplate extends StatelessWidget {
  final BibleVerse verse;
  final double fontSize;
  const _MinimalTemplate({required this.verse, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(32),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 3,
            color: AppDesignSystem.midnight,
          ),
          const SizedBox(height: 20),
          Text(
            verse.text,
            style: TextStyle(
              fontFamily: 'CrimsonPro',
              fontSize: fontSize,
              color: AppDesignSystem.midnight,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${verse.reference} · ${verse.version}',
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppDesignSystem.midnight.withOpacity(0.5),
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
