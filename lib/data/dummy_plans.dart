/// ═══════════════════════════════════════════════════════════════════════════
/// DUMMY PLANS - Base de Datos de Planes Espirituales
/// 12 Planes con duraciones variables y contenido semántico coherente
/// ═══════════════════════════════════════════════════════════════════════════
library;

import '../constants/image_urls.dart';

/// Representa un día individual dentro de un plan
class DayPlan {
  final int dayNumber;
  final String title;
  final String content;
  final String scripture;
  final String scriptureReference;
  bool isLocked;
  bool isCompleted;

  DayPlan({
    required this.dayNumber,
    required this.title,
    required this.content,
    required this.scripture,
    required this.scriptureReference,
    this.isLocked = true,
    this.isCompleted = false,
  });

  DayPlan copyWith({bool? isLocked, bool? isCompleted}) {
    return DayPlan(
      dayNumber: dayNumber,
      title: title,
      content: content,
      scripture: scripture,
      scriptureReference: scriptureReference,
      isLocked: isLocked ?? this.isLocked,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

/// Modelo principal para un Plan Espiritual
class SpiritualPlan {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String image;
  final int days;
  final String category;
  final String difficulty;
  List<DayPlan> daysList;

  SpiritualPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.image,
    required this.days,
    required this.category,
    required this.difficulty,
    required this.daysList,
  });

  /// Obtiene el primer día no completado
  int get currentDayIndex {
    for (int i = 0; i < daysList.length; i++) {
      if (!daysList[i].isCompleted) return i;
    }
    return daysList.length - 1;
  }

  /// Progreso del plan (0.0 - 1.0)
  double get progress {
    if (daysList.isEmpty) return 0.0;
    int completed = daysList.where((d) => d.isCompleted).length;
    return completed / daysList.length;
  }

  /// Verifica si el plan está completado
  bool get isCompleted => daysList.every((d) => d.isCompleted);

  /// Verifica si el plan ha sido iniciado
  bool get isStarted => daysList.any((d) => d.isCompleted || !d.isLocked);
}

/// ═══════════════════════════════════════════════════════════════════════════
/// CLASE PRINCIPAL CON TODOS LOS PLANES
/// ═══════════════════════════════════════════════════════════════════════════

class DummyPlans {
  // Imágenes centralizadas en ImageUrls
  static const String _imgArmadura = ImageUrls.planArmadura;
  static const String _imgMente = ImageUrls.planMente;
  static const String _imgFuego = ImageUrls.planFuego;
  static const String _imgCadenas = ImageUrls.planCadenas;
  static const String _imgPaz = ImageUrls.planPaz;
  static const String _imgIdentidad = ImageUrls.planIdentidad;
  static const String _imgSilencio = ImageUrls.planSilencio;
  static const String _imgTesoros = ImageUrls.planTesoros;
  static const String _imgLengua = ImageUrls.planLengua;
  static const String _imgAmor = ImageUrls.planAmor;
  static const String _imgPureza = ImageUrls.planPureza;
  static const String _imgDescanso = ImageUrls.planDescanso;

  static List<SpiritualPlan> allPlans = [
    // ═══════════════════════════════════════════════════════════════════════
    // 3 DÍAS - URGENTE
    // ═══════════════════════════════════════════════════════════════════════
    
    // 1. CALMA EN LA TORMENTA (3 días)
    SpiritualPlan(
      id: 'calma-tormenta',
      title: 'Calma en la Tormenta',
      subtitle: 'Paz sobrenatural en medio de la crisis',
      description: 'Las olas rugen. El viento azota. Todo parece hundirse. Pero Jesús sigue en la barca contigo.',
      image: _imgPaz,
      days: 3,
      category: 'Fortaleza del Corazón',
      difficulty: 'Principiante',
      daysList: [
        DayPlan(
          dayNumber: 1,
          title: 'Jesús en la Barca',
          scripture: 'Él se levantó, reprendió al viento y dijo al mar: ¡Calla, enmudece! Y el viento cesó, y se hizo grande bonanza.',
          scriptureReference: 'Marcos 4:39',
          content: '''Imagina la escena: una tormenta furiosa, olas que amenazan con hundir la barca, discípulos aterrados... y Jesús durmiendo plácidamente en la popa.

¿Cómo podía dormir en medio del caos? Porque conocía algo que los discípulos habían olvidado: la tormenta no tenía la última palabra.

Hoy, quizás sientes que las olas de la vida están a punto de hundirte. Problemas financieros, conflictos familiares, ansiedad que no te deja dormir. Y te preguntas: ¿Dónde está Dios en todo esto?

La verdad es que Jesús sigue en tu barca. No está dormido porque no le importe, sino porque tiene autoridad absoluta sobre cada tormenta. Él puede calmar las aguas con una palabra.

Tu trabajo hoy no es resolver la tormenta. Es recordar quién está contigo en ella.

REFLEXIÓN:
¿Qué tormenta estás enfrentando ahora mismo? ¿Has invitado a Jesús a hablar paz sobre ella?

ORACIÓN:
Señor Jesús, confieso que a veces me siento abrumado por las tormentas de la vida. Hoy elijo recordar que tú estás en mi barca. Habla paz sobre mi situación. Calma mi corazón aunque las circunstancias no cambien inmediatamente. Confío en tu autoridad. Amén.''',
          isLocked: false,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 2,
          title: 'El Ancla del Alma',
          scripture: 'La cual tenemos como segura y firme ancla del alma.',
          scriptureReference: 'Hebreos 6:19',
          content: '''Un barco sin ancla es juguete de las olas. Va a donde el viento lo lleve, sin control, sin dirección.

Muchas personas viven así espiritualmente. Cuando vienen los vientos de adversidad, son arrastrados por el miedo. Cuando soplan vientos de tentación, se dejan llevar. Sin ancla, todo es inestabilidad.

Pero Dios te ha dado un ancla: la esperanza segura en sus promesas. Esta ancla no está clavada en el fondo del mar, sino en el cielo mismo. Penetra hasta donde está Jesús, intercediendo por ti.

El ancla no elimina la tormenta. El ancla te mantiene firme DURANTE la tormenta. Las olas pueden rugir, el viento puede aullar, pero tú no te moverás de tu posición en Cristo.

Hoy, revisa dónde está tu ancla. ¿Está en tus finanzas? Se hundirán. ¿En tu trabajo? Puede desaparecer. ¿En tus relaciones? Son imperfectas. Solo hay un lugar seguro para anclar tu alma: las promesas inmutables de Dios.

REFLEXIÓN:
¿En qué has estado anclando tu paz y seguridad? ¿Qué pasaría si eso fallara?

ORACIÓN:
Padre, confieso que a veces anclo mi seguridad en cosas temporales. Hoy elijo anclar mi alma en tus promesas que nunca fallan. Tú eres mi roca, mi fortaleza, mi refugio seguro. Aunque todo tiemble, tú permaneces. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 3,
          title: 'Paz que Sobrepasa',
          scripture: 'Y la paz de Dios, que sobrepasa todo entendimiento, guardará vuestros corazones y vuestros pensamientos en Cristo Jesús.',
          scriptureReference: 'Filipenses 4:7',
          content: '''Hay una paz que el mundo puede dar: la paz de las circunstancias favorables. Cuando todo va bien, te sientes tranquilo. Pero esta paz es frágil. Una mala noticia la destruye.

Y hay otra paz. Una paz que no tiene explicación lógica. Una paz que permanece cuando todo a tu alrededor es caos. Esta es la paz de Dios.

Pablo escribe desde la cárcel, encadenado, sin saber si vivirá o morirá. Y desde ahí nos enseña el secreto de la paz sobrenatural: la oración con acción de gracias.

"Por nada estéis afanosos, sino sean conocidas vuestras peticiones delante de Dios en toda oración y ruego, con acción de gracias."

La clave está en esas últimas tres palabras: CON ACCIÓN DE GRACIAS. No es solo pedir que la tormenta cese. Es agradecer EN MEDIO de la tormenta porque sabes que Dios está obrando.

Esta paz no significa que entiendes lo que Dios está haciendo. De hecho, "sobrepasa todo entendimiento". No la explicas, la experimentas. No viene de comprender la situación, sino de conocer al que tiene el control.

REFLEXIÓN:
¿Qué puedes agradecer HOY, aunque la tormenta no haya cesado?

ORACIÓN:
Dios de paz, hoy te pido esa paz que sobrepasa mi entendimiento. No necesito entender tu plan completo. Solo necesito confiar en que tú eres bueno y estás en control. Gracias por lo que estás haciendo aunque no lo vea. Guarda mi corazón y mi mente en Cristo Jesús. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
      ],
    ),

    // 2. DIOS EN EL SILENCIO (3 días)
    SpiritualPlan(
      id: 'dios-silencio',
      title: 'Dios en el Silencio',
      subtitle: 'Cuando el cielo parece callado',
      description: 'Has orado. Has clamado. Has esperado. Pero el cielo parece de bronce. Este plan es para esos momentos.',
      image: _imgSilencio,
      days: 3,
      category: 'Fortaleza del Corazón',
      difficulty: 'Intermedio',
      daysList: [
        DayPlan(
          dayNumber: 1,
          title: 'El Cielo de Bronce',
          scripture: '¿Hasta cuándo, Jehová? ¿Me olvidarás para siempre? ¿Hasta cuándo esconderás tu rostro de mí?',
          scriptureReference: 'Salmo 13:1',
          content: '''David, el hombre conforme al corazón de Dios, el rey ungido, el adorador más famoso de la historia... también conoció el silencio de Dios.

"¿Hasta cuándo?" No es una pregunta de rebeldía. Es el grito honesto de un alma que ama a Dios y no entiende por qué Él parece distante.

Si estás en un período donde la oración se siente vacía, donde lees la Biblia y las palabras no cobran vida, donde otros hablan de experiencias con Dios y tú te sientes desconectado... no estás solo.

Los grandes héroes de la fe conocieron el silencio: Job clamó y Dios no respondió por capítulos enteros. Elías tuvo que esperar el susurro apacible después del fuego. Jesús mismo gritó: "¿Por qué me has desamparado?"

El silencio de Dios no significa ausencia de Dios. A veces el silencio es su forma de profundizar tu fe. Es fácil creer cuando hay señales y maravillas. La fe madura cree aún cuando el cielo parece de bronce.

REFLEXIÓN:
¿Qué significaría para ti seguir confiando en Dios aunque Él no hable como esperas?

ORACIÓN:
Señor, honestamente me cuesta entender tu silencio. Me siento lejos de ti. Pero elijo creer que tu silencio no es abandono. Tú estás trabajando aunque yo no lo vea. Ayúdame a confiar en tu presencia aunque no sienta tu voz. Amén.''',
          isLocked: false,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 2,
          title: 'El Propósito de la Espera',
          scripture: 'Pero los que esperan a Jehová tendrán nuevas fuerzas; levantarán alas como las águilas.',
          scriptureReference: 'Isaías 40:31',
          content: '''La palabra hebrea para "esperar" en este versículo es "qavah". No significa sentarse pasivamente. Significa estar tenso como una cuerda, anticipando con esperanza activa.

Dios usa los tiempos de silencio para hacer cosas en ti que no podrían suceder de otra manera:

1. PURIFICA TUS MOTIVOS: Cuando Dios parece callado, descubres por qué realmente lo buscas. ¿Lo quieres a Él o solo sus bendiciones?

2. FORTALECE TU FE: Los músculos crecen bajo resistencia. Tu fe se fortalece precisamente cuando es difícil creer.

3. PROFUNDIZA TU RELACIÓN: Las relaciones superficiales dependen de recompensas constantes. El amor verdadero persevera en el silencio.

4. PREPARA ALGO MAYOR: José esperó años en prisión. David esperó décadas antes de ser rey. El silencio no era desprecio; era preparación.

Piensa en esto: si Dios respondiera instantáneamente cada oración, ¿cómo sería diferente tu relación con Él? Probablemente lo tratarías como un dispensador de bendiciones, no como un Padre amoroso.

REFLEXIÓN:
¿Qué podría Dios estar purificando, fortaleciendo o preparando en ti durante este tiempo de espera?

ORACIÓN:
Padre, perdóname por las veces que te he buscado solo por lo que puedes darme. Quiero conocerte a ti, no solo tus dones. Usa este tiempo de silencio para profundizar mi fe y purificar mis motivos. Espero en ti con esperanza activa. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 3,
          title: 'El Susurro Apacible',
          scripture: 'Y tras el terremoto un fuego; pero Jehová no estaba en el fuego. Y tras el fuego un silbo apacible y delicado.',
          scriptureReference: '1 Reyes 19:12',
          content: '''Elías esperaba que Dios se manifestara en lo espectacular: el viento huracanado, el terremoto, el fuego. Pero Dios habló en un susurro.

A veces no escuchamos a Dios porque estamos esperando la forma equivocada de comunicación. Queremos visiones dramáticas cuando Él susurra en la paz de la mañana. Queremos señales sobrenaturales cuando Él habla a través de un versículo que leíste mil veces.

Dios no grita para competir con el ruido de tu vida. Él susurra para que te acerques.

Aquí hay algunas formas en que Dios puede estar hablándote ahora mismo:

• A través de las Escrituras que lees
• A través de circunstancias que alinea
• A través de consejos sabios de hermanos
• A través de una paz inexplicable sobre una decisión
• A través del Espíritu Santo que testifica en tu interior

El silencio que sientes puede ser una invitación a escuchar de manera diferente. No más alto, sino más profundo. No más espectacular, sino más íntimo.

REFLEXIÓN:
¿En qué formas podría Dios estar hablándote que no has considerado? ¿Hay ruido en tu vida que necesitas silenciar para escuchar su susurro?

ORACIÓN:
Espíritu Santo, perdóname por buscar lo espectacular cuando tú hablas en susurros. Abre mis oídos espirituales. Quiero escucharte en la Palabra, en la paz, en la voz de hermanos sabios. Silencio el ruido de mi vida para escuchar tu voz. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 5 DÍAS - RETO CORTO
    // ═══════════════════════════════════════════════════════════════════════

    // 3. CORAZÓN DE LEÓN (5 días)
    SpiritualPlan(
      id: 'corazon-leon',
      title: 'Corazón de León',
      subtitle: 'Valentía sobrenatural ante el miedo',
      description: 'El miedo paraliza. El miedo miente. Pero Dios no te dio espíritu de cobardía. Es hora de despertar al león.',
      image: _imgFuego,
      days: 5,
      category: 'Batallas Mentales',
      difficulty: 'Intermedio',
      daysList: [
        DayPlan(
          dayNumber: 1,
          title: 'El Origen del Miedo',
          scripture: 'Porque no nos ha dado Dios espíritu de cobardía, sino de poder, de amor y de dominio propio.',
          scriptureReference: '2 Timoteo 1:7',
          content: '''Si el espíritu de cobardía no viene de Dios, ¿de dónde viene? De tres fuentes principales:

1. DEL ENEMIGO: Satanás usa el miedo como arma de parálisis. Si puede mantenerte aterrado, puede mantenerte inactivo.

2. DE LA CARNE: Tu naturaleza caída prefiere la seguridad del status quo al riesgo de la fe.

3. DEL MUNDO: La cultura del miedo bombardea constantemente con razones para temer.

Pero Pablo le recuerda a Timoteo (y a nosotros) lo que SÍ nos dio Dios:

PODER (dynamis): La misma palabra de donde viene "dinamita". Tienes poder explosivo del Espíritu Santo.

AMOR: El perfecto amor echa fuera el temor. Cuando amas a Dios más que a tu seguridad, el miedo pierde su agarre.

DOMINIO PROPIO: Puedes elegir tus respuestas. El miedo es una emoción, pero la cobardía es una decisión.

El miedo no es pecado. Ceder al miedo sin pelear sí lo es. Los valientes sienten miedo y avanzan de todos modos.

REFLEXIÓN:
¿Qué miedos te han paralizado? ¿De qué fuente crees que vienen?

ORACIÓN:
Padre, reconozco que el espíritu de cobardía no viene de ti. Hoy recibo tu poder, tu amor y tu dominio propio. Dame valentía para enfrentar lo que he estado evitando por miedo. Amén.''',
          isLocked: false,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 2,
          title: 'David ante el Gigante',
          scripture: 'Tú vienes a mí con espada y lanza y jabalina; mas yo vengo a ti en el nombre de Jehová de los ejércitos.',
          scriptureReference: '1 Samuel 17:45',
          content: '''Todos veían a Goliat. David también lo vio. La diferencia no fue que David ignoró al gigante; la diferencia fue a quién comparó con quién.

El ejército de Israel comparaba a Goliat con ellos mismos: "Es demasiado grande para pegarle". David comparaba a Goliat con Dios: "Es demasiado grande para fallarle".

Nota lo que David NO dijo:
• No dijo "el gigante no es real" (el pensamiento positivo vacío no funciona)
• No dijo "puedo vencerlo con mis fuerzas" (la confianza en uno mismo tampoco)
• No dijo "Dios hará todo mientras yo miro" (la pasividad espiritual es falsa fe)

Lo que David SÍ hizo:
• Recordó victorias pasadas (el león y el oso)
• Confió en el carácter de Dios (Jehová de los ejércitos)
• Tomó acción audaz (corrió hacia el gigante)

La valentía de David no vino de negar la realidad del gigante, sino de conocer la realidad de Dios.

REFLEXIÓN:
¿Con quién estás comparando tus gigantes? ¿Qué victorias pasadas necesitas recordar?

ORACIÓN:
Dios de David, tú no has cambiado. El Dios que venció leones, osos y gigantes sigue siendo mi Dios. Dame ojos para ver mis problemas en comparación contigo, no conmigo. Dame pies para correr hacia el gigante, no huir de él. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 3,
          title: 'Daniel en el Foso',
          scripture: 'Mi Dios envió su ángel, el cual cerró la boca de los leones.',
          scriptureReference: 'Daniel 6:22',
          content: '''Daniel sabía que orar le costaría la vida. El decreto era claro: quien orara a otro que no fuera el rey sería echado a los leones. ¿Y qué hizo Daniel?

"Cuando Daniel supo que el edicto había sido firmado, entró en su casa, y abiertas las ventanas de su cámara que daban hacia Jerusalén, se arrodillaba tres veces al día, y oraba y daba gracias delante de su Dios, como lo solía hacer antes." (Daniel 6:10)

"Como lo solía hacer antes". Daniel no cambió su rutina por la amenaza. No oró en secreto. No se excusó diciendo "Dios entenderá si bajo el perfil por un tiempo".

La valentía de Daniel no era temeridad. Era prioridad. Para él, su relación con Dios valía más que su propia vida.

Y Dios honró esa fe. No evitó que Daniel entrara al foso (a veces la obediencia te llevará a lugares peligrosos), pero lo acompañó EN el foso.

La promesa de Dios no es que nunca enfrentarás leones. Es que Él estará contigo cuando los enfrentes.

REFLEXIÓN:
¿Hay algo que Dios te ha pedido hacer que estás evitando por miedo a las consecuencias?

ORACIÓN:
Dios de Daniel, dame una fe que valora la obediencia por encima de la comodidad. Si me toca entrar al foso por seguirte, confío que entrarás conmigo. Dame valentía para obedecer "como solía hacerlo antes", sin importar las amenazas. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 4,
          title: 'Ester: Si Perezco, Que Perezca',
          scripture: 'Entraré a ver al rey, aunque no sea conforme a la ley; y si perezco, que perezca.',
          scriptureReference: 'Ester 4:16',
          content: '''Ester tenía todo que perder. Era reina, vivía en el palacio, tenía seguridad y lujo. Nadie sabía que era judía. Podía quedarse callada mientras su pueblo era masacrado.

Pero Mardoqueo le envió este mensaje: "¿Quién sabe si para esta hora has llegado al reino?"

A veces Dios te pone en posiciones de influencia no para tu beneficio, sino para el de otros. Tus privilegios vienen con responsabilidades. Tu silencio cuando deberías hablar es complicidad.

Ester ayunó tres días. Luego tomó la decisión más valiente de su vida: entrar ante el rey sin ser llamada, arriesgando su propia muerte.

"Si perezco, que perezca."

Esto no es pasividad fatalista. Es determinación sagrada. Es decir: "Haré lo correcto aunque me cueste todo".

La valentía no es la ausencia de miedo. Es decidir que algo es más importante que tu miedo.

REFLEXIÓN:
¿Para qué "hora" te ha puesto Dios donde estás? ¿Qué acción valiente te está pidiendo que podrías estar evitando?

ORACIÓN:
Dios de Ester, gracias por las posiciones de influencia que me has dado. Perdóname por las veces que he guardado silencio cuando debí hablar. Dame el valor de decir "si perezco, que perezca" y hacer lo correcto sin importar el costo. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
        DayPlan(
          dayNumber: 5,
          title: 'El León de Judá en Ti',
          scripture: 'El impío huye sin que nadie lo persiga; mas el justo está confiado como un león.',
          scriptureReference: 'Proverbios 28:1',
          content: '''Hay una razón por la que Jesús es llamado "el León de Judá". Y ese León vive en ti.

El mismo Espíritu que resucitó a Cristo de entre los muertos habita en ti. No eres un cordero indefenso esperando ser devorado. Eres hijo del Rey, con ADN de león.

Los impíos huyen sin que nadie los persiga porque viven en culpa y miedo. Pero tú has sido perdonado. Tú has sido justificado. Tú tienes acceso directo al trono de la gracia.

¿Por qué vivir como un ratón cuando eres un león?

La confianza del león no viene de su propia fuerza. Viene de saber quién es y de quién es. Tú sabes quién eres: hijo de Dios. Tú sabes de quién eres: del León de Judá.

Hoy, despierta al león. No para arrogancia carnal, sino para valentía santa. No para pelear batallas egoístas, sino para defender la verdad, proteger a los débiles, y avanzar el Reino.

REFLEXIÓN:
¿Cómo cambiaría tu día de hoy si vivieras con la confianza de un león?

ORACIÓN:
León de Judá, gracias por vivir en mí. Despierta la valentía santa en mi corazón. No quiero vivir como un ratón asustado cuando tú me has dado ADN de león. Dame confianza para enfrentar este día con valentía sobrenatural. Amén.''',
          isLocked: true,
          isCompleted: false,
        ),
      ],
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 7 DÍAS - ESTÁNDAR
    // ═══════════════════════════════════════════════════════════════════════

    // 4. MENTE BLINDADA (7 días)
    SpiritualPlan(
      id: 'mente-blindada',
      title: 'Mente Blindada',
      subtitle: 'Derrota la ansiedad con verdades bíblicas',
      description: 'Tu mente es el campo de batalla principal. Aprende a blindarla contra los ataques del enemigo.',
      image: _imgMente,
      days: 7,
      category: 'Batallas Mentales',
      difficulty: 'Intermedio',
      daysList: _generateDays(7, 'mente-blindada', [
        ('El Campo de Batalla', 'Romanos 12:2', 'No os conforméis a este siglo, sino transformaos por medio de la renovación de vuestro entendimiento.'),
        ('Patrones de Pensamiento', '2 Corintios 10:5', 'Derribando argumentos y toda altivez que se levanta contra el conocimiento de Dios.'),
        ('La Renovación Mental', 'Efesios 4:23', 'Y renovaos en el espíritu de vuestra mente.'),
        ('Pensamientos Cautivos', '2 Corintios 10:5', 'Llevando cautivo todo pensamiento a la obediencia a Cristo.'),
        ('El Antídoto de la Ansiedad', 'Filipenses 4:6-7', 'Por nada estéis afanosos, sino sean conocidas vuestras peticiones delante de Dios.'),
        ('Declaraciones de Verdad', 'Proverbios 18:21', 'La muerte y la vida están en poder de la lengua.'),
        ('Paz que Guarda', 'Filipenses 4:7', 'Y la paz de Dios, que sobrepasa todo entendimiento, guardará vuestros corazones y vuestros pensamientos.'),
      ]),
    ),

    // 5. TU VERDADERA IDENTIDAD (7 días)
    SpiritualPlan(
      id: 'verdadera-identidad',
      title: 'Tu Verdadera Identidad',
      subtitle: 'Descubre quién eres realmente en Cristo',
      description: 'El mundo te dice quién deberías ser. Tus fracasos te definen. Pero Dios dice algo diferente.',
      image: _imgIdentidad,
      days: 7,
      category: 'Fortaleza del Corazón',
      difficulty: 'Principiante',
      daysList: _generateDays(7, 'verdadera-identidad', [
        ('Las Mentiras que Creíste', 'Juan 8:32', 'Y conoceréis la verdad, y la verdad os hará libres.'),
        ('Hijo Amado', '1 Juan 3:1', 'Mirad cuál amor nos ha dado el Padre, para que seamos llamados hijos de Dios.'),
        ('Nueva Criatura', '2 Corintios 5:17', 'Si alguno está en Cristo, nueva criatura es; las cosas viejas pasaron.'),
        ('Escogido y Apartado', '1 Pedro 2:9', 'Mas vosotros sois linaje escogido, real sacerdocio, nación santa.'),
        ('Más que Vencedor', 'Romanos 8:37', 'Somos más que vencedores por medio de aquel que nos amó.'),
        ('Obra Maestra de Dios', 'Efesios 2:10', 'Somos hechura suya, creados en Cristo Jesús para buenas obras.'),
        ('Cristo en Ti', 'Gálatas 2:20', 'Ya no vivo yo, mas vive Cristo en mí.'),
      ]),
    ),

    // 6. ROMPIENDO CADENAS (7 días)
    SpiritualPlan(
      id: 'rompiendo-cadenas',
      title: 'Rompiendo Cadenas',
      subtitle: 'El camino del perdón y la libertad',
      description: 'El resentimiento es una prisión que tú mismo cierras desde adentro. Es hora de romper las cadenas.',
      image: _imgCadenas,
      days: 7,
      category: 'Relaciones y Comunidad',
      difficulty: 'Intermedio',
      daysList: _generateDays(7, 'rompiendo-cadenas', [
        ('El Peso del Resentimiento', 'Efesios 4:31', 'Quítense de vosotros toda amargura, enojo, ira, gritería y maledicencia.'),
        ('Perdonar no es Olvidar', 'Efesios 4:32', 'Perdonándoos unos a otros, como Dios también os perdonó a vosotros en Cristo.'),
        ('La Deuda Cancelada', 'Mateo 18:32-33', 'Toda aquella deuda te perdoné... ¿No debías también tener misericordia?'),
        ('Perdonándote a Ti Mismo', 'Romanos 8:1', 'Ninguna condenación hay para los que están en Cristo Jesús.'),
        ('Cuando el Ofensor no se Arrepiente', 'Lucas 23:34', 'Padre, perdónalos, porque no saben lo que hacen.'),
        ('Bendiciendo a tus Enemigos', 'Lucas 6:28', 'Bendecid a los que os maldicen, y orad por los que os calumnian.'),
        ('Libertad Total', 'Juan 8:36', 'Si el Hijo os libertare, seréis verdaderamente libres.'),
      ]),
    ),

    // 7. TESOROS ETERNOS (7 días)
    SpiritualPlan(
      id: 'tesoros-eternos',
      title: 'Tesoros Eternos',
      subtitle: 'Mayordomía bíblica y libertad financiera',
      description: 'El dinero no es malo. Pero el amor al dinero puede destruirte. Aprende los principios del Reino.',
      image: _imgTesoros,
      days: 7,
      category: 'Relaciones y Comunidad',
      difficulty: 'Principiante',
      daysList: _generateDays(7, 'tesoros-eternos', [
        ('Todo le Pertenece a Dios', 'Salmo 24:1', 'De Jehová es la tierra y su plenitud; el mundo, y los que en él habitan.'),
        ('La Trampa del Materialismo', '1 Timoteo 6:10', 'Raíz de todos los males es el amor al dinero.'),
        ('Dar con Gozo', '2 Corintios 9:7', 'Dios ama al dador alegre.'),
        ('Contentamiento Verdadero', 'Filipenses 4:11', 'He aprendido a contentarme, cualquiera que sea mi situación.'),
        ('Invirtiendo en lo Eterno', 'Mateo 6:20', 'Haceos tesoros en el cielo, donde ni la polilla ni el orín corrompen.'),
        ('Confiando en el Proveedor', 'Filipenses 4:19', 'Mi Dios, pues, suplirá todo lo que os falta.'),
        ('Riqueza Verdadera', 'Marcos 8:36', '¿Qué aprovechará al hombre si ganare todo el mundo y perdiere su alma?'),
      ]),
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 10 DÍAS - PROFUNDO
    // ═══════════════════════════════════════════════════════════════════════

    // 8. LA ARMADURA INVISIBLE (10 días)
    SpiritualPlan(
      id: 'armadura-invisible',
      title: 'La Armadura Invisible',
      subtitle: 'Estrategias para la guerra espiritual',
      description: 'Cada día enfrentamos una guerra espiritual. Este plan te enseñará a vestir cada pieza de la armadura de Dios.',
      image: _imgArmadura,
      days: 10,
      category: 'Batallas Mentales',
      difficulty: 'Avanzado',
      daysList: _generateDays(10, 'armadura-invisible', [
        ('Reconociendo al Enemigo', 'Efesios 6:12', 'No tenemos lucha contra sangre y carne, sino contra principados.'),
        ('El Cinturón de la Verdad', 'Juan 8:32', 'Conoceréis la verdad, y la verdad os hará libres.'),
        ('La Coraza de Justicia', '2 Corintios 5:21', 'Al que no conoció pecado, por nosotros lo hizo pecado.'),
        ('El Calzado del Evangelio', 'Romanos 10:15', '¡Cuán hermosos son los pies de los que anuncian la paz!'),
        ('El Escudo de la Fe', 'Efesios 6:16', 'Tomad el escudo de la fe, con que podáis apagar todos los dardos.'),
        ('El Yelmo de la Salvación', 'Efesios 2:8', 'Por gracia sois salvos por medio de la fe.'),
        ('La Espada del Espíritu', 'Hebreos 4:12', 'La palabra de Dios es viva y eficaz, más cortante que toda espada.'),
        ('La Oración como Arma', 'Efesios 6:18', 'Orando en todo tiempo con toda oración y súplica.'),
        ('Velando con Perseverancia', 'Mateo 26:41', 'Velad y orad, para que no entréis en tentación.'),
        ('Victoria Asegurada', '1 Corintios 15:57', 'Gracias sean dadas a Dios, que nos da la victoria por medio de Cristo.'),
      ]),
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 14 DÍAS - INTERMEDIO
    // ═══════════════════════════════════════════════════════════════════════

    // 9. DOMANDO LA LENGUA (14 días)
    SpiritualPlan(
      id: 'domando-lengua',
      title: 'Domando la Lengua',
      subtitle: 'El poder de vida y muerte en tus palabras',
      description: 'La lengua es un fuego. Puede destruir o edificar. Aprende a usar tus palabras como armas de luz.',
      image: _imgLengua,
      days: 14,
      category: 'Batallas Mentales',
      difficulty: 'Intermedio',
      daysList: _generateDays(14, 'domando-lengua', [
        ('El Poder de las Palabras', 'Proverbios 18:21', 'La muerte y la vida están en poder de la lengua.'),
        ('Un Fuego Pequeño', 'Santiago 3:5', 'La lengua es un miembro pequeño, pero se jacta de grandes cosas.'),
        ('Controlando la Crítica', 'Mateo 7:1', 'No juzguéis, para que no seáis juzgados.'),
        ('Eliminando la Queja', 'Filipenses 2:14', 'Haced todo sin murmuraciones y contiendas.'),
        ('Palabras de Edificación', 'Efesios 4:29', 'Ninguna palabra corrompida salga de vuestra boca.'),
        ('El Chisme Destructor', 'Proverbios 16:28', 'El chismoso aparta a los mejores amigos.'),
        ('Hablando Verdad en Amor', 'Efesios 4:15', 'Hablando la verdad en amor, crezcamos en todo.'),
        ('El Silencio Sabio', 'Proverbios 17:28', 'Aun el necio, cuando calla, es contado por sabio.'),
        ('Bendecir vs Maldecir', 'Santiago 3:10', 'De una misma boca proceden bendición y maldición.'),
        ('Confesión Poderosa', 'Romanos 10:9-10', 'Con la boca se confiesa para salvación.'),
        ('Palabras de Fe', 'Marcos 11:23', 'Cualquiera que dijere a este monte: Quítate.'),
        ('Sanando con Palabras', 'Proverbios 12:18', 'La lengua de los sabios es medicina.'),
        ('Declarando Promesas', 'Josué 1:8', 'Nunca se apartará de tu boca este libro de la ley.'),
        ('Lengua de Vida', 'Proverbios 15:4', 'La lengua apacible es árbol de vida.'),
      ]),
    ),

    // 10. AMOR QUE PERDURA (14 días)
    SpiritualPlan(
      id: 'amor-perdura',
      title: 'Amor que Perdura',
      subtitle: 'Relaciones a prueba de fuego',
      description: 'El amor del mundo es frágil. El amor de Dios es inquebrantable. Aprende los principios de 1 Corintios 13.',
      image: _imgAmor,
      days: 14,
      category: 'Relaciones y Comunidad',
      difficulty: 'Principiante',
      daysList: _generateDays(14, 'amor-perdura', [
        ('El Amor Más Excelente', '1 Corintios 12:31', 'Yo os muestro un camino aún más excelente.'),
        ('Amor que es Paciente', '1 Corintios 13:4', 'El amor es sufrido, es benigno.'),
        ('Amor sin Envidia', '1 Corintios 13:4', 'El amor no tiene envidia.'),
        ('Amor Humilde', '1 Corintios 13:4', 'El amor no es jactancioso, no se envanece.'),
        ('Amor que Respeta', '1 Corintios 13:5', 'No hace nada indebido, no busca lo suyo.'),
        ('Amor sin Resentimiento', '1 Corintios 13:5', 'No guarda rencor.'),
        ('Amor que Celebra la Verdad', '1 Corintios 13:6', 'No se goza de la injusticia, mas se goza de la verdad.'),
        ('Amor que Protege', '1 Corintios 13:7', 'Todo lo sufre, todo lo cree.'),
        ('Amor que Espera', '1 Corintios 13:7', 'Todo lo espera, todo lo soporta.'),
        ('Amor Eterno', '1 Corintios 13:8', 'El amor nunca deja de ser.'),
        ('Fe, Esperanza y Amor', '1 Corintios 13:13', 'Ahora permanecen la fe, la esperanza y el amor.'),
        ('El Mayor es el Amor', '1 Corintios 13:13', 'Pero el mayor de ellos es el amor.'),
        ('Amando como Cristo', 'Juan 15:12', 'Este es mi mandamiento: Que os améis unos a otros.'),
        ('Amor en Acción', '1 Juan 3:18', 'No amemos de palabra ni de lengua, sino de hecho y en verdad.'),
      ]),
    ),

    // ═══════════════════════════════════════════════════════════════════════
    // 21 DÍAS - HÁBITO
    // ═══════════════════════════════════════════════════════════════════════

    // 11. PUREZA DE ACERO (21 días)
    SpiritualPlan(
      id: 'pureza-acero',
      title: 'Pureza de Acero',
      subtitle: 'Venciendo la tentación sexual con poder divino',
      description: 'La tentación es real. La lucha es intensa. Pero la victoria es posible. Sin rodeos, sin vergüenza, con poder.',
      image: _imgPureza,
      days: 21,
      category: 'Relaciones y Comunidad',
      difficulty: 'Avanzado',
      daysList: _generateDays(21, 'pureza-acero', [
        ('La Batalla es Real', '1 Corintios 6:18', 'Huid de la fornicación.'),
        ('El Poder del Pacto', 'Job 31:1', 'Hice pacto con mis ojos.'),
        ('Raíces de la Tentación', 'Santiago 1:14', 'Cada uno es tentado cuando es atraído por su propia concupiscencia.'),
        ('José: Huir es Vencer', 'Génesis 39:12', 'Dejó su ropa en las manos de ella, y huyó.'),
        ('Renovando la Mente Sexual', 'Romanos 12:2', 'Transformaos por medio de la renovación de vuestro entendimiento.'),
        ('El Poder de la Confesión', 'Santiago 5:16', 'Confesaos vuestras ofensas unos a otros.'),
        ('Guardando el Corazón', 'Proverbios 4:23', 'Sobre toda cosa guardada, guarda tu corazón.'),
        ('Comunidad de Batalla', 'Eclesiastés 4:9-10', 'Mejores son dos que uno.'),
        ('Cuando Caes, Levántate', 'Proverbios 24:16', 'Siete veces cae el justo, y vuelve a levantarse.'),
        ('El Templo del Espíritu', '1 Corintios 6:19', 'Vuestro cuerpo es templo del Espíritu Santo.'),
        ('Purificando los Ojos', 'Mateo 5:28', 'Cualquiera que mira a una mujer para codiciarla...'),
        ('Fortaleciendo los Límites', '1 Corintios 10:13', 'No os ha sobrevenido ninguna tentación que no sea humana.'),
        ('La Salida de Escape', '1 Corintios 10:13', 'Dios dará también juntamente con la tentación la salida.'),
        ('Llenando el Vacío', 'Salmo 16:11', 'En tu presencia hay plenitud de gozo.'),
        ('Rompiendo Patrones', 'Romanos 6:14', 'El pecado no se enseñoreará de vosotros.'),
        ('Identidad sobre Deseo', '1 Pedro 2:11', 'Como extranjeros y peregrinos, que os abstengáis de los deseos carnales.'),
        ('La Gracia Suficiente', '2 Corintios 12:9', 'Bástate mi gracia; mi poder se perfecciona en la debilidad.'),
        ('Victoria Diaria', 'Romanos 8:37', 'Somos más que vencedores.'),
        ('Santificación Progresiva', 'Filipenses 1:6', 'El que comenzó la buena obra la perfeccionará.'),
        ('Celebrando el Progreso', '2 Corintios 3:18', 'Somos transformados de gloria en gloria.'),
        ('Pureza Permanente', '1 Juan 3:3', 'Todo aquel que tiene esta esperanza en él, se purifica.'),
      ]),
    ),

    // 12. EL DESCANSO SAGRADO (21 días)
    SpiritualPlan(
      id: 'descanso-sagrado',
      title: 'El Descanso Sagrado',
      subtitle: 'Sanando el burnout con principios eternos',
      description: 'Dios diseñó el descanso antes del trabajo. Redescubre el Sabbath y encuentra restauración para tu alma.',
      image: _imgDescanso,
      days: 21,
      category: 'Fortaleza del Corazón',
      difficulty: 'Principiante',
      daysList: _generateDays(21, 'descanso-sagrado', [
        ('El Diseño del Reposo', 'Génesis 2:2', 'Reposó Dios en el día séptimo de toda la obra que hizo.'),
        ('El Yugo Ligero', 'Mateo 11:28-30', 'Venid a mí todos los que estáis trabajados y cargados.'),
        ('Soltando el Control', 'Salmo 55:22', 'Echa sobre Jehová tu carga, y él te sustentará.'),
        ('Productividad vs Propósito', 'Mateo 6:33', 'Buscad primeramente el reino de Dios.'),
        ('El Regalo del Sabbath', 'Marcos 2:27', 'El día de reposo fue hecho por causa del hombre.'),
        ('Restauración del Alma', 'Salmo 23:3', 'Confortará mi alma.'),
        ('Vivir sin Prisa', 'Salmo 46:10', 'Estad quietos, y conoced que yo soy Dios.'),
        ('La Trampa del Workaholismo', 'Eclesiastés 4:6', 'Mejor es un puño lleno con descanso.'),
        ('Ritmos de Gracia', 'Éxodo 20:8', 'Acuérdate del día de reposo para santificarlo.'),
        ('Desconectando para Reconectar', 'Marcos 6:31', 'Venid vosotros aparte a un lugar desierto, y descansad.'),
        ('El Maná Diario', 'Éxodo 16:4', 'He aquí yo os haré llover pan del cielo.'),
        ('Confianza sobre Ansiedad', 'Mateo 6:34', 'Así que, no os afanéis por el día de mañana.'),
        ('Límites Saludables', 'Eclesiastés 3:1', 'Todo tiene su tiempo, y todo lo que se quiere debajo del cielo.'),
        ('El Silencio Restaurador', '1 Reyes 19:12', 'Y tras el fuego un silbo apacible y delicado.'),
        ('Soledad Sagrada', 'Marcos 1:35', 'Se levantó muy de mañana, y salió y se fue a un lugar desierto.'),
        ('Gratitud como Descanso', '1 Tesalonicenses 5:18', 'Dad gracias en todo.'),
        ('Celebración Intencional', 'Nehemías 8:10', 'El gozo de Jehová es vuestra fuerza.'),
        ('Cuidando el Templo', '1 Corintios 6:19', 'Vuestro cuerpo es templo del Espíritu Santo.'),
        ('Delegando Responsabilidades', 'Éxodo 18:21', 'Escoge de entre el pueblo varones de virtud.'),
        ('El Descanso Eterno', 'Hebreos 4:9-10', 'Queda un reposo para el pueblo de Dios.'),
        ('Viviendo en Ritmo', 'Lamentaciones 3:22-23', 'Nuevas son cada mañana.'),
      ]),
    ),
  ];

  /// Función auxiliar para generar días con contenido
  static List<DayPlan> _generateDays(int count, String planId, List<(String, String, String)> dayData) {
    return List.generate(count, (index) {
      final data = dayData[index];
      return DayPlan(
        dayNumber: index + 1,
        title: data.$1,
        scripture: data.$3,
        scriptureReference: data.$2,
        content: _generateContent(planId, index + 1, data.$1, data.$3, data.$2),
        isLocked: index != 0, // Solo el día 1 está desbloqueado
        isCompleted: false,
      );
    });
  }

  /// Genera contenido extenso para cada día
  static String _generateContent(String planId, int day, String title, String scripture, String reference) {
    return '''$title

"$scripture" — $reference

Día $day de tu jornada espiritual.

Hoy exploramos una verdad poderosa que transformará tu perspectiva. Este versículo no es solo palabras antiguas; es la voz viva de Dios hablándote directamente en este momento de tu vida.

La Escritura de hoy nos revela que Dios tiene un propósito específico para cada uno de nosotros. No estás aquí por accidente. Cada batalla que enfrentas, cada lágrima que derramas, cada victoria que celebras es parte de un tapiz más grande que Dios está tejiendo en tu vida.

MEDITACIÓN PROFUNDA:

Tómate unos minutos para reflexionar en estas palabras. No las leas de prisa. Deja que penetren tu corazón. El Espíritu Santo quiere revelarte algo nuevo hoy, algo que tal vez has leído cien veces pero nunca has experimentado.

Considera esto: ¿Qué área de tu vida necesita más esta verdad hoy? ¿Dónde has estado luchando? ¿Dónde has sentido que Dios está en silencio?

La promesa de las Escrituras es que Dios nunca te dejará ni te abandonará. Incluso en los momentos más oscuros, Él está trabajando. Incluso cuando no lo sientes, Él está contigo.

APLICACIÓN PRÁCTICA:

Hoy te invito a dar un paso de fe. No basta con leer la Palabra; debemos vivirla. Identifica una acción específica que puedes tomar hoy para aplicar esta verdad.

Tal vez necesitas perdonar a alguien. Tal vez necesitas tomar una decisión que has estado posponiendo. Tal vez simplemente necesitas descansar en la presencia de Dios y dejar de intentar controlar todo.

Sea lo que sea, hazlo hoy. La fe sin obras está muerta.

ORACIÓN:

Padre celestial, gracias por tu Palabra que es lámpara a mis pies y lumbrera a mi camino. Hoy me comprometo a no solo escuchar tu verdad, sino a vivirla. Dame la valentía para aplicar lo que he aprendido. Transforma mi mente, purifica mi corazón, y guía mis pasos. En el nombre de Jesús, amén.

Que la paz de Cristo guarde tu corazón hoy.''';
  }

  /// Obtiene un plan por su ID
  static SpiritualPlan? getPlanById(String id) {
    try {
      return allPlans.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Planes por categoría
  static List<SpiritualPlan> getPlansByCategory(String category) {
    return allPlans.where((p) => p.category == category).toList();
  }
}
