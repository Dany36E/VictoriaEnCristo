/// ═══════════════════════════════════════════════════════════════════════════
/// ANÁLISIS DE PATRONES — horas y días de más riesgo, detonantes y emociones.
/// Lógica pura (sin Flutter) para poder probarla.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'fecha_calendario.dart';

/// Un evento para analizar (registro propio o entrada del diario).
class EventoPatron {
  final DateTime fecha;

  /// `true` si fue una caída; `false` si fue una tentación.
  final bool caida;
  final List<String> etiquetas;

  const EventoPatron({
    required this.fecha,
    required this.caida,
    required this.etiquetas,
  });
}

/// Resultado del análisis.
class Patrones {
  final int total;
  final int caidas;

  /// Eventos por hora del día (0-23).
  final List<int> porHora;

  /// Eventos por día de la semana (0 = lunes … 6 = domingo).
  final List<int> porDia;

  /// Detonantes ordenados de más a menos frecuente.
  final List<MapEntry<String, int>> detonantes;

  /// Para cada emoción frecuente, eventos por semana (de la más antigua a
  /// la actual).
  final Map<String, List<int>> emocionesPorSemana;

  const Patrones({
    required this.total,
    required this.caidas,
    required this.porHora,
    required this.porDia,
    required this.detonantes,
    required this.emocionesPorSemana,
  });

  bool get vacio => total == 0;

  /// Hora con más eventos (o `null` si no hay).
  int? get horaPico => _indiceMaximo(porHora);

  /// Día con más eventos (0 = lunes) o `null`.
  int? get diaPico => _indiceMaximo(porDia);

  static int? _indiceMaximo(List<int> valores) {
    var mejor = -1;
    var max = 0;
    for (var i = 0; i < valores.length; i++) {
      if (valores[i] > max) {
        max = valores[i];
        mejor = i;
      }
    }
    return mejor < 0 ? null : mejor;
  }
}

const List<String> kDiasSemana = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// Analiza [eventos]. [emociones] dice qué etiquetas son emociones;
/// [semanas] cuántas semanas mostrar en la evolución.
Patrones analizarPatrones(
  List<EventoPatron> eventos, {
  required Set<String> emociones,
  required DateTime hoy,
  int semanas = 8,
  int maxEmociones = 3,
}) {
  final porHora = List<int>.filled(24, 0);
  final porDia = List<int>.filled(7, 0);
  final conteo = <String, int>{};
  final conteoEmocion = <String, int>{};
  var caidas = 0;

  for (final e in eventos) {
    porHora[e.fecha.hour]++;
    porDia[e.fecha.weekday - 1]++;
    if (e.caida) caidas++;
    for (final et in e.etiquetas.toSet()) {
      conteo[et] = (conteo[et] ?? 0) + 1;
      if (emociones.contains(et)) {
        conteoEmocion[et] = (conteoEmocion[et] ?? 0) + 1;
      }
    }
  }

  int orden(MapEntry<String, int> a, MapEntry<String, int> b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  }

  final detonantes = conteo.entries.toList()..sort(orden);
  final topEmociones = (conteoEmocion.entries.toList()..sort(orden))
      .take(maxEmociones)
      .map((e) => e.key)
      .toList();

  // Semanas de lunes a domingo; la última es la actual.
  final lunesActual = FechaCalendario.sumarDias(hoy, -(hoy.weekday - 1));
  final inicio = FechaCalendario.sumarDias(lunesActual, -7 * (semanas - 1));
  final evolucion = {
    for (final emo in topEmociones) emo: List<int>.filled(semanas, 0),
  };
  for (final e in eventos) {
    final dias = FechaCalendario.diasEntre(inicio, e.fecha);
    if (dias < 0) continue;
    final semana = dias ~/ 7;
    if (semana >= semanas) continue;
    for (final emo in e.etiquetas.toSet()) {
      evolucion[emo]?[semana]++;
    }
  }

  return Patrones(
    total: eventos.length,
    caidas: caidas,
    porHora: porHora,
    porDia: porDia,
    detonantes: detonantes,
    emocionesPorSemana: evolucion,
  );
}

/// "entre las 22:00 y las 23:00".
String textoFranjaHora(int hora) {
  final fin = (hora + 1) % 24;
  String h(int x) => '${x.toString().padLeft(2, '0')}:00';
  return 'entre las ${h(hora)} y las ${h(fin)}';
}
