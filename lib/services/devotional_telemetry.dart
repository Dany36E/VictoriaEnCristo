/// ═══════════════════════════════════════════════════════════════════════════
/// DEVOTIONAL TELEMETRY — RFC-003
/// Eventos del rediseño del Devocional. Wrapper liviano sobre Firebase
/// Analytics con fallback silencioso si la plataforma no lo soporta.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

import '../utils/platform_capabilities.dart';

/// Origen desde donde se abrió el devocional
enum DevotionalSource { home, notification, widget, dailyChecklist, deeplink, unknown }

/// Modo de lectura
enum DevotionalReadMode { quick, standard, deep }

extension DevotionalReadModeX on DevotionalReadMode {
  String get id => switch (this) {
    DevotionalReadMode.quick => 'quick_2min',
    DevotionalReadMode.standard => 'standard_8min',
    DevotionalReadMode.deep => 'deep_15min',
  };
}

extension DevotionalSourceX on DevotionalSource {
  String get id => name;
}

/// Servicio de telemetría dedicado a la sección Devocional.
class DevotionalTelemetry {
  DevotionalTelemetry._();
  static final DevotionalTelemetry I = DevotionalTelemetry._();

  Future<void> _log(String name, Map<String, Object?> params) async {
    if (!PlatformCapabilities.supportsFirebaseAnalytics) return;
    try {
      final clean = <String, Object>{};
      for (final entry in params.entries) {
        final v = entry.value;
        if (v == null) continue;
        if (v is num || v is String) {
          clean[entry.key] = v;
        } else if (v is bool) {
          clean[entry.key] = v ? 1 : 0;
        } else {
          clean[entry.key] = v.toString();
        }
      }
      await FirebaseAnalytics.instance.logEvent(name: name, parameters: clean);
    } catch (e) {
      if (kDebugMode) debugPrint('[devotionalTelemetry] $name failed: $e');
    }
  }

  Future<void> opened({
    required String entryId,
    String? giant,
    String? stage,
    DevotionalSource source = DevotionalSource.unknown,
    DevotionalReadMode mode = DevotionalReadMode.standard,
  }) => _log('devotional_opened', {
    'entry_id': entryId,
    'giant': giant ?? 'general',
    'stage': stage ?? 'unknown',
    'source': source.id,
    'mode': mode.id,
  });

  Future<void> sectionViewed({
    required String entryId,
    required String section, // verse|reflection|prayer|action|checkIn
    required int dwellMs,
  }) => _log('devotional_section_viewed', {
    'entry_id': entryId,
    'section': section,
    'dwell_ms': dwellMs,
  });

  Future<void> completed({
    required String entryId,
    required DevotionalReadMode mode,
    required int totalMs,
    required int sectionsViewed,
    required String trigger, // cta|scroll_dwell
  }) => _log('devotional_completed', {
    'entry_id': entryId,
    'mode': mode.id,
    'total_ms': totalMs,
    'sections_viewed': sectionsViewed,
    'trigger': trigger,
  });

  Future<void> skipped({
    required String entryId,
    required String lastSection,
    required int dwellMs,
  }) => _log('devotional_skipped', {
    'entry_id': entryId,
    'last_section': lastSection,
    'dwell_ms': dwellMs,
  });

  Future<void> giantOverride({
    required String entryId,
    required String fromGiant,
    required String toGiant,
  }) => _log('devotional_giant_override', {
    'entry_id': entryId,
    'from_giant': fromGiant,
    'to_giant': toGiant,
  });

  Future<void> crisisVariantShown({required String entryId, String? primaryGiant}) => _log(
    'devotional_crisis_variant_shown',
    {'entry_id': entryId, 'primary_giant': primaryGiant ?? 'general'},
  );

  Future<void> relevanceRated({
    required String entryId,
    required int score, // 1..5
  }) => _log('devotional_relevance_rated', {'entry_id': entryId, 'score': score});

  Future<void> audioPlayed({required String entryId, required int durationMs}) =>
      _log('devotional_audio_played', {'entry_id': entryId, 'duration_ms': durationMs});

  Future<void> rolloutAssigned({
    required String entryId,
    required String variant,
    required int bucket,
    required int rolloutPercent,
    required bool forced,
  }) => _log('devotional_rollout_assigned', {
    'entry_id': entryId,
    'variant': variant,
    'bucket': bucket,
    'rollout_percent': rolloutPercent,
    'forced': forced,
  });
}
