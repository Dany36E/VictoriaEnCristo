/// Normalización compartida para búsquedas en hebreo, griego y
/// transliteraciones. No translitera: sólo elimina signos, puntuación y
/// diacríticos para que una palabra copiada del interlineal pueda encontrarse
/// aunque se escriba sin vocales o acentos.
String normalizeOriginalLanguageTerm(String value) {
  final buffer = StringBuffer();

  for (final rune in value.trim().toLowerCase().runes) {
    // Signos vocálicos y de cantilación hebreos.
    if (rune >= 0x0591 && rune <= 0x05c7) continue;
    // Marcas combinantes latinas/griegas.
    if (rune >= 0x0300 && rune <= 0x036f) continue;

    final character = String.fromCharCode(rune);
    final folded = _foldedCharacters[character];
    if (folded != null) {
      buffer.write(folded);
      continue;
    }

    final isAsciiLetter = rune >= 0x61 && rune <= 0x7a;
    final isDigit = rune >= 0x30 && rune <= 0x39;
    final isGreek =
        (rune >= 0x0370 && rune <= 0x03ff) ||
        (rune >= 0x1f00 && rune <= 0x1fff);
    final isHebrew =
        (rune >= 0x05d0 && rune <= 0x05ea) ||
        (rune >= 0xfb1d && rune <= 0xfb4f);

    if (isAsciiLetter || isDigit || isGreek || isHebrew) {
      buffer.write(character);
    }
  }

  return buffer.toString();
}

const Map<String, String> _foldedCharacters = {
  // Griego monotónico y politónico. Incluye las formas que aparecen en los
  // datos SBLGNT; sigma final se unifica para búsquedas por lema.
  'ά': 'α', 'ὰ': 'α', 'ᾶ': 'α', 'ἀ': 'α', 'ἁ': 'α', 'ἂ': 'α',
  'ἃ': 'α', 'ἄ': 'α', 'ἅ': 'α', 'ἆ': 'α', 'ἇ': 'α', 'ᾳ': 'α',
  'ᾀ': 'α', 'ᾁ': 'α', 'ᾂ': 'α', 'ᾃ': 'α', 'ᾄ': 'α', 'ᾅ': 'α',
  'ᾆ': 'α', 'ᾇ': 'α', 'ᾴ': 'α', 'ᾲ': 'α', 'ᾷ': 'α',
  'έ': 'ε', 'ὲ': 'ε', 'ἐ': 'ε', 'ἑ': 'ε', 'ἒ': 'ε', 'ἓ': 'ε',
  'ἔ': 'ε', 'ἕ': 'ε',
  'ή': 'η', 'ὴ': 'η', 'ῆ': 'η', 'ἠ': 'η', 'ἡ': 'η', 'ἢ': 'η',
  'ἣ': 'η', 'ἤ': 'η', 'ἥ': 'η', 'ἦ': 'η', 'ἧ': 'η', 'ῃ': 'η',
  'ᾐ': 'η', 'ᾑ': 'η', 'ᾒ': 'η', 'ᾓ': 'η', 'ᾔ': 'η', 'ᾕ': 'η',
  'ᾖ': 'η', 'ᾗ': 'η', 'ῄ': 'η', 'ῂ': 'η', 'ῇ': 'η',
  'ί': 'ι', 'ὶ': 'ι', 'ῖ': 'ι', 'ϊ': 'ι', 'ΐ': 'ι', 'ἰ': 'ι',
  'ἱ': 'ι', 'ἲ': 'ι', 'ἳ': 'ι', 'ἴ': 'ι', 'ἵ': 'ι', 'ἶ': 'ι',
  'ἷ': 'ι', 'ῒ': 'ι', 'ῗ': 'ι',
  'ό': 'ο', 'ὸ': 'ο', 'ὀ': 'ο', 'ὁ': 'ο', 'ὂ': 'ο', 'ὃ': 'ο',
  'ὄ': 'ο', 'ὅ': 'ο',
  'ύ': 'υ', 'ὺ': 'υ', 'ῦ': 'υ', 'ϋ': 'υ', 'ΰ': 'υ', 'ὐ': 'υ',
  'ὑ': 'υ', 'ὒ': 'υ', 'ὓ': 'υ', 'ὔ': 'υ', 'ὕ': 'υ', 'ὖ': 'υ',
  'ὗ': 'υ', 'ῢ': 'υ', 'ῧ': 'υ',
  'ώ': 'ω', 'ὼ': 'ω', 'ῶ': 'ω', 'ὠ': 'ω', 'ὡ': 'ω', 'ὢ': 'ω',
  'ὣ': 'ω', 'ὤ': 'ω', 'ὥ': 'ω', 'ὦ': 'ω', 'ὧ': 'ω', 'ῳ': 'ω',
  'ᾠ': 'ω', 'ᾡ': 'ω', 'ᾢ': 'ω', 'ᾣ': 'ω', 'ᾤ': 'ω', 'ᾥ': 'ω',
  'ᾦ': 'ω', 'ᾧ': 'ω', 'ῴ': 'ω', 'ῲ': 'ω', 'ῷ': 'ω',
  'ῥ': 'ρ', 'ῤ': 'ρ', 'ς': 'σ',

  // Transliteraciones latinas frecuentes en los léxicos Strong.
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'ā': 'a', 'ă': 'a', 'ʼ': '', 'ʽ': '',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ĕ': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ĭ': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ō': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
  'ç': 'c', 'ñ': 'n', 'š': 's', 'ś': 's', 'ṣ': 's', 'ṭ': 't',
  'ḏ': 'd', 'ḥ': 'h', 'ḵ': 'k', 'ḳ': 'q', 'ẓ': 'z',
};
