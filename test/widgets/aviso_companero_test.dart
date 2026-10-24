import 'package:app_quitar/models/wall_post.dart';
import 'package:app_quitar/services/shield_status_service.dart';
import 'package:app_quitar/widgets/aviso_companero.dart';
import 'package:app_quitar/widgets/ayuda_crisis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Avisar a mi compañero (ventana para deshacer)', () {
    testWidgets('envía al terminar la ventana', (tester) async {
      var llamadas = 0;
      int? resultado;
      final c = AvisoCompaneroController(
        enviar: () async {
          llamadas++;
          return 2;
        },
      );
      expect(c.programar(alTerminar: (n) => resultado = n), isTrue);
      expect(c.estado.value, EstadoAviso.esperando);
      await tester.pump(const Duration(seconds: 4));
      expect(llamadas, 0);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();
      expect(llamadas, 1);
      expect(resultado, 2);
      expect(c.estado.value, EstadoAviso.enviado);
    });

    testWidgets('deshacer dentro de la ventana no envía nada', (tester) async {
      var llamadas = 0;
      final c = AvisoCompaneroController(
        enviar: () async {
          llamadas++;
          return 1;
        },
      );
      c.programar();
      await tester.pump(const Duration(seconds: 2));
      expect(c.deshacer(), isTrue);
      await tester.pump(const Duration(seconds: 10));
      expect(llamadas, 0);
      expect(c.estado.value, EstadoAviso.inactivo);
      expect(c.deshacer(), isFalse);
    });

    testWidgets('no programa dos avisos a la vez y reporta fallos', (
      tester,
    ) async {
      final c = AvisoCompaneroController(enviar: () async => 0);
      expect(c.programar(), isTrue);
      expect(c.programar(), isFalse);
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      expect(c.estado.value, EstadoAviso.fallido);
      expect(c.programar(), isTrue, reason: 'se puede reintentar');
      c.reiniciar();
    });
  });

  group('respuesta del Muro con señales de crisis', () {
    test('no se toma como éxito ni como "en revisión"', () {
      final r = WallPostResult.fromCallable({
        'success': false,
        'status': 'crisis',
        'crisis': true,
        'message': 'No lo publicamos',
      });
      expect(r.crisis, isTrue);
      expect(r.success, isFalse);
      final normal = WallPostResult.fromCallable({
        'success': true,
        'message': 'Tu publicación está en revisión.',
      });
      expect(normal.crisis, isFalse);
      expect(normal.success, isTrue);
    });
  });

  group('líneas de crisis', () {
    test('todas se pueden marcar (tel:) sin espacios', () {
      for (final l in kLineasCrisis) {
        expect(l.uri.scheme, 'tel');
        expect(l.marcar, isNot(contains(' ')));
        expect(l.marcar, matches(RegExp(r'^\*?[0-9]{3,10}$')));
      }
      expect(kLineasCrisis.map((l) => l.marcar), containsAll(['024', '988']));
    });
  });

  group('cambios del Escudo a reportar', () {
    final ahora = DateTime(2026, 10, 23, 8);

    test(
      'apagado con la app cerrada y vuelto a encender: se conservan ambos',
      () {
        final apagado = CambioEscudo(
          MotivoEscudo.permisoRevocado,
          DateTime(2026, 10, 23, 1),
        );
        final c = decidirCambiosEscudo(
          deseado: true,
          activo: true,
          ultimoActivoReportado: true,
          nativo: EventosNativosEscudo(
            apagado: apagado,
            encendido: DateTime(2026, 10, 23, 7),
          ),
          ahora: ahora,
        );
        expect(c.apagado, apagado);
        expect(c.encendido, DateTime(2026, 10, 23, 7));
      },
    );

    test('lo apagó el usuario desde la app', () {
      final c = decidirCambiosEscudo(
        deseado: false,
        activo: false,
        ultimoActivoReportado: true,
        nativo: null,
        ahora: ahora,
      );
      expect(c.apagado?.motivo, MotivoEscudo.apagadoPorUsuario);
    });

    test('lo quería encendido y no corre: detenido', () {
      final c = decidirCambiosEscudo(
        deseado: true,
        activo: false,
        ultimoActivoReportado: null,
        nativo: null,
        ahora: ahora,
      );
      expect(c.apagado?.motivo, MotivoEscudo.detenido);
    });

    test('nunca lo activó: no se inventa un apagado', () {
      final c = decidirCambiosEscudo(
        deseado: false,
        activo: false,
        ultimoActivoReportado: null,
        nativo: null,
        ahora: ahora,
      );
      expect(c.apagado, isNull);
      expect(c.encendido, isNull);
    });

    test('encendido nuevo', () {
      final c = decidirCambiosEscudo(
        deseado: true,
        activo: true,
        ultimoActivoReportado: false,
        nativo: null,
        ahora: ahora,
      );
      expect(c.encendido, ahora);
      expect(c.apagado, isNull);
    });
  });
}
