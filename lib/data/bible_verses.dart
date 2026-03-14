class BibleVerse {
  final String verse;
  final String reference;
  final String category;

  const BibleVerse({
    required this.verse,
    required this.reference,
    required this.category,
  });

  /// Crea un BibleVerse desde JSON (para cargar favoritos)
  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    return BibleVerse(
      verse: json['verse'] as String,
      reference: json['reference'] as String,
      category: json['category'] as String? ?? 'general',
    );
  }

  /// Convierte a JSON (para guardar favoritos)
  Map<String, dynamic> toJson() {
    return {
      'verse': verse,
      'reference': reference,
      'category': category,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BibleVerse &&
        other.verse == verse &&
        other.reference == reference;
  }

  @override
  int get hashCode => verse.hashCode ^ reference.hashCode;
}

class BibleVerses {
  // ═══════════════════════════════════════════════════════════════════════════
  // VERSÍCULOS POR EMOCIÓN - "Emotional Verse Jar"
  // ═══════════════════════════════════════════════════════════════════════════

  // 😊 FELIZ - Para celebrar y agradecer la alegría
  static const List<BibleVerse> happyVerses = [
    BibleVerse(
      verse: "Este es el día que hizo Jehová; nos gozaremos y alegraremos en él.",
      reference: "Salmos 118:24",
      category: "feliz",
    ),
    BibleVerse(
      verse: "Estad siempre gozosos. Orad sin cesar. Dad gracias en todo.",
      reference: "1 Tesalonicenses 5:16-18",
      category: "feliz",
    ),
    BibleVerse(
      verse: "El gozo del Señor es vuestra fortaleza.",
      reference: "Nehemías 8:10",
      category: "feliz",
    ),
    BibleVerse(
      verse: "Me mostrarás la senda de la vida; en tu presencia hay plenitud de gozo.",
      reference: "Salmos 16:11",
      category: "feliz",
    ),
  ];

  // 😰 ANSIOSO - Para calmar la ansiedad
  static const List<BibleVerse> anxiousVerses = [
    BibleVerse(
      verse: "Por nada estéis afanosos, sino sean conocidas vuestras peticiones delante de Dios en toda oración y ruego, con acción de gracias.",
      reference: "Filipenses 4:6",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "Echando toda vuestra ansiedad sobre él, porque él tiene cuidado de vosotros.",
      reference: "1 Pedro 5:7",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "La paz os dejo, mi paz os doy; yo no os la doy como el mundo la da. No se turbe vuestro corazón, ni tenga miedo.",
      reference: "Juan 14:27",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "Tú guardarás en completa paz a aquel cuyo pensamiento en ti persevera.",
      reference: "Isaías 26:3",
      category: "ansioso",
    ),
  ];

  // 🙏 AGRADECIDO - Para expresar gratitud
  static const List<BibleVerse> gratefulVerses = [
    BibleVerse(
      verse: "Dad gracias en todo, porque esta es la voluntad de Dios para con vosotros en Cristo Jesús.",
      reference: "1 Tesalonicenses 5:18",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "Alabad a Jehová, porque él es bueno; porque para siempre es su misericordia.",
      reference: "Salmos 136:1",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "Toda buena dádiva y todo don perfecto desciende de lo alto, del Padre de las luces.",
      reference: "Santiago 1:17",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "Bendice, alma mía, a Jehová, y no olvides ninguno de sus beneficios.",
      reference: "Salmos 103:2",
      category: "agradecido",
    ),
  ];

  // 😔 SOLO - Para momentos de soledad
  static const List<BibleVerse> lonelyVerses = [
    BibleVerse(
      verse: "No te desampararé, ni te dejaré.",
      reference: "Hebreos 13:5",
      category: "solo",
    ),
    BibleVerse(
      verse: "He aquí, yo estoy con vosotros todos los días, hasta el fin del mundo.",
      reference: "Mateo 28:20",
      category: "solo",
    ),
    BibleVerse(
      verse: "Aunque mi padre y mi madre me dejaran, con todo, Jehová me recogerá.",
      reference: "Salmos 27:10",
      category: "solo",
    ),
    BibleVerse(
      verse: "Cercano está Jehová a los quebrantados de corazón; y salva a los contritos de espíritu.",
      reference: "Salmos 34:18",
      category: "solo",
    ),
  ];

  // 😠 ENOJADO - Para calmar la ira
  static const List<BibleVerse> angryVerses = [
    BibleVerse(
      verse: "Airaos, pero no pequéis; no se ponga el sol sobre vuestro enojo.",
      reference: "Efesios 4:26",
      category: "enojado",
    ),
    BibleVerse(
      verse: "Mejor es el que tarda en airarse que el fuerte; y el que se enseñorea de su espíritu, que el que toma una ciudad.",
      reference: "Proverbios 16:32",
      category: "enojado",
    ),
    BibleVerse(
      verse: "La blanda respuesta quita la ira; mas la palabra áspera hace subir el furor.",
      reference: "Proverbios 15:1",
      category: "enojado",
    ),
    BibleVerse(
      verse: "Todo hombre sea pronto para oír, tardo para hablar, tardo para airarse.",
      reference: "Santiago 1:19",
      category: "enojado",
    ),
  ];

  // 😢 TRISTE - Para momentos de tristeza
  static const List<BibleVerse> sadVerses = [
    BibleVerse(
      verse: "Bienaventurados los que lloran, porque ellos recibirán consolación.",
      reference: "Mateo 5:4",
      category: "triste",
    ),
    BibleVerse(
      verse: "Enjugará Dios toda lágrima de los ojos de ellos.",
      reference: "Apocalipsis 21:4",
      category: "triste",
    ),
    BibleVerse(
      verse: "Por la noche durará el lloro, y a la mañana vendrá la alegría.",
      reference: "Salmos 30:5",
      category: "triste",
    ),
    BibleVerse(
      verse: "Los que sembraron con lágrimas, con regocijo segarán.",
      reference: "Salmos 126:5",
      category: "triste",
    ),
  ];

  // Versículos para momentos de tentación
  static const List<BibleVerse> temptationVerses = [
    BibleVerse(
      verse: "No os ha sobrevenido ninguna tentación que no sea humana; pero fiel es Dios, que no os dejará ser tentados más de lo que podéis resistir, sino que dará también juntamente con la tentación la salida, para que podáis soportar.",
      reference: "1 Corintios 10:13",
      category: "tentación",
    ),
    BibleVerse(
      verse: "Someteos, pues, a Dios; resistid al diablo, y huirá de vosotros.",
      reference: "Santiago 4:7",
      category: "tentación",
    ),
    BibleVerse(
      verse: "Velad y orad, para que no entréis en tentación; el espíritu a la verdad está dispuesto, pero la carne es débil.",
      reference: "Mateo 26:41",
      category: "tentación",
    ),
    BibleVerse(
      verse: "Bienaventurado el varón que soporta la tentación; porque cuando haya resistido la prueba, recibirá la corona de vida.",
      reference: "Santiago 1:12",
      category: "tentación",
    ),
    BibleVerse(
      verse: "Porque no tenemos un sumo sacerdote que no pueda compadecerse de nuestras debilidades, sino uno que fue tentado en todo según nuestra semejanza, pero sin pecado.",
      reference: "Hebreos 4:15",
      category: "tentación",
    ),
  ];

  // Versículos sobre pureza
  static const List<BibleVerse> purityVerses = [
    BibleVerse(
      verse: "Bienaventurados los de limpio corazón, porque ellos verán a Dios.",
      reference: "Mateo 5:8",
      category: "pureza",
    ),
    BibleVerse(
      verse: "Huid de la fornicación. Cualquier otro pecado que el hombre cometa, está fuera del cuerpo; mas el que fornica, contra su propio cuerpo peca.",
      reference: "1 Corintios 6:18",
      category: "pureza",
    ),
    BibleVerse(
      verse: "¿Con qué limpiará el joven su camino? Con guardar tu palabra.",
      reference: "Salmos 119:9",
      category: "pureza",
    ),
    BibleVerse(
      verse: "Crea en mí, oh Dios, un corazón limpio, y renueva un espíritu recto dentro de mí.",
      reference: "Salmos 51:10",
      category: "pureza",
    ),
    BibleVerse(
      verse: "En mi corazón he guardado tus dichos, para no pecar contra ti.",
      reference: "Salmos 119:11",
      category: "pureza",
    ),
  ];

  // Versículos sobre fortaleza
  static const List<BibleVerse> strengthVerses = [
    BibleVerse(
      verse: "Todo lo puedo en Cristo que me fortalece.",
      reference: "Filipenses 4:13",
      category: "fortaleza",
    ),
    BibleVerse(
      verse: "Jehová es mi luz y mi salvación; ¿de quién temeré? Jehová es la fortaleza de mi vida; ¿de quién he de atemorizarme?",
      reference: "Salmos 27:1",
      category: "fortaleza",
    ),
    BibleVerse(
      verse: "El da esfuerzo al cansado, y multiplica las fuerzas al que no tiene ningunas.",
      reference: "Isaías 40:29",
      category: "fortaleza",
    ),
    BibleVerse(
      verse: "Fortaleceos en el Señor, y en el poder de su fuerza.",
      reference: "Efesios 6:10",
      category: "fortaleza",
    ),
    BibleVerse(
      verse: "Cuando soy débil, entonces soy fuerte.",
      reference: "2 Corintios 12:10",
      category: "fortaleza",
    ),
  ];

  // Versículos sobre victoria
  static const List<BibleVerse> victoryVerses = [
    BibleVerse(
      verse: "Mas gracias sean dadas a Dios, que nos da la victoria por medio de nuestro Señor Jesucristo.",
      reference: "1 Corintios 15:57",
      category: "victoria",
    ),
    BibleVerse(
      verse: "Antes, en todas estas cosas somos más que vencedores por medio de aquel que nos amó.",
      reference: "Romanos 8:37",
      category: "victoria",
    ),
    BibleVerse(
      verse: "Porque todo lo que es nacido de Dios vence al mundo; y esta es la victoria que ha vencido al mundo, nuestra fe.",
      reference: "1 Juan 5:4",
      category: "victoria",
    ),
    BibleVerse(
      verse: "Mas a Dios gracias, el cual nos lleva siempre en triunfo en Cristo Jesús.",
      reference: "2 Corintios 2:14",
      category: "victoria",
    ),
    BibleVerse(
      verse: "El que venciere heredará todas las cosas, y yo seré su Dios, y él será mi hijo.",
      reference: "Apocalipsis 21:7",
      category: "victoria",
    ),
  ];

  // Versículos sobre el Espíritu Santo
  static const List<BibleVerse> holySpiriteVerses = [
    BibleVerse(
      verse: "Digo, pues: Andad en el Espíritu, y no satisfagáis los deseos de la carne.",
      reference: "Gálatas 5:16",
      category: "espíritu",
    ),
    BibleVerse(
      verse: "¿O ignoráis que vuestro cuerpo es templo del Espíritu Santo, el cual está en vosotros, el cual tenéis de Dios, y que no sois vuestros?",
      reference: "1 Corintios 6:19",
      category: "espíritu",
    ),
    BibleVerse(
      verse: "Mas el fruto del Espíritu es amor, gozo, paz, paciencia, benignidad, bondad, fe, mansedumbre, templanza.",
      reference: "Gálatas 5:22-23",
      category: "espíritu",
    ),
  ];

  // Obtener todos los versículos
  static List<BibleVerse> get allVerses {
    return [
      ...temptationVerses,
      ...purityVerses,
      ...strengthVerses,
      ...victoryVerses,
      ...holySpiriteVerses,
      ...happyVerses,
      ...anxiousVerses,
      ...gratefulVerses,
      ...lonelyVerses,
      ...angryVerses,
      ...sadVerses,
    ];
  }

  // Obtener versículo aleatorio
  static BibleVerse getRandomVerse() {
    final verses = allVerses;
    verses.shuffle();
    return verses.first;
  }

  // Obtener versículo aleatorio por categoría
  static BibleVerse getRandomVerseByCategory(String category) {
    List<BibleVerse> categoryVerses;
    switch (category.toLowerCase()) {
      case 'tentación':
        categoryVerses = temptationVerses;
        break;
      case 'pureza':
        categoryVerses = purityVerses;
        break;
      case 'fortaleza':
        categoryVerses = strengthVerses;
        break;
      case 'victoria':
        categoryVerses = victoryVerses;
        break;
      case 'espíritu':
        categoryVerses = holySpiriteVerses;
        break;
      // Emociones
      case 'feliz':
        categoryVerses = happyVerses;
        break;
      case 'ansioso':
        categoryVerses = anxiousVerses;
        break;
      case 'agradecido':
        categoryVerses = gratefulVerses;
        break;
      case 'solo':
        categoryVerses = lonelyVerses;
        break;
      case 'enojado':
        categoryVerses = angryVerses;
        break;
      case 'triste':
        categoryVerses = sadVerses;
        break;
      default:
        categoryVerses = allVerses;
    }
    categoryVerses = List.from(categoryVerses)..shuffle();
    return categoryVerses.first;
  }

  // Obtener versículos por emoción
  static List<BibleVerse> getVersesByEmotion(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'feliz':
        return happyVerses;
      case 'ansioso':
        return anxiousVerses;
      case 'agradecido':
        return gratefulVerses;
      case 'solo':
        return lonelyVerses;
      case 'enojado':
        return angryVerses;
      case 'triste':
        return sadVerses;
      default:
        return allVerses;
    }
  }
}
