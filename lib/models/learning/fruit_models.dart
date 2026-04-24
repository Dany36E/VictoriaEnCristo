/// ═══════════════════════════════════════════════════════════════════════════
/// FRUIT MODELS — Fruto del Espíritu (Gálatas 5:22-23)
///
/// 9 frutos. Cada uno es una "semana": versículo clave, 3 microacciones,
/// reflexión y reto de 7 días. Al completar todas las acciones + reflexión
/// gana la "insignia" del fruto.
/// ═══════════════════════════════════════════════════════════════════════════
library;

class FruitAction {
  final String id;
  final String text;

  const FruitAction({required this.id, required this.text});

  factory FruitAction.fromJson(Map<String, dynamic> j) => FruitAction(
        id: j['id'] as String,
        text: j['text'] as String,
      );
}

class SpiritFruit {
  final String id;
  final int order;
  final String name;
  final String greek; // nombre en griego original
  final String icon;
  final String colorHex; // "#RRGGBB"
  final String definition;
  final String keyVerse;
  final String keyVerseRef;
  final String meditation;
  final List<FruitAction> actions;
  final String reflectionPrompt;
  final int xpReward;

  const SpiritFruit({
    required this.id,
    required this.order,
    required this.name,
    required this.greek,
    required this.icon,
    required this.colorHex,
    required this.definition,
    required this.keyVerse,
    required this.keyVerseRef,
    required this.meditation,
    required this.actions,
    required this.reflectionPrompt,
    required this.xpReward,
  });

  factory SpiritFruit.fromJson(Map<String, dynamic> j) => SpiritFruit(
        id: j['id'] as String,
        order: j['order'] as int,
        name: j['name'] as String,
        greek: j['greek'] as String,
        icon: j['icon'] as String,
        colorHex: j['colorHex'] as String,
        definition: j['definition'] as String,
        keyVerse: j['keyVerse'] as String,
        keyVerseRef: j['keyVerseRef'] as String,
        meditation: j['meditation'] as String,
        actions: (j['actions'] as List)
            .map((e) => FruitAction.fromJson(e as Map<String, dynamic>))
            .toList(),
        reflectionPrompt: j['reflectionPrompt'] as String,
        xpReward: (j['xpReward'] as num?)?.toInt() ?? 40,
      );
}
