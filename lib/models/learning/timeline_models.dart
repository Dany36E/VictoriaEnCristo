/// ═══════════════════════════════════════════════════════════════════════════
/// TIMELINE MODELS — Línea del Tiempo Bíblica
///
/// Una lección de timeline tiene:
///   • Varias eras (en orden cronológico)
///   • Un banco de personajes/eventos para arrastrar a su era correcta
/// ═══════════════════════════════════════════════════════════════════════════
library;

class TimelineEra {
  final String id;
  final String label;
  final String range; // "2000 aC"
  final String description;

  const TimelineEra({
    required this.id,
    required this.label,
    required this.range,
    required this.description,
  });

  factory TimelineEra.fromJson(Map<String, dynamic> j) => TimelineEra(
        id: j['id'] as String,
        label: j['label'] as String,
        range: j['range'] as String,
        description: j['description'] as String? ?? '',
      );
}

class TimelineItem {
  final String id;
  final String name;
  final String eraId; // respuesta correcta
  final String hint;

  const TimelineItem({
    required this.id,
    required this.name,
    required this.eraId,
    required this.hint,
  });

  factory TimelineItem.fromJson(Map<String, dynamic> j) => TimelineItem(
        id: j['id'] as String,
        name: j['name'] as String,
        eraId: j['eraId'] as String,
        hint: j['hint'] as String? ?? '',
      );
}

class TimelineLesson {
  final String id;
  final int order;
  final String title;
  final String subtitle;
  final List<TimelineEra> eras;
  final List<TimelineItem> items;
  final int xpReward;

  const TimelineLesson({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.eras,
    required this.items,
    required this.xpReward,
  });

  factory TimelineLesson.fromJson(Map<String, dynamic> j) => TimelineLesson(
        id: j['id'] as String,
        order: j['order'] as int,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        eras: (j['eras'] as List)
            .map((e) => TimelineEra.fromJson(e as Map<String, dynamic>))
            .toList(),
        items: (j['items'] as List)
            .map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        xpReward: (j['xpReward'] as num?)?.toInt() ?? 30,
      );
}
