/// ═══════════════════════════════════════════════════════════════════════════
/// ORACIONES — contenido curado para los momentos clave del día
/// ═══════════════════════════════════════════════════════════════════════════
/// Cada oración es un texto listo para leer/orar. Las categorías siguen el
/// arco emocional de un creyente en batalla: crisis, consagración, descanso,
/// fortaleza, gratitud, perdón, guerra espiritual y familia.
/// ═══════════════════════════════════════════════════════════════════════════
library;

class Prayer {
  final String title;
  final String content;
  final String category;
  final int durationMinutes;

  const Prayer({
    required this.title,
    required this.content,
    required this.category,
    required this.durationMinutes,
  });
}

class Prayers {
  // ═══════════════════════════════════════════════════════════════════════════
  // 🆘 EMERGENCIA — cuando la tentación aprieta
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> emergencyPrayers = [
    Prayer(
      title: 'Auxilio inmediato',
      content: '''Señor Jesús, vengo a Ti ahora mismo.

La tentación está frente a mí y me siento débil. Reconozco que sin Ti no puedo, pero en Ti todo lo puedo.

Cubre mis ojos. Guarda mi mente. Toma mis manos. Que mi cuerpo, templo del Espíritu Santo, no sea usado para la impureza.

En el nombre de Jesús reprendo todo pensamiento impuro y declaro que soy más que vencedor por Aquel que me amó.

Tu sangre me limpia. Tu gracia me sostiene. Tu presencia me basta.

Amén.''',
      category: 'emergencia',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Oración de liberación',
      content: '''Padre Celestial, me presento ante Ti humillado.

Confieso que he luchado con pensamientos y deseos que no Te glorifican. Perdóname, Señor.

Hoy declaro que rompo con toda cadena oculta. No seré esclavo de mis deseos carnales porque Cristo me hizo libre.

Espíritu Santo, toma control de mi mente. Renueva mis pensamientos. Transforma mis deseos.

Declaro victoria sobre la lujuria, sobre todo vicio, sobre toda adicción. La sangre de Cristo me limpia y me libera.

Gracias Señor porque Tu gracia es suficiente para mí.

En el poderoso nombre de Jesús. Amén.''',
      category: 'emergencia',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Escape de la tentación',
      content: '''Dios Todopoderoso, necesito Tu mano ahora.

Tu Palabra promete que con la tentación darás también la salida (1 Cor 10:13). Señor, muéstrame esa salida y dame las fuerzas para tomarla.

Aleja de mí lo que me destruye. Trae a mi memoria Tu Palabra. Recuérdame quién soy en Cristo.

Cambio la pantalla. Cambio el lugar. Cambio la conversación. Huyo, como huyó José, porque mi alma Te pertenece.

Envía Tus ángeles a guardar mis caminos. Sostenme, Señor, sostenme.

En el nombre de Jesús. Amén.''',
      category: 'emergencia',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Después de una caída',
      content: '''Padre, vengo con un corazón quebrantado.

He fallado. Otra vez. Sé que Te ofendí y no lo tomo a la ligera. Pero Tu Palabra dice que si confieso mi pecado, Tú eres fiel y justo para perdonarme (1 Jn 1:9).

No me escondo, como Adán. Vengo a Ti, como el hijo pródigo.

No permito que el enemigo me quede acusando. Cristo ya pagó por esto. Me levanto, no por mis fuerzas, sino por Tu gracia.

Restaura el gozo de mi salvación. Un corazón contrito y humillado no despreciarás.

Empiezo de nuevo. En Ti. Amén.''',
      category: 'emergencia',
      durationMinutes: 3,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌅 MAÑANA — consagración y armadura
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> morningPrayers = [
    Prayer(
      title: 'Consagración matutina',
      content: '''Buenos días, Señor.

Antes de comenzar este día, Te entrego mis pensamientos, mis ojos, mis manos y todo mi ser.

Guárdame de toda tentación. Que mis ojos solo vean lo que Te agrada. Que mis pensamientos sean puros y santos.

Revísteme con la armadura de Dios para resistir los dardos del enemigo: la verdad ceñida, la justicia como coraza, el calzado del evangelio, el escudo de la fe, el yelmo de la salvación y la espada del Espíritu, que es Tu Palabra.

Que este día sea para Tu gloria. Ayúdame a caminar en integridad y pureza.

En el nombre de Jesús. Amén.''',
      category: 'mañana',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Primera hora con Dios',
      content: '''Padre, Tú eres la primera palabra de mi día.

Antes del celular, antes del trabajo, antes de cualquier voz — escucho la Tuya.

Renueva mis fuerzas como las del águila. Que mi mente sea alineada con Tu Palabra antes de tocar el mundo.

Pongo delante de Ti este día: mis decisiones, mis reuniones, mis conversaciones, mis pantallas. Que todo pase por el filtro de Tu Espíritu.

Llena mi boca de bendición. Que quien me vea hoy, te encuentre a Ti.

En el nombre de Jesús. Amén.''',
      category: 'mañana',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Propósito del día',
      content: '''Señor, hoy es un regalo que no merezco y que quiero honrar.

Ordena mis prioridades. Líbrame del desperdicio, del chisme, del scroll sin fin.

Que lo primero sea Tu Reino y Tu justicia, y que las demás cosas me sean añadidas.

Abre mis ojos para ver a quien necesita una palabra. Abre mis manos para servir. Abre mi corazón para amar como Tú amas.

Y si hoy me toca sufrir, que sufra por causas dignas: por Ti, por mi familia, por el bien.

Úsame, Señor. Todo lo que soy es Tuyo.

Amén.''',
      category: 'mañana',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Propósitos del día',
      content: '''Señor, antes de ponerme en movimiento hoy declaro tres cosas.

Uno: mis ojos son Tuyos. Hago pacto contigo de no detenerme en lo que contamina (Job 31:1).

Dos: mi tiempo es Tuyo. No desperdiciaré horas en scroll que no me edifica; lo que gane en tiempo lo invierto en Ti, en mi familia o en servir.

Tres: mi lengua es Tuya. Solo saldrán de mi boca palabras de vida.

Ayúdame, Espíritu Santo. En mis fuerzas fallo; en las Tuyas venzo.

Amén.''',
      category: 'mañana',
      durationMinutes: 2,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 🌙 NOCHE — reflexión y descanso
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> nightPrayers = [
    Prayer(
      title: 'Reflexión nocturna',
      content: '''Señor, al terminar este día vengo a Ti.

Gracias por Tu fidelidad. Gracias por ayudarme a resistir las tentaciones de hoy.

Si en algo fallé, te pido perdón. Límpiame con Tu sangre preciosa.

Mientras duermo, guarda mi mente. Que mis sueños sean puros y que despierte renovado para servirte.

Gracias por otro día de victoria. Confío en que mañana también estarás conmigo.

Buenas noches, Señor. Amén.''',
      category: 'noche',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Examen de conciencia',
      content: '''Señor, antes de dormir quiero revisar este día contigo.

¿En qué me acerqué a Ti? Te doy gracias por cada victoria, por pequeña que parezca.

¿En qué me alejé? Me arrepiento. No quiero llevar culpa a la almohada: Tu sangre me limpia ahora mismo.

Perdono a quienes me hirieron hoy. Bendigo a quienes me costó amar. Entrego los afanes del día a Tus manos.

Aquiétame. Apaga el ruido interior. Habla Tú en la quietud.

Mañana empiezo fresco, por Tu gracia.

Amén.''',
      category: 'noche',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Paz para descansar',
      content: '''Padre de toda paz, entrego en Tus manos este día y esta noche.

"En paz me acostaré, y asimismo dormiré; porque solo Tú, Señor, me haces vivir confiado" (Sal 4:8).

Los pendientes los dejo contigo. Las preocupaciones no pasan mi puerta. Las pantallas se apagan.

Calla toda voz que no sea la Tuya. Sella mis ojos y mi mente contra toda impureza nocturna. Rodea mi cama con Tus ángeles.

Que descanse en Ti como un niño descansa en su padre.

En el nombre de Jesús. Amén.''',
      category: 'noche',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Oración antes de dormir',
      content: '''Señor Jesús, cierro los ojos confiando en Ti.

Tú nunca duermes ni te adormeces, por eso puedo descansar tranquilo. Mi guardador eres Tú (Sal 121:4).

Sana las heridas de hoy. Restaura lo que se gastó. Trae gozo en la mañana.

Si desperté en la madrugada tentado, Tu Espíritu me recuerde Tu Palabra y huiré como José. No me dejaré arrastrar por la noche.

Duermo en paz porque Tú velas por mí. Buenas noches, Padre.

Amén.''',
      category: 'noche',
      durationMinutes: 2,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 💪 FORTALEZA — cuando el alma está cansada
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> strengthPrayers = [
    Prayer(
      title: 'Oración por fortaleza',
      content: '''Padre, vengo a Ti porque me siento débil.

Tu Palabra dice que cuando soy débil, entonces soy fuerte en Ti. Necesito Tu fuerza ahora.

No quiero seguir cayendo en los mismos errores. Quiero ser libre de verdad.

Fortalece mi voluntad. Dame dominio propio. Ayúdame a huir de la tentación.

Sé que puedo todas las cosas en Cristo que me fortalece. Hoy reclamo esa promesa para mi vida.

Gracias porque Tu poder se perfecciona en mi debilidad.

En el nombre de Jesús. Amén.''',
      category: 'fortaleza',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Cuando el alma duele',
      content: '''Señor, el alma me pesa hoy.

No sé explicar todo lo que siento, pero Tú conoces mi corazón. "Cercano está el Señor a los quebrantados de corazón" (Sal 34:18).

Recibe esta tristeza. Ponla delante de Ti. No quiero medicarla con pantallas, con comida, con vicios. Quiero sanarla contigo.

Lléname de Tu consuelo. Abrázame con Tu Palabra. Recuérdame que no estoy solo.

Y si esta noche no pasa todo, al menos pasa contigo. Eso basta.

En el nombre de Jesús. Amén.''',
      category: 'fortaleza',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Contra la ansiedad',
      content: '''Padre, traigo a Tus pies esta ansiedad que me oprime.

Tu Palabra dice: "Por nada estéis afanosos, sino sean conocidas vuestras peticiones delante de Dios en toda oración" (Fil 4:6).

Respiro profundo. Exhalo. Suelto el control. Tú no has perdido Tu trono.

No soy dueño del mañana, pero Tú sí. Tú proveíste ayer. Proveerás hoy. Proveerás mañana.

Que Tu paz, que sobrepasa todo entendimiento, guarde mi corazón y mi mente en Cristo Jesús.

Amén.''',
      category: 'fortaleza',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Ancla en la tormenta',
      content: '''Señor, siento que las olas me golpean. Ansiedad, desánimo, viejos recuerdos que vuelven.

No miraré las olas. Miro a Ti, como Pedro cuando andaba sobre el agua.

Tu Palabra es mi ancla: "El que habita al abrigo del Altísimo morará bajo la sombra del Omnipotente" (Sal 91:1).

No soy lo que siento. Soy lo que Tú dices que soy: amado, perdonado, libre.

Respiro profundo. Tu paz, que sobrepasa todo entendimiento, guarde mi corazón y mis pensamientos en Cristo Jesús (Fil 4:7).

Amén.''',
      category: 'fortaleza',
      durationMinutes: 2,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 🙏 GRATITUD — orientar el corazón hacia la luz
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> gratitudePrayers = [
    Prayer(
      title: 'Acción de gracias',
      content: '''Señor, antes de pedir nada, quiero agradecerte.

Gracias por el aire que respiro. Por mi cuerpo que aún se mueve. Por mi mente que aún piensa.

Gracias por mi salvación, comprada con sangre. Por Tu Espíritu que mora en mí. Por la cruz, por la tumba vacía, por Tu venida.

Gracias por cada persona en mi vida — incluso las que me retan, porque me empujan hacia Ti.

"Dad gracias en todo, porque esta es la voluntad de Dios para con vosotros en Cristo Jesús" (1 Tes 5:18).

Hoy escojo gratitud. Amén.''',
      category: 'gratitud',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Reconocer Tu mano',
      content: '''Padre, abre mis ojos para ver lo que ya has hecho.

Cuántas veces me libraste sin que yo lo supiera. Cuántas puertas cerraste para protegerme. Cuántos "no" Tuyos fueron en realidad Tu cuidado.

Perdona mi queja. Perdona mi comparación. Tengo más de lo que merezco y merezco menos de lo que creo.

Que mi boca se llene de alabanza. Que mi día empiece con "gracias" y termine con "gracias".

En el nombre de Jesús. Amén.''',
      category: 'gratitud',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Gozo en la batalla',
      content: '''Dios mío, incluso en medio de la lucha quiero darte gracias.

Gracias por esta batalla — porque me empuja a Tus brazos. Gracias porque la tentación no tiene la última palabra. Gracias porque cada victoria es Tuya primero, y mía en Ti.

"Tened por sumo gozo cuando os halléis en diversas pruebas" (Stg 1:2).

No pido ausencia de batalla; pido presencia Tuya en ella. Eso me basta.

Amén.''',
      category: 'gratitud',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Por lo que todavía no llega',
      content: '''Padre, quiero darte gracias por las victorias que todavía no veo.

Por el día 30, por el día 100, por el año entero que viene caminando contigo.

Por la libertad que ya decretaste sobre mí aunque hoy sienta que aprieta.

Por la persona en la que me estás transformando: paciente, puro, firme, lleno de Tu Espíritu.

Te creo antes de ver. Fe es la certeza de lo que se espera (Heb 11:1). Gracias porque Tú cumples Tu Palabra.

Amén.''',
      category: 'gratitud',
      durationMinutes: 2,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // ✝️ PERDÓN — dejar ir y ser libre
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> forgivenessPrayers = [
    Prayer(
      title: 'Perdón recibido',
      content: '''Padre santo, vengo a Ti sin máscaras.

Confieso mis pecados, conocidos y ocultos. No te oculto nada porque Tú lo ves todo y aún así me amas.

"Si confesamos nuestros pecados, él es fiel y justo para perdonarnos y limpiarnos de toda maldad" (1 Jn 1:9).

Recibo Tu perdón. No lo gano, lo recibo. Tu sangre es suficiente.

No volveré a cargar lo que Cristo ya cargó. No volveré a pagar lo que ya fue pagado.

Soy limpio. Soy libre. Soy Tuyo.

Amén.''',
      category: 'perdón',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Perdonar a otros',
      content: '''Señor, enséñame a perdonar como Tú me perdonaste.

Traigo ante Ti a quien me hirió. No lo disculpo; Te lo entrego. El juez eres Tú, no yo.

Suelto el rencor. Suelto el derecho a devolver el daño. Suelto la obsesión.

Bendice a esa persona. Sana lo que en mí quedó roto. Que Tu perdón fluya de Ti, a través de mí, hacia él/ella.

"Perdonándoos unos a otros, como Dios también os perdonó a vosotros en Cristo" (Ef 4:32).

Hoy escojo ser libre. Amén.''',
      category: 'perdón',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Perdonarme a mí mismo',
      content: '''Padre, lo más difícil es perdonarme a mí mismo.

Repaso mis caídas y me avergüenzo. El enemigo usa mi pasado como prisión. Pero Tú ya me declaraste libre.

Si Tú me perdonaste, ¿quién soy yo para no perdonarme?

No soy lo que hice. Soy lo que Tú dices que soy: hijo amado, heredero, santo.

Hoy me levanto. No por mérito, sino por gracia. No con culpa, sino con gratitud.

En el nombre de Jesús. Amén.''',
      category: 'perdón',
      durationMinutes: 3,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // ⚔️ GUERRA ESPIRITUAL — tomar territorio en el Nombre de Jesús
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> warfarePrayers = [
    Prayer(
      title: 'Vestido con la armadura',
      content: '''Padre, me visto con toda la armadura de Dios (Ef 6:10-18).

Ciño mis lomos con la verdad. Visto la coraza de la justicia de Cristo. Calzo mis pies con el evangelio de la paz. Tomo el escudo de la fe contra los dardos de fuego del maligno. Pongo el yelmo de la salvación sobre mi mente. Empuño la espada del Espíritu, que es Tu Palabra.

Oro en todo tiempo en el Espíritu. Velo con perseverancia.

No peleo en mis fuerzas. Peleo desde la victoria que Cristo ya ganó en la cruz.

En el nombre de Jesús. Amén.''',
      category: 'guerra',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Autoridad en el Nombre',
      content: '''En el nombre de Jesucristo, resisto al diablo y huye de mí (Stg 4:7).

Rompo toda atadura que no venga de Dios. Rompo toda maldición generacional sobre mi vida y mi familia. Rompo todo pacto oculto con mis ojos, con mis manos, con mi mente.

Declaro esta casa santa. Declaro mi celular santo. Declaro mi corazón santo.

Ningún arma forjada contra mí prosperará (Is 54:17).

La sangre de Jesús es mi cobertura hoy.

Amén.''',
      category: 'guerra',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Mente cautiva a Cristo',
      content: '''Señor, tomo autoridad sobre mi mente.

"Derribando argumentos y toda altivez que se levanta contra el conocimiento de Dios, y llevando cautivo todo pensamiento a la obediencia de Cristo" (2 Cor 10:5).

Todo pensamiento de lujuria, cautivo. Todo pensamiento de vergüenza, cautivo. Toda mentira del enemigo, cautiva.

Renuevo mi mente con Tu Palabra. Pongo la mira en las cosas de arriba.

Que mis ojos solo se deleiten en lo puro. Que mi imaginación solo dibuje lo honroso.

En el nombre de Jesús. Amén.''',
      category: 'guerra',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Cancelando ciclos heredados',
      content: '''Padre Celestial, en el nombre de Jesús rompo hoy todo ciclo de pecado heredado en mi familia.

La sangre de Cristo corta lo que generaciones pasadas cultivaron: adicción, infidelidad, amargura, miedo, lujuria. Lo que entró por pactos, palabras o costumbres, lo cancelo ahora.

Yo soy nueva criatura (2 Cor 5:17). En mi línea empieza algo nuevo.

Declaro bendición sobre mis hijos y sobre los que vendrán: serán libres, serán santos, serán usados por Ti.

En el nombre poderoso de Jesús. Amén.''',
      category: 'guerra',
      durationMinutes: 3,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // 👨‍👩‍👧 FAMILIA Y RELACIONES
  // ═══════════════════════════════════════════════════════════════════════════
  static const List<Prayer> familyPrayers = [
    Prayer(
      title: 'Por mi familia',
      content: '''Padre, cubro con la sangre de Cristo a cada miembro de mi familia.

Bendice a mis padres, a mi cónyuge, a mis hijos, a mis hermanos. Lo que no puedo hacer por ellos, hazlo Tú.

Sé muro de fuego alrededor de mi hogar. Que nada del maligno cruce la puerta.

Hazme mejor hijo, mejor hermano, mejor esposo, mejor padre. Que mi pureza bendiga a los que amo, que mi caminar sea ejemplo, que mi oración los sostenga.

"Yo y mi casa serviremos al Señor" (Jos 24:15).

En el nombre de Jesús. Amén.''',
      category: 'familia',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Por mi futura esposa / esposo',
      content: '''Señor, oro por la persona con quien caminaré.

Cuídala donde esté. Guarda su corazón. Guarda sus ojos. Guárdanos a ambos del enemigo y de nuestra propia impaciencia.

No quiero llegar a ella con los ojos sucios. Por eso peleo hoy. Por eso me cuido hoy. Por eso Te entrego mi intimidad hoy.

Prepáranos para amarnos como Cristo amó a la iglesia.

En el nombre de Jesús. Amén.''',
      category: 'familia',
      durationMinutes: 2,
    ),
    Prayer(
      title: 'Sanar una relación',
      content: '''Dios de reconciliación, traigo ante Ti esta relación que duele.

Sana lo que se rompió. Donde hubo palabras hirientes, trae bálsamo. Donde hubo silencio, trae conversación. Donde hubo orgullo, trae humildad.

Empieza por mí. No esperaré a que el otro cambie; yo me muevo primero hacia Ti, y Tú harás lo demás.

Si hace falta pedir perdón, dame valor. Si hace falta perdonar, dame amor.

En el nombre de Jesús. Amén.''',
      category: 'familia',
      durationMinutes: 3,
    ),
    Prayer(
      title: 'Por mi hogar como templo',
      content: '''Señor, consagro mi hogar como Tu templo.

Que cada habitación sea lugar de Tu presencia. Que nada impuro habite entre estas paredes.

Cubro con Tu sangre puertas, pantallas, redes, conversaciones. Nada de lo que Tú no bendices tendrá cabida aquí.

Que al entrar a mi casa se respire paz. Que al salir, llevemos Tu luz.

"Yo y mi casa serviremos al Señor" (Jos 24:15). Lo declaro como pacto contigo.

Amén.''',
      category: 'familia',
      durationMinutes: 2,
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // API pública
  // ═══════════════════════════════════════════════════════════════════════════

  static List<Prayer> get allPrayers {
    return [
      ...emergencyPrayers,
      ...morningPrayers,
      ...nightPrayers,
      ...strengthPrayers,
      ...gratitudePrayers,
      ...forgivenessPrayers,
      ...warfarePrayers,
      ...familyPrayers,
    ];
  }
}
