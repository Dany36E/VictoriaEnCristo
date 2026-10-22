import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';

import '../../utils/tinta.dart';

/// Herramientas de tinta del lienzo de Apuntes.
enum HerramientaTrazo { pluma, lapiz, marcador, resaltador }

/// Fondo de la hoja, como en Notas: liso, rayado, cuadrícula o puntos.
enum FondoLienzo { liso, rayado, cuadricula, puntos }

/// Un trazo de tinta. Los puntos están en unidades del lienzo (el lienzo
/// mide [DatosDibujo.ancho] de ancho, sin importar la pantalla).
class Trazo {
  final HerramientaTrazo herramienta;

  /// Color ARGB.
  final int color;
  final double grosor;

  /// La presión viene del lápiz; si no, se simula con la velocidad.
  final bool presionReal;
  final List<PuntoTinta> puntos;

  Trazo({
    required this.herramienta,
    required this.color,
    required this.grosor,
    required this.puntos,
    this.presionReal = false,
  });

  OpcionesTinta get opciones => switch (herramienta) {
    HerramientaTrazo.pluma => OpcionesTinta(
      tamano: grosor,
      adelgazado: 0.6,
      suavizado: 0.5,
      estabilizado: 0.5,
      simularPresion: !presionReal,
    ),
    HerramientaTrazo.lapiz => OpcionesTinta(
      tamano: grosor,
      adelgazado: 0.3,
      suavizado: 0.4,
      estabilizado: 0.35,
      simularPresion: !presionReal,
    ),
    HerramientaTrazo.marcador => OpcionesTinta(
      tamano: grosor,
      adelgazado: 0,
      suavizado: 0.5,
      estabilizado: 0.6,
      simularPresion: false,
    ),
    HerramientaTrazo.resaltador => OpcionesTinta(
      tamano: grosor,
      adelgazado: 0,
      suavizado: 0.6,
      estabilizado: 0.7,
      simularPresion: false,
    ),
  };

  /// El resaltador es translúcido y el lápiz un poco más claro que la pluma.
  double get opacidad => switch (herramienta) {
    HerramientaTrazo.resaltador => 0.35,
    HerramientaTrazo.lapiz => 0.85,
    _ => 1,
  };

  late final List<Offset> contorno = contornoTinta(puntos, opciones);
  late final Path camino = caminoTinta(contorno);

  late final Rect limites = () {
    if (puntos.isEmpty) return Rect.zero;
    var minX = puntos.first.x, maxX = minX;
    var minY = puntos.first.y, maxY = minY;
    for (final p in puntos) {
      minX = math.min(minX, p.x);
      maxX = math.max(maxX, p.x);
      minY = math.min(minY, p.y);
      maxY = math.max(maxY, p.y);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(grosor / 2 + 1);
  }();

  Trazo copiar({
    int? color,
    List<PuntoTinta>? puntos,
  }) => Trazo(
    herramienta: herramienta,
    color: color ?? this.color,
    grosor: grosor,
    puntos: puntos ?? this.puntos,
    presionReal: presionReal,
  );

  Trazo mover(Offset d) => copiar(
    puntos: [for (final p in puntos) PuntoTinta(p.x + d.dx, p.y + d.dy, p.presion)],
  );

  Map<String, dynamic> toMap() => {
    'h': herramienta.name,
    'c': color,
    'g': grosor,
    if (presionReal) 'pr': 1,
    // Plano y entero para que pese poco: x*10, y*10, presión*100.
    'p': [
      for (final p in puntos) ...[
        (p.x * 10).round(),
        (p.y * 10).round(),
        (p.presion * 100).round(),
      ],
    ],
  };

  static Trazo? fromMap(Map<String, dynamic> map) {
    final crudos = (map['p'] as List?)?.whereType<num>().toList() ?? const [];
    if (crudos.length < 3) return null;
    return Trazo(
      herramienta: HerramientaTrazo.values.firstWhere(
        (h) => h.name == map['h'],
        orElse: () => HerramientaTrazo.pluma,
      ),
      color: (map['c'] as num?)?.toInt() ?? 0xFF2B2622,
      grosor: (map['g'] as num?)?.toDouble() ?? 6,
      presionReal: map['pr'] == 1,
      puntos: [
        for (var i = 0; i + 2 < crudos.length; i += 3)
          PuntoTinta(crudos[i] / 10, crudos[i + 1] / 10, crudos[i + 2] / 100),
      ],
    );
  }
}

/// Un dibujo de Apuntes: hoja de ancho fijo con trazos vectoriales.
class DatosDibujo {
  static const double ancho = 1000;
  static const double altoInicial = 1300;

  /// Lo que crece la hoja con «Más espacio».
  static const double espacioExtra = 650;

  final double alto;
  final FondoLienzo fondo;
  final List<Trazo> trazos;

  const DatosDibujo({
    this.alto = altoInicial,
    this.fondo = FondoLienzo.liso,
    this.trazos = const [],
  });

  bool get vacio => trazos.isEmpty;
  double get proporcion => ancho / alto;

  DatosDibujo copiar({
    double? alto,
    FondoLienzo? fondo,
    List<Trazo>? trazos,
  }) => DatosDibujo(
    alto: alto ?? this.alto,
    fondo: fondo ?? this.fondo,
    trazos: trazos ?? this.trazos,
  );

  Map<String, dynamic> toMap() => {
    'v': 1,
    'alto': alto,
    'fondo': fondo.name,
    'trazos': [for (final t in trazos) t.toMap()],
  };

  factory DatosDibujo.fromMap(Map<String, dynamic> map) => DatosDibujo(
    alto: (map['alto'] as num?)?.toDouble() ?? altoInicial,
    fondo: FondoLienzo.values.firstWhere(
      (f) => f.name == map['fondo'],
      orElse: () => FondoLienzo.liso,
    ),
    trazos: [
      for (final t in (map['trazos'] as List? ?? const []).whereType<Map>())
        ?Trazo.fromMap(Map<String, dynamic>.from(t)),
    ],
  );

  /// SVG con el dibujo a la vista y los trazos originales en `<metadata>`,
  /// para poder volver a editarlo. [conPapel] pinta la hoja de fondo (las
  /// marcas sobre una foto van sin hoja).
  String aSvg({bool conPapel = true}) {
    final datos = base64Encode(utf8.encode(jsonEncode(toMap())));
    final alto = this.alto.round();
    final b = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('width="${ancho.round()}" height="$alto" ')
      ..write('viewBox="0 0 ${ancho.round()} $alto">')
      ..write('<metadata id="victoria-dibujo">$datos</metadata>');
    if (conPapel) {
      b.write('<rect width="100%" height="100%" fill="#FBF7EE"/>');
    }
    for (final t in trazos) {
      final d = svgDeContorno(t.contorno);
      if (d.isEmpty) continue;
      final rgb = (t.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
      final alfa = ((t.color >> 24) & 0xFF) / 255 * t.opacidad;
      b.write('<path d="$d" fill="#$rgb"');
      if (alfa < 1) b.write(' fill-opacity="${alfa.toStringAsFixed(2)}"');
      b.write('/>');
    }
    b.write('</svg>');
    return b.toString();
  }

  static final RegExp _metadatos = RegExp(
    r'<metadata id="victoria-dibujo">([A-Za-z0-9+/=]+)</metadata>',
  );

  /// Lee un SVG hecho con [aSvg]. Null si no trae los trazos.
  static DatosDibujo? desdeSvg(String svg) {
    final m = _metadatos.firstMatch(svg);
    if (m == null) return null;
    try {
      final mapa = jsonDecode(utf8.decode(base64Decode(m.group(1)!)));
      if (mapa is! Map) return null;
      return DatosDibujo.fromMap(Map<String, dynamic>.from(mapa));
    } catch (_) {
      return null;
    }
  }
}
