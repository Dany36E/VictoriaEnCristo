/// ═══════════════════════════════════════════════════════════════════════════
/// TalentsService — economía de "Talentos" (Mt 25)
///
/// Diseñado para ser:
///   1. Offline-first: SharedPreferences es la verdad. Funciona sin red.
///   2. Token-friendly con Firestore: 1 lectura al login, 1 escritura por
///      ventana de 30 s (debounced). Talentos y coleccionables comparten
///      documento → 1 sola escritura.
///   3. Conflict-free: al primer login en otro dispositivo, máximo de balance
///      y unión de unlocks (nunca se pierde lo coleccionado).
///
/// Estructura del documento Firestore:
///   users/{uid}/learning/economy
///     {
///       balance:       int,    // talentos disponibles
///       totalEarned:   int,    // suma de todo lo que ha ganado
///       totalSpent:    int,    // suma de todo lo gastado
///       unlocked:      [str],  // IDs de coleccionables (compartido con
///                              // CollectiblesService — un solo doc para
///                              // ahorrar writes)
///       updatedAt:     ts,     // server timestamp
///     }
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tabla pública de recompensas. Centralizada para no esparcir magic numbers.
class TalentRewards {
  TalentRewards._();

  // Maná
  static const int perCorrectAnswer = 1;
  static const int sessionPerfectBonus = 5;

  // Versículos (Armadura)
  static const int verseMastered = 20;

  // Travesía
  static const int journeyStation = 10;

  // Héroes / Parábolas / Línea / Fruto / Mapas / Profecías / Libros / Orden
  static const int heroUnlocked = 15;
  static const int parableCompleted = 12;
  static const int timelineLessonStar = 4; // por estrella
  static const int fruitBadge = 25;
  static const int mapPerStar = 6; // 18 si 3★
  static const int prophecyPerStar = 4;
  static const int bookStudied = 15;
  static const int bibleOrderPerStar = 3;

  // Streaks
  static const int streak7 = 30;
  static const int streak30 = 150;

  // Reglas de seguridad
  static const int maxBalance = 999999;
}

/// Una entrada del libro de transacciones (ledger). Solo se guarda local.
@immutable
class TalentEntry {
  final int delta; // +ganado / -gastado
  final String reason; // "mana_perfect", "verse_mastered:eph_6_11", ...
  final int balanceAfter;
  final int atMs;

  const TalentEntry({
    required this.delta,
    required this.reason,
    required this.balanceAfter,
    required this.atMs,
  });

  Map<String, dynamic> toJson() => {
        'delta': delta,
        'reason': reason,
        'balanceAfter': balanceAfter,
        'atMs': atMs,
      };

  factory TalentEntry.fromJson(Map<String, dynamic> j) => TalentEntry(
        delta: (j['delta'] as num?)?.toInt() ?? 0,
        reason: (j['reason'] as String?) ?? '',
        balanceAfter: (j['balanceAfter'] as num?)?.toInt() ?? 0,
        atMs: (j['atMs'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class TalentsState {
  final int balance;
  final int totalEarned;
  final int totalSpent;
  final Set<String> unlocked; // espejo del CollectiblesService

  const TalentsState({
    required this.balance,
    required this.totalEarned,
    required this.totalSpent,
    required this.unlocked,
  });

  const TalentsState.initial()
      : balance = 0,
        totalEarned = 0,
        totalSpent = 0,
        unlocked = const {};

  TalentsState copyWith({
    int? balance,
    int? totalEarned,
    int? totalSpent,
    Set<String>? unlocked,
  }) =>
      TalentsState(
        balance: balance ?? this.balance,
        totalEarned: totalEarned ?? this.totalEarned,
        totalSpent: totalSpent ?? this.totalSpent,
        unlocked: unlocked ?? this.unlocked,
      );
}

class TalentsService {
  TalentsService._();
  static final TalentsService I = TalentsService._();

  // ── Claves locales ──────────────────────────────────────────────────────
  static const String _kStateV1 = 'learning.talents.v1';
  static const String _kLedgerV1 = 'learning.talents.ledger.v1';
  static const int _ledgerMaxEntries = 50;

  // ── Debounce de Firestore ───────────────────────────────────────────────
  static const Duration _syncDebounce = Duration(seconds: 30);

  bool _init = false;
  SharedPreferences? _prefs;
  Timer? _syncTimer;
  bool _dirty = false;

  /// Notificador de balance. Las UIs pequeñas (badge, modales) escuchan esto.
  final ValueNotifier<TalentsState> stateNotifier =
      ValueNotifier(const TalentsState.initial());

  /// Última recompensa otorgada (útil para mostrar toast/animación). Cambia
  /// en cada `earn()`. La UI puede escucharlo y limpiar tras mostrar.
  final ValueNotifier<TalentEntry?> lastEarnNotifier = ValueNotifier(null);

  /// Ledger en memoria (solo local, no se sincroniza).
  final List<TalentEntry> _ledger = [];
  List<TalentEntry> get recentEntries => List.unmodifiable(_ledger);

  /// Inicializa: lee de SharedPreferences, e intenta merge con Firestore (best
  /// effort). Si está offline, sigue sin error.
  Future<void> init() async {
    if (_init) return;
    _prefs = await SharedPreferences.getInstance();
    _init = true;
    _loadFromPrefs();
    _loadLedger();
    // Intento de merge con la nube — no bloquea el init.
    unawaited(_pullFromCloud());
    debugPrint(
        '⭐ [TALENTS] Init balance=${stateNotifier.value.balance} '
        'unlocks=${stateNotifier.value.unlocked.length}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PERSISTENCIA LOCAL
  // ══════════════════════════════════════════════════════════════════════════

  void _loadFromPrefs() {
    final raw = _prefs?.getString(_kStateV1);
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      stateNotifier.value = TalentsState(
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        totalEarned: (j['totalEarned'] as num?)?.toInt() ?? 0,
        totalSpent: (j['totalSpent'] as num?)?.toInt() ?? 0,
        unlocked: ((j['unlocked'] as List?)
                ?.map((e) => '$e')
                .toSet() ??
            {}),
      );
    } catch (_) {/* estado inicial */}
  }

  Future<void> _saveToPrefs() async {
    final s = stateNotifier.value;
    final j = {
      'balance': s.balance,
      'totalEarned': s.totalEarned,
      'totalSpent': s.totalSpent,
      'unlocked': s.unlocked.toList(),
    };
    await _prefs?.setString(_kStateV1, jsonEncode(j));
  }

  void _loadLedger() {
    final raw = _prefs?.getString(_kLedgerV1);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _ledger
        ..clear()
        ..addAll(list.map(TalentEntry.fromJson));
    } catch (_) {/* swallow */}
  }

  Future<void> _saveLedger() async {
    final list = _ledger.map((e) => e.toJson()).toList();
    await _prefs?.setString(_kLedgerV1, jsonEncode(list));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA
  // ══════════════════════════════════════════════════════════════════════════

  /// Otorga talentos. Idempotente sólo si el llamador controla la deduplicación
  /// (este servicio no lo hace; cada llamada es una transacción nueva).
  Future<void> earn(int amount, {required String reason}) async {
    if (!_init) await init();
    if (amount <= 0) return;
    final s = stateNotifier.value;
    final newBalance = (s.balance + amount).clamp(0, TalentRewards.maxBalance);
    final newTotal = s.totalEarned + amount;
    stateNotifier.value = s.copyWith(
      balance: newBalance,
      totalEarned: newTotal,
    );
    final entry = TalentEntry(
      delta: amount,
      reason: reason,
      balanceAfter: newBalance,
      atMs: DateTime.now().millisecondsSinceEpoch,
    );
    _appendLedger(entry);
    lastEarnNotifier.value = entry;
    await _saveToPrefs();
    _scheduleSync();
  }

  /// Intenta gastar. Devuelve true si tenía saldo y la transacción se aplicó.
  Future<bool> spend(int amount, {required String reason}) async {
    if (!_init) await init();
    if (amount <= 0) return true;
    final s = stateNotifier.value;
    if (s.balance < amount) return false;
    final newBalance = s.balance - amount;
    stateNotifier.value = s.copyWith(
      balance: newBalance,
      totalSpent: s.totalSpent + amount,
    );
    _appendLedger(TalentEntry(
      delta: -amount,
      reason: reason,
      balanceAfter: newBalance,
      atMs: DateTime.now().millisecondsSinceEpoch,
    ));
    await _saveToPrefs();
    _scheduleSync();
    return true;
  }

  /// Llamado por CollectiblesService cuando agrega/quita unlocks. No persiste
  /// los talentos (los gestiona spend), solo refresca el espejo de unlocked y
  /// programa sync.
  Future<void> mirrorUnlocked(Set<String> unlocked) async {
    if (!_init) await init();
    final s = stateNotifier.value;
    if (setEquals(s.unlocked, unlocked)) return;
    stateNotifier.value = s.copyWith(unlocked: unlocked);
    await _saveToPrefs();
    _scheduleSync();
  }

  void _appendLedger(TalentEntry e) {
    _ledger.insert(0, e);
    if (_ledger.length > _ledgerMaxEntries) {
      _ledger.removeRange(_ledgerMaxEntries, _ledger.length);
    }
    unawaited(_saveLedger());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // FIREBASE — escrituras debounceadas, lectura única
  // ══════════════════════════════════════════════════════════════════════════

  void _scheduleSync() {
    _dirty = true;
    _syncTimer?.cancel();
    _syncTimer = Timer(_syncDebounce, () {
      unawaited(_pushToCloud());
    });
  }

  /// Fuerza un push inmediato (útil al cerrar sesión / dispose).
  Future<void> flushSync() async {
    _syncTimer?.cancel();
    if (_dirty) await _pushToCloud();
  }

  DocumentReference<Map<String, dynamic>>? _docRef() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('learning')
        .doc('economy');
  }

  Future<void> _pushToCloud() async {
    final ref = _docRef();
    if (ref == null) return;
    final s = stateNotifier.value;
    try {
      await ref.set({
        'balance': s.balance,
        'totalEarned': s.totalEarned,
        'totalSpent': s.totalSpent,
        'unlocked': s.unlocked.toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _dirty = false;
      debugPrint(
          '⭐ [TALENTS] Push OK balance=${s.balance} unlocks=${s.unlocked.length}');
    } catch (e) {
      debugPrint('⭐ [TALENTS] Push falló (lo reintentaremos): $e');
      // No reintentamos: el próximo earn/spend volverá a programar el sync.
    }
  }

  Future<void> _pullFromCloud() async {
    final ref = _docRef();
    if (ref == null) return;
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        // Primera vez: subimos el local (si tiene algo).
        if (stateNotifier.value.balance > 0 ||
            stateNotifier.value.unlocked.isNotEmpty) {
          _scheduleSync();
        }
        return;
      }
      final j = snap.data() ?? {};
      final remoteBalance = (j['balance'] as num?)?.toInt() ?? 0;
      final remoteEarned = (j['totalEarned'] as num?)?.toInt() ?? 0;
      final remoteSpent = (j['totalSpent'] as num?)?.toInt() ?? 0;
      final remoteUnlocked = ((j['unlocked'] as List?)
              ?.map((e) => '$e')
              .toSet() ??
          {});
      final s = stateNotifier.value;
      // Resolución de conflicto: max balance/totales, unión de unlocks.
      final merged = TalentsState(
        balance: s.balance > remoteBalance ? s.balance : remoteBalance,
        totalEarned:
            s.totalEarned > remoteEarned ? s.totalEarned : remoteEarned,
        totalSpent: s.totalSpent > remoteSpent ? s.totalSpent : remoteSpent,
        unlocked: {...s.unlocked, ...remoteUnlocked},
      );
      // Solo persistimos y empujamos si hay cambios.
      final changed = merged.balance != s.balance ||
          merged.totalEarned != s.totalEarned ||
          merged.totalSpent != s.totalSpent ||
          !setEquals(merged.unlocked, s.unlocked);
      if (changed) {
        stateNotifier.value = merged;
        await _saveToPrefs();
        _scheduleSync();
      }
      debugPrint(
          '⭐ [TALENTS] Pull OK remoto=$remoteBalance local=${s.balance} merged=${merged.balance}');
    } catch (e) {
      debugPrint('⭐ [TALENTS] Pull falló: $e');
    }
  }

  /// Solo tests.
  @visibleForTesting
  Future<void> resetForTesting() async {
    _syncTimer?.cancel();
    _ledger.clear();
    stateNotifier.value = const TalentsState.initial();
    lastEarnNotifier.value = null;
    await _prefs?.remove(_kStateV1);
    await _prefs?.remove(_kLedgerV1);
  }
}
