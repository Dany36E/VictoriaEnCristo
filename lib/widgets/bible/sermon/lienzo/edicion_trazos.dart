/// Operaciones sobre los trazos del lienzo: borrar trazos completos o solo
/// una parte, seleccionar con el lazo y enderezar líneas.
library;

import 'dart:math' as math;
import 'dart:ui';

import '../../../../models/bible/dibujo_nota.dart';
import '../../../../utils/tinta.dart';

double distanciaASegmento(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final largo2 = ab.distanceSquared;
  if (largo2 == 0) return (p - a).distance;
  final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / largo2).clamp(
    0.0,
    1.0,
  );
  return (p - (a + ab * t)).distance;
}

bool _tocaTrazo(Trazo t, Offset p, double radio) {
  final alcance = radio + t.grosor / 2;
  if (!t.limites.inflate(radio).contains(p)) return false;
  final pts = t.puntos;
  if (pts.length == 1) return (pts.first.offset - p).distance <= alcance;
  for (var i = 1; i < pts.length; i++) {
    if (distanciaASegmento(p, pts[i - 1].offset, pts[i].offset) <= alcance) {
      return true;
    }
  }
  return false;
}

/// Quita los trazos que toca el borrador (como el borrador de objetos de
/// Notas). Devuelve la misma lista si no tocó nada.
List<Trazo> borrarTrazosCompletos(List<Trazo> trazos, Offset p, double radio) {
  final quedan = [
    for (final t in trazos)
      if (!_tocaTrazo(t, p, radio)) t,
  ];
  return quedan.length == trazos.length ? trazos : quedan;
}

/// Borra solo la parte que toca el borrador, partiendo los trazos.
List<Trazo> borrarParcial(List<Trazo> trazos, Offset p, double radio) {
  var cambio = false;
  final resultado = <Trazo>[];
  for (final t in trazos) {
    if (!_tocaTrazo(t, p, radio)) {
      resultado.add(t);
      continue;
    }
    cambio = true;
    var tramo = <PuntoTinta>[];
    for (final punto in t.puntos) {
      if ((punto.offset - p).distance <= radio + t.grosor / 4) {
        if (tramo.length >= 2) resultado.add(t.copiar(puntos: tramo));
        tramo = <PuntoTinta>[];
      } else {
        tramo.add(punto);
      }
    }
    if (tramo.length >= 2) resultado.add(t.copiar(puntos: tramo));
  }
  return cambio ? resultado : trazos;
}

bool puntoEnPoligono(Offset p, List<Offset> poligono) {
  var dentro = false;
  for (var i = 0, j = poligono.length - 1; i < poligono.length; j = i++) {
    final a = poligono[i], b = poligono[j];
    if ((a.dy > p.dy) != (b.dy > p.dy) &&
        p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
      dentro = !dentro;
    }
  }
  return dentro;
}

/// Índices de los trazos que quedan dentro del lazo (al menos la mitad de
/// sus puntos).
Set<int> seleccionarConLazo(List<Trazo> trazos, List<Offset> lazo) {
  if (lazo.length < 3) return const {};
  final seleccion = <int>{};
  for (var i = 0; i < trazos.length; i++) {
    final pts = trazos[i].puntos;
    final dentro = pts.where((p) => puntoEnPoligono(p.offset, lazo)).length;
    if (dentro * 2 >= pts.length) seleccion.add(i);
  }
  return seleccion;
}

Rect? limitesDe(List<Trazo> trazos, Iterable<int> indices) {
  Rect? caja;
  for (final i in indices) {
    final l = trazos[i].limites;
    caja = caja == null ? l : caja.expandToInclude(l);
  }
  return caja;
}

/// Línea recta entre dos puntos, con puntos intermedios para que la tinta
/// tenga el mismo grosor de punta a punta.
List<PuntoTinta> lineaRecta(PuntoTinta a, PuntoTinta b) {
  final largo = (b.offset - a.offset).distance;
  final pasos = math.max(2, (largo / 6).ceil());
  return [
    for (var i = 0; i <= pasos; i++)
      PuntoTinta(
        a.x + (b.x - a.x) * i / pasos,
        a.y + (b.y - a.y) * i / pasos,
        0.5,
      ),
  ];
}
