import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/safe_log.dart';

/// Lee /config/app desde Firestore, cachea en SharedPreferences con TTL 6h.
/// Offline-first: la app arranca con defaults hardcoded y actualiza en background.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService I = RemoteConfigService._();

  static const _prefsKey = 'remote_config_json';
  static const _prefsTsKey = 'remote_config_ts';
  static const _ttl = Duration(hours: 6);

  Map<String, dynamic> _cache = {};
  bool _initialized = false;

  /// Inicializa: carga cache local de forma síncrona, luego refresca en background.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    await _loadLocal();
    _fetchAndCache(); // fire-and-forget — no bloquea el startup
  }

  /// Devuelve el valor del flag, o [defaultValue] si no existe / tipo incorrecto.
  T get<T>(String key, T defaultValue) {
    final value = _cache[key];
    if (value is T) return value;
    return defaultValue;
  }

  Future<void> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          _cache = decoded;
          safeLog('REMOTE-CFG', 'Loaded ${_cache.length} flags from cache');
        }
      }
    } catch (e) {
      safeWarn('REMOTE-CFG', 'Could not load local cache: $e');
    }
  }

  Future<void> _fetchAndCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastTs = prefs.getInt(_prefsTsKey) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - lastTs;
      if (age < _ttl.inMilliseconds) {
        safeLog('REMOTE-CFG', 'Cache fresh (${age ~/ 1000}s old), skipping fetch');
        return;
      }

      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('app')
          .get()
          .timeout(const Duration(seconds: 5));

      final data = snap.data();
      if (data == null) return;

      _cache = Map<String, dynamic>.from(data);
      await prefs.setString(_prefsKey, jsonEncode(_cache));
      await prefs.setInt(_prefsTsKey, DateTime.now().millisecondsSinceEpoch);
      safeLog('REMOTE-CFG', 'Fetched ${_cache.length} flags from Firestore');
    } catch (e) {
      // Silencioso: la app sigue funcionando con defaults / cache anterior.
      safeWarn('REMOTE-CFG', 'Fetch failed (using cached/defaults): $e');
    }
  }

  /// Fuerza un re-fetch en el próximo init (útil para tests).
  Future<void> invalidateCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    await prefs.remove(_prefsTsKey);
    _cache = {};
    _initialized = false;
  }
}
