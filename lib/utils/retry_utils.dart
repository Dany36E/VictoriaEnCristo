/// ═══════════════════════════════════════════════════════════════════════════
/// RETRY UTILS - Utilidad de reintento con backoff exponencial
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

/// Ejecuta [operation] con reintentos y backoff exponencial.
/// - [maxAttempts]: máximo de intentos (default 3)
/// - [initialDelay]: delay antes del primer reintento (default 1s)
/// - Delay se duplica en cada intento: 1s, 2s, 4s...
Future<T> retryWithBackoff<T>(
  Future<T> Function() operation, {
  int maxAttempts = 3,
  Duration initialDelay = const Duration(seconds: 1),
}) async {
  for (int attempt = 0; attempt < maxAttempts; attempt++) {
    try {
      return await operation();
    } catch (e) {
      if (attempt == maxAttempts - 1) rethrow;
      final delay = initialDelay * (1 << attempt);
      debugPrint('⏳ [RETRY] Attempt ${attempt + 1}/$maxAttempts failed, retrying in ${delay.inMilliseconds}ms...');
      await Future.delayed(delay);
    }
  }
  throw StateError('unreachable');
}

/// Timeouts estándar para operaciones de red
class NetworkTimeouts {
  NetworkTimeouts._();
  
  /// Lectura Firestore con Source.server
  static const firestoreServer = Duration(seconds: 15);
  
  /// API HTTP estándar
  static const httpDefault = Duration(seconds: 10);
  
  /// Carga de assets/parsing
  static const assetLoad = Duration(seconds: 8);
}
