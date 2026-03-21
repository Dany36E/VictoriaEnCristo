/// Clasifica el tipo de conexión entre dos referencias bíblicas.
enum CrossRefType {
  parallel,     // Mismo evento narrado en otro lugar (Evangelios)
  prophecy,     // Profecía AT → cumplimiento NT
  oldTestQuote, // Cita textual del AT en el NT
  typology,     // Tipo del AT cumplido en NT
  thematic,     // Mismo tema
}

class CrossRefClassifier {
  CrossRefClassifier._();

  static const _gospelBooks = {40, 41, 42, 43}; // MAT, MRK, LUK, JHN

  static bool _isGospel(int bookNumber) => _gospelBooks.contains(bookNumber);
  static bool _isOT(int bookNumber) => bookNumber >= 1 && bookNumber <= 39;
  static bool _isNT(int bookNumber) => bookNumber >= 40 && bookNumber <= 66;

  /// Clasifica la relación de un versículo fuente hacia su referencia cruzada.
  static CrossRefType classify(int fromBook, int toBook) {
    // Ambos evangelios → paralelo
    if (_isGospel(fromBook) && _isGospel(toBook)) return CrossRefType.parallel;

    // NT citando AT
    if (_isNT(fromBook) && _isOT(toBook)) return CrossRefType.oldTestQuote;

    // AT apuntando a NT → profecía / tipología
    if (_isOT(fromBook) && _isNT(toBook)) return CrossRefType.prophecy;

    return CrossRefType.thematic;
  }

  /// Etiqueta en español para el tipo.
  static String label(CrossRefType type) {
    switch (type) {
      case CrossRefType.parallel: return 'Paralelo';
      case CrossRefType.prophecy: return 'Profecía';
      case CrossRefType.oldTestQuote: return 'Cita AT';
      case CrossRefType.typology: return 'Tipología';
      case CrossRefType.thematic: return 'Temático';
    }
  }

  /// Explicación breve por defecto según el tipo de conexión.
  static String defaultExplanation(CrossRefType type) {
    switch (type) {
      case CrossRefType.parallel:
        return 'Narra el mismo evento desde otra perspectiva.';
      case CrossRefType.prophecy:
        return 'Este pasaje del AT fue profetizado y cumplido en el NT.';
      case CrossRefType.oldTestQuote:
        return 'Esta frase es citada directamente del Antiguo Testamento.';
      case CrossRefType.typology:
        return 'Prefigura un elemento que se cumple en el Nuevo Testamento.';
      case CrossRefType.thematic:
        return 'Comparte un tema o enseñanza similar.';
    }
  }
}
