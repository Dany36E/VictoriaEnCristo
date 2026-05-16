/// Versículos curados para acompañar el "Mapa de Oración".
///
/// El usuario seleccionó referencias específicas (Salmo 34:4, 1 Timoteo 2:8,
/// Hebreos 3:14, Salmos 6:9, Salmos 33:22). A esta base se añaden otras citas
/// breves centradas en la oración para tener rotación diaria.
class PrayerVerse {
  final String reference;
  final String text;

  const PrayerVerse({required this.reference, required this.text});
}

class PrayerVerses {
  PrayerVerses._();

  static const List<PrayerVerse> all = [
    PrayerVerse(
      reference: 'Salmo 34:4',
      text:
          'Busqué al Señor, y él me respondió; me libró de todos mis temores.',
    ),
    PrayerVerse(
      reference: '1 Timoteo 2:8',
      text:
          'Quiero, pues, que los hombres oren en todo lugar, levantando manos santas, sin ira ni contienda.',
    ),
    PrayerVerse(
      reference: 'Hebreos 3:14',
      text:
          'Porque somos hechos participantes de Cristo, con tal que retengamos firme hasta el fin nuestra confianza del principio.',
    ),
    PrayerVerse(
      reference: 'Salmos 6:9',
      text: 'Jehová ha oído mi ruego; ha recibido Jehová mi oración.',
    ),
    PrayerVerse(
      reference: 'Salmos 33:22',
      text: 'Sea tu misericordia, oh Jehová, sobre nosotros, según esperamos en ti.',
    ),
    PrayerVerse(
      reference: 'Filipenses 4:6',
      text:
          'Por nada estéis afanosos, sino sean conocidas vuestras peticiones delante de Dios en toda oración y ruego, con acción de gracias.',
    ),
    PrayerVerse(
      reference: '1 Tesalonicenses 5:17',
      text: 'Orad sin cesar.',
    ),
    PrayerVerse(
      reference: 'Mateo 7:7',
      text:
          'Pedid, y se os dará; buscad, y hallaréis; llamad, y se os abrirá.',
    ),
    PrayerVerse(
      reference: 'Santiago 5:16',
      text:
          'La oración eficaz del justo puede mucho.',
    ),
    PrayerVerse(
      reference: 'Jeremías 33:3',
      text:
          'Clama a mí, y yo te responderé, y te enseñaré cosas grandes y ocultas que tú no conoces.',
    ),
    PrayerVerse(
      reference: 'Salmos 145:18',
      text:
          'Cercano está Jehová a todos los que le invocan, a todos los que le invocan de veras.',
    ),
    PrayerVerse(
      reference: 'Marcos 11:24',
      text:
          'Todo lo que pidiereis orando, creed que lo recibiréis, y os vendrá.',
    ),
    PrayerVerse(
      reference: 'Lucas 18:1',
      text: 'Es necesario orar siempre, y no desmayar.',
    ),
    PrayerVerse(
      reference: 'Romanos 12:12',
      text:
          'Gozosos en la esperanza; sufridos en la tribulación; constantes en la oración.',
    ),
    PrayerVerse(
      reference: 'Salmos 5:3',
      text:
          'Oh Jehová, de mañana oirás mi voz; de mañana me presentaré delante de ti, y esperaré.',
    ),
    PrayerVerse(
      reference: 'Salmos 55:17',
      text:
          'Tarde y mañana y a mediodía oraré y clamaré, y él oirá mi voz.',
    ),
    PrayerVerse(
      reference: 'Efesios 6:18',
      text:
          'Orando en todo tiempo con toda oración y súplica en el Espíritu.',
    ),
    PrayerVerse(
      reference: 'Salmos 4:1',
      text:
          'Respóndeme cuando clamo, oh Dios de mi justicia. Cuando estaba en angustia, tú me hiciste ensanchar.',
    ),
    PrayerVerse(
      reference: 'Colosenses 4:2',
      text:
          'Perseverad en la oración, velando en ella con acción de gracias.',
    ),
    PrayerVerse(
      reference: 'Isaías 65:24',
      text:
          'Y antes que clamen, responderé yo; mientras aún hablan, yo habré oído.',
    ),
  ];

  /// Devuelve el versículo del día de forma determinística (mismo día = mismo
  /// versículo para todos los usuarios, sin requerir red).
  static PrayerVerse forToday() {
    final now = DateTime.now();
    final dayOfYear = int.parse(
      '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}',
    );
    return all[dayOfYear % all.length];
  }
}
