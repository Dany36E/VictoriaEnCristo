/// Extrae una palabra clave teológica de alto impacto de un versículo.
/// Útil para resaltar un tema principal en la tarjeta de compartir.
String extractVerseKeyword(String verseText) {
  const highImpact = [
    'amor', 'amó', 'ama', 'vida', 'luz', 'paz', 'fe', 'gracia',
    'verdad', 'salvador', 'gloria', 'poder', 'fuerza', 'fortaleza',
    'esperanza', 'gozo', 'eterno', 'eterna', 'eternas', 'eternos',
    'misericordia', 'fiel', 'fidelidad', 'justicia', 'justo',
    'salvación', 'redención', 'perdón', 'refugio', 'consuelo',
    'victoria', 'libertad', 'libre', 'santo', 'santa',
  ];

  final words = verseText.toLowerCase().split(RegExp(r'\s+'));
  for (final word in words) {
    final clean = word.replaceAll(RegExp(r'[,\.\!\?\;\:\"\'\(\)]'), '');
    if (highImpact.contains(clean)) {
      return clean[0].toUpperCase() + clean.substring(1);
    }
  }

  // Fallback: primeras 2 palabras significativas
  final significant = words
      .map((w) => w.replaceAll(RegExp(r'[,\.\!\?\;\:\"\'\(\)]'), ''))
      .where((w) => w.length > 3)
      .take(2)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
  return significant;
}
