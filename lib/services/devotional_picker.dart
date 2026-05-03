/// ═══════════════════════════════════════════════════════════════════════════
/// DEVOTIONAL PICKER — RFC-002
///
/// Selector determinista del devocional del día. Vive como extensión sobre
/// [PersonalizationEngine] para no contaminar el motor genérico.
///
/// Reglas (en orden, primero que matchee gana):
/// 1. Crisis activa o relapseLast24h → pool[stage=restoration, ⊇ primaryGiant]
/// 2. Nuevo creyente (≤7 días en la app) → pool[stage∈{crisis,habit}]
/// 3. Default → pool[stage=user.currentStage, ⊇ primaryGiant]
/// 4. Tie-break: maximizar diversidad (no repetir últimos 14 días)
/// 5. Fallback: primer entry disponible
///
/// Determinismo: dos llamadas con el mismo `(uid, fecha, override)` devuelven
/// la misma entrada — semilla = `hash(uid + yyyy-mm-dd + override?)`.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_enums.dart';
import '../models/devotional_entry.dart';
import '../models/plan_day.dart';
import '../models/plan_metadata.dart';
import 'devotional_repository.dart';
import 'personalization_engine.dart';
import 'user_pref_cloud_sync_service.dart';

/// Estado de usuario contextual para la selección.
class DevotionalUserState {
  final GiantId? primaryGiant;
  final ContentStage stage;
  final bool isCrisisMode;
  final bool recentRelapse;
  final int daysSinceStart;
  final String userKey; // uid o "anon"

  const DevotionalUserState({
    required this.primaryGiant,
    required this.stage,
    required this.isCrisisMode,
    required this.recentRelapse,
    required this.daysSinceStart,
    required this.userKey,
  });
}

/// Resultado: la entrada elegida + por qué.
class DevotionalSelection {
  final DevotionalEntry entry;
  final String reasonCode; // crisis|new_believer|stage_match|fallback|override
  final String reasonHuman; // mensaje para chip/sheet
  final GiantId? matchedGiant;
  final ContentStage matchedStage;

  const DevotionalSelection({
    required this.entry,
    required this.reasonCode,
    required this.reasonHuman,
    required this.matchedGiant,
    required this.matchedStage,
  });
}

extension DevotionalPicker on PersonalizationEngine {
  static const _historyKey = 'devotional_v2_history_v1';
  static const _historyDays = 14;

  /// Selector principal. Si `giantOverride` está, ignora `primaryGiant`.
  Future<DevotionalSelection> pickDevotionalForToday({
    DateTime? when,
    GiantId? giantOverride,
    bool? crisisOverride,
    bool? recentRelapseOverride,
    int? daysSinceStartOverride,
    String? userKey,
  }) async {
    final repo = DevotionalRepository.I;
    await repo.ensureLoaded();

    final today = when ?? DateTime.now();
    final dateKey = _yyyyMmDd(today);

    // Construir estado del usuario.
    final crisis = crisisOverride ?? false;
    final relapse = recentRelapseOverride ?? false;
    final stage = getUserStage(isCrisisMode: crisis, recentRelapse: relapse);
    final state = DevotionalUserState(
      primaryGiant: giantOverride ?? primaryGiant,
      stage: stage,
      isCrisisMode: crisis,
      recentRelapse: relapse,
      daysSinceStart: daysSinceStartOverride ?? 0,
      userKey: userKey ?? 'anon',
    );

    // Recientes (últimos 14 días).
    final recent = await _loadRecentIds();

    // Aplicar reglas en cascada.
    var (candidates, reasonCode, reasonHuman, matchedStage) = _selectCandidates(repo, state);

    // Si override manual de gigante, marcar razón.
    if (giantOverride != null) {
      reasonCode = 'override';
      reasonHuman = 'Tú elegiste enfocar en ${giantOverride.displayName}';
    }

    // Filtrar entradas ya vistas (diversidad).
    final fresh = candidates.where((e) => !recent.contains(e.id)).toList();
    final pool = fresh.isNotEmpty ? fresh : candidates;

    // Determinismo por seed.
    DevotionalEntry chosen;
    if (pool.isEmpty) {
      // Último recurso: cualquier entrada del repo.
      chosen = repo.all.isNotEmpty ? repo.all.first : _emergencyEntry();
      reasonCode = 'fallback';
      reasonHuman = 'Tu lectura de hoy';
    } else {
      final seed = _seed('${state.userKey}|$dateKey|${giantOverride?.id ?? ''}');
      final rng = Random(seed);
      chosen = pool[rng.nextInt(pool.length)];
    }

    // Persistir como visto hoy.
    await _recordShown(chosen.id, today);

    return DevotionalSelection(
      entry: chosen,
      reasonCode: reasonCode,
      reasonHuman: reasonHuman,
      matchedGiant: state.primaryGiant,
      matchedStage: matchedStage,
    );
  }

  /// Selecciona candidatos según reglas determinísticas.
  /// Devuelve (lista, reasonCode, reasonHuman, etapa elegida).
  (List<DevotionalEntry>, String, String, ContentStage) _selectCandidates(
    DevotionalRepository repo,
    DevotionalUserState s,
  ) {
    // Regla 1: crisis / restauración
    if (s.isCrisisMode || s.recentRelapse) {
      final list = repo.byFilter(giant: s.primaryGiant, stage: ContentStage.restoration);
      if (list.isNotEmpty) {
        return (
          list,
          'crisis',
          s.primaryGiant != null
              ? 'Estás en restauración. Esto es para tu lucha con ${s.primaryGiant!.displayName}'
              : 'Estás en restauración. Esto es para ti hoy',
          ContentStage.restoration,
        );
      }
      // Si no hay restoration con ese giant, probar sin giant
      final any = repo.byFilter(stage: ContentStage.restoration);
      if (any.isNotEmpty) {
        return (
          any,
          'crisis',
          'Estás en restauración. Esto es para ti hoy',
          ContentStage.restoration,
        );
      }
    }

    // Regla 2: nuevo creyente
    if (s.daysSinceStart > 0 && s.daysSinceStart <= 7) {
      final list = [
        ...repo.byFilter(stage: ContentStage.crisis),
        ...repo.byFilter(stage: ContentStage.habit),
      ];
      if (list.isNotEmpty) {
        return (list, 'new_believer', 'Tus primeros días — pasos firmes', ContentStage.habit);
      }
    }

    // Regla 3: default por etapa + gigante
    final byStageAndGiant = repo.byFilter(giant: s.primaryGiant, stage: s.stage);
    if (byStageAndGiant.isNotEmpty) {
      final reason = s.primaryGiant != null
          ? 'Para tu lucha con ${s.primaryGiant!.displayName} · ${s.stage.displayName}'
          : 'Para tu etapa de ${s.stage.displayName.toLowerCase()}';
      return (byStageAndGiant, 'stage_match', reason, s.stage);
    }

    // Regla 4: relajar etapa (mismo gigante, cualquier etapa)
    if (s.primaryGiant != null) {
      final byGiant = repo.byFilter(giant: s.primaryGiant);
      if (byGiant.isNotEmpty) {
        return (byGiant, 'giant_only', 'Para tu lucha con ${s.primaryGiant!.displayName}', s.stage);
      }
    }

    // Regla 5: cualquier entrada de la etapa
    final byStage = repo.byFilter(stage: s.stage);
    if (byStage.isNotEmpty) {
      return (
        byStage,
        'stage_only',
        'Para tu etapa de ${s.stage.displayName.toLowerCase()}',
        s.stage,
      );
    }

    // Regla 6: cualquiera
    return (repo.all, 'fallback', 'Tu lectura de hoy', s.stage);
  }

  // ────────────────────────────────────────────────────────────────────────
  // Historial de devocionales mostrados (diversidad ≥ 14 días)
  // ────────────────────────────────────────────────────────────────────────

  Future<Set<String>> _loadRecentIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return <String>{};
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final cutoff = DateTime.now().subtract(const Duration(days: _historyDays));
      final out = <String>{};
      for (final entry in data.entries) {
        final date = DateTime.tryParse(entry.key);
        if (date == null || date.isBefore(cutoff)) continue;
        final id = entry.value as String?;
        if (id != null) out.add(id);
      }
      return out;
    } catch (e) {
      debugPrint('[DevotionalPicker] _loadRecentIds error: $e');
      return <String>{};
    }
  }

  Future<void> _recordShown(String id, DateTime when) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      final data = raw != null
          ? Map<String, dynamic>.from(jsonDecode(raw) as Map)
          : <String, dynamic>{};
      data[_yyyyMmDd(when)] = id;
      // Compactar: solo últimos 30 días
      final cutoff = when.subtract(const Duration(days: 30));
      data.removeWhere((k, _) {
        final d = DateTime.tryParse(k);
        return d == null || d.isBefore(cutoff);
      });
      await prefs.setString(_historyKey, jsonEncode(data));
      UserPrefCloudSyncService.I.markDirty();
    } catch (e) {
      debugPrint('[DevotionalPicker] _recordShown error: $e');
    }
  }

  /// Última entrada mostrada para una fecha (para abrir el mismo si vuelven).
  Future<String?> getEntryIdForDate(DateTime date) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return data[_yyyyMmDd(date)] as String?;
    } catch (_) {
      return null;
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────────────────

  static String _yyyyMmDd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  static int _seed(String s) {
    // Hash determinista simple FNV-1a 32-bit
    var hash = 0x811c9dc5;
    for (final code in s.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static DevotionalEntry _emergencyEntry() {
    return const DevotionalEntry(
      id: 'dev_emergency_fallback',
      planDay: PlanDay(
        dayIndex: 1,
        title: 'Tu lectura de hoy',
        scripture: Scripture(
          reference: 'Salmos 46:1',
          text: 'Dios es nuestro amparo y fortaleza, nuestro pronto auxilio en las tribulaciones.',
        ),
        reflection:
            'Aunque hoy no encontremos un texto específico para tu lucha, '
            'Dios sí te encuentra. Respira y descansa en Su presencia.',
        prayer: 'Señor, sostienes mi vida en Tus manos. Hoy elijo confiar en Ti. Amén.',
      ),
      metadata: PlanMetadata(
        giants: <GiantId>[],
        stage: ContentStage.habit,
        planType: PlanType.discipleship,
        reviewLevel: PlanReviewLevel.approved,
      ),
    );
  }
}
