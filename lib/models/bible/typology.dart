/// Tipología bíblica: un "tipo" del AT prefigura un "antitipo" en el NT.
class Typology {
  final String id;
  final String title;
  final String description;
  final TypologyRef oldTestament;
  final TypologyRef newTestament;
  final List<String> tags;

  const Typology({
    required this.id,
    required this.title,
    required this.description,
    required this.oldTestament,
    required this.newTestament,
    this.tags = const [],
  });

  factory Typology.fromJson(Map<String, dynamic> json) {
    return Typology(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      oldTestament: TypologyRef.fromJson(json['oldTestament'] as Map<String, dynamic>),
      newTestament: TypologyRef.fromJson(json['newTestament'] as Map<String, dynamic>),
      tags: (json['tags'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }
}

class TypologyRef {
  final String reference; // OSIS ref, e.g. "GEN.2.7"
  final String text;
  final String aspect;

  const TypologyRef({
    required this.reference,
    this.text = '',
    this.aspect = '',
  });

  factory TypologyRef.fromJson(Map<String, dynamic> json) {
    return TypologyRef(
      reference: json['reference'] as String,
      text: json['text'] as String? ?? '',
      aspect: json['aspect'] as String? ?? '',
    );
  }
}
