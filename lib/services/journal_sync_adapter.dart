/// ═══════════════════════════════════════════════════════════════════════════
/// JOURNAL SYNC ADAPTER
/// Puente entre JournalService (local) y JournalRepository (cloud)
/// 
/// Estrategia:
/// - JournalService sigue manejando datos locales
/// - Este adapter sincroniza cambios a Firestore
/// - Al login, fusiona cloud con local (cloud gana en conflictos)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../repositories/journal_repository.dart';
import 'journal_service.dart';

class JournalSyncAdapter {
  // Singleton
  static final JournalSyncAdapter _instance = JournalSyncAdapter._internal();
  factory JournalSyncAdapter() => _instance;
  JournalSyncAdapter._internal();
  static JournalSyncAdapter get I => _instance;

  bool _isListening = false;
  StreamSubscription? _authSubscription;
  
  /// Referencia al servicio local
  final JournalService _localService = JournalService();

  /// Inicializar (modo pasivo + write-through)
  void init() {
    if (_isListening) return;
    _isListening = true;
    
    // NOTA: Ya NO hacemos connectUser aquí.
    // El bootstrap lo maneja exclusivamente AccountSessionManager/DataBootstrapper.
    // Este adapter solo sirve como puente para escrituras explícitas del usuario.
    
    // Write-through: cada vez que el usuario escribe en JournalService,
    // sincronizar automáticamente a Firestore.
    _localService.onEntryAdded = (entry) {
      syncEntryToCloud(entry);
    };
    _localService.onEntryDeleted = (id) {
      deleteEntryFromCloud(id);
    };
    
    debugPrint('🔄 [JOURNAL_SYNC] Initialized (passive mode + write-through)');
  }

  // _onUserConnected ELIMINADO: era raíz de condición de carrera.
  // _mergeCloudWithLocal ELIMINADO: el merge local→cloud
  //   podía subir entries vacías/stale después de un logout+purge.
  // _uploadLocalToCloud ELIMINADO: un cache local vacío post-logout
  //   NUNCA debe disparar escrituras batch hacia Firestore.

  /// Sincronizar una entrada específica a cloud
  /// Llamar después de addEntry o updateEntry en JournalService
  Future<void> syncEntryToCloud(JournalEntry entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      // Usar el método add del repository que ya maneja la lógica
      await JournalRepository.I.add(
        content: entry.content,
        mood: entry.mood,
        triggers: entry.triggers,
        hadVictory: entry.hadVictory,
        verseOfDay: entry.verseOfDay,
      );
      debugPrint('☁️ [JOURNAL_SYNC] Synced entry ${entry.id} to cloud');
    } catch (e) {
      debugPrint('❌ [JOURNAL_SYNC] Sync entry error: $e');
    }
  }

  /// Eliminar entrada de cloud
  Future<void> deleteEntryFromCloud(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    
    try {
      await JournalRepository.I.delete(id);
      debugPrint('☁️ [JOURNAL_SYNC] Deleted entry $id from cloud');
    } catch (e) {
      debugPrint('❌ [JOURNAL_SYNC] Delete entry error: $e');
    }
  }

  /// Forzar sincronización completa de LOCAL → CLOUD (solo para uso explícito)
  /// ⚠️ Solo llamar cuando el usuario EXPLÍCITAMENTE pide sincronizar
  Future<void> forceSyncAll() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('⚠️ [JOURNAL_SYNC] No user, cannot sync');
      return;
    }
    
    try {
      await _localService.initialize();
      
      for (final localEntry in _localService.entries) {
        await JournalRepository.I.add(
          content: localEntry.content,
          mood: localEntry.mood,
          triggers: localEntry.triggers,
          hadVictory: localEntry.hadVictory,
          verseOfDay: localEntry.verseOfDay,
        );
      }
      
      debugPrint('✅ [JOURNAL_SYNC] Force sync uploaded ${_localService.entries.length} entries');
    } catch (e) {
      debugPrint('❌ [JOURNAL_SYNC] Force sync error: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    _authSubscription?.cancel();
    _isListening = false;
  }
}
