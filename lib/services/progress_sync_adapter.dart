/// ═══════════════════════════════════════════════════════════════════════════
/// PROGRESS SYNC ADAPTER
/// Puente entre VictoryScoringService (local) y ProgressRepository (cloud)
/// 
/// Estrategia:
/// - VictoryScoringService sigue siendo la fuente primaria para la UI
/// - Este adapter sincroniza los cambios a Firestore en segundo plano
/// - Al login, descarga datos de cloud y los fusiona con local
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../repositories/progress_repository.dart';
import 'battle_partner_service.dart';
import '../utils/time_utils.dart';
import 'victory_scoring_service.dart';

class ProgressSyncAdapter {
  // Singleton
  static final ProgressSyncAdapter _instance = ProgressSyncAdapter._internal();
  factory ProgressSyncAdapter() => _instance;
  ProgressSyncAdapter._internal();
  static ProgressSyncAdapter get I => _instance;

  bool _isListening = false;
  StreamSubscription? _authSubscription;
  
  /// Inicializar y escuchar cambios de auth
  void init() {
    if (_isListening) return;
    _isListening = true;
    
    // NOTA: Ya NO hacemos connectUser aquí.
    // El bootstrap lo maneja exclusivamente AccountSessionManager/DataBootstrapper.
    // Este adapter solo sirve como puente para escrituras explícitas del usuario.
    
    // Write-through: cada vez que el usuario escribe en VictoryScoringService,
    // sincronizar automáticamente a Firestore.
    VictoryScoringService.I.onDayChanged = (date) {
      syncDayToCloud(date);
      // Sync public progress para compañeros de batalla (fire-and-forget)
      if (BattlePartnerService.I.isInitialized) {
        BattlePartnerService.I.syncPublicProgress();
      }
    };
    
    debugPrint('🔄 [SYNC_ADAPTER] Initialized (passive mode + write-through)');
  }
  
  // _onUserConnected ELIMINADO: era la raíz de la condición de carrera.
  // Al tener su propio authStateChanges listener, competía con
  // AccountSessionManager y podía subir datos locales vacíos/stale a cloud.
  
  // _uploadLocalToCloud ELIMINADO: un cache local vacío post-logout
  // NUNCA debe disparar una escritura batch hacia Firestore.
  
  // _syncFromCloudToLocal ELIMINADO: la descarga desde cloud
  // la maneja exclusivamente ProgressRepository.connectUser().
  
  /// Sincronizar un día específico a cloud
  /// Llamar esto después de cada cambio en VictoryScoringService
  Future<void> syncDayToCloud(DateTime date) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      final scoring = VictoryScoringService.I;
      final states = scoring.getDayGiantStates(date);
      final selectedGiants = scoring.selectedGiants;
      final threshold = scoring.threshold;
      
      // Actualizar cada estado de gigante
      for (final entry in states.entries) {
        await ProgressRepository.I.setDayGiantState(
          date,
          entry.key,
          entry.value,
          selectedGiants: selectedGiants,
          threshold: threshold,
        );
      }
      
      debugPrint('☁️ [SYNC_ADAPTER] Synced ${_dateToISO(date)} to cloud');
    } catch (e) {
      debugPrint('❌ [SYNC_ADAPTER] Sync day error: $e');
    }
  }
  
  /// Forzar sincronización completa de LOCAL → CLOUD (solo para uso explícito)
  /// ⚠️ Solo llamar cuando el usuario EXPLÍCITAMENTE pide sincronizar
  /// NUNCA llamar automáticamente durante login/connect
  Future<void> forceSyncAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [SYNC_ADAPTER] No user, cannot sync');
      return;
    }
    
    try {
      final scoring = VictoryScoringService.I;
      await scoring.init();
      
      final selectedGiants = scoring.selectedGiants;
      final threshold = scoring.threshold;
      final today = DateTime.now();
      final startYear = today.year - 1;
      
      int uploaded = 0;
      
      for (int year = startYear; year <= today.year; year++) {
        for (int month = 1; month <= 12; month++) {
          final monthDate = DateTime(year, month, 1);
          final victoryDays = scoring.getVictoryDaysInMonth(monthDate);
          
          for (final dateISO in victoryDays) {
            final date = _parseISO(dateISO);
            if (date == null) continue;
            
            await ProgressRepository.I.setDayAllGiants(
              date,
              1,
              selectedGiants: selectedGiants,
              threshold: threshold,
            );
            uploaded++;
          }
        }
      }
      
      debugPrint('✅ [SYNC_ADAPTER] Force sync uploaded $uploaded days');
    } catch (e) {
      debugPrint('❌ [SYNC_ADAPTER] Force sync error: $e');
    }
  }
  
  /// Limpiar recursos
  void dispose() {
    _authSubscription?.cancel();
    _isListening = false;
  }
  
  // Delegados a TimeUtils centralizado
  String _dateToISO(DateTime date) => TimeUtils.dateToISO(date);
  DateTime? _parseISO(String iso) => TimeUtils.parseISO(iso);
}
