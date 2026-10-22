import 'package:app_quitar/services/exercise_log_service.dart';
import 'package:flutter_test/flutter_test.dart';

ExerciseCompletion registro(String id, DateTime cuando) => ExerciseCompletion(
  id: id,
  exerciseId: 'respiracion',
  completedAt: cuando,
  durationSeconds: 60,
);

void main() {
  final lunes = registro('1', DateTime.utc(2026, 10, 19, 8));
  final martes = registro('2', DateTime.utc(2026, 10, 20, 8));
  final miercoles = registro('3', DateTime.utc(2026, 10, 21, 8));

  test('la primera vez sube todo lo que no está en la nube', () {
    final pendientes = ExerciseLogService.porSubir(
      [miercoles, martes, lunes],
      enNube: {'2'},
    );
    expect(pendientes.map((e) => e.id), ['3', '1']);
  });

  test('después solo sube lo nuevo desde la última sincronización', () {
    final marca = martes.completedAt.toUtc().toIso8601String();
    final pendientes = ExerciseLogService.porSubir(
      [miercoles, martes, lunes],
      enNube: const {},
      marca: marca,
    );
    expect(pendientes.map((e) => e.id), ['3']);
  });

  test('si ya llegó de la nube no se vuelve a subir', () {
    final marca = lunes.completedAt.toUtc().toIso8601String();
    final pendientes = ExerciseLogService.porSubir(
      [miercoles, martes],
      enNube: {'3', '2'},
      marca: marca,
    );
    expect(pendientes, isEmpty);
  });
}
