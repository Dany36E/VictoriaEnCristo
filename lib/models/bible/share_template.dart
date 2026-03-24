import 'dart:ui';

/// Estilo de texto para una plantilla de compartir.
class ShareTextStyle {
  final String verseFont;
  final double verseFontSize;
  final Color verseColor;
  final String referenceFont;
  final double referenceFontSize;
  final Color referenceColor;
  final Color appNameColor;

  const ShareTextStyle({
    required this.verseFont,
    required this.verseFontSize,
    required this.verseColor,
    required this.referenceFont,
    required this.referenceFontSize,
    required this.referenceColor,
    required this.appNameColor,
  });
}

/// Layout del texto sobre el fondo.
enum ShareLayout {
  centered, // texto centrado en el medio
  bottom,   // texto en banda inferior
  topLeft,  // texto alineado arriba-izquierda
  keyword,  // palabra clave gigante + texto pequeño
  circular, // texto orbital con CustomPainter
}

/// Plantilla de imagen para compartir versículos.
/// El fondo es un asset PNG estático (generado offline con IA).
/// Flutter renderiza el texto nativamente encima.
class ShareCardTemplate {
  final String id;
  final String name;
  final String? backgroundAsset; // null = solo color/gradient
  final ShareTextStyle textStyle;
  final ShareLayout layout;
  final bool isDark;
  final String? keywordOverride; // fuerza una palabra clave específica

  const ShareCardTemplate({
    required this.id,
    required this.name,
    this.backgroundAsset,
    required this.textStyle,
    this.layout = ShareLayout.centered,
    this.isDark = true,
    this.keywordOverride,
  });
}

/// Las 10 plantillas premium con fondos pregenerados (DALL-E 3).
const List<ShareCardTemplate> kShareTemplates = [
  // ── 1. Cosmos ──
  ShareCardTemplate(
    id: 'cosmos',
    name: 'Cosmos',
    backgroundAsset: 'assets/bible/share_backgrounds/cosmos.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFF0F0F0),
      referenceFont: 'Manrope',
      referenceFontSize: 22,
      referenceColor: Color(0xFFD4AF37),
      appNameColor: Color(0x80D4AF37),
    ),
    layout: ShareLayout.centered,
  ),
  // ── 2. Persona B/N ──
  ShareCardTemplate(
    id: 'person_bw',
    name: 'Persona',
    backgroundAsset: 'assets/bible/share_backgrounds/person_bw.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFF5F5F5),
      referenceFont: 'Cinzel',
      referenceFontSize: 22,
      referenceColor: Color(0xFFBDBDBD),
      appNameColor: Color(0x60BDBDBD),
    ),
    layout: ShareLayout.centered,
  ),
  // ── 3. Amanecer ──
  ShareCardTemplate(
    id: 'sunrise_sky',
    name: 'Amanecer',
    backgroundAsset: 'assets/bible/share_backgrounds/sunrise_sky.png',
    isDark: false,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFF1A1A1A),
      referenceFont: 'Cinzel',
      referenceFontSize: 22,
      referenceColor: Color(0xFF8B6914),
      appNameColor: Color(0x608B6914),
    ),
    layout: ShareLayout.bottom,
  ),
  // ── 4. Ola oceánica ──
  ShareCardTemplate(
    id: 'ocean_wave',
    name: 'Océano',
    backgroundAsset: 'assets/bible/share_backgrounds/ocean_wave.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFE0F7FA),
      referenceFont: 'Manrope',
      referenceFontSize: 22,
      referenceColor: Color(0xFF80DEEA),
      appNameColor: Color(0x6080DEEA),
    ),
    layout: ShareLayout.centered,
  ),
  // ── 5. Globo oscuro (circular) ──
  ShareCardTemplate(
    id: 'globe_dark',
    name: 'Globo',
    backgroundAsset: 'assets/bible/share_backgrounds/globe_dark.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFF0F0F0),
      referenceFont: 'Manrope',
      referenceFontSize: 22,
      referenceColor: Color(0xFF64FFDA),
      appNameColor: Color(0x6064FFDA),
    ),
    layout: ShareLayout.circular,
  ),
  // ── 6. Vibrante Rojo (keyword) ──
  ShareCardTemplate(
    id: 'vibrant_red',
    name: 'Rojo',
    backgroundAsset: 'assets/bible/share_backgrounds/vibrant_red.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFFFF8E1),
      referenceFont: 'Manrope',
      referenceFontSize: 22,
      referenceColor: Color(0xFFFF8A80),
      appNameColor: Color(0x60FF8A80),
    ),
    layout: ShareLayout.keyword,
  ),
  // ── 7. Vibrante Teal (keyword) ──
  ShareCardTemplate(
    id: 'vibrant_teal',
    name: 'Teal',
    backgroundAsset: 'assets/bible/share_backgrounds/vibrant_teal.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFE0F2F1),
      referenceFont: 'Manrope',
      referenceFontSize: 22,
      referenceColor: Color(0xFF80CBC4),
      appNameColor: Color(0x6080CBC4),
    ),
    layout: ShareLayout.keyword,
  ),
  // ── 8. Vibrante Púrpura (keyword) ──
  ShareCardTemplate(
    id: 'vibrant_purple',
    name: 'Púrpura',
    backgroundAsset: 'assets/bible/share_backgrounds/vibrant_purple.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFF3E5F5),
      referenceFont: 'Cinzel',
      referenceFontSize: 22,
      referenceColor: Color(0xFFCE93D8),
      appNameColor: Color(0x60CE93D8),
    ),
    layout: ShareLayout.keyword,
  ),
  // ── 9. Cruz desierto ──
  ShareCardTemplate(
    id: 'desert_cross',
    name: 'Desierto',
    backgroundAsset: 'assets/bible/share_backgrounds/desert_cross.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFFFF8E1),
      referenceFont: 'Manrope',
      referenceFontSize: 22,
      referenceColor: Color(0xFFFFCC80),
      appNameColor: Color(0x60FFCC80),
    ),
    layout: ShareLayout.bottom,
  ),
  // ── 10. Bosque luminoso ──
  ShareCardTemplate(
    id: 'forest_light',
    name: 'Bosque',
    backgroundAsset: 'assets/bible/share_backgrounds/forest_light.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 34,
      verseColor: Color(0xFFF1F8E9),
      referenceFont: 'Manrope',
      referenceFontSize: 22,
      referenceColor: Color(0xFFA5D6A7),
      appNameColor: Color(0x60A5D6A7),
    ),
    layout: ShareLayout.centered,
  ),
];
