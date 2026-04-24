/// ═══════════════════════════════════════════════════════════════════════════
/// BADGE SYNC ADAPTER
/// Puente entre BadgeService (local) y BadgeRepository (cloud)
/// 
/// Estrategia:
/// - BadgeService sigue siendo la fuente primaria para la UI
/// - Este adapter sincroniza cambios a Firestore en segundo plano
/// - OPTIMIZADO: envía el mapa COMPLETO en un solo write (1 documento)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import '../repositories/badge_repository.dart';
import '../utils/sync_retry.dart';
import 'badge_service.dart';

class BadgeSyncAdapter {
  // Singleton
  static final BadgeSyncAdapter _instance = BadgeSyncAdapter._internal();
  factory BadgeSyncAdapter() => _instance;
  BadgeSyncAdapter._internal();
  static BadgeSyncAdapter get I => _instance;

  bool _isListening = false;

  /// Inicializar (modo pasivo + write-through)
  void init() {
    if (_isListening) return;
    _isListening = true;

    // Write-through: cada vez que se desbloquean nuevos badges,
    // sincronizar automáticamente a Firestore (un solo documento)
    BadgeService.I.onBadgesChanged = (Map<String, int> levels) {
      _syncToCloud(levels);
    };

    debugPrint('🔄 [BADGE_SYNC] Initialized (passive mode + write-through)');
  }

  /// Sincronizar badges a cloud
  Future<void> _syncToCloud(Map<String, int> levels) async {
    await SyncRetry.withBackoff(
      () => BadgeRepository.I.saveAllToCloud(levels),
      where: 'BadgeSync.save',
    );
  }

  /// Forzar sincronización completa de LOCAL → CLOUD
  Future<void> forceSyncAll() async {
    try {
      final levels = BadgeService.I.unlockedLevels;
      await BadgeRepository.I.saveAllToCloud(levels);
      debugPrint('✅ [BADGE_SYNC] Force sync uploaded ${levels.length} badge levels');
    } catch (e) {
      debugPrint('❌ [BADGE_SYNC] Force sync error: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    BadgeService.I.onBadgesChanged = null;
    _isListening = false;
  }
}
