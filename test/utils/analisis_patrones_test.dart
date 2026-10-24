import 'package:app_quitar/utils/analisis_patrones.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hoy = DateTime(2026, 10, 23, 12); // viernes
  const emociones = {'Soledad', 'Estrés'};

  test('sin eventos', () {
    final p = analizarPatrones(const [], emociones: emociones, hoy: hoy);
    expect(p.vacio, isTrue);
    expect(p.horaPico, isNull);
    expect(p.diaPico, isNull);
    expect(p.emocionesPorSemana, isEmpty);
  });

  test('horas, días, detonantes y emociones por semana', () {
    final eventos = [
      EventoPatron(
        fecha: DateTime(2026, 10, 22, 23, 10),
        caida: true,
        etiquetas: const ['Soledad', 'Noche', 'Celular'],
      ),
      EventoPatron(
        fecha: DateTime(2026, 10, 21, 23, 40),
        caida: false,
        etiquetas: const ['Soledad', 'Celular'],
      ),
      EventoPatron(
        fecha: DateTime(2026, 10, 15, 14),
        caida: false,
        etiquetas: const ['Estrés'],
      ),
      // Etiqueta repetida en el mismo evento cuenta una vez.
      EventoPatron(
        fecha: DateTime(2026, 10, 1, 23),
        caida: true,
        etiquetas: const ['Soledad', 'Soledad'],
      ),
    ];
    final p = analizarPatrones(eventos, emociones: emociones, hoy: hoy);
    expect(p.total, 4);
    expect(p.caidas, 2);
    expect(p.horaPico, 23);
    expect(p.porHora[23], 3);
    expect(p.diaPico, 3); // jueves (1, 15 y 22 de oct.)
    expect(p.detonantes.first, isA<MapEntry<String, int>>());
    expect(p.detonantes.first.key, 'Soledad');
    expect(p.detonantes.first.value, 3);
    expect(p.emocionesPorSemana.keys, ['Soledad', 'Estrés']);
    // La última semana es la actual (19-25 oct.).
    expect(p.emocionesPorSemana['Soledad']!.last, 2);
    expect(p.emocionesPorSemana['Estrés']![6], 1);
    expect(p.emocionesPorSemana['Soledad']![4], 1);
  });

  test('franja horaria en texto', () {
    expect(textoFranjaHora(22), 'entre las 22:00 y las 23:00');
    expect(textoFranjaHora(23), 'entre las 23:00 y las 00:00');
  });
}
