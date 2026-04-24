/// ═══════════════════════════════════════════════════════════════════════════
/// Travesía Bíblica — modelos de datos
///
/// Una "Travesía" es una ruta narrativa de estaciones a través de la historia
/// bíblica: Creación → Caída → Diluvio → Abraham → Moisés → David → Profetas
/// → Nacimiento de Jesús → Ministerio → Cruz → Resurrección → Pentecostés.
///
/// Cada estación contiene:
///   • Narrativa corta de contexto (qué pasó, dónde, quién)
///   • Un versículo clave
///   • 2-3 preguntas de comprensión (auto-grading)
///   • Un prompt de reflexión personal (opcional, solo marca "leído")
///
/// Al completar las preguntas, la estación queda marcada completada,
/// desbloquea la siguiente y otorga XP al LearningProgressService.
/// ═══════════════════════════════════════════════════════════════════════════
library;

enum JourneyEra { oldTestament, gospels, earlyChurch }

extension JourneyEraX on JourneyEra {
  String get label {
    switch (this) {
      case JourneyEra.oldTestament:
        return 'Antiguo Testamento';
      case JourneyEra.gospels:
        return 'Evangelios';
      case JourneyEra.earlyChurch:
        return 'Iglesia Primitiva';
    }
  }

  static JourneyEra fromString(String s) {
    switch (s) {
      case 'old':
        return JourneyEra.oldTestament;
      case 'gospels':
        return JourneyEra.gospels;
      case 'church':
        return JourneyEra.earlyChurch;
      default:
        return JourneyEra.oldTestament;
    }
  }
}

class JourneyQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  const JourneyQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  factory JourneyQuestion.fromJson(Map<String, dynamic> j) => JourneyQuestion(
        prompt: j['prompt'] as String,
        options: (j['options'] as List).cast<String>(),
        correctIndex: j['correctIndex'] as int,
        explanation: j['explanation'] as String?,
      );
}

class JourneyStation {
  final String id;
  final int order;
  final JourneyEra era;
  final String title;
  final String subtitle;
  final String icon; // Material icon codepoint name
  final String narrative;
  final String keyVerseReference;
  final String keyVerseText;
  final List<JourneyQuestion> questions;
  final String reflectionPrompt;
  final int xpReward;

  const JourneyStation({
    required this.id,
    required this.order,
    required this.era,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.narrative,
    required this.keyVerseReference,
    required this.keyVerseText,
    required this.questions,
    required this.reflectionPrompt,
    required this.xpReward,
  });

  factory JourneyStation.fromJson(Map<String, dynamic> j) => JourneyStation(
        id: j['id'] as String,
        order: j['order'] as int,
        era: JourneyEraX.fromString(j['era'] as String),
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        icon: j['icon'] as String,
        narrative: j['narrative'] as String,
        keyVerseReference: j['keyVerseReference'] as String,
        keyVerseText: j['keyVerseText'] as String,
        questions: (j['questions'] as List)
            .map((e) => JourneyQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        reflectionPrompt: j['reflectionPrompt'] as String,
        xpReward: j['xpReward'] as int? ?? 20,
      );
}
