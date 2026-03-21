/// Modelo para entradas del diccionario bíblico.
library;

class DictionaryEntry {
  final String term;
  final String definition;
  final List<String> references;  // ["GEN.2.7", "ROM.5.12"]
  final String source;            // "Easton's Bible Dictionary"

  const DictionaryEntry({
    required this.term,
    required this.definition,
    this.references = const [],
    required this.source,
  });

  /// Primeras ~2 oraciones.
  String get shortDefinition {
    final sentences = definition.split(RegExp(r'(?<=[.!?])\s+'));
    if (sentences.length <= 2) return definition;
    return '${sentences.take(2).join(' ')}...';
  }
}
