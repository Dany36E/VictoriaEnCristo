import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PURITY GUARD — Bloqueador de contenido adulto (Gigante "Pureza Sexual")
///
/// Android: activa una VPN local que filtra DNS. Al detectar una web XXX,
/// la bloquea en cualquier navegador y lanza la app en "Necesito Ayuda".
/// El motor real vive en Kotlin (PurityVpnService); aquí está el puente.
///
/// iOS: no es posible un bloqueador real con certificado gratis (requiere
/// Network Extension de pago). La pantalla de Protección guía al usuario a
/// activar el filtro integrado de iOS (Tiempo en Pantalla).
/// ═══════════════════════════════════════════════════════════════════════════
class PurityGuardService {
  PurityGuardService._();
  static final PurityGuardService I = PurityGuardService._();

  static const _channel = MethodChannel('victoria/purity_guard');
  static const _prefKeyDesired = 'purityGuardDesiredOn';
  static const _prefDisclosureVersion = 'purityGuardDisclosureVersion';
  static const int disclosureVersion = 1;

  /// Estado real del bloqueador (VPN corriendo).
  final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  /// True solo en plataformas donde el motor propio funciona (Android).
  bool get isEngineSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid;
    } catch (_) {
      return false;
    }
  }

  /// True en iOS/iPadOS: mostramos guía al filtro nativo de iOS.
  bool get isIOS {
    if (kIsWeb) return false;
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Sincroniza [active] con el estado real de la VPN nativa.
  Future<void> refresh() async {
    if (!isEngineSupported) {
      active.value = false;
      return;
    }
    try {
      final running = await _channel.invokeMethod<bool>('isRunning');
      active.value = running ?? false;
    } catch (e) {
      debugPrint('[PurityGuard] refresh error: $e');
    }
  }

  /// Estadísticas de bloqueos: total histórico y del día de hoy.
  Future<({int total, int today})> blockStats() async {
    if (!isEngineSupported) return (total: 0, today: 0);
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>('blockStats');
      return (
        total: (m?['total'] as int?) ?? 0,
        today: (m?['today'] as int?) ?? 0,
      );
    } catch (e) {
      debugPrint('[PurityGuard] blockStats error: $e');
      return (total: 0, today: 0);
    }
  }

  /// Cuántos dominios contiene la lista de bloqueo empaquetada.
  Future<int> blocklistCount() async {
    if (!isEngineSupported) return 0;
    try {
      final n = await _channel.invokeMethod<int>('blocklistCount');
      return n ?? 0;
    } catch (e) {
      debugPrint('[PurityGuard] blocklistCount error: $e');
      return 0;
    }
  }

  /// Activa el bloqueador. En Android pide el permiso de VPN si hace falta.
  /// Devuelve true si quedó activo.
  Future<bool> enable() async {
    if (!isEngineSupported) return false;
    try {
      final ok = await _channel.invokeMethod<bool>('start');
      active.value = ok ?? false;
      await _setDesired(active.value);
      return active.value;
    } catch (e) {
      debugPrint('[PurityGuard] enable error: $e');
      return false;
    }
  }

  /// El aviso debe aceptarse antes de solicitar el permiso VPN de Android.
  /// Se versiona para volver a mostrarlo si cambia el tratamiento de datos.
  Future<bool> hasAcceptedDisclosure() async {
    if (!isEngineSupported) return true;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefDisclosureVersion) == disclosureVersion;
  }

  Future<void> acceptDisclosure() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefDisclosureVersion, disclosureVersion);
  }

  /// Desactiva el bloqueador.
  Future<void> disable() async {
    if (!isEngineSupported) return;
    try {
      await _channel.invokeMethod('stop');
    } catch (e) {
      debugPrint('[PurityGuard] disable error: $e');
    }
    active.value = false;
    await _setDesired(false);
  }

  /// Si el usuario lo tenía activo, reintenta encenderlo silenciosamente al
  /// abrir la app (solo funciona si el permiso de VPN ya fue concedido; si no,
  /// Android no muestra el diálogo sin gesto del usuario y simplemente no
  /// arranca — el usuario lo reactiva desde Protección).
  Future<void> restoreIfEnabled() async {
    if (!isEngineSupported) return;
    final prefs = await SharedPreferences.getInstance();
    final desired = prefs.getBool(_prefKeyDesired) ?? false;
    if (!desired) {
      await refresh();
      return;
    }
    await refresh();
    if (!active.value) {
      // Reintento silencioso; si requiere consentimiento, no hará nada.
      try {
        final ok = await _channel.invokeMethod<bool>('startIfPrepared');
        active.value = ok ?? false;
      } catch (e) {
        debugPrint('[PurityGuard] restore error: $e');
      }
    }
  }

  Future<void> _setDesired(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKeyDesired, value);
  }
}
