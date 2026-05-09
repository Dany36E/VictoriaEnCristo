import 'package:flutter/foundation.dart';

/// Helper de logging seguro: solo emite en `kDebugMode` y trunca cualquier
/// `uid` o token a un prefijo corto para evitar fugas en builds release y en
/// `adb logcat` capturado por terceros.
///
/// Uso:
/// ```dart
/// safeLog('FCM', 'token=${shortToken(token)}');
/// safeLog('AUTH', 'uid=${shortUid(uid)} login OK');
/// ```
void safeLog(String tag, String message) {
  if (kDebugMode) {
    debugPrint('[$tag] $message');
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
