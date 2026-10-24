import 'dart:io';

import 'package:app_quitar/services/planes_retirados_cleanup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Limpieza única de planes retirados', () {
    Map<String, Object> prefsConPlanes() => {
      'plan_active_id': 'mente-blindada',
      'plan_all_progress': '{"mente-blindada":{}}',
      'active_plan_id': 'mente-blindada',
      'plans_cache_v1': '[]',
      'plans_pending_writes': '[]',
      'daily_practice_v1:2026-10-22': '{"devotional":true}',
    };

    test('cancela recordatorios, borra el progreso y no toca lo demás', () async {
      SharedPreferences.setMockInitialValues(prefsConPlanes());
      var cancelaciones = 0;
      final hecho = await PlanesRetiradosCleanup.ejecutarUnaVez(
        cancelarRecordatorios: () async {
          cancelaciones++;
          return true;
        },
      );
      expect(hecho, isTrue);
      expect(cancelaciones, 1);
      final prefs = await SharedPreferences.getInstance();
      for (final clave in PlanesRetiradosCleanup.clavesDePlanes) {
        expect(prefs.containsKey(clave), isFalse, reason: clave);
      }
      expect(prefs.getString('daily_practice_v1:2026-10-22'), isNotNull);
      expect(prefs.getBool(PlanesRetiradosCleanup.claveHecha), isTrue);

      // Una sola vez.
      final otra = await PlanesRetiradosCleanup.ejecutarUnaVez(
        cancelarRecordatorios: () async {
          cancelaciones++;
          return true;
        },
      );
      expect(otra, isFalse);
      expect(cancelaciones, 1);
    });

    test('si cancelar falla, se reintenta en el próximo arranque', () async {
      SharedPreferences.setMockInitialValues(prefsConPlanes());
      final primero = await PlanesRetiradosCleanup.ejecutarUnaVez(
        cancelarRecordatorios: () async => false,
      );
      expect(primero, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(PlanesRetiradosCleanup.claveHecha), isNull);

      final segundo = await PlanesRetiradosCleanup.ejecutarUnaVez(
        cancelarRecordatorios: () async => true,
      );
      expect(segundo, isTrue);
    });

    test('un error inesperado no rompe el arranque', () async {
      SharedPreferences.setMockInitialValues({});
      final r = await PlanesRetiradosCleanup.ejecutarUnaVez(
        cancelarRecordatorios: () async => throw StateError('plugin'),
      );
      expect(r, isFalse);
    });
  });

  group('Sin restos de los planes de lectura', () {
    test('no quedan pantallas, servicios ni assets de planes', () {
      for (final ruta in [
        'assets/content/plans.json',
        'assets/images/plan_covers',
        'lib/screens/plan_library_screen.dart',
        'lib/screens/plan_detail_screen_v2.dart',
        'lib/screens/plan_reader_screen.dart',
        'lib/screens/day_reading_screen.dart',
        'lib/services/plan_progress_service.dart',
        'lib/services/plan_repository.dart',
        'lib/services/plans_sync_adapter.dart',
        'lib/repositories/plans_repository.dart',
        'lib/models/plan.dart',
        'lib/data/dummy_plans.dart',
        'lib/widgets/home/plans_section.dart',
      ]) {
        expect(
          FileSystemEntity.typeSync(ruta),
          FileSystemEntityType.notFound,
          reason: ruta,
        );
      }
    });

    test('ningún archivo de lib/ ni pubspec los menciona', () {
      final prohibidos = RegExp(
        r'PlanLibraryScreen|PlanDetailScreen|PlanReaderScreen|'
        r'DayReadingScreen|PlansRepository|PlanProgressService|'
        r'PlanRepository\b|PlansSyncAdapter|openPlanLibrary|'
        r'scheduleDailyPlanReminder|plans\.json|plan_covers|dummy_plans',
      );
      final archivos = [
        File('pubspec.yaml'),
        ...Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
      ];
      final hallazgos = <String>[];
      for (final f in archivos) {
        final lineas = f.readAsLinesSync();
        for (var i = 0; i < lineas.length; i++) {
          if (prohibidos.hasMatch(lineas[i])) {
            hallazgos.add('${f.path}:${i + 1}: ${lineas[i].trim()}');
          }
        }
      }
      expect(hallazgos, isEmpty);
    });
  });
}
