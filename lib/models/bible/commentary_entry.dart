/// Modelo para comentarios bíblicos (Matthew Henry, etc.)
library;

class CommentaryEntry {
  final String bookCode;
  final int chapter;
  final int verse;
  final String text;
  final String source;

  const CommentaryEntry({
    required this.bookCode,
    required this.chapter,
    required this.verse,
    required this.text,
    this.source = 'Matthew Henry, 1706',
  });

  /// Primeras ~3 líneas del texto.
  String get shortText {
    if (text.length <= 200) return text;
    final idx = text.indexOf(' ', 190);
    return '${text.substring(0, idx > 0 ? idx : 200)}...';
  }
}
