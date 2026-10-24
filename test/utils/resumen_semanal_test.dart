// Mismo ejemplo que functions/test/rendicionCuentasLogica.test.js: la app
// muestra exactamente el texto que la Cloud Function envía al compañero.
import 'package:app_quitar/utils/resumen_semanal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('texto completo igual al del servidor', () {
    final texto = textoResumenSemanal(
      nombre: 'Daniel',
      datos: const DatosResumenSemanal(
        diasRegistrados: 6,
        victorias: 5,
        gracias: 1,
        racha: 12,
        escudoActivo: true,
        bloqueos: 1,
      ),
      compartir: const CompartirResumen(),
    );
    expect(
      texto,
      'Resumen semanal de Daniel\n'
      '• Registró 6 de 7 días.\n'
      '• 5 días de victoria y 1 de gracia.\n'
      '• Racha actual: 12 días.\n'
      '• Escudo de Pureza: activo · 1 bloqueo esta semana.\n'
      'Ora por Daniel y anímale esta semana.',
    );
  });

  test('respeta lo que el usuario no comparte', () {
    final texto = textoResumenSemanal(
      nombre: 'Ana',
      datos: const DatosResumenSemanal(
        diasRegistrados: 1,
        victorias: 1,
        gracias: 0,
        racha: 1,
        escudoActivo: false,
        bloqueos: 4,
      ),
      compartir: const CompartirResumen(
        registro: false,
        victoriaGracia: false,
        racha: false,
        escudo: false,
      ),
    );
    expect(
      texto,
      'Resumen semanal de Ana\n• Sigue en la batalla esta semana.\n'
      'Ora por Ana y anímale esta semana.',
    );
  });

  test('sin Escudo (iOS) no menciona el Escudo', () {
    final texto = textoResumenSemanal(
      nombre: 'Luis',
      datos: const DatosResumenSemanal(
        diasRegistrados: 7,
        victorias: 1,
        gracias: 6,
      ),
      compartir: const CompartirResumen(),
    );
    expect(texto, isNot(contains('Escudo')));
    expect(texto, contains('• 1 día de victoria y 6 de gracia.'));
  });

  test('CompartirResumen ida y vuelta', () {
    const c = CompartirResumen(racha: false);
    expect(CompartirResumen.fromMap(c.toMap()).racha, isFalse);
    expect(CompartirResumen.fromMap(null).escudo, isTrue);
  });
}
