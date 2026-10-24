import 'package:cloud_firestore/cloud_firestore.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BOSQUEJO DE SERMÓN
///
/// Título, texto principal, introducción, puntos con subpuntos (cada uno con
/// versículos vinculados), ilustración y conclusión.
///
/// Firestore: /users/{uid}/sermonOutlines/{id}
/// ═══════════════════════════════════════════════════════════════════════════

/// Versículo (o rango) vinculado a un punto o subpunto. Guarda el texto para
/// mostrarlo y exportarlo sin conexión.
class VersiculoBosquejo {
  final String referencia;
  final int bookNumber;
  final int chapter;
  final int verseStart;
  final int verseEnd;
  final String versionId;
  final String texto;

  const VersiculoBosquejo({
    required this.referencia,
    required this.bookNumber,
    required this.chapter,
    required this.verseStart,
    required this.verseEnd,
    required this.versionId,
    required this.texto,
  });

  String get clave => '$versionId:$bookNumber:$chapter:$verseStart-$verseEnd';

  Map<String, dynamic> toMap() => {
    'referencia': referencia,
    'bookNumber': bookNumber,
    'chapter': chapter,
    'verseStart': verseStart,
    'verseEnd': verseEnd,
    'versionId': versionId,
    'texto': texto,
  };

  factory VersiculoBosquejo.fromMap(Map<String, dynamic> map) {
    final inicio = _asInt(map['verseStart']);
    return VersiculoBosquejo(
      referencia: map['referencia'] as String? ?? '',
      bookNumber: _asInt(map['bookNumber']),
      chapter: _asInt(map['chapter']),
      verseStart: inicio,
      verseEnd: map['verseEnd'] == null ? inicio : _asInt(map['verseEnd']),
      versionId: map['versionId'] as String? ?? 'RVR1960',
      texto: map['texto'] as String? ?? '',
    );
  }
}

class SubpuntoBosquejo {
  final String id;
  final String texto;
  final List<VersiculoBosquejo> versiculos;

  const SubpuntoBosquejo({
    required this.id,
    required this.texto,
    this.versiculos = const [],
  });

  factory SubpuntoBosquejo.nuevo({String texto = ''}) =>
      SubpuntoBosquejo(id: _nuevoId('s'), texto: texto);

  SubpuntoBosquejo copyWith({
    String? texto,
    List<VersiculoBosquejo>? versiculos,
  }) => SubpuntoBosquejo(
    id: id,
    texto: texto ?? this.texto,
    versiculos: versiculos ?? this.versiculos,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'texto': texto,
    'versiculos': [for (final v in versiculos) v.toMap()],
  };

  factory SubpuntoBosquejo.fromMap(Map<String, dynamic> map) =>
      SubpuntoBosquejo(
        id: _idO(map['id'], 's'),
        texto: map['texto'] as String? ?? '',
        versiculos: _versiculosDe(map['versiculos']),
      );
}

class PuntoBosquejo {
  final String id;
  final String titulo;
  final String notas;
  final List<SubpuntoBosquejo> subpuntos;
  final List<VersiculoBosquejo> versiculos;

  const PuntoBosquejo({
    required this.id,
    required this.titulo,
    this.notas = '',
    this.subpuntos = const [],
    this.versiculos = const [],
  });

  factory PuntoBosquejo.nuevo({String titulo = ''}) =>
      PuntoBosquejo(id: _nuevoId('p'), titulo: titulo);

  PuntoBosquejo copyWith({
    String? titulo,
    String? notas,
    List<SubpuntoBosquejo>? subpuntos,
    List<VersiculoBosquejo>? versiculos,
  }) => PuntoBosquejo(
    id: id,
    titulo: titulo ?? this.titulo,
    notas: notas ?? this.notas,
    subpuntos: subpuntos ?? this.subpuntos,
    versiculos: versiculos ?? this.versiculos,
  );

  bool get hasContent =>
      titulo.trim().isNotEmpty ||
      notas.trim().isNotEmpty ||
      versiculos.isNotEmpty ||
      subpuntos.any((s) => s.texto.trim().isNotEmpty || s.versiculos.isNotEmpty);

  Map<String, dynamic> toMap() => {
    'id': id,
    'titulo': titulo,
    'notas': notas,
    'subpuntos': [for (final s in subpuntos) s.toMap()],
    'versiculos': [for (final v in versiculos) v.toMap()],
  };

  factory PuntoBosquejo.fromMap(Map<String, dynamic> map) => PuntoBosquejo(
    id: _idO(map['id'], 'p'),
    titulo: map['titulo'] as String? ?? '',
    notas: map['notas'] as String? ?? '',
    subpuntos: [
      for (final s in (map['subpuntos'] as List? ?? const []).whereType<Map>())
        SubpuntoBosquejo.fromMap(Map<String, dynamic>.from(s)),
    ],
    versiculos: _versiculosDe(map['versiculos']),
  );
}

class BosquejoSermon {
  final String id;
  final String titulo;

  /// Texto principal del sermón, como se escribió (p. ej. «Juan 3:16-18»).
  final String textoPrincipal;
  final String introduccion;
  final String ilustracion;
  final String conclusion;
  final List<PuntoBosquejo> puntos;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BosquejoSermon({
    required this.id,
    required this.titulo,
    required this.textoPrincipal,
    required this.introduccion,
    required this.ilustracion,
    required this.conclusion,
    required this.puntos,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BosquejoSermon.nuevo({String? id}) {
    final ahora = DateTime.now();
    return BosquejoSermon(
      id: id ?? 'bosquejo_${ahora.microsecondsSinceEpoch}',
      titulo: '',
      textoPrincipal: '',
      introduccion: '',
      ilustracion: '',
      conclusion: '',
      puntos: const [],
      createdAt: ahora,
      updatedAt: ahora,
    );
  }

  bool get hasContent =>
      titulo.trim().isNotEmpty ||
      textoPrincipal.trim().isNotEmpty ||
      introduccion.trim().isNotEmpty ||
      ilustracion.trim().isNotEmpty ||
      conclusion.trim().isNotEmpty ||
      puntos.any((p) => p.hasContent);

  String get tituloVisible =>
      titulo.trim().isEmpty ? 'Bosquejo sin título' : titulo.trim();

  /// Todo el texto del bosquejo en una sola cadena, para buscar.
  String get textoBuscable {
    final b = StringBuffer()
      ..writeln(titulo)
      ..writeln(textoPrincipal)
      ..writeln(introduccion);
    for (final p in puntos) {
      b
        ..writeln(p.titulo)
        ..writeln(p.notas);
      for (final v in p.versiculos) {
        b
          ..writeln(v.referencia)
          ..writeln(v.texto);
      }
      for (final s in p.subpuntos) {
        b.writeln(s.texto);
        for (final v in s.versiculos) {
          b
            ..writeln(v.referencia)
            ..writeln(v.texto);
        }
      }
    }
    b
      ..writeln(ilustracion)
      ..writeln(conclusion);
    return b.toString();
  }

  /// Copia con los campos dados. Por defecto actualiza [updatedAt].
  BosquejoSermon copyWith({
    String? titulo,
    String? textoPrincipal,
    String? introduccion,
    String? ilustracion,
    String? conclusion,
    List<PuntoBosquejo>? puntos,
    DateTime? updatedAt,
  }) => BosquejoSermon(
    id: id,
    titulo: titulo ?? this.titulo,
    textoPrincipal: textoPrincipal ?? this.textoPrincipal,
    introduccion: introduccion ?? this.introduccion,
    ilustracion: ilustracion ?? this.ilustracion,
    conclusion: conclusion ?? this.conclusion,
    puntos: puntos ?? this.puntos,
    createdAt: createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  /// Mueve un punto con la semántica de `ReorderableListView.onReorder`
  /// (si baja, el índice nuevo cuenta todavía el elemento que se movió).
  BosquejoSermon reordenarPunto(int indiceViejo, int indiceNuevo) =>
      copyWith(puntos: reordenar(puntos, indiceViejo, indiceNuevo));

  /// Mueve un subpunto dentro de su punto (misma semántica).
  BosquejoSermon reordenarSubpunto(
    String puntoId,
    int indiceViejo,
    int indiceNuevo,
  ) => copyWith(
    puntos: [
      for (final p in puntos)
        p.id == puntoId
            ? p.copyWith(
                subpuntos: reordenar(p.subpuntos, indiceViejo, indiceNuevo),
              )
            : p,
    ],
  );

  /// Reemplaza un punto por id.
  BosquejoSermon conPunto(PuntoBosquejo punto) => copyWith(
    puntos: [for (final p in puntos) p.id == punto.id ? punto : p],
  );

  /// Todo lo que se guarda menos la fecha de edición: si no cambió, no se
  /// vuelve a escribir.
  String get huellaContenido {
    final mapa = toLocalMap()..remove('updatedAtMs');
    return mapa.toString();
  }

  /// Documento de Firestore.
  Map<String, dynamic> toMap() => {
    ..._camposComunes(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  /// Cache local en JSON (fechas en milisegundos).
  Map<String, dynamic> toLocalMap() => {
    'id': id,
    ..._camposComunes(),
    'createdAtMs': createdAt.millisecondsSinceEpoch,
    'updatedAtMs': updatedAt.millisecondsSinceEpoch,
  };

  Map<String, dynamic> _camposComunes() => {
    'titulo': titulo,
    'textoPrincipal': textoPrincipal,
    'introduccion': introduccion,
    'ilustracion': ilustracion,
    'conclusion': conclusion,
    'puntos': [for (final p in puntos) p.toMap()],
  };

  /// Lee un documento de Firestore o de la cache local.
  factory BosquejoSermon.fromMap(String id, Map<String, dynamic> map) =>
      BosquejoSermon(
        id: id,
        titulo: map['titulo'] as String? ?? '',
        textoPrincipal: map['textoPrincipal'] as String? ?? '',
        introduccion: map['introduccion'] as String? ?? '',
        ilustracion: map['ilustracion'] as String? ?? '',
        conclusion: map['conclusion'] as String? ?? '',
        puntos: [
          for (final p in (map['puntos'] as List? ?? const []).whereType<Map>())
            PuntoBosquejo.fromMap(Map<String, dynamic>.from(p)),
        ],
        createdAt: _fecha(map['createdAt'] ?? map['createdAtMs']),
        updatedAt: _fecha(map['updatedAt'] ?? map['updatedAtMs']),
      );
}

/// Mueve un elemento con la semántica de `ReorderableListView.onReorder`.
List<T> reordenar<T>(List<T> lista, int indiceViejo, int indiceNuevo) {
  if (indiceViejo < 0 || indiceViejo >= lista.length) return lista;
  var destino = indiceNuevo;
  if (destino > indiceViejo) destino -= 1;
  destino = destino.clamp(0, lista.length - 1);
  if (destino == indiceViejo) return lista;
  final copia = [...lista];
  final elemento = copia.removeAt(indiceViejo);
  copia.insert(destino, elemento);
  return copia;
}

int _contador = 0;

String _nuevoId(String prefijo) =>
    '$prefijo${DateTime.now().microsecondsSinceEpoch}_${_contador++}';

String _idO(dynamic valor, String prefijo) {
  final texto = valor?.toString() ?? '';
  return texto.isEmpty ? _nuevoId(prefijo) : texto;
}

List<VersiculoBosquejo> _versiculosDe(dynamic lista) => [
  for (final v in (lista as List? ?? const []).whereType<Map>())
    VersiculoBosquejo.fromMap(Map<String, dynamic>.from(v)),
];

int _asInt(dynamic value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _fecha(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
