/// Modelos de "Profecías Mesiánicas": pares AT → NT.
library;

class ProphecyPair {
  final String id;
  final String topic; // Nacimiento, Pasión, etc.
  final String prophecyRef;
  final String prophecyText;
  final String fulfillmentRef;
  final String fulfillmentText;

  ProphecyPair({
    required this.id,
    required this.topic,
    required this.prophecyRef,
    required this.prophecyText,
    required this.fulfillmentRef,
    required this.fulfillmentText,
  });

  factory ProphecyPair.fromJson(Map<String, dynamic> j) => ProphecyPair(
        id: j['id'] as String,
        topic: j['topic'] as String,
        prophecyRef: j['prophecyRef'] as String,
        prophecyText: j['prophecyText'] as String,
        fulfillmentRef: j['fulfillmentRef'] as String,
        fulfillmentText: j['fulfillmentText'] as String,
      );
}

class ProphecyRound {
  final String id;
  final String title;
  final String description;
  final List<ProphecyPair> pairs;
  final int xpReward;

  ProphecyRound({
    required this.id,
    required this.title,
    required this.description,
    required this.pairs,
    required this.xpReward,
  });

  factory ProphecyRound.fromJson(Map<String, dynamic> j) => ProphecyRound(
        id: j['id'] as String,
        title: j['title'] as String,
        description: j['description'] as String? ?? '',
        pairs: (j['pairs'] as List<dynamic>)
            .map((e) => ProphecyPair.fromJson(e as Map<String, dynamic>))
            .toList(),
        xpReward: j['xpReward'] as int? ?? 30,
      );
}
