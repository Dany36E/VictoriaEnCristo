import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/bible/share_template.dart';
import '../../utils/verse_keyword_extractor.dart';

/// Renderiza la tarjeta de versículo para captura como imagen.
/// Flutter dibuja TODO el texto nativo (100% nítido, sin errores).
/// El fondo es un asset PNG estático pregenerado.
class ShareCardRenderer extends StatelessWidget {
  final ShareCardTemplate template;
  final String verseText;
  final String reference;
  final String version;
  final double customFontSize;
  final bool showLogo;
  final TextAlign textAlign;
  final Size cardSize;

  const ShareCardRenderer({
    super.key,
    required this.template,
    required this.verseText,
    required this.reference,
    this.version = '',
    this.customFontSize = 0,
    this.showLogo = true,
    this.textAlign = TextAlign.center,
    this.cardSize = const Size(1080, 1080),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: cardSize.width,
      height: cardSize.height,
      child: Stack(
        children: [
          // CAPA 1: Fondo (asset PNG pregenerado)
          if (template.backgroundAsset != null)
            Positioned.fill(
              child: Image.asset(
                template.backgroundAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => CustomPaint(
                  size: cardSize,
                  painter: _FallbackBackgroundPainter(isDark: template.isDark),
                ),
              ),
            )
          else
            Positioned.fill(
              child: CustomPaint(
                size: cardSize,
                painter: _FallbackBackgroundPainter(isDark: template.isDark),
              ),
            ),

          // CAPA 2: Overlay sutil para legibilidad
          if (template.isDark)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      Colors.black.withOpacity(0.05),
                      Colors.black.withOpacity(0.35),
                    ],
                  ),
                ),
              ),
            ),

          // CAPA 3: TEXTO (renderizado por Flutter, 100% nítido)
          _buildTextLayer(),

          // CAPA 4: Marca de agua discreta
          if (showLogo)
            Positioned(
              bottom: _scale(32),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'VICTORIA EN CRISTO',
                  style: TextStyle(
                    fontSize: _scale(18),
                    color: template.textStyle.appNameColor,
                    fontFamily: 'Manrope',
                    letterSpacing: _scale(3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextLayer() {
    switch (template.layout) {
      case ShareLayout.centered:
        return _buildCenteredLayout();
      case ShareLayout.bottom:
        return _buildBottomLayout();
      case ShareLayout.topLeft:
        return _buildTopLeftLayout();
      case ShareLayout.keyword:
        return _buildKeywordLayout();
      case ShareLayout.circular:
        return _buildCircularLayout();
    }
  }

  Widget _buildCenteredLayout() {
    final ts = template.textStyle;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _scale(80),
        vertical: _scale(100),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: _crossAxis(),
        children: [
          // Comillas decorativas
          Text(
            '\u201C',
            style: TextStyle(
              fontSize: _scale(72),
              color: ts.referenceColor.withOpacity(0.35),
              fontFamily: 'Georgia',
              height: 0.6,
            ),
          ),
          SizedBox(height: _scale(16)),
          // VERSÍCULO
          Text(
            verseText,
            style: _verseStyle(ts),
            textAlign: textAlign,
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _scale(24)),
          // Línea decorativa
          Container(
            width: _scale(48),
            height: _scale(1.5),
            color: ts.referenceColor.withOpacity(0.5),
          ),
          SizedBox(height: _scale(12)),
          // REFERENCIA
          Text(
            reference.toUpperCase(),
            style: _referenceStyle(ts),
          ),
          if (version.isNotEmpty) ...[
            SizedBox(height: _scale(4)),
            Text(
              version,
              style: TextStyle(
                fontSize: _scale(18),
                color: ts.referenceColor.withOpacity(0.5),
                fontFamily: 'Manrope',
                letterSpacing: _scale(2),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomLayout() {
    final ts = template.textStyle;
    return Column(
      children: [
        const Spacer(flex: 3),
        // Banda inferior con texto
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: _scale(64),
            vertical: _scale(48),
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withOpacity(template.isDark ? 0.6 : 0.4),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: _crossAxis(),
            children: [
              Text(
                verseText,
                style: _verseStyle(ts).copyWith(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.9),
                      blurRadius: 12,
                    ),
                  ],
                ),
                textAlign: textAlign,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: _scale(16)),
              Container(
                width: _scale(32),
                height: _scale(1.5),
                color: ts.referenceColor.withOpacity(0.7),
              ),
              SizedBox(height: _scale(10)),
              Text(
                reference.toUpperCase(),
                style: _referenceStyle(ts).copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _scale(48)),
      ],
    );
  }

  Widget _buildTopLeftLayout() {
    final ts = template.textStyle;
    return Padding(
      padding: EdgeInsets.all(_scale(80)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: _scale(32),
            height: _scale(3),
            color: ts.referenceColor,
          ),
          SizedBox(height: _scale(20)),
          Text(
            verseText,
            style: _verseStyle(ts),
            textAlign: TextAlign.left,
            maxLines: 12,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _scale(20)),
          Text(
            reference.toUpperCase(),
            style: _referenceStyle(ts),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordLayout() {
    final ts = template.textStyle;
    final keyword = template.keywordOverride ?? extractVerseKeyword(verseText);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _scale(72),
        vertical: _scale(80),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Palabra clave gigante
          Text(
            keyword.toUpperCase(),
            style: TextStyle(
              fontSize: _scale(96 * _scaleForLength(keyword.length * 6)),
              color: ts.verseColor,
              fontFamily: 'Cinzel',
              fontWeight: FontWeight.w900,
              letterSpacing: _scale(4),
              height: 1.0,
              shadows: template.isDark
                  ? [
                      Shadow(
                        color: Colors.black.withOpacity(0.9),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _scale(28)),
          // Línea decorativa
          Container(
            width: _scale(60),
            height: _scale(2.5),
            color: ts.referenceColor.withOpacity(0.6),
          ),
          SizedBox(height: _scale(24)),
          // Versículo pequeño
          Text(
            verseText,
            style: _verseStyle(ts).copyWith(
              fontStyle: FontStyle.normal,
              fontSize: _scale(26 * _scaleForLength(verseText.length)),
              height: 1.6,
            ),
            textAlign: TextAlign.left,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: _scale(16)),
          Text(
            reference.toUpperCase(),
            style: _referenceStyle(ts),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularLayout() {
    final ts = template.textStyle;
    return Padding(
      padding: EdgeInsets.all(_scale(48)),
      child: Stack(
        children: [
          // Texto orbital
          Positioned.fill(
            child: CustomPaint(
              painter: _CircularTextPainter(
                text: verseText,
                color: ts.verseColor,
                fontSize: _scale(28),
                fontFamily: ts.verseFont,
                addShadow: template.isDark,
              ),
            ),
          ),
          // Referencia centrada
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: _scale(40),
                  height: _scale(1.5),
                  color: ts.referenceColor.withOpacity(0.5),
                ),
                SizedBox(height: _scale(12)),
                Text(
                  reference.toUpperCase(),
                  style: _referenceStyle(ts).copyWith(
                    fontSize: _scale(30),
                    letterSpacing: _scale(4),
                  ),
                ),
                SizedBox(height: _scale(8)),
                if (version.isNotEmpty)
                  Text(
                    version,
                    style: TextStyle(
                      fontSize: _scale(18),
                      color: ts.referenceColor.withOpacity(0.5),
                      fontFamily: 'Manrope',
                      letterSpacing: _scale(2),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  TextStyle _verseStyle(ShareTextStyle ts) {
    final baseFontSize = customFontSize > 0 ? customFontSize : ts.verseFontSize;
    return TextStyle(
      fontSize: _scale(baseFontSize * _scaleForLength(verseText.length)),
      color: ts.verseColor,
      fontFamily: ts.verseFont,
      fontStyle: FontStyle.italic,
      height: 1.7,
      letterSpacing: 0.3,
      shadows: template.isDark
          ? [
              Shadow(
                color: Colors.black.withOpacity(0.8),
                blurRadius: 8,
              ),
            ]
          : [],
    );
  }

  TextStyle _referenceStyle(ShareTextStyle ts) {
    return TextStyle(
      fontSize: _scale(ts.referenceFontSize),
      color: ts.referenceColor,
      fontFamily: ts.referenceFont,
      letterSpacing: _scale(2.5),
      fontWeight: FontWeight.w600,
      shadows: template.isDark
          ? [
              Shadow(
                color: Colors.black.withOpacity(0.9),
                blurRadius: 4,
              ),
            ]
          : [],
    );
  }

  CrossAxisAlignment _crossAxis() {
    switch (textAlign) {
      case TextAlign.left:
      case TextAlign.start:
        return CrossAxisAlignment.start;
      case TextAlign.right:
      case TextAlign.end:
        return CrossAxisAlignment.end;
      default:
        return CrossAxisAlignment.center;
    }
  }

  /// Escalar dimensiones relativas al tamaño base de 1080.
  double _scale(double value) => value * (cardSize.width / 1080);

  /// Auto-escalar texto según longitud del versículo.
  double _scaleForLength(int length) {
    if (length < 80) return 1.15;
    if (length < 150) return 1.0;
    if (length < 250) return 0.88;
    if (length < 400) return 0.78;
    return 0.68;
  }
}

/// CustomPainter que dibuja texto en forma orbital/circular.
class _CircularTextPainter extends CustomPainter {
  final String text;
  final Color color;
  final double fontSize;
  final String fontFamily;
  final bool addShadow;

  _CircularTextPainter({
    required this.text,
    required this.color,
    required this.fontSize,
    required this.fontFamily,
    this.addShadow = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) * 0.42;
    final center = Offset(size.width / 2, size.height / 2);

    // Calcular cuántos caracteres caben en el círculo
    final charAngle = fontSize * 0.8 / radius; // aproximación
    final maxChars = (2 * math.pi / charAngle).floor();
    final displayText = text.length > maxChars
        ? '${text.substring(0, maxChars - 3)}...'
        : text;

    canvas.save();
    canvas.translate(center.dx, center.dy);

    // Rotar para empezar arriba
    canvas.rotate(-math.pi / 2);

    for (int i = 0; i < displayText.length; i++) {
      final angle = i * charAngle;
      canvas.save();
      canvas.rotate(angle);
      canvas.translate(0, -radius);

      final textPainter = TextPainter(
        text: TextSpan(
          text: displayText[i],
          style: TextStyle(
            fontSize: fontSize,
            color: color,
            fontFamily: fontFamily,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            shadows: addShadow
                ? [
                    Shadow(
                      color: Color(0xCC000000),
                      blurRadius: 6,
                    ),
                    Shadow(
                      color: Color(0x80000000),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, Offset(-textPainter.width / 2, 0));
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CircularTextPainter oldDelegate) =>
      text != oldDelegate.text ||
      color != oldDelegate.color ||
      fontSize != oldDelegate.fontSize;
}

/// Fondo degradado de respaldo cuando las PNGs aún no existen.
class _FallbackBackgroundPainter extends CustomPainter {
  final bool isDark;
  _FallbackBackgroundPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final Paint paint;
    if (isDark) {
      paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A0A1E), Color(0xFF1A1A3E), Color(0xFF0D0D20)],
        ).createShader(rect);
    } else {
      paint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF8E1), Color(0xFFFAF0D7), Color(0xFFF5E6C8)],
        ).createShader(rect);
    }
    canvas.drawRect(rect, paint);

    // Sutil patrón radial
    final radial = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.8,
        colors: [
          (isDark ? const Color(0xFF1A1A3E) : const Color(0xFFFFE0B2))
              .withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, radial);
  }

  @override
  bool shouldRepaint(_FallbackBackgroundPainter oldDelegate) =>
      isDark != oldDelegate.isDark;
}
