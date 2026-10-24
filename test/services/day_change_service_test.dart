import 'package:app_quitar/services/daily_practice_service.dart';
import 'package:app_quitar/services/day_change_service.dart';
import 'package:app_quitar/utils/time_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => TimeUtils.relojParaPruebas = null);

  group('DayChangeService', () {
    test('comprobar avisa solo cuando cambia la fecha local', () {
      var ahora = DateTime(2026, 10, 22, 22, 30);
      final servicio = DayChangeService(reloj: () => ahora);
      final avisos = <String>[];
      servicio.hoy.addListener(() => avisos.add(servicio.hoy.value));

      expect(servicio.comprobar(), isFalse);
      ahora = DateTime(2026, 10, 22, 23, 59, 59);
      expect(servicio.comprobar(), isFalse);
      ahora = DateTime(2026, 10, 23, 0, 0, 1);
      expect(servicio.comprobar(), isTrue);
      expect(servicio.comprobar(), isFalse);
      expect(avisos, ['2026-10-23']);
    });

    test('al volver del fondo varios días después también avisa', () {
      var ahora = DateTime(2026, 10, 20, 8);
      final servicio = DayChangeService(reloj: () => ahora);
      ahora = DateTime(2026, 10, 23, 7);
      expect(servicio.comprobar(), isTrue);
      expect(servicio.hoy.value, '2026-10-23');
    });

    test('el temporizador espera hasta pasada la medianoche', () {
      final servicio = DayChangeService(
        reloj: () => DateTime(2026, 10, 22, 23, 59, 0),
      );
      final espera = servicio.tiempoHastaMedianoche();
      expect(espera, greaterThan(const Duration(seconds: 60)));
      expect(espera, lessThan(const Duration(seconds: 70)));
    });

    testWidgets('con la app abierta, el temporizador detecta la medianoche', (
      tester,
    ) async {
      var ahora = DateTime(2026, 10, 22, 23, 58);
      final servicio = DayChangeService(reloj: () => ahora);
      var avisos = 0;
      servicio.hoy.addListener(() => avisos++);

      servicio.iniciarTemporizador();
      expect(servicio.temporizadorActivo, isTrue);

      // Un minuto después todavía es el mismo día.
      ahora = DateTime(2026, 10, 22, 23, 59);
      await tester.pump(const Duration(minutes: 1));
      expect(avisos, 0);

      // Pasada la medianoche el temporizador dispara y se reprograma.
      ahora = DateTime(2026, 10, 23, 0, 0, 3);
      await tester.pump(const Duration(minutes: 1, seconds: 3));
      expect(avisos, 1);
      expect(servicio.hoy.value, '2026-10-23');
      expect(servicio.temporizadorActivo, isTrue);

      servicio.detenerTemporizador();
      expect(servicio.temporizadorActivo, isFalse);
    });
  });

  group('Prácticas de hoy al cambiar de día', () {
    test('las marcas de ayer (incluido el devocional) no se ven hoy', () async {
      SharedPreferences.setMockInitialValues({});
      var ahora = DateTime(2026, 10, 22, 21);
      TimeUtils.relojParaPruebas = () => ahora;
      final practicas = DailyPracticeService.I;
      await practicas.init();

      await practicas.mark(DailyPractice.devotional);
      await practicas.mark(DailyPractice.journal);
      expect(practicas.snapshotNotifier.value.devotional, isTrue);
      expect(practicas.snapshotNotifier.value.completedCount, 2);

      // La app queda en segundo plano y vuelve al día siguiente.
      ahora = DateTime(2026, 10, 23, 7, 30);
      practicas.refresh();
      expect(practicas.snapshotNotifier.value.devotional, isFalse);
      expect(practicas.snapshotNotifier.value.completedCount, 0);
      // La racha de devocionales conserva el día de ayer.
      expect(practicas.devotionalDatesCompleted, contains('2026-10-22'));

      // Marcar hoy funciona sobre la fecha nueva.
      await practicas.mark(DailyPractice.devotional);
      expect(practicas.devotionalStreak, 2);
    });
  });
}
