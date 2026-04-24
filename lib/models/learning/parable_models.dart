/// ═══════════════════════════════════════════════════════════════════════════
/// PARABLE MODELS — Parábolas de Jesús
///
/// Cada parábola tiene:
///   • Narrativa cinematográfica (escenas con texto)
///   • Versículo clave + referencia
///   • 2-3 preguntas de comprensión
///   • Prompt de aplicación personal
/// ═══════════════════════════════════════════════════════════════════════════
library;

class ParableQuestion {
  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  const ParableQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  factory ParableQuestion.fromJson(Map<String, dynamic> j) => ParableQuestion(
        prompt: j['prompt'] as String,
        options: (j['options'] as List).cast<String>(),
        correctIndex: j['correctIndex'] as int,
        explanation: j['explanation'] as String?,
      );
}

class ParableScene {
  final String text;
  final String? speaker;

  const ParableScene({required this.text, this.speaker});

  factory ParableScene.fromJson(Map<String, dynamic> j) => ParableScene(
        text: j['text'] as String,
        speaker: j['speaker'] as String?,
      );
}

class Parable {
  final String id;
  final int order;
  final String title;
  final String subtitle;
  final String icon;
  final String reference;
  final String keyVerse;
  final List<ParableScene> scenes;
  final String meaning; // interpretación
  final List<ParableQuestion> questions;
  final String applicationPrompt;
  final int xpReward;

  const Parable({
    required this.id,
    required this.order,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.reference,
    required this.keyVerse,
    required this.scenes,
    required this.meaning,
    required this.questions,
    required this.applicationPrompt,
    required this.xpReward,
  });

  factory Parable.fromJson(Map<String, dynamic> j) => Parable(
        id: j['id'] as String,
        order: j['order'] as int,
        title: j['title'] as String,
        subtitle: j['subtitle'] as String,
        icon: j['icon'] as String,
        reference: j['reference'] as String,
        keyVerse: j['keyVerse'] as String,
        scenes: (j['scenes'] as List)
            .map((e) => ParableScene.fromJson(e as Map<String, dynamic>))
            .toList(),
        meaning: j['meaning'] as String,
        questions: (j['questions'] as List)
            .map((e) => ParableQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
        applicationPrompt: j['applicationPrompt'] as String,
        xpReward: (j['xpReward'] as num?)?.toInt() ?? 25,
      );
}
