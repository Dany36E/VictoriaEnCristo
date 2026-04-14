/// ═══════════════════════════════════════════════════════════════════════════
/// PLANS SYNC ADAPTER
/// Puente entre PlanProgressService (local/UI) y PlansRepository (cloud)
/// 
/// Estrategia:
/// - PlanProgressService sigue siendo usado por la UI
/// - Este adapter detecta cambios y los replica a PlansRepository → Firestore
/// - Al login, DataBootstrapper hidrata PlanProgressService desde cloud
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import '../repositories/plans_repository.dart';
import 'plan_progress_service.dart';

class PlansSyncAdapter {
  // Singleton
  static final PlansSyncAdapter _instance = PlansSyncAdapter._internal();
  factory PlansSyncAdapter() => _instance;
  PlansSyncAdapter._internal();
  static PlansSyncAdapter get I => _instance;

  bool _isListening = false;

  /// Inicializar (modo pasivo + write-through)
  void init() {
    if (_isListening) return;
    _isListening = true;

    final service = PlanProgressService.I;

    // Write-through: cuando se completa un día, sincronizar a PlansRepository
    service.onDayCompleted = (String planId, int dayIndex) {
      _syncDayCompleted(planId, dayIndex);
    };

    // Write-through: cuando se activa un plan
    service.onPlanActivated = (String planId) {
      _syncPlanActivated(planId);
    };

    debugPrint('🔄 [PLANS_SYNC] Initialized (passive mode + write-through)');
  }

  Future<void> _syncDayCompleted(String planId, int dayIndex) async {
    try {
      final progress = PlanProgressService.I.getProgress(planId);
      final totalDays = progress?.completedDays.length ?? dayIndex + 1;
      await PlansRepository.I.completeDay(planId, dayIndex, totalDays);
      debugPrint('☁️ [PLANS_SYNC] Synced day $dayIndex of $planId');
    } catch (e) {
      debugPrint('❌ [PLANS_SYNC] Sync day error: $e');
    }
  }

  Future<void> _syncPlanActivated(String planId) async {
    try {
      await PlansRepository.I.setActivePlan(planId);
      debugPrint('☁️ [PLANS_SYNC] Synced active plan: $planId');
    } catch (e) {
      debugPrint('❌ [PLANS_SYNC] Sync active plan error: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    PlanProgressService.I.onDayCompleted = null;
    PlanProgressService.I.onPlanActivated = null;
    _isListening = false;
  }
}
