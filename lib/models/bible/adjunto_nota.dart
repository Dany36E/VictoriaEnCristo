/// Foto o dibujo agregado a un apunte. La nota solo guarda estos datos; el
/// archivo vive en el teléfono y en Firebase Storage
/// (`users/<uid>/apuntes/<notaId>/<archivo>`).
enum TipoAdjunto { foto, dibujo }

class AdjuntoNota {
  final String id;
  final TipoAdjunto tipo;

  /// Ancho entre alto, para reservar el espacio antes de cargar el archivo.
  final double proporcion;

  /// Pie de foto opcional.
  final String pie;

  /// La foto tiene marcas dibujadas encima (archivo `<id>_marcas.svg`).
  final bool conMarcas;
  final DateTime creadoEn;

  const AdjuntoNota({
    required this.id,
    required this.tipo,
    required this.proporcion,
    required this.creadoEn,
    this.pie = '',
    this.conMarcas = false,
  });

  factory AdjuntoNota.nuevo(TipoAdjunto tipo, {required double proporcion}) {
    final ahora = DateTime.now();
    return AdjuntoNota(
      id: 'a${ahora.microsecondsSinceEpoch}',
      tipo: tipo,
      proporcion: proporcion,
      creadoEn: ahora,
    );
  }

  /// Archivo principal: la foto en JPEG o el dibujo en SVG.
  String get archivo => tipo == TipoAdjunto.foto ? '$id.jpg' : '$id.svg';

  /// Marcas dibujadas sobre una foto.
  String get archivoMarcas => '${id}_marcas.svg';

  List<String> get archivos => [archivo, if (conMarcas) archivoMarcas];

  AdjuntoNota copyWith({
    double? proporcion,
    String? pie,
    bool? conMarcas,
  }) => AdjuntoNota(
    id: id,
    tipo: tipo,
    proporcion: proporcion ?? this.proporcion,
    creadoEn: creadoEn,
    pie: pie ?? this.pie,
    conMarcas: conMarcas ?? this.conMarcas,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'tipo': tipo.name,
    'proporcion': proporcion,
    if (pie.isNotEmpty) 'pie': pie,
    if (conMarcas) 'marcas': true,
    'creadoMs': creadoEn.millisecondsSinceEpoch,
  };

  static AdjuntoNota? fromMap(Map<String, dynamic> map) {
    final id = map['id'] as String? ?? '';
    if (id.isEmpty) return null;
    final proporcion = (map['proporcion'] as num?)?.toDouble() ?? 1;
    return AdjuntoNota(
      id: id,
      tipo: map['tipo'] == TipoAdjunto.dibujo.name
          ? TipoAdjunto.dibujo
          : TipoAdjunto.foto,
      proporcion: proporcion.isFinite && proporcion > 0 ? proporcion : 1,
      pie: map['pie'] as String? ?? '',
      conMarcas: map['marcas'] == true,
      creadoEn: DateTime.fromMillisecondsSinceEpoch(
        (map['creadoMs'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}
