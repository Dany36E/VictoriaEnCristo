import 'package:flutter_test/flutter_test.dart';
import 'package:app_quitar/utils/retry_utils.dart';

void main() {
  group('retryWithBackoff', () {
    test('retorna valor al éxito en primer intento', () async {
      final result = await retryWithBackoff(
        () async => 42,
        initialDelay: const Duration(milliseconds: 1),
      );
      expect(result, 42);
    });

    test('reintenta y tiene éxito en segundo intento', () async {
      int attempts = 0;
      final result = await retryWithBackoff(
        () async {
          attempts++;
          if (attempts < 2) throw Exception('fail');
          return 'ok';
        },
        initialDelay: const Duration(milliseconds: 1),
      );
      expect(result, 'ok');
      expect(attempts, 2);
    });

    test('reintenta y tiene éxito en tercer intento', () async {
      int attempts = 0;
      final result = await retryWithBackoff(
        () async {
          attempts++;
          if (attempts < 3) throw Exception('fail');
          return 'recovered';
        },
        initialDelay: const Duration(milliseconds: 1),
      );
      expect(result, 'recovered');
      expect(attempts, 3);
    });

    test('lanza excepción después de maxAttempts fallos', () async {
      expect(
        () => retryWithBackoff(
          () async {
            throw Exception('always fails');
          },
          maxAttempts: 3,
          initialDelay: const Duration(milliseconds: 1),
        ),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('always fails'),
        )),
      );
    });

    test('respeta maxAttempts = 1 (sin reintentos)', () async {
      expect(
        () => retryWithBackoff(
          () async {
            throw Exception('no retry');
          },
          maxAttempts: 1,
          initialDelay: const Duration(milliseconds: 1),
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('ejecuta exactamente maxAttempts veces antes de fallar', () async {
      int attempts = 0;
      try {
        await retryWithBackoff(
          () async {
            attempts++;
            throw Exception('fail');
          },
          maxAttempts: 4,
          initialDelay: const Duration(milliseconds: 1),
        );
      } catch (_) {}
      expect(attempts, 4);
    });

    test('funciona con tipos genéricos distintos', () async {
      final listResult = await retryWithBackoff<List<int>>(
        () async => [1, 2, 3],
        initialDelay: const Duration(milliseconds: 1),
      );
      expect(listResult, [1, 2, 3]);

      final mapResult = await retryWithBackoff<Map<String, bool>>(
        () async => {'ok': true},
        initialDelay: const Duration(milliseconds: 1),
      );
      expect(mapResult, {'ok': true});
    });

    test('preserva el tipo de excepción original', () async {
      expect(
        () => retryWithBackoff(
          () async => throw FormatException('bad format'),
          maxAttempts: 1,
          initialDelay: const Duration(milliseconds: 1),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
