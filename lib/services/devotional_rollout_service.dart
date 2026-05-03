library;

import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'user_pref_cloud_sync_service.dart';

/// Rollout determinístico para Devotional v2.
///
/// No usa Remote Config porque el proyecto aún no depende de
/// firebase_remote_config y `pubspec.yaml` no debe modificarse sin confirmación.
/// Este servicio deja el mecanismo listo: porcentaje, variante forzada y seed
/// estable se guardan en SharedPreferences y se sincronizan por cloud prefs.
enum DevotionalRolloutVariant { controlMinimal, personalizedDaily, audioGuided }

extension DevotionalRolloutVariantX on DevotionalRolloutVariant {
  String get id => switch (this) {
    DevotionalRolloutVariant.controlMinimal => 'control_minimal',
    DevotionalRolloutVariant.personalizedDaily => 'personalized_daily',
    DevotionalRolloutVariant.audioGuided => 'audio_guided',
  };

  String get label => switch (this) {
    DevotionalRolloutVariant.controlMinimal => 'Control mínimo',
    DevotionalRolloutVariant.personalizedDaily => 'Personalizado',
    DevotionalRolloutVariant.audioGuided => 'Audio guiado',
  };

  static DevotionalRolloutVariant? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final value in DevotionalRolloutVariant.values) {
      if (value.id == id || value.name == id) return value;
    }
    return null;
  }
}

class DevotionalRolloutAssignment {
  final DevotionalRolloutVariant variant;
  final int bucket;
  final int rolloutPercent;
  final bool forced;

  const DevotionalRolloutAssignment({
    required this.variant,
    required this.bucket,
    required this.rolloutPercent,
    this.forced = false,
  });

  bool get showAudioCard => variant == DevotionalRolloutVariant.audioGuided;
}

class DevotionalRolloutService {
  DevotionalRolloutService._();
  static final DevotionalRolloutService I = DevotionalRolloutService._();

  static const String rolloutPercentKey = 'devotional_v2_rollout_percent';
  static const String rolloutSeedKey = 'devotional_v2_rollout_seed';
  static const String forcedVariantKey = 'devotional_v2_rollout_forced_variant';

  static const int defaultRolloutPercent = 100;

  Future<DevotionalRolloutAssignment> assignment({String? userKey}) async {
    final prefs = await SharedPreferences.getInstance();
    final forced = DevotionalRolloutVariantX.fromId(prefs.getString(forcedVariantKey));
    final percent = (prefs.getInt(rolloutPercentKey) ?? defaultRolloutPercent)
        .clamp(0, 100)
        .toInt();
    final seed = userKey?.trim().isNotEmpty == true
        ? userKey!.trim()
        : await _stableLocalSeed(prefs);
    final bucket = bucketForKey(seed);

    if (forced != null) {
      return DevotionalRolloutAssignment(
        variant: forced,
        bucket: bucket,
        rolloutPercent: percent,
        forced: true,
      );
    }

    if (bucket >= percent) {
      return DevotionalRolloutAssignment(
        variant: DevotionalRolloutVariant.controlMinimal,
        bucket: bucket,
        rolloutPercent: percent,
      );
    }

    return DevotionalRolloutAssignment(
      variant: bucket.isEven
          ? DevotionalRolloutVariant.personalizedDaily
          : DevotionalRolloutVariant.audioGuided,
      bucket: bucket,
      rolloutPercent: percent,
    );
  }

  Future<void> setRolloutPercent(int percent) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(rolloutPercentKey, percent.clamp(0, 100).toInt());
    UserPrefCloudSyncService.I.markDirty();
  }

  Future<void> forceVariant(DevotionalRolloutVariant? variant) async {
    final prefs = await SharedPreferences.getInstance();
    if (variant == null) {
      await prefs.remove(forcedVariantKey);
    } else {
      await prefs.setString(forcedVariantKey, variant.id);
    }
    UserPrefCloudSyncService.I.markDirty();
  }

  @visibleForTesting
  int bucketForKey(String key) => _fnv1a32(key) % 100;

  Future<String> _stableLocalSeed(SharedPreferences prefs) async {
    final existing = prefs.getString(rolloutSeedKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final generated = 'local-${_randomUint32().toRadixString(16)}';
    await prefs.setString(rolloutSeedKey, generated);
    UserPrefCloudSyncService.I.markDirty();
    return generated;
  }

  int _randomUint32() {
    try {
      return Random.secure().nextInt(0x7fffffff);
    } catch (_) {
      return DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
    }
  }

  int _fnv1a32(String input) {
    var hash = 0x811c9dc5;
    for (final code in input.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }
}
