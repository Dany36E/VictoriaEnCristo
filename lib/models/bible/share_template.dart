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
  bottom, // texto en banda inferior
  topLeft, // texto alineado arriba-izquierda
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

  const ShareCardTemplate({
    required this.id,
    required this.name,
    this.backgroundAsset,
    required this.textStyle,
    this.layout = ShareLayout.centered,
    this.isDark = true,
  });
}

/// Las 10 plantillas premium con fondos pregenerados.
const List<ShareCardTemplate> kShareTemplates = [
  ShareCardTemplate(
    id: 'dark_cosmos',
    name: 'Cosmos',
    backgroundAsset: 'assets/bible/share_backgrounds/dark_cosmos.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFFF0F0F0),
      referenceFont: 'Manrope',
      referenceFontSize: 12,
      referenceColor: Color(0xFFD4AF37),
      appNameColor: Color(0x80D4AF37),
    ),
    layout: ShareLayout.centered,
  ),
  ShareCardTemplate(
    id: 'sunrise_faith',
    name: 'Amanecer',
    backgroundAsset: 'assets/bible/share_backgrounds/sunrise_faith.png',
    isDark: false,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFF1A1A1A),
      referenceFont: 'Cinzel',
      referenceFontSize: 12,
      referenceColor: Color(0xFF8B6914),
      appNameColor: Color(0x608B6914),
    ),
    layout: ShareLayout.bottom,
  ),
  ShareCardTemplate(
    id: 'parchment_ancient',
    name: 'Pergamino',
    backgroundAsset: 'assets/bible/share_backgrounds/parchment_ancient.png',
    isDark: false,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 17,
      verseColor: Color(0xFF3E2723),
      referenceFont: 'Cinzel',
      referenceFontSize: 11,
      referenceColor: Color(0xFF8B4513),
      appNameColor: Color(0x608B4513),
    ),
    layout: ShareLayout.centered,
  ),
  ShareCardTemplate(
    id: 'ocean_deep',
    name: 'Océano',
    backgroundAsset: 'assets/bible/share_backgrounds/ocean_deep.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFFE0F7FA),
      referenceFont: 'Manrope',
      referenceFontSize: 12,
      referenceColor: Color(0xFF80DEEA),
      appNameColor: Color(0x6080DEEA),
    ),
    layout: ShareLayout.centered,
  ),
  ShareCardTemplate(
    id: 'forest_nature',
    name: 'Naturaleza',
    backgroundAsset: 'assets/bible/share_backgrounds/forest_nature.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFFF1F8E9),
      referenceFont: 'Manrope',
      referenceFontSize: 12,
      referenceColor: Color(0xFFA5D6A7),
      appNameColor: Color(0x60A5D6A7),
    ),
    layout: ShareLayout.centered,
  ),
  ShareCardTemplate(
    id: 'pure_light',
    name: 'Luz Pura',
    backgroundAsset: 'assets/bible/share_backgrounds/pure_light.png',
    isDark: false,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFF1A1A1A),
      referenceFont: 'Cinzel',
      referenceFontSize: 12,
      referenceColor: Color(0xFFC19A3E),
      appNameColor: Color(0x40C19A3E),
    ),
    layout: ShareLayout.centered,
  ),
  ShareCardTemplate(
    id: 'royal_purple',
    name: 'Real',
    backgroundAsset: 'assets/bible/share_backgrounds/royal_purple.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFFF3E5F5),
      referenceFont: 'Cinzel',
      referenceFontSize: 12,
      referenceColor: Color(0xFFD4AF37),
      appNameColor: Color(0x80D4AF37),
    ),
    layout: ShareLayout.centered,
  ),
  ShareCardTemplate(
    id: 'desert_sinai',
    name: 'Desierto',
    backgroundAsset: 'assets/bible/share_backgrounds/desert_sinai.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFFFFF8E1),
      referenceFont: 'Manrope',
      referenceFontSize: 12,
      referenceColor: Color(0xFFFFCC80),
      appNameColor: Color(0x60FFCC80),
    ),
    layout: ShareLayout.bottom,
  ),
  ShareCardTemplate(
    id: 'storm_hope',
    name: 'Tormenta',
    backgroundAsset: 'assets/bible/share_backgrounds/storm_hope.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFFECEFF1),
      referenceFont: 'Manrope',
      referenceFontSize: 12,
      referenceColor: Color(0xFFD4AF37),
      appNameColor: Color(0x80D4AF37),
    ),
    layout: ShareLayout.centered,
  ),
  ShareCardTemplate(
    id: 'minimal_dark',
    name: 'Minimalista',
    backgroundAsset: 'assets/bible/share_backgrounds/minimal_dark.png',
    isDark: true,
    textStyle: ShareTextStyle(
      verseFont: 'CrimsonPro',
      verseFontSize: 18,
      verseColor: Color(0xFFF0F0F0),
      referenceFont: 'Manrope',
      referenceFontSize: 12,
      referenceColor: Color(0xFFD4AF37),
      appNameColor: Color(0x80D4AF37),
    ),
    layout: ShareLayout.centered,
  ),
];
