/// Sección de la Armonía de los Evangelios.
/// Representa un evento narrado en uno o más Evangelios.
class HarmonySection {
  final String id;
  final String title;
  final String category;
  final Map<String, String?> references; // matthew, mark, luke, john → OSIS ref

  const HarmonySection({
    required this.id,
    required this.title,
    required this.category,
    required this.references,
  });

  factory HarmonySection.fromJson(Map<String, dynamic> json) {
    final refs = json['references'] as Map<String, dynamic>;
    return HarmonySection(
      id: json['id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      references: {
        'matthew': refs['matthew'] as String?,
        'mark': refs['mark'] as String?,
        'luke': refs['luke'] as String?,
        'john': refs['john'] as String?,
      },
    );
  }

  /// Número de evangelios que cubren este evento.
  int get gospelCount =>
      references.values.where((v) => v != null).length;

  /// True si el libro indicado (MAT/MRK/LUK/JHN) cubre este evento.
  bool coversBook(int bookNumber) {
    switch (bookNumber) {
      case 40: return references['matthew'] != null;
      case 41: return references['mark'] != null;
      case 42: return references['luke'] != null;
      case 43: return references['john'] != null;
      default: return false;
    }
  }
}
