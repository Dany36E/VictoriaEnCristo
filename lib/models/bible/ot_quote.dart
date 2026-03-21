/// Cita del Antiguo Testamento citada en el Nuevo Testamento.
class OTQuote {
  final String id;
  final String ntReference; // OSIS ref del versículo NT
  final String ntText;
  final String otReference; // OSIS ref del versículo AT
  final String otText;
  final QuoteType quoteType;
  final String context;
  final String significance;

  const OTQuote({
    required this.id,
    required this.ntReference,
    required this.otReference,
    this.ntText = '',
    this.otText = '',
    this.quoteType = QuoteType.direct,
    this.context = '',
    this.significance = '',
  });

  factory OTQuote.fromJson(Map<String, dynamic> json) {
    return OTQuote(
      id: json['id'] as String,
      ntReference: json['ntReference'] as String,
      otReference: json['otReference'] as String,
      ntText: json['ntText'] as String? ?? '',
      otText: json['otText'] as String? ?? '',
      quoteType: _parseType(json['quoteType'] as String?),
      context: json['context'] as String? ?? '',
      significance: json['significance'] as String? ?? '',
    );
  }

  static QuoteType _parseType(String? t) {
    switch (t) {
      case 'direct': return QuoteType.direct;
      case 'paraphrase': return QuoteType.paraphrase;
      case 'allusion': return QuoteType.allusion;
      default: return QuoteType.direct;
    }
  }
}

enum QuoteType {
  direct,     // Cita textual
  paraphrase, // Paráfrasis
  allusion,   // Alusión implícita
}
