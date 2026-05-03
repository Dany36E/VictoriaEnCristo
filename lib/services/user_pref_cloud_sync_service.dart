import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Syncs small user-scoped SharedPreferences values that are not already owned
/// by a dedicated repository/service.
class UserPrefCloudSyncService {
  UserPrefCloudSyncService._();
  static final UserPrefCloudSyncService I = UserPrefCloudSyncService._();

  static const List<String> _exactKeys = <String>[
    'devotional_current_day',
    'devotional_v2_length',
    'devotional_v2_history_v1',
    'devotional_v2_rollout_percent',
    'devotional_v2_rollout_seed',
    'devotional_v2_rollout_forced_variant',
    'recommendation_history_v1',
    'widget_config_json',
    'sacred_alarm_config_v1',
    'sacred_alarm_events_v1',
    'victory_threshold',
    'last_broken_streak_v1',
    'last_break_date_iso_v1',
    'relapse_ack_date_iso_v1',
    'grace_tokens_v1',
    'grace_tokens_month_v1',
    'grace_days_used_v1',
    'journey_start_iso_v1',
    'learning.mana.session_v1',
    'lastReadBookNumber',
    'lastReadBookName',
    'lastReadChapter',
    'bible_study_mode_enabled',
    'advanced_search_history',
    'bible_search_recent',
    'parallel_font_size',
    'morning_checkin_last_shown',
    'audio_bgm_enabled',
    'audio_sfx_enabled',
    'audio_bgm_volume',
    'audio_sfx_volume',
    'audio_enabled',
    'audio_speed',
    'audio_pitch',
    'feedback_haptics_enabled',
    'feedback_sfx_enabled',
    'feedback_sfx_volume',
    'app_theme_id',
    'auto_theme',
    'last_dark_theme',
    'last_light_theme',
    'morning_notification_enabled',
    'morning_notification_time',
    'night_notification_enabled',
    'night_notification_time',
    'emergency_reminder_enabled',
    'victory_reminder_enabled',
    'reengagement_enabled',
    'battle.acceptingInvites',
    'battle.trustedPartnerUid',
    'active_plan_id',
    'plan_active_id',
  ];

  static const List<String> _prefixes = <String>[
    'devotional_challenge_',
    'devotional_v2_challenge_',
    'devotional_v2_override_giant_',
    'daily_practice_v1:',
  ];

  static const String _localUpdatedPrefix = 'user_pref_sync.updatedAtMs.v1.';
  static const Duration _debounce = Duration(seconds: 10);

  SharedPreferences? _prefs;
  Timer? _timer;
  String? _uid;
  String? _bootstrappedUid;
  bool _dirty = false;

  Future<void> bootstrap(String uid, {bool force = false}) async {
    if (!force && _bootstrappedUid == uid) return;
    _prefs ??= await SharedPreferences.getInstance();
    _uid = uid;
    _bootstrappedUid = uid;

    final ref = _docRef(uid);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        if (_hasLocalData()) _schedulePush();
        debugPrint('☁️ [USER_PREF_SYNC] Remote doc empty, local push scheduled');
        return;
      }

      final data = snap.data() ?? const <String, dynamic>{};
      final remoteMs = (data['updatedAtMs'] as num?)?.toInt() ?? 0;
      final localMs = _prefs?.getInt(_localUpdatedKey(uid)) ?? 0;
      final remotePrefs = Map<String, dynamic>.from(
        (data['prefs'] as Map?) ?? const <String, dynamic>{},
      );

      if (remoteMs > localMs) {
        await _restorePrefs(remotePrefs);
        await _prefs?.setInt(_localUpdatedKey(uid), remoteMs);
        debugPrint('☁️ [USER_PREF_SYNC] Restored ${remotePrefs.length} prefs from cloud');
      } else if (localMs > remoteMs && _hasLocalData()) {
        _schedulePush();
        debugPrint('☁️ [USER_PREF_SYNC] Local prefs newer, push scheduled');
      }
    } catch (e) {
      debugPrint('☁️ [USER_PREF_SYNC] Bootstrap skipped: $e');
    }
  }

  void markDirty() {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    _dirty = true;
    _prefs?.setInt(_localUpdatedKey(uid), DateTime.now().millisecondsSinceEpoch);
    _schedulePush();
  }

  Future<void> flush() async {
    _timer?.cancel();
    if (_dirty) await _push();
  }

  void resetForSignOut() {
    _timer?.cancel();
    _uid = null;
    _bootstrappedUid = null;
    _dirty = false;
  }

  Future<void> clearLocalCache() async {
    _prefs ??= await SharedPreferences.getInstance();
    final prefs = _prefs;
    if (prefs == null) return;

    for (final key in _exactKeys) {
      await prefs.remove(key);
    }
    final keys = prefs.getKeys().toList(growable: false);
    for (final key in keys) {
      if (_prefixes.any(key.startsWith) || key.startsWith(_localUpdatedPrefix)) {
        await prefs.remove(key);
      }
    }
    resetForSignOut();
  }

  DocumentReference<Map<String, dynamic>> _docRef(String uid) {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('appState')
        .doc('preferences');
  }

  String _localUpdatedKey(String uid) => '$_localUpdatedPrefix$uid';

  bool _hasLocalData() => _collectPrefs().isNotEmpty;

  Map<String, dynamic> _collectPrefs() {
    final prefs = _prefs;
    if (prefs == null) return const <String, dynamic>{};

    final out = <String, dynamic>{};
    for (final key in _exactKeys) {
      final value = prefs.get(key);
      if (value != null) out[key] = _firestoreValue(value);
    }
    for (final key in prefs.getKeys()) {
      if (!_prefixes.any(key.startsWith)) continue;
      final value = prefs.get(key);
      if (value != null) out[key] = _firestoreValue(value);
    }
    return out;
  }

  Object _firestoreValue(Object value) {
    if (value is List<String>) return value;
    if (value is String || value is bool || value is int || value is double) {
      return value;
    }
    return value.toString();
  }

  Future<void> _restorePrefs(Map<String, dynamic> prefsMap) async {
    final prefs = _prefs;
    if (prefs == null) return;
    final remoteOwnedKeys = _ownedKeysFrom(prefsMap.keys);
    await _removeOwnedPrefsMissingFromRemote(prefs, remoteOwnedKeys);

    for (final entry in prefsMap.entries) {
      final key = entry.key;
      if (!_isSyncedKey(key)) continue;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(key, value);
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      } else if (value is double) {
        await prefs.setDouble(key, value);
      } else if (value is num) {
        await prefs.setDouble(key, value.toDouble());
      } else if (value is List) {
        await prefs.setStringList(key, value.map((e) => e.toString()).toList());
      }
    }
  }

  bool _isSyncedKey(String key) {
    return _exactKeys.contains(key) || _prefixes.any(key.startsWith);
  }

  static Map<String, dynamic> _mergeOwnedPrefs(
    Map<String, dynamic> remotePrefs,
    Map<String, dynamic> localPrefs,
  ) {
    final preservedRemote = Map<String, dynamic>.from(remotePrefs)
      ..removeWhere((key, _) => _exactKeys.contains(key) || _prefixes.any(key.startsWith));
    return <String, dynamic>{...preservedRemote, ...localPrefs};
  }

  static Set<String> _ownedKeysFrom(Iterable<String> keys) {
    return keys.where((key) => _exactKeys.contains(key) || _prefixes.any(key.startsWith)).toSet();
  }

  Future<void> _removeOwnedPrefsMissingFromRemote(
    SharedPreferences prefs,
    Set<String> remoteOwnedKeys,
  ) async {
    final localOwnedKeys = _ownedKeysFrom(prefs.getKeys());
    for (final key in localOwnedKeys) {
      if (!remoteOwnedKeys.contains(key)) {
        await prefs.remove(key);
      }
    }
  }

  @visibleForTesting
  static bool isSyncedKeyForTesting(String key) {
    return _exactKeys.contains(key) || _prefixes.any(key.startsWith);
  }

  @visibleForTesting
  static Map<String, dynamic> mergeOwnedPrefsForTesting(
    Map<String, dynamic> remotePrefs,
    Map<String, dynamic> localPrefs,
  ) {
    return _mergeOwnedPrefs(remotePrefs, localPrefs);
  }

  @visibleForTesting
  static Set<String> ownedKeysMissingFromRemoteForTesting(
    Iterable<String> localKeys,
    Iterable<String> remoteKeys,
  ) {
    return _ownedKeysFrom(localKeys).difference(_ownedKeysFrom(remoteKeys));
  }

  void _schedulePush() {
    _timer?.cancel();
    _timer = Timer(_debounce, () => unawaited(_push()));
  }

  Future<void> _push() async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final localPrefs = _collectPrefs();

    final ref = _docRef(uid);
    final updatedAtMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final snap = await ref.get();
      final remotePrefs = Map<String, dynamic>.from(
        (snap.data()?['prefs'] as Map?) ?? const <String, dynamic>{},
      );
      final mergedPrefs = _mergeOwnedPrefs(remotePrefs, localPrefs);
      await ref.set({
        'prefs': mergedPrefs,
        'updatedAtMs': updatedAtMs,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _prefs?.setInt(_localUpdatedKey(uid), updatedAtMs);
      _dirty = false;
      debugPrint('☁️ [USER_PREF_SYNC] Push OK (${localPrefs.length} prefs)');
    } catch (e) {
      _dirty = true;
      debugPrint('☁️ [USER_PREF_SYNC] Push failed: $e');
    }
  }
}
