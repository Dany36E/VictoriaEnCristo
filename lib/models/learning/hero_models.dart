/// ═══════════════════════════════════════════════════════════════════════════
/// Héroes de la Fe — modelos de datos (Fase 3 Escuela del Reino)
///
/// Galería estilo Hebreos 11. Cada héroe bíblico presenta:
///   • Nombre, era y época
///   • Gigante que venció (miedo, orgullo, lujuria, desánimo, etc.)
///   • Historia breve (narrativa inspiracional)
///   • Versículo clave que resume su testimonio
///   • Lección práctica aplicable al lector
///   • Reto corto (2 preguntas) para fijar aprendizaje
///
/// Al completar el reto, el héroe queda desbloqueado y se otorga XP.
/// ═══════════════════════════════════════════════════════════════════════════
library;

enum HeroEra { patriarch, exodus, kingdom, prophets, gospels, earlyChurch }

extension HeroEraX on HeroEra {
  String get label {
    switch (this) {
      case HeroEra.patriarch:
        return 'Patriarcas';
      case HeroEra.exodus:
        return 'Éxodo';
      case HeroEra.kingdom:
        return 'Reino';
      case HeroEra.prophets:
        return 'Profetas';
      case HeroEra.gospels:
        return 'Evangelios';
      case HeroEra.earlyChurch:
        return 'Iglesia Primitiva';
    }
  }

  static HeroEra fromString(String s) {
    switch (s) {
      case 'patriarch':
        return HeroEra.patriarch;
      case 'exodus':
        return HeroEra.exodus;
      case 'kingdom':
        return HeroEra.kingdom;
      case 'prophets':
        return HeroEra.prophets;
      case 'gospels':
        return HeroEra.gospels;
      case 'church':
        return HeroEra.earlyChurch;
      default:
        return HeroEra.patriarch;
    }
  }
}

class HeroChallenge {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  const HeroChallenge({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  factory HeroChallenge.fromJson(Map<String, dynamic> j) => HeroChallenge(
        prompt: j['prompt'] as String,
        options: (j['options'] as List).cast<String>(),
        correctIndex: j['correctIndex'] as int,
        explanation: j['explanation'] as String?,
      );
}

class HeroOfFaith {
  final String id;
  final int order;
  final HeroEra era;
  final String name;
  final String epithet; // p.ej. "Padre de la fe"
  final String giantDefeated; // p.ej. "Miedo", "Orgullo", "Desánimo"
  final String icon; // nombre de Material icon
  final String story;
  final String keyVerseReference;
  final String keyVerseText;
  final String lesson;
  final List<HeroChallenge> challenges;
  final int xpReward;

  const HeroOfFaith({
    required this.id,
    required this.order,
    required this.era,
    required this.name,
    required this.epithet,
    required this.giantDefeated,
    required this.icon,
    required this.story,
    required this.keyVerseReference,
    required this.keyVerseText,
    required this.lesson,
    required this.challenges,
    required this.xpReward,
  });

  factory HeroOfFaith.fromJson(Map<String, dynamic> j) => HeroOfFaith(
        id: j['id'] as String,
        order: j['order'] as int,
        era: HeroEraX.fromString(j['era'] as String),
        name: j['name'] as String,
        epithet: j['epithet'] as String,
        giantDefeated: j['giantDefeated'] as String,
        icon: j['icon'] as String,
        story: j['story'] as String,
        keyVerseReference: j['keyVerseReference'] as String,
        keyVerseText: j['keyVerseText'] as String,
        lesson: j['lesson'] as String,
        challenges: (j['challenges'] as List)
            .map((e) => HeroChallenge.fromJson(e as Map<String, dynamic>))
            .toList(),
        xpReward: j['xpReward'] as int? ?? 25,
      );
}
