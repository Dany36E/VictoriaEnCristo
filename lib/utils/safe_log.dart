import 'package:flutter/foundation.dart';

/// Helpers de logging seguros: solo emiten en `kDebugMode` (el no-op de
/// `debugPrint` en release cubre todo internamente) y truncan uid/tokens.
///
/// Niveles:
///   `safeLog`   → info:  `[TAG] mensaje`
///   `safeWarn`  → warn:  `[WARN][TAG] mensaje`
///   `safeError` → error: `[ERROR][TAG] mensaje — error`
///
/// Migración: reemplazar `debugPrint('🔐 [AUTH] msg $e')` por
/// `safeError('AUTH', 'msg', e)`. No migrar en masa — sólo al tocar el archivo.
void safeLog(String tag, String message) {
  if (kDebugMode) {
    debugPrint('[$tag] $message');
  }
}

void safeWarn(String tag, String message) {
  if (kDebugMode) {
    debugPrint('[WARN][$tag] $message');
  }
}

void safeError(String tag, String message, [Object? error]) {
  if (kDebugMode) {
    final suffix = error != null ? ' — $error' : '';
    debugPrint('[ERROR][$tag] $message$suffix');
  }
}

/// Devuelve solo los primeros 6 chars de un uid (suficiente para correlación
/// en logs sin exponer el id completo).
String shortUid(String? uid) {
  if (uid == null || uid.isEmpty) return '<none>';
  final n = uid.length < 6 ? uid.length : 6;
  return '${uid.substring(0, n)}…';
}

/// Devuelve solo los primeros 8 chars + sufijo "…" para tokens; nunca loggear
/// el token completo (FCM, OAuth, BLB API key).
String shortToken(String? token) {
  if (token == null || token.isEmpty) return '<none>';
  final n = token.length < 8 ? token.length : 8;
  return '${token.substring(0, n)}…';
}
