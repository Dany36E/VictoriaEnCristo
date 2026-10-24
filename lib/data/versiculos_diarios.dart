/// ═══════════════════════════════════════════════════════════════════════════
/// Versículos del día — referencias curadas por tema
///
/// Se guardan REFERENCIAS (libro/capítulo/versículos). El texto se carga de la
/// versión de la Biblia activa del usuario (ver `DailyVerseService`); cada
/// entrada trae además el texto RVR1960 como respaldo para el primer arranque,
/// sin conexión o en pruebas.
///
/// La lista ([versiculosDiarios]) se genera con
/// `tool/generar_versiculos_diarios.py` a partir de
/// `tool/versiculos_diarios.tsv`, intercalando los temas para que dos días
/// seguidos nunca repitan tema (tampoco al dar la vuelta a la lista).
/// ═══════════════════════════════════════════════════════════════════════════
library;

export 'versiculos_diarios_lista.dart' show versiculosDiarios;

/// Temas del versículo del día.
enum TemaVersiculo {
  esperanza('Esperanza'),
  gracia('Gracia'),
  pureza('Pureza'),
  fortaleza('Fortaleza'),
  oracion('Oración'),
  identidad('Identidad en Cristo'),
  tentacion('Tentación'),
  perdon('Perdón'),
  paz('Paz'),
  fe('Fe y confianza'),
  amor('Amor de Dios'),
  victoria('Victoria'),
  palabra('La Palabra'),
  gozo('Gozo y gratitud');

  const TemaVersiculo(this.etiqueta);

  /// Nombre visible del tema.
  final String etiqueta;
}

/// Nombres de los 66 libros tal como los entiende
/// `BibleNavigationHelper.parseSpanishRef` (índice = número de libro - 1).
const List<String> nombresLibrosBiblia = <String>[
  'Génesis', 'Éxodo', 'Levítico', 'Números', 'Deuteronomio', 'Josué',
  'Jueces', 'Rut', '1 Samuel', '2 Samuel', '1 Reyes', '2 Reyes',
  '1 Crónicas', '2 Crónicas', 'Esdras', 'Nehemías', 'Ester', 'Job',
  'Salmos', 'Proverbios', 'Eclesiastés', 'Cantares', 'Isaías', 'Jeremías',
  'Lamentaciones', 'Ezequiel', 'Daniel', 'Oseas', 'Joel', 'Amós', 'Abdías',
  'Jonás', 'Miqueas', 'Nahúm', 'Habacuc', 'Sofonías', 'Hageo', 'Zacarías',
  'Malaquías', 'Mateo', 'Marcos', 'Lucas', 'Juan', 'Hechos', 'Romanos',
  '1 Corintios', '2 Corintios', 'Gálatas', 'Efesios', 'Filipenses',
  'Colosenses', '1 Tesalonicenses', '2 Tesalonicenses', '1 Timoteo',
  '2 Timoteo', 'Tito', 'Filemón', 'Hebreos', 'Santiago', '1 Pedro',
  '2 Pedro', '1 Juan', '2 Juan', '3 Juan', 'Judas', 'Apocalipsis',
];

/// Una referencia del versículo del día.
class VersiculoDiario {
  /// Número de libro (1 = Génesis … 66 = Apocalipsis).
  final int libro;
  final int capitulo;
  final int versoInicio;
  final int versoFin;
  final TemaVersiculo tema;

  /// Texto Reina-Valera 1960 de respaldo.
  final String textoRvr;

  const VersiculoDiario(
    this.libro,
    this.capitulo,
    this.versoInicio,
    this.versoFin,
    this.tema,
    this.textoRvr,
  );

  String get nombreLibro => nombresLibrosBiblia[libro - 1];

  /// Referencia legible, p. ej. «Gálatas 5:22-23».
  String get referencia => versoFin > versoInicio
      ? '$nombreLibro $capitulo:$versoInicio-$versoFin'
      : '$nombreLibro $capitulo:$versoInicio';
}
