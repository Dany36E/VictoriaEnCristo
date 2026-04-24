import 'dart:convert';

import 'package:flutter/services.dart';

class Devotional {
  final int day;
  final String title;
  final String verse;
  final String verseReference;
  final String reflection;
  final String challenge;
  final String prayer;

  const Devotional({
    required this.day,
    required this.title,
    required this.verse,
    required this.verseReference,
    required this.reflection,
    required this.challenge,
    required this.prayer,
  });

  factory Devotional.fromJson(Map<String, dynamic> json) => Devotional(
        day: json['day'] as int,
        title: json['title'] as String,
        verse: json['verse'] as String,
        verseReference: json['verseReference'] as String,
        reflection: json['reflection'] as String,
        challenge: json['challenge'] as String,
        prayer: json['prayer'] as String,
      );
}

class Devotionals {
  /// Devocionales por defecto (fallback hardcodeado). Se pueden actualizar
  /// en tiempo de arranque desde `assets/content/devotionals.json` via
  /// [init], sin necesidad de recompilar el c\u00f3digo.
  static const List<Devotional> _fallbackDevotionals = [
    // SEMANA 1: FUNDAMENTOS
    Devotional(
      day: 1,
      title: "El Primer Paso: Reconocer",
      verse: "Si confesamos nuestros pecados, él es fiel y justo para perdonar nuestros pecados, y limpiarnos de toda maldad.",
      verseReference: "1 Juan 1:9",
      reflection: '''El primer paso hacia la libertad es reconocer que tenemos un problema. No podemos superar lo que no admitimos.

Dios no espera que seamos perfectos para acercarnos a Él. Al contrario, quiere que vengamos tal como somos, con nuestras luchas y debilidades.

Cuando confesamos nuestros pecados, Dios es fiel para perdonarnos. No hay pecado tan grande que Su gracia no pueda cubrir.''',
      challenge: "Hoy, toma un momento para ser honesto contigo mismo y con Dios. Escribe en un papel las áreas donde luchas. Luego, entrégalas a Dios en oración.",
      prayer: "Señor, reconozco que he luchado con pensamientos y acciones que no Te agradan. Gracias porque Tu perdón está disponible para mí. Ayúdame a ser honesto contigo cada día. Amén.",
    ),
    Devotional(
      day: 2,
      title: "El Poder de la Palabra",
      verse: "En mi corazón he guardado tus dichos, para no pecar contra ti.",
      verseReference: "Salmos 119:11",
      reflection: '''La Palabra de Dios es nuestra arma más poderosa contra la tentación. Jesús mismo usó las Escrituras cuando fue tentado en el desierto.

Cuando memorizamos versículos bíblicos, estamos llenando nuestra mente con verdad. Esta verdad nos ayuda a reconocer las mentiras del enemigo y a resistir la tentación.

No se trata solo de leer la Biblia, sino de guardarla en nuestro corazón, meditarla y aplicarla a nuestra vida diaria.''',
      challenge: "Memoriza el versículo de hoy. Escríbelo en una tarjeta y léelo varias veces durante el día. Cuando venga la tentación, recita este versículo.",
      prayer: "Padre, ayúdame a amar Tu Palabra y a esconderla en mi corazón. Que sea una lámpara a mis pies y una luz en mi camino. Amén.",
    ),
    Devotional(
      day: 3,
      title: "Correr Hacia la Libertad",
      verse: "Huid de la fornicación. Cualquier otro pecado que el hombre cometa, está fuera del cuerpo; mas el que fornica, contra su propio cuerpo peca.",
      verseReference: "1 Corintios 6:18",
      reflection: '''La Biblia no dice "resiste" la inmoralidad sexual, dice "huye". Pero huir no significa huir con miedo, sino correr hacia algo mejor: la libertad que Cristo ya compró para ti.

Negociar con la tentación suele desgastarnos. No tienes que pelear en su terreno. Puedes simplemente alejarte con paz, sabiendo que no estás escapando de un enemigo más fuerte que tú, sino moviéndote hacia el lugar donde Dios ya ganó la batalla.

José, cuando fue tentado por la esposa de Potifar, no se quedó a discutir ni se castigó por sentir la tentación: se movió. Dejó el manto, siguió caminando. La huida fue un acto de sabiduría, no de cobardía.''',
      challenge: "Con mansedumbre, identifica 1 o 2 situaciones que te exponen innecesariamente. Sin culparte, pon un pequeño límite hoy: eliminar una app, bloquear un sitio, cambiar una rutina. Un paso pequeño es suficiente.",
      prayer: "Padre, gracias porque Tu gracia va delante de mí. Dame ojos para reconocer los terrenos difíciles y pies libres para alejarme sin pelear. No quiero negociar con lo que me aleja de Ti; quiero correr hacia Ti. Amén.",
    ),
    Devotional(
      day: 4,
      title: "No Estás Solo",
      verse: "Confesaos vuestras ofensas unos a otros, y orad unos por otros, para que seáis sanados.",
      verseReference: "Santiago 5:16",
      reflection: '''Una de las tácticas del enemigo es hacerte creer que estás solo en esta lucha, que nadie más entiende.

Pero la verdad es que millones de personas luchan con los mismos problemas. No eres el único, y no tienes que luchar solo.

La comunidad y la rendición de cuentas son cruciales para la victoria. Cuando tenemos a alguien de confianza con quien hablar, la tentación pierde poder.''',
      challenge: "Si no tienes a alguien de confianza con quien hablar, ora para que Dios ponga a esa persona en tu vida. Si ya tienes a alguien, contáctalo hoy y sé honesto sobre tu lucha.",
      prayer: "Padre, gracias porque no tengo que luchar solo. Ayúdame a encontrar comunidad y a ser vulnerable con personas de confianza. Rompe el aislamiento en mi vida. Amén.",
    ),
    Devotional(
      day: 5,
      title: "Renovando la Mente",
      verse: "No os conforméis a este siglo, sino transformaos por medio de la renovación de vuestro entendimiento.",
      verseReference: "Romanos 12:2",
      reflection: '''La batalla contra la tentación comienza en la mente. Lo que pensamos determina lo que hacemos.

El mundo constantemente bombardea nuestra mente con imágenes y mensajes que normalizan el pecado. Debemos ser intencionales en renovar nuestra mente con la verdad de Dios.

La transformación es un proceso. No sucede de la noche a la mañana, pero cada día podemos elegir alimentar nuestra mente con cosas que edifican.''',
      challenge: "Haz un inventario de lo que consumes: redes sociales, programas de TV, música, etc. Elimina o reduce lo que no te ayuda a crecer espiritualmente.",
      prayer: "Señor, renueva mi mente. Ayúdame a pensar en todo lo que es verdadero, honesto, justo, puro y amable. Transforma mis pensamientos para que reflejen Tu verdad. Amén.",
    ),
    Devotional(
      day: 6,
      title: "El Propósito Mayor",
      verse: "¿O ignoráis que vuestro cuerpo es templo del Espíritu Santo, el cual está en vosotros, el cual tenéis de Dios, y que no sois vuestros?",
      verseReference: "1 Corintios 6:19",
      reflection: '''Tu cuerpo no es tuyo. Fue comprado por precio, la sangre de Jesús.

Cuando entendemos que somos templo del Espíritu Santo, nuestra perspectiva cambia. Ya no se trata solo de evitar el pecado, sino de honrar a Dios con nuestro cuerpo.

Tienes un propósito mayor. Dios quiere usarte para Su gloria. Pero el pecado nos roba la efectividad y nos aleja de nuestro llamado.''',
      challenge: "Hoy, cada vez que sientas tentación, recuerda: 'Mi cuerpo es templo del Espíritu Santo'. Escribe esta verdad donde puedas verla frecuentemente.",
      prayer: "Señor, gracias porque Tu Espíritu vive en mí. Ayúdame a tratarme como Tu templo, a cuidar mi cuerpo y a usarlo para Tu gloria. Amén.",
    ),
    Devotional(
      day: 7,
      title: "Victoria en Cristo",
      verse: "Mas gracias sean dadas a Dios, que nos da la victoria por medio de nuestro Señor Jesucristo.",
      verseReference: "1 Corintios 15:57",
      reflection: '''La victoria ya fue ganada en la cruz. Jesús venció el pecado y la muerte.

No luchamos PARA obtener la victoria, luchamos DESDE la victoria. Cristo ya ganó, y nosotros participamos de esa victoria.

Esto no significa que no tendremos luchas, pero significa que el resultado final ya está determinado. En Cristo, somos más que vencedores.''',
      challenge: "Celebra cada pequeña victoria. Cada día que resistes la tentación es un día de triunfo. Agradece a Dios por Su fidelidad y sigue adelante.",
      prayer: "Gracias Señor porque la victoria es mía en Cristo Jesús. Declaro que soy más que vencedor. Aunque caiga, me levantaré, porque Tú estás conmigo. Amén.",
    ),
    // SEMANA 2: PROFUNDIZANDO
    Devotional(
      day: 8,
      title: "La Armadura de Dios",
      verse: "Vestíos de toda la armadura de Dios, para que podáis estar firmes contra las asechanzas del diablo.",
      verseReference: "Efesios 6:11",
      reflection: '''Dios no nos dejó indefensos. Nos ha dado una armadura completa para la batalla espiritual.

Cada pieza tiene un propósito: el cinturón de la verdad, la coraza de justicia, el calzado del evangelio, el escudo de la fe, el yelmo de la salvación, y la espada del Espíritu.

No es opcional usar esta armadura. Es necesaria para la victoria.''',
      challenge: "Lee Efesios 6:10-18. Identifica cada pieza de la armadura y cómo aplicarla en tu vida.",
      prayer: "Padre, ayúdame a vestirme cada día con Tu armadura completa. Amén.",
    ),
    Devotional(
      day: 9,
      title: "El Poder de la Oración",
      verse: "Velad y orad, para que no entréis en tentación.",
      verseReference: "Mateo 26:41",
      reflection: '''Jesús nos dio la fórmula: velar y orar. No solo orar, sino también estar alertas.

La oración no es solo pedir cosas. Es conexión con Dios. Es dependencia de Él.

Cuando oramos, reconocemos nuestra debilidad y la fortaleza de Dios.''',
      challenge: "Establece un tiempo fijo de oración cada día. Aunque sean solo 5 minutos, sé constante.",
      prayer: "Señor, enséñame a orar. Quiero depender de Ti en todo momento. Amén.",
    ),
    Devotional(
      day: 10,
      title: "Gracia Suficiente",
      verse: "Bástate mi gracia; porque mi poder se perfecciona en la debilidad.",
      verseReference: "2 Corintios 12:9",
      reflection: '''Pablo tenía un "aguijón en la carne". Pidió tres veces que fuera quitado.

Pero Dios le dijo que Su gracia era suficiente. En nuestra debilidad, Su poder se manifiesta.

No tienes que ser fuerte. Solo tienes que depender de Él.''',
      challenge: "Cuando te sientas débil, en vez de frustrarte, agradece. Es ahí donde Dios obra.",
      prayer: "Señor, cuando soy débil, entonces soy fuerte en Ti. Tu gracia me basta. Amén.",
    ),
    Devotional(
      day: 11,
      title: "Pensamientos Cautivos",
      verse: "Llevando cautivo todo pensamiento a la obediencia a Cristo.",
      verseReference: "2 Corintios 10:5",
      reflection: '''La batalla se gana o se pierde en la mente. Los pensamientos preceden a las acciones.

Debemos aprender a capturar los pensamientos antes de que se conviertan en fantasías.

No podemos evitar que un pájaro vuele sobre nuestra cabeza, pero sí podemos evitar que haga nido.''',
      challenge: "Cuando venga un pensamiento impuro, reemplázalo inmediatamente con un versículo.",
      prayer: "Padre, ayúdame a llevar cautivo todo pensamiento. Dame control sobre mi mente. Amén.",
    ),
    Devotional(
      day: 12,
      title: "El Fruto del Espíritu",
      verse: "Mas el fruto del Espíritu es amor, gozo, paz, paciencia, benignidad, bondad, fe, mansedumbre, templanza.",
      verseReference: "Gálatas 5:22-23",
      reflection: '''El dominio propio (templanza) es fruto del Espíritu, no de nuestra fuerza de voluntad.

No podemos producir este fruto por nosotros mismos. Solo el Espíritu puede producirlo en nosotros.

Nuestra parte es permanecer conectados a la vid, que es Cristo.''',
      challenge: "Pide al Espíritu Santo que produzca más dominio propio en tu vida.",
      prayer: "Espíritu Santo, produce en mí el fruto de la templanza. Sin Ti nada puedo. Amén.",
    ),
    Devotional(
      day: 13,
      title: "Libertad Verdadera",
      verse: "Así que, si el Hijo os libertare, seréis verdaderamente libres.",
      verseReference: "Juan 8:36",
      reflection: '''El mundo ofrece una falsa libertad: "haz lo que quieras". Pero eso es esclavitud.

La verdadera libertad es poder decir NO al pecado. Es vivir sin cadenas.

Cristo vino a darnos esa libertad.''',
      challenge: "Define qué significa la libertad para ti. ¿Cómo sería tu vida libre de este pecado?",
      prayer: "Señor Jesús, gracias por la libertad que me das. Ayúdame a caminar en ella. Amén.",
    ),
    Devotional(
      day: 14,
      title: "Dos Semanas de Victoria",
      verse: "El que comenzó en vosotros la buena obra, la perfeccionará hasta el día de Jesucristo.",
      verseReference: "Filipenses 1:6",
      reflection: '''¡Dos semanas! Estás creando nuevos patrones en tu cerebro.

Dios no te va a dejar a medias. Él que comenzó la obra la va a completar.

Cada día de victoria es un paso más hacia la libertad permanente.''',
      challenge: "Celebra este hito. Escribe cómo te sientes después de dos semanas.",
      prayer: "Gracias Señor por estas dos semanas. Sé que Tú completarás la obra en mí. Amén.",
    ),
    // SEMANA 3: CRECIENDO
    Devotional(
      day: 15,
      title: "Cuidando los Ojos",
      verse: "Hice pacto con mis ojos; ¿cómo, pues, había yo de mirar a una virgen?",
      verseReference: "Job 31:1",
      reflection: '''Job, un hombre justo, hizo un pacto con sus ojos. Sabía que la batalla comienza con lo que miramos.

En la era digital, este pacto es más necesario que nunca.

Debemos ser intencionales en guardar nuestra vista.''',
      challenge: "Haz un pacto con tus ojos hoy. Declara en voz alta tu compromiso.",
      prayer: "Señor, hago pacto con mis ojos. Ayúdame a mirar solo lo que Te agrada. Amén.",
    ),
    Devotional(
      day: 16,
      title: "El Peligro del Aislamiento",
      verse: "Mejores son dos que uno; porque tienen mejor paga de su trabajo.",
      verseReference: "Eclesiastés 4:9",
      reflection: '''El enemigo quiere aislarte. En el aislamiento es donde caemos más fácilmente.

Necesitamos comunidad. Necesitamos hermanos que nos levanten cuando caemos.

No fuimos diseñados para caminar solos.''',
      challenge: "Busca a alguien con quien puedas ser transparente.",
      prayer: "Padre, rompe el aislamiento en mi vida. Dame hermanos con quien caminar. Amén.",
    ),
    Devotional(
      day: 17,
      title: "Llenando el Vacío",
      verse: "Yo soy el pan de vida; el que a mí viene, nunca tendrá hambre.",
      verseReference: "Juan 6:35",
      reflection: '''A menudo, la tentación sexual es un intento de llenar un vacío: soledad, aburrimiento, estrés.

Pero ningún placer temporal puede satisfacer el alma. Solo Jesús puede llenar el vacío.

Cuando identificamos qué vacío estamos tratando de llenar, podemos ir a la fuente correcta.''',
      challenge: "La próxima vez que sientas tentación, pregúntate: ¿qué vacío estoy tratando de llenar?",
      prayer: "Señor, solo Tú puedes satisfacer mi alma. Llena cada vacío con Tu presencia. Amén.",
    ),
    Devotional(
      day: 18,
      title: "El Perdón Continuo",
      verse: "Cuanto está lejos el oriente del occidente, hizo alejar de nosotros nuestras rebeliones.",
      verseReference: "Salmo 103:12",
      reflection: '''Cuando caemos, el enemigo quiere que nos revolquemos en la culpa. Pero eso no es de Dios.

Dios perdona completamente. No guarda registro de nuestros pecados perdonados.

Levántate, confiesa, recibe el perdón, y sigue adelante.''',
      challenge: "Si has caído, no te quedes en la culpa. Confiesa, levántate, y continúa.",
      prayer: "Gracias Señor porque Tu perdón es completo. Me levanto y sigo adelante. Amén.",
    ),
    Devotional(
      day: 19,
      title: "Disciplinas Espirituales",
      verse: "Ejercítate para la piedad.",
      verseReference: "1 Timoteo 4:7",
      reflection: '''Los atletas entrenan diariamente. Nosotros también debemos ejercitar nuestra fe.

Las disciplinas espirituales (oración, lectura, ayuno, comunidad) nos fortalecen.

No son para ganar el favor de Dios, sino para crecer en Él.''',
      challenge: "Añade una nueva disciplina espiritual a tu rutina esta semana.",
      prayer: "Señor, quiero crecer en Ti. Ayúdame a ser disciplinado. Amén.",
    ),
    Devotional(
      day: 20,
      title: "Gratitud en la Lucha",
      verse: "Dad gracias en todo, porque esta es la voluntad de Dios para con vosotros.",
      verseReference: "1 Tesalonicenses 5:18",
      reflection: '''¿Dar gracias en medio de la lucha? Parece contradictorio.

Pero la gratitud cambia nuestra perspectiva. Nos enfoca en lo que Dios ha hecho.

Aunque la batalla es real, tenemos mucho por qué agradecer.''',
      challenge: "Escribe 10 cosas por las que estás agradecido hoy.",
      prayer: "Gracias Señor por todo. Incluso por esta lucha que me acerca más a Ti. Amén.",
    ),
    Devotional(
      day: 21,
      title: "Tres Semanas de Crecimiento",
      verse: "Creced en la gracia y el conocimiento de nuestro Señor y Salvador Jesucristo.",
      verseReference: "2 Pedro 3:18",
      reflection: '''Tres semanas. 21 días. Se dice que se necesitan 21 días para formar un hábito.

Estás estableciendo nuevos patrones de pensamiento y comportamiento.

El crecimiento espiritual es un proceso, y estás en el camino correcto.''',
      challenge: "Reflexiona sobre cómo has crecido en estas tres semanas. ¿Qué ha cambiado?",
      prayer: "Señor, gracias por el crecimiento. Continúa Tu obra en mí. Amén.",
    ),
    // SEMANA 4: FORTALECIENDO
    Devotional(
      day: 22,
      title: "Guardando el Corazón",
      verse: "Sobre toda cosa guardada, guarda tu corazón; porque de él mana la vida.",
      verseReference: "Proverbios 4:23",
      reflection: '''El corazón es el centro de todo. De él fluyen nuestros pensamientos, palabras y acciones.

Debemos proteger nuestro corazón de influencias que lo contaminen.

Lo que permitimos entrar a nuestro corazón determinará lo que sale de él.''',
      challenge: "¿Qué estás permitiendo que entre a tu corazón? Evalúa y haz ajustes.",
      prayer: "Señor, ayúdame a guardar mi corazón. Que solo entre lo que Te glorifica. Amén.",
    ),
    Devotional(
      day: 23,
      title: "Fortaleza en la Debilidad",
      verse: "Todo lo puedo en Cristo que me fortalece.",
      verseReference: "Filipenses 4:13",
      reflection: '''Este versículo no dice "todo lo puedo por mi fuerza de voluntad".

La fortaleza viene de Cristo. No de nuestro esfuerzo humano.

Cuando dependemos de Él, podemos hacer lo que no podríamos solos.''',
      challenge: "Memoriza Filipenses 4:13. Recítalo cuando te sientas débil.",
      prayer: "Señor, en Ti encuentro mi fortaleza. Sin Ti nada puedo, pero contigo todo. Amén.",
    ),
    Devotional(
      day: 24,
      title: "Restauración Completa",
      verse: "Y os restituiré los años que comió la oruga.",
      verseReference: "Joel 2:25",
      reflection: '''El enemigo ha robado tiempo, energía, relaciones. Pero Dios es restaurador.

Él puede redimir lo que se perdió. Puede convertir las cenizas en belleza.

Tu pasado no define tu futuro cuando Dios está en control.''',
      challenge: "Confía en que Dios puede restaurar lo que el pecado ha dañado.",
      prayer: "Señor, restaura los años perdidos. Convierte mi historia en un testimonio. Amén.",
    ),
    Devotional(
      day: 25,
      title: "Propósito Eterno",
      verse: "Porque yo sé los pensamientos que tengo acerca de vosotros, pensamientos de paz, y no de mal.",
      verseReference: "Jeremías 29:11",
      reflection: '''Dios tiene planes para ti. Buenos planes. Planes de esperanza y futuro.

El pecado intenta robarte ese propósito. Pero Dios es mayor.

Tu lucha de hoy es parte de tu testimonio de mañana.''',
      challenge: "Escribe cuál crees que es el propósito de Dios para tu vida.",
      prayer: "Padre, ayúdame a cumplir el propósito para el cual me creaste. Amén.",
    ),
    Devotional(
      day: 26,
      title: "La Comunidad que Sana",
      verse: "Sobrellevad los unos las cargas de los otros, y cumplid así la ley de Cristo.",
      verseReference: "Gálatas 6:2",
      reflection: '''No fuimos creados para cargar solos. Necesitamos hermanos.

La vulnerabilidad es difícil, pero es necesaria para la sanidad.

Cuando compartimos nuestras cargas, se hacen más livianas.''',
      challenge: "Comparte tu carga con alguien de confianza esta semana.",
      prayer: "Señor, dame el valor de ser vulnerable. Ayúdame a encontrar comunidad. Amén.",
    ),
    Devotional(
      day: 27,
      title: "Identidad en Cristo",
      verse: "Mas vosotros sois linaje escogido, real sacerdocio, nación santa.",
      verseReference: "1 Pedro 2:9",
      reflection: '''Tu identidad no está en tu pecado. Está en Cristo.

Eres escogido. Eres sacerdote real. Eres santo.

No pelees desde la derrota. Pelea desde quien eres en Cristo.''',
      challenge: "Declara en voz alta quién eres en Cristo: escogido, amado, perdonado, libre.",
      prayer: "Gracias Señor por mi identidad en Ti. Soy quien Tú dices que soy. Amén.",
    ),
    Devotional(
      day: 28,
      title: "Casi Un Mes",
      verse: "No nos cansemos, pues, de hacer bien; porque a su tiempo segaremos, si no desmayamos.",
      verseReference: "Gálatas 6:9",
      reflection: '''Cuatro semanas de lucha intencional. ¡Increíble!

No te canses de hacer lo correcto. La cosecha viene.

Cada día de victoria suma. No desmayez.''',
      challenge: "Escribe cómo te sientes al llegar a este punto. Celebra tu progreso.",
      prayer: "Señor, no me dejes desmayar. Ayúdame a perseverar hasta el final. Amén.",
    ),
    Devotional(
      day: 29,
      title: "Testimonio de Victoria",
      verse: "Y ellos le han vencido por medio de la sangre del Cordero y de la palabra del testimonio de ellos.",
      verseReference: "Apocalipsis 12:11",
      reflection: '''Tu testimonio es poderoso. Tu historia puede ayudar a otros.

Lo que has aprendido en esta lucha puede ser luz para alguien más.

Dios redime nuestras luchas para bendición de otros.''',
      challenge: "Piensa en cómo tu testimonio podría ayudar a alguien que lucha igual.",
      prayer: "Señor, usa mi historia para Tu gloria y para ayudar a otros. Amén.",
    ),
    Devotional(
      day: 30,
      title: "Un Mes de Victoria",
      verse: "Bienaventurado el varón que soporta la tentación; porque cuando haya resistido la prueba, recibirá la corona de vida.",
      verseReference: "Santiago 1:12",
      reflection: '''¡UN MES! 30 días de lucha, de victorias, de crecimiento.

La corona de vida espera a los que perseveran. Estás en el camino.

Esto no termina aquí. Cada día es una nueva oportunidad de victoria.''',
      challenge: "Comprométete a continuar. Establece metas para los próximos 30 días.",
      prayer: "Gracias Señor por este mes. La victoria es posible en Ti. Continúo adelante. Amén.",
    ),
  ];

  /// Lista viva: inicia con el fallback y se reemplaza tras [init].
  static List<Devotional> _cache = List<Devotional>.unmodifiable(_fallbackDevotionals);
  static bool _initialized = false;

  /// Carga los devocionales desde el asset JSON. Si falla, se conserva el
  /// fallback hardcodeado. Seguro de llamar m\u00e1s de una vez.
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final raw = await rootBundle.loadString('assets/content/devotionals.json');
      final data = jsonDecode(raw) as List<dynamic>;
      final parsed = data
          .map((e) => Devotional.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      if (parsed.isNotEmpty) {
        _cache = List<Devotional>.unmodifiable(parsed);
      }
    } catch (_) {
      // Mantener fallback silenciosamente; el app debe seguir funcionando.
    }
  }

  static List<Devotional> get allDevotionals => _cache;

  static List<Devotional> get weeklyDevotionals => allDevotionals.take(7).toList();
  
  static int get totalDays => allDevotionals.length;

  static Devotional getDevotionalForDay(int dayNumber) {
    final index = (dayNumber - 1) % allDevotionals.length;
    return allDevotionals[index];
  }

  static List<Devotional> getDevotionalsForWeek(int weekNumber) {
    final startIndex = (weekNumber - 1) * 7;
    final endIndex = startIndex + 7;
    if (startIndex >= allDevotionals.length) return [];
    return allDevotionals.sublist(
      startIndex, 
      endIndex > allDevotionals.length ? allDevotionals.length : endIndex
    );
  }

  static int get totalWeeks => (allDevotionals.length / 7).ceil();
}
