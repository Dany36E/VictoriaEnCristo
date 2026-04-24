/// ═══════════════════════════════════════════════════════════════════════════
/// SyncRetry - Wrapper con backoff exponencial + cola acotada
///
/// Uso:
///   final result = await SyncRetry.withBackoff(
///     where: 'JournalSync.add',
///     () => FirebaseFirestore.instance.collection(...).add(...),
///   );
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../services/app_error_handler.dart';

class SyncRetry {
  SyncRetry._();

  /// Ejecuta [action] con reintentos exponenciales (máx [maxAttempts]).
  ///
  /// Delays: 500ms, 1s, 2s (con jitter). Si todos fallan, reporta a AppErrorHandler
  /// con [severity] y retorna `null`. No lanza excepción (para no romper UI).
  static Future<T?> withBackoff<T>(
    Future<T> Function() action, {
    required String where,
    int maxAttempts = 3,
    Duration baseDelay = const Duration(milliseconds: 500),
    ErrorSeverity severity = ErrorSeverity.low,
    String? userMessageOnFinalFail,
  }) async {
    final rnd = math.Random();
    Object? lastErr;
    StackTrace? lastStack;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await action();
      } catch (e, s) {
        lastErr = e;
        lastStack = s;
        if (attempt == maxAttempts - 1) break;
        final expo = baseDelay * math.pow(2, attempt).toInt();
        final jitter = Duration(milliseconds: rnd.nextInt(200));
        final wait = expo + jitter;
        if (kDebugMode) {
          debugPrint(
              '🔁 [$where] attempt ${attempt + 1}/$maxAttempts failed: $e — retry in ${wait.inMilliseconds}ms');
        }
        await Future.delayed(wait);
      }
    }

    AppErrorHandler.I.report(
      lastErr ?? 'unknown',
      stack: lastStack,
      where: where,
      severity: severity,
      userMessage: userMessageOnFinalFail,
      extra: {'attempts': maxAttempts},
    );
    return null;
  }
}

/// Debouncer simple: agrupa múltiples llamadas rápidas en una sola después de
/// [duration] de inactividad.
class Debouncer {
  final Duration duration;
  Timer? _timer;

  Debouncer({this.duration = const Duration(milliseconds: 400)});

  void call(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() => cancel();
}

/// Cola acotada FIFO en memoria: si se llena descarta la más vieja.
/// Útil para sync queues que no deben crecer sin límite.
class BoundedQueue<T> {
  final int maxSize;
  final List<T> _items = [];

  BoundedQueue({this.maxSize = 100});

  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;
  List<T> get items => List.unmodifiable(_items);

  /// Agrega al final; si excede maxSize descarta la primera.
  void add(T value) {
    _items.add(value);
    while (_items.length > maxSize) {
      _items.removeAt(0);
    }
  }

  T? removeFirst() => _items.isEmpty ? null : _items.removeAt(0);
  void clear() => _items.clear();
}
