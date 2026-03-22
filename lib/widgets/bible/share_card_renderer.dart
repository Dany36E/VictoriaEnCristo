import 'package:flutter/material.dart';
import '../../models/bible/share_template.dart';

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
                errorBuilder: (_, __, ___) => Container(
                  color: template.isDark
                      ? const Color(0xFF0A0A12)
                      : const Color(0xFFFAF8F3),
                ),
              ),
            )
          else
            Positioned.fill(
              child: Container(
                color: template.isDark
                    ? const Color(0xFF0A0A12)
                    : const Color(0xFFFAF8F3),
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
                    fontSize: _scale(11),
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
                fontSize: _scale(10),
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
