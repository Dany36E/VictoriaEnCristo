import 'dart:math';

class BibleVerse {
  final String verse;
  final String reference;
  final String category;

  /// Sigla de la versión del texto (p. ej. «RVR60»). Vacía si no aplica.
  /// No se guarda en JSON: es solo para mostrarla.
  final String version;

  const BibleVerse({
    required this.verse,
    required this.reference,
    required this.category,
    this.version = '',
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
    BibleVerse(
      verse: "Regocijaos en el Señor siempre. Otra vez digo: ¡Regocijaos!",
      reference: "Filipenses 4:4",
      category: "feliz",
    ),
    BibleVerse(
      verse: "Tú diste alegría a mi corazón Mayor que la de ellos cuando abundaba su grano y su mosto.",
      reference: "Salmos 4:7",
      category: "feliz",
    ),
    BibleVerse(
      verse: "Deléitate asimismo en Jehová, Y él te concederá las peticiones de tu corazón.",
      reference: "Salmos 37:4",
      category: "feliz",
    ),
    BibleVerse(
      verse: "El corazón alegre constituye buen remedio; Mas el espíritu triste seca los huesos.",
      reference: "Proverbios 17:22",
      category: "feliz",
    ),
    BibleVerse(
      verse: "Cantad alegres a Dios, habitantes de toda la tierra. Servid a Jehová con alegría; Venid ante su presencia con regocijo.",
      reference: "Salmos 100:1-2",
      category: "feliz",
    ),
    BibleVerse(
      verse: "Grandes cosas ha hecho Jehová con nosotros; Estaremos alegres.",
      reference: "Salmos 126:3",
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
    BibleVerse(
      verse: "Así que, no os afanéis por el día de mañana, porque el día de mañana traerá su afán. Basta a cada día su propio mal.",
      reference: "Mateo 6:34",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "En la multitud de mis pensamientos dentro de mí, Tus consolaciones alegraban mi alma.",
      reference: "Salmos 94:19",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "En el día que temo, Yo en ti confío.",
      reference: "Salmos 56:3",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "No temas, porque yo estoy contigo; no desmayes, porque yo soy tu Dios que te esfuerzo; siempre te ayudaré, siempre te sustentaré con la diestra de mi justicia.",
      reference: "Isaías 41:10",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "Venid a mí todos los que estáis trabajados y cargados, y yo os haré descansar.",
      reference: "Mateo 11:28",
      category: "ansioso",
    ),
    BibleVerse(
      verse: "Echa sobre Jehová tu carga, y él te sustentará; No dejará para siempre caído al justo.",
      reference: "Salmos 55:22",
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
    BibleVerse(
      verse: "Entrad por sus puertas con acción de gracias, Por sus atrios con alabanza; Alabadle, bendecid su nombre.",
      reference: "Salmos 100:4",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "Y todo lo que hacéis, sea de palabra o de hecho, hacedlo todo en el nombre del Señor Jesús, dando gracias a Dios Padre por medio de él.",
      reference: "Colosenses 3:17",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "Dando siempre gracias por todo al Dios y Padre, en el nombre de nuestro Señor Jesucristo.",
      reference: "Efesios 5:20",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "Alabad a Jehová, porque él es bueno; Porque para siempre es su misericordia.",
      reference: "Salmos 107:1",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "¡Gracias a Dios por su don inefable!",
      reference: "2 Corintios 9:15",
      category: "agradecido",
    ),
    BibleVerse(
      verse: "Te alabaré, oh Jehová, con todo mi corazón; Contaré todas tus maravillas.",
      reference: "Salmos 9:1",
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
    BibleVerse(
      verse: "Y Jehová va delante de ti; él estará contigo, no te dejará, ni te desamparará; no temas ni te intimides.",
      reference: "Deuteronomio 31:8",
      category: "solo",
    ),
    BibleVerse(
      verse: "Cuando pases por las aguas, yo estaré contigo; y si por los ríos, no te anegarán. Cuando pases por el fuego, no te quemarás, ni la llama arderá en ti.",
      reference: "Isaías 43:2",
      category: "solo",
    ),
    BibleVerse(
      verse: "Con todo, yo siempre estuve contigo; Me tomaste de la mano derecha.",
      reference: "Salmos 73:23",
      category: "solo",
    ),
    BibleVerse(
      verse: "No os dejaré huérfanos; vendré a vosotros.",
      reference: "Juan 14:18",
      category: "solo",
    ),
    BibleVerse(
      verse: "Aunque ande en valle de sombra de muerte, No temeré mal alguno, porque tú estarás conmigo; Tu vara y tu cayado me infundirán aliento.",
      reference: "Salmos 23:4",
      category: "solo",
    ),
    BibleVerse(
      verse: "Cercano está Jehová a todos los que le invocan, A todos los que le invocan de veras.",
      reference: "Salmos 145:18",
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
    BibleVerse(
      verse: "Deja la ira, y desecha el enojo; No te excites en manera alguna a hacer lo malo.",
      reference: "Salmos 37:8",
      category: "enojado",
    ),
    BibleVerse(
      verse: "La cordura del hombre detiene su furor, Y su honra es pasar por alto la ofensa.",
      reference: "Proverbios 19:11",
      category: "enojado",
    ),
    BibleVerse(
      verse: "Quítense de vosotros toda amargura, enojo, ira, gritería y maledicencia, y toda malicia.",
      reference: "Efesios 4:31",
      category: "enojado",
    ),
    BibleVerse(
      verse: "Pero ahora dejad también vosotros todas estas cosas: ira, enojo, malicia, blasfemia, palabras deshonestas de vuestra boca.",
      reference: "Colosenses 3:8",
      category: "enojado",
    ),
    BibleVerse(
      verse: "No te apresures en tu espíritu a enojarte; porque el enojo reposa en el seno de los necios.",
      reference: "Eclesiastés 7:9",
      category: "enojado",
    ),
    BibleVerse(
      verse: "No seas vencido de lo malo, sino vence con el bien el mal.",
      reference: "Romanos 12:21",
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
    BibleVerse(
      verse: "¿Por qué te abates, oh alma mía, Y por qué te turbas dentro de mí? Espera en Dios; porque aún he de alabarle, Salvación mía y Dios mío.",
      reference: "Salmos 42:11",
      category: "triste",
    ),
    BibleVerse(
      verse: "Él sana a los quebrantados de corazón, Y venda sus heridas.",
      reference: "Salmos 147:3",
      category: "triste",
    ),
    BibleVerse(
      verse: "También vosotros ahora tenéis tristeza; pero os volveré a ver, y se gozará vuestro corazón, y nadie os quitará vuestro gozo.",
      reference: "Juan 16:22",
      category: "triste",
    ),
    BibleVerse(
      verse: "Bendito sea el Dios y Padre de nuestro Señor Jesucristo, Padre de misericordias y Dios de toda consolación, el cual nos consuela en todas nuestras tribulaciones, para que podamos también nosotros consolar a los que están en cualquier tribulación, por medio de la consolación con que nosotros somos consolados por Dios.",
      reference: "2 Corintios 1:3-4",
      category: "triste",
    ),
    BibleVerse(
      verse: "Has cambiado mi lamento en baile; Desataste mi cilicio, y me ceñiste de alegría.",
      reference: "Salmos 30:11",
      category: "triste",
    ),
    BibleVerse(
      verse: "Mi carne y mi corazón desfallecen; Mas la roca de mi corazón y mi porción es Dios para siempre.",
      reference: "Salmos 73:26",
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

  /// Último versículo mostrado por categoría (frasco de emociones), para no
  /// sacar el mismo papelito dos veces seguidas.
  static final Map<String, BibleVerse> _ultimoPorCategoria = {};

  /// Obtener versículo aleatorio por categoría, distinto del último que se
  /// mostró para esa misma categoría (si hay más de uno).
  static BibleVerse getRandomVerseByCategory(String category, {Random? random}) {
    final clave = category.toLowerCase();
    final candidatos = versesForCategory(clave);
    final ultimo = _ultimoPorCategoria[clave];
    final opciones = candidatos.length > 1 && ultimo != null
        ? candidatos.where((v) => v != ultimo).toList()
        : candidatos;
    final elegido = opciones[(random ?? Random()).nextInt(opciones.length)];
    _ultimoPorCategoria[clave] = elegido;
    return elegido;
  }

  /// Olvida el último versículo mostrado (pruebas).
  static void reiniciarUltimosMostrados() => _ultimoPorCategoria.clear();

  /// Lista de versículos de una categoría (tema o emoción).
  static List<BibleVerse> versesForCategory(String category) {
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
    return categoryVerses;
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
