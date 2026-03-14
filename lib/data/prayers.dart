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
  static const List<Prayer> emergencyPrayers = [
    Prayer(
      title: "Oración de Auxilio Inmediato",
      content: '''Señor Jesús, en este momento de debilidad vengo a Ti.
      
Reconozco que sin Ti nada puedo hacer. La tentación está frente a mí, pero Tú eres más grande que cualquier tentación.

Dame la fuerza para resistir. Llena mi mente con Tu paz y mi corazón con Tu amor.

Recuérdame que mi cuerpo es templo del Espíritu Santo. Ayúdame a honrarte con mis pensamientos y acciones.

En el nombre de Jesús, reprendo todo pensamiento impuro y declaro que soy más que vencedor por medio de Cristo.

Amén.''',
      category: "emergencia",
      durationMinutes: 2,
    ),
    Prayer(
      title: "Oración de Liberación",
      content: '''Padre Celestial, me presento ante Ti con un corazón humillado.

Confieso que he luchado con pensamientos y deseos que no Te glorifican. Perdóname, Señor.

Hoy declaro que rompo con todo lazo de esclavitud. No seré dominado por mis deseos carnales, porque Cristo me ha hecho libre.

Espíritu Santo, toma control de mi mente. Renueva mis pensamientos. Transforma mis deseos.

Declaro victoria sobre la lujuria, sobre todo vicio, sobre toda adicción. La sangre de Cristo me limpia y me libera.

Gracias Señor porque Tu gracia es suficiente para mí.

En el poderoso nombre de Jesús. Amén.''',
      category: "liberación",
      durationMinutes: 3,
    ),
  ];

  static const List<Prayer> morningPrayers = [
    Prayer(
      title: "Consagración Matutina",
      content: '''Buenos días, Señor.

Antes de comenzar este día, quiero entregarte mis pensamientos, mis ojos, mis manos y todo mi ser.

Guárdame de toda tentación. Que mis ojos solo vean lo que Te agrada. Que mis pensamientos sean puros y santos.

Revísteme con la armadura de Dios para poder resistir los dardos del enemigo.

Que este día sea para Tu gloria. Ayúdame a caminar en integridad y pureza.

En el nombre de Jesús. Amén.''',
      category: "mañana",
      durationMinutes: 2,
    ),
  ];

  static const List<Prayer> nightPrayers = [
    Prayer(
      title: "Reflexión Nocturna",
      content: '''Señor, al terminar este día vengo a Ti.

Gracias por Tu fidelidad. Gracias por ayudarme a resistir las tentaciones de hoy.

Si en algo fallé, Te pido perdón. Límpiame con Tu sangre preciosa.

Mientras duermo, guarda mi mente. Que mis sueños sean puros y que despierte renovado para servirte.

Gracias por otro día de victoria. Confío en que mañana también estarás conmigo.

Buenas noches, Señor. Amén.''',
      category: "noche",
      durationMinutes: 2,
    ),
  ];

  static const List<Prayer> strengthPrayers = [
    Prayer(
      title: "Oración por Fortaleza",
      content: '''Padre, vengo a Ti porque me siento débil.

Tu Palabra dice que cuando soy débil, entonces soy fuerte en Ti. Necesito Tu fuerza ahora.

No quiero seguir cayendo en los mismos errores. Quiero ser libre de verdad.

Fortalece mi voluntad. Dame dominio propio. Ayúdame a huir de la tentación.

Sé que puedo todas las cosas en Cristo que me fortalece. Hoy reclamo esa promesa para mi vida.

Gracias porque Tu poder se perfecciona en mi debilidad.

En el nombre de Jesús. Amén.''',
      category: "fortaleza",
      durationMinutes: 3,
    ),
  ];

  static List<Prayer> get allPrayers {
    return [
      ...emergencyPrayers,
      ...morningPrayers,
      ...nightPrayers,
      ...strengthPrayers,
    ];
  }
}
