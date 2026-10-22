/// Contorno de trazos a mano alzada, con grosor que responde a la presión
/// del lápiz (o a la velocidad del dedo). Es una adaptación del algoritmo de
/// «perfect-freehand» de Steve Ruiz (licencia MIT): suaviza los puntos,
/// calcula un radio por punto y devuelve el polígono del trazo, con puntas
/// redondas.
library;

import 'dart:math' as math;
import 'dart:ui';

/// Un punto del trazo en coordenadas del lienzo; [presion] va de 0 a 1.
class PuntoTinta {
  final double x;
  final double y;
  final double presion;

  const PuntoTinta(this.x, this.y, [this.presion = 0.5]);

  Offset get offset => Offset(x, y);
}

class OpcionesTinta {
  /// Diámetro base del trazo.
  final double tamano;

  /// Cuánto afecta la presión al grosor (0 = grosor fijo).
  final double adelgazado;

  /// Suavizado de las orillas del contorno.
  final double suavizado;

  /// Cuánto se «retrasa» el trazo para quitar temblores (0 a 1).
  final double estabilizado;

  /// Sin lápiz con presión: se simula según la velocidad.
  final bool simularPresion;

  /// El trazo terminó (la punta final se dibuja completa).
  final bool terminado;

  const OpcionesTinta({
    required this.tamano,
    this.adelgazado = 0.5,
    this.suavizado = 0.5,
    this.estabilizado = 0.5,
    this.simularPresion = true,
    this.terminado = true,
  });
}

const double _piFijo = math.pi + 0.0001;
const double _ritmoPresion = 0.275;

class _PuntoTrazo {
  final Offset punto;
  final double presion;
  final Offset vector;
  final double distancia;
  final double recorrido;

  const _PuntoTrazo(
    this.punto,
    this.presion,
    this.vector,
    this.distancia,
    this.recorrido,
  );
}

Offset _unitario(Offset v) {
  final d = v.distance;
  return d == 0 ? Offset.zero : v / d;
}

Offset _perpendicular(Offset v) => Offset(v.dy, -v.dx);

double _punto(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

Offset _girarAlrededor(Offset a, Offset centro, double r) {
  final s = math.sin(r), c = math.cos(r);
  final px = a.dx - centro.dx, py = a.dy - centro.dy;
  return Offset(px * c - py * s + centro.dx, px * s + py * c + centro.dy);
}

List<_PuntoTrazo> _puntosDelTrazo(List<PuntoTinta> entrada, OpcionesTinta o) {
  if (entrada.isEmpty) return const [];
  final t = 0.15 + (1 - o.estabilizado) * 0.85;
  var puntos = entrada;
  if (puntos.length == 2) {
    // Con solo dos puntos se interpolan intermedios para que el contorno
    // tenga cuerpo.
    final a = puntos[0], b = puntos[1];
    puntos = [
      a,
      for (var i = 1; i < 5; i++)
        PuntoTinta(
          a.x + (b.x - a.x) * i / 4,
          a.y + (b.y - a.y) * i / 4,
          a.presion + (b.presion - a.presion) * i / 4,
        ),
    ];
  }
  final resultado = <_PuntoTrazo>[
    _PuntoTrazo(puntos.first.offset, puntos.first.presion, const Offset(1, 1),
        0, 0),
  ];
  var alcanzoMinimo = false;
  var recorrido = 0.0;
  var previo = resultado.first;
  final ultimo = puntos.length - 1;
  for (var i = 1; i < puntos.length; i++) {
    final p = o.terminado && i == ultimo
        ? puntos[i].offset
        : Offset.lerp(previo.punto, puntos[i].offset, t)!;
    if (p == previo.punto) continue;
    final distancia = (p - previo.punto).distance;
    recorrido += distancia;
    if (i < ultimo && !alcanzoMinimo) {
      if (recorrido < o.tamano) continue;
      alcanzoMinimo = true;
    }
    previo = _PuntoTrazo(
      p,
      puntos[i].presion,
      _unitario(previo.punto - p),
      distancia,
      recorrido,
    );
    resultado.add(previo);
  }
  if (resultado.length > 1) {
    final r = resultado[0];
    resultado[0] = _PuntoTrazo(
      r.punto,
      r.presion,
      resultado[1].vector,
      r.distancia,
      r.recorrido,
    );
  }
  return resultado;
}

double _radio(double tamano, double adelgazado, double presion) =>
    tamano * (0.5 - adelgazado * (0.5 - presion));

/// Polígono del contorno del trazo. Vacío si no hay puntos.
List<Offset> contornoTinta(List<PuntoTinta> entrada, OpcionesTinta o) {
  final puntos = _puntosDelTrazo(entrada, o);
  if (puntos.isEmpty || o.tamano <= 0) return const [];
  final total = puntos.last.recorrido;
  final distanciaMinima = math.pow(o.tamano * o.suavizado, 2).toDouble();
  final izquierda = <Offset>[];
  final derecha = <Offset>[];

  var presionPrevia = puntos.take(10).fold<double>(puntos.first.presion, (
    acc,
    actual,
  ) {
    var presion = actual.presion;
    if (o.simularPresion) {
      final sp = math.min(1.0, actual.distancia / o.tamano);
      final rp = math.min(1.0, 1 - sp);
      presion = math.min(1.0, acc + (rp - acc) * (sp * _ritmoPresion));
    }
    return (acc + presion) / 2;
  });

  var radio = _radio(o.tamano, o.adelgazado, puntos.last.presion);
  double? primerRadio;
  var vectorPrevio = puntos.first.vector;
  var pl = puntos.first.punto, pr = pl, tl = pl, tr = pr;
  var esquinaPrevia = false;

  for (var i = 0; i < puntos.length; i++) {
    final actual = puntos[i];
    var presion = actual.presion;
    if (i < puntos.length - 1 && total - actual.recorrido < 3) continue;

    if (o.adelgazado != 0) {
      if (o.simularPresion) {
        final sp = math.min(1.0, actual.distancia / o.tamano);
        final rp = math.min(1.0, 1 - sp);
        presion = math.min(
          1.0,
          presionPrevia + (rp - presionPrevia) * (sp * _ritmoPresion),
        );
      }
      radio = _radio(o.tamano, o.adelgazado, presion);
    } else {
      radio = o.tamano / 2;
    }
    radio = math.max(0.01, radio);
    primerRadio ??= radio;

    final vectorSiguiente =
        (i < puntos.length - 1 ? puntos[i + 1] : actual).vector;
    final dprSiguiente =
        i < puntos.length - 1 ? _punto(actual.vector, vectorSiguiente) : 1.0;
    final dprPrevio = _punto(actual.vector, vectorPrevio);
    final esquina = dprPrevio < 0 && !esquinaPrevia;
    final esquinaSiguiente = dprSiguiente < 0;

    if (esquina || esquinaSiguiente) {
      // Vuelta cerrada: se rodea la punta con un medio círculo.
      final desplazamiento = _perpendicular(vectorPrevio) * radio;
      for (var t = 0.0; t <= 1; t += 1 / 13) {
        tl = _girarAlrededor(
          actual.punto - desplazamiento,
          actual.punto,
          _piFijo * t,
        );
        izquierda.add(tl);
        tr = _girarAlrededor(
          actual.punto + desplazamiento,
          actual.punto,
          _piFijo * -t,
        );
        derecha.add(tr);
      }
      pl = tl;
      pr = tr;
      if (esquinaSiguiente) esquinaPrevia = true;
      continue;
    }
    esquinaPrevia = false;

    if (i == puntos.length - 1) {
      final desplazamiento = _perpendicular(actual.vector) * radio;
      izquierda.add(actual.punto - desplazamiento);
      derecha.add(actual.punto + desplazamiento);
      continue;
    }

    final mezcla = Offset.lerp(vectorSiguiente, actual.vector, dprSiguiente)!;
    final desplazamiento = _perpendicular(mezcla) * radio;
    tl = actual.punto - desplazamiento;
    if (i <= 1 || (pl - tl).distanceSquared > distanciaMinima) {
      izquierda.add(tl);
      pl = tl;
    }
    tr = actual.punto + desplazamiento;
    if (i <= 1 || (pr - tr).distanceSquared > distanciaMinima) {
      derecha.add(tr);
      pr = tr;
    }
    presionPrevia = presion;
    vectorPrevio = actual.vector;
  }

  final primero = puntos.first.punto;
  final ultimo = puntos.length > 1
      ? puntos.last.punto
      : puntos.first.punto + const Offset(1, 1);

  // Un toque: un punto redondo.
  if (puntos.length == 1 || izquierda.isEmpty || derecha.isEmpty) {
    final r = primerRadio ?? radio;
    return [
      for (var t = 0.0; t < 1; t += 1 / 13)
        _girarAlrededor(
          primero + Offset(r, 0),
          primero,
          _piFijo * 2 * t,
        ),
    ];
  }

  final puntaInicial = <Offset>[
    for (var t = 1 / 13; t <= 1; t += 1 / 13)
      _girarAlrededor(derecha.first, primero, _piFijo * t),
  ];
  final direccion = _perpendicular(-puntos.last.vector);
  final inicioFinal = ultimo + direccion * radio;
  final puntaFinal = <Offset>[
    for (var t = 1 / 29; t < 1; t += 1 / 29)
      _girarAlrededor(inicioFinal, ultimo, _piFijo * 3 * t),
  ];
  return [
    ...izquierda,
    ...puntaFinal,
    ...derecha.reversed,
    ...puntaInicial,
  ];
}

/// Camino cerrado y suave que pasa por el contorno (curvas por los puntos
/// medios, como recomienda perfect-freehand).
Path caminoTinta(List<Offset> contorno) {
  final camino = Path();
  if (contorno.isEmpty) return camino;
  if (contorno.length < 3) {
    final c = contorno.first;
    return camino..addOval(Rect.fromCircle(center: c, radius: 1));
  }
  camino.moveTo(contorno.first.dx, contorno.first.dy);
  for (var i = 0; i < contorno.length; i++) {
    final a = contorno[i];
    final b = contorno[(i + 1) % contorno.length];
    camino.quadraticBezierTo(a.dx, a.dy, (a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  }
  return camino..close();
}

/// El mismo camino en sintaxis de SVG.
String svgDeContorno(List<Offset> contorno) {
  if (contorno.length < 3) return '';
  String f(double v) => v.toStringAsFixed(1);
  final b = StringBuffer('M${f(contorno.first.dx)} ${f(contorno.first.dy)}');
  for (var i = 0; i < contorno.length; i++) {
    final a = contorno[i];
    final c = contorno[(i + 1) % contorno.length];
    b.write(
      ' Q${f(a.dx)} ${f(a.dy)} ${f((a.dx + c.dx) / 2)} ${f((a.dy + c.dy) / 2)}',
    );
  }
  b.write(' Z');
  return b.toString();
}
