/// ═══════════════════════════════════════════════════════════════════════════
/// AppErrorHandler - Manejo centralizado de errores
///
/// Rutea errores a:
/// - Crashlytics (con contexto y severidad)
/// - Snackbar/banner al usuario (mensajes amables)
/// - debugPrint en dev
///
/// Evita que los servicios se acoplen a ScaffoldMessenger o a Firebase.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../theme/app_theme.dart';

enum ErrorSeverity {
  /// No bloquea al usuario, se loguea. Ej: un sync falló en silencio.
  low,

  /// Afecta una acción puntual. Se muestra snackbar.
  medium,

  /// Afecta el flujo principal. Se muestra banner persistente + Crashlytics.
  high,

  /// Crashlytics fatal.
  fatal,
}

class AppErrorHandler {
  AppErrorHandler._();
  static final AppErrorHandler I = AppErrorHandler._();

  /// MessengerKey opcional para mostrar snackbars sin context.
  /// Asignar en main.dart: `MaterialApp(scaffoldMessengerKey: AppErrorHandler.I.messengerKey)`.
  final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Reporta un error con contexto.
  ///
  /// [where] identifica el origen (ej. 'JournalSyncAdapter.updateEntry').
  /// [userMessage] si se provee, se muestra al usuario (medium/high severity).
  void report(
    Object error, {
    StackTrace? stack,
    required String where,
    ErrorSeverity severity = ErrorSeverity.medium,
    String? userMessage,
    Map<String, Object?>? extra,
  }) {
    // Log siempre en debug
    debugPrint('❌ [$where] ($severity) $error');
    if (stack != null && severity.index >= ErrorSeverity.high.index) {
      debugPrint(stack.toString());
    }

    // Crashlytics según severidad
    try {
      final crash = FirebaseCrashlytics.instance;
      crash.setCustomKey('where', where);
      if (extra != null) {
        for (final e in extra.entries) {
          final v = e.value;
          if (v == null) continue;
          crash.setCustomKey(e.key, v.toString());
        }
      }
      switch (severity) {
        case ErrorSeverity.low:
          // Solo log, no crashlytics (ruido).
          break;
        case ErrorSeverity.medium:
          crash.recordError(error, stack, reason: where, fatal: false);
          break;
        case ErrorSeverity.high:
          crash.recordError(error, stack, reason: where, fatal: false);
          break;
        case ErrorSeverity.fatal:
          crash.recordError(error, stack, reason: where, fatal: true);
          break;
      }
    } catch (_) {
      // Crashlytics puede no estar inicializado en tests.
    }

    // Mensaje al usuario
    if (userMessage != null &&
        severity.index >= ErrorSeverity.medium.index) {
      showSnack(userMessage, isError: true);
    }
  }

  /// Muestra un snackbar sin requerir context (usa [messengerKey]).
  void showSnack(String message, {bool isError = false, Duration? duration}) {
    final state = messengerKey.currentState;
    if (state == null) {
      debugPrint('⚠️  Snackbar sin messenger: $message');
      return;
    }
    state.hideCurrentSnackBar();
    state.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? AppDesignSystem.struggle
            : AppDesignSystem.midnightLight,
        duration: duration ?? const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
