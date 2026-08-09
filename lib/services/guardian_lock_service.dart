import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum GuardianVerifyResult { ok, wrong, lockedOut }

/// ═══════════════════════════════════════════════════════════════════════════
/// CANDADO DEL GUARDIÁN (opcional)
///
/// Un PIN que idealmente solo conoce el Compañero de Batalla. Cuando está
/// activo, desactivar el Escudo de Pureza requiere ese PIN, para que el usuario
/// no lo apague por impulso en un momento de debilidad.
///
/// El PIN se guarda hasheado (SHA-256 + salt) en almacenamiento seguro; nunca
/// en texto plano. Incluye bloqueo temporal tras varios intentos fallidos para
/// que un PIN corto no sea fácil de adivinar por fuerza bruta.
///
/// Honestidad: esto añade fricción, no es infranqueable. Android siempre permite
/// apagar una VPN desde los ajustes del sistema o desinstalar la app. El candado
/// protege el interruptor dentro de la app, que es donde ocurren las recaídas
/// impulsivas.
/// ═══════════════════════════════════════════════════════════════════════════
class GuardianLockService {
  GuardianLockService._();
  static final GuardianLockService I = GuardianLockService._();

  static const _storage = FlutterSecureStorage();
  static const _kHash = 'guardian_pin_hash';
  static const _kSalt = 'guardian_pin_salt';
  static const _kFails = 'guardian_fail_count';
  static const _kLockUntil = 'guardian_lock_until';

  static const int _maxAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 15);

  /// Notifica cambios (activado/desactivado) para refrescar la UI.
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);

  Future<void> refresh() async {
    enabled.value = await isEnabled();
  }

  Future<bool> isEnabled() async {
    try {
      final hash = await _storage.read(key: _kHash);
      return hash != null && hash.isNotEmpty;
    } catch (e) {
      debugPrint('[GuardianLock] isEnabled error: $e');
      return false;
    }
  }

  /// Define el PIN (lo hace el compañero). Requiere 4 a 8 dígitos.
  Future<bool> setPin(String pin) async {
    if (!_isValidPin(pin)) return false;
    try {
      final salt = _randomSalt();
      final hash = _hash(pin, salt);
      await _storage.write(key: _kSalt, value: salt);
      await _storage.write(key: _kHash, value: hash);
      await _storage.delete(key: _kFails);
      await _storage.delete(key: _kLockUntil);
      enabled.value = true;
      return true;
    } catch (e) {
      debugPrint('[GuardianLock] setPin error: $e');
      return false;
    }
  }

  /// Verifica el PIN, respetando el bloqueo por intentos fallidos.
  Future<GuardianVerifyResult> verify(String pin) async {
    final remaining = await lockoutRemaining();
    if (remaining != null && remaining > Duration.zero) {
      return GuardianVerifyResult.lockedOut;
    }
    try {
      final salt = await _storage.read(key: _kSalt);
      final hash = await _storage.read(key: _kHash);
      if (salt == null || hash == null) return GuardianVerifyResult.wrong;
      if (_hash(pin, salt) == hash) {
        await _storage.delete(key: _kFails);
        await _storage.delete(key: _kLockUntil);
        return GuardianVerifyResult.ok;
      }
      // Intento fallido → incrementar y quizá bloquear.
      final fails = (int.tryParse(await _storage.read(key: _kFails) ?? '0') ?? 0) + 1;
      await _storage.write(key: _kFails, value: '$fails');
      if (fails >= _maxAttempts) {
        final until = DateTime.now().add(_lockoutDuration).millisecondsSinceEpoch;
        await _storage.write(key: _kLockUntil, value: '$until');
        await _storage.write(key: _kFails, value: '0');
        return GuardianVerifyResult.lockedOut;
      }
      return GuardianVerifyResult.wrong;
    } catch (e) {
      debugPrint('[GuardianLock] verify error: $e');
      return GuardianVerifyResult.wrong;
    }
  }

  /// Tiempo restante de bloqueo, o null si no está bloqueado.
  Future<Duration?> lockoutRemaining() async {
    try {
      final raw = await _storage.read(key: _kLockUntil);
      if (raw == null) return null;
      final until = int.tryParse(raw);
      if (until == null) return null;
      final diff = until - DateTime.now().millisecondsSinceEpoch;
      return diff > 0 ? Duration(milliseconds: diff) : null;
    } catch (_) {
      return null;
    }
  }

  /// Quita el candado. Debe llamarse solo después de verificar el PIN.
  Future<void> clear() async {
    try {
      await _storage.delete(key: _kHash);
      await _storage.delete(key: _kSalt);
      await _storage.delete(key: _kFails);
      await _storage.delete(key: _kLockUntil);
    } catch (e) {
      debugPrint('[GuardianLock] clear error: $e');
    }
    enabled.value = false;
  }

  bool _isValidPin(String pin) {
    return RegExp(r'^\d{4,8}$').hasMatch(pin);
  }

  String _randomSalt() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt|$pin')).toString();
  }
}
