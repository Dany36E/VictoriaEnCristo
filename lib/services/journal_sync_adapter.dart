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
import '../utils/sync_retry.dart';
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
    _localService.onEntryUpdated = (entry) {
      updateEntryInCloud(entry);
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
  /// Llamar después de addEntry en JournalService. Usa el mismo id local
  /// para que updates/deletes futuros puedan localizar el doc cloud.
  Future<void> syncEntryToCloud(JournalEntry entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await SyncRetry.withBackoff(
      () => JournalRepository.I.add(
        id: entry.id,
        content: entry.content,
        mood: entry.mood,
        triggers: entry.triggers,
        hadVictory: entry.hadVictory,
        verseOfDay: entry.verseOfDay,
      ),
      where: 'JournalSync.add',
    );
    debugPrint('☁️ [JOURNAL_SYNC] Synced entry ${entry.id} to cloud');
  }

  /// Actualizar entrada en cloud. Fallback a add() si el doc aún no existe
  /// (por ejemplo, entradas creadas antes de alinear los IDs local/cloud).
  Future<void> updateEntryInCloud(JournalEntry entry) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final ok = await JournalRepository.I.update(
        entry.id,
        content: entry.content,
        mood: entry.mood,
        triggers: entry.triggers,
        hadVictory: entry.hadVictory,
        verseOfDay: entry.verseOfDay,
      );
      if (!ok) {
        // No existe en cloud: crearlo con el mismo id local
        await JournalRepository.I.add(
          id: entry.id,
          content: entry.content,
          mood: entry.mood,
          triggers: entry.triggers,
          hadVictory: entry.hadVictory,
          verseOfDay: entry.verseOfDay,
        );
        debugPrint('☁️ [JOURNAL_SYNC] Update fallback: added entry ${entry.id} to cloud');
      } else {
        debugPrint('☁️ [JOURNAL_SYNC] Updated entry ${entry.id} in cloud');
      }
    } catch (e) {
      debugPrint('❌ [JOURNAL_SYNC] Update entry error: $e');
    }
  }

  /// Eliminar entrada de cloud
  Future<void> deleteEntryFromCloud(String id) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await SyncRetry.withBackoff(
      () => JournalRepository.I.delete(id),
      where: 'JournalSync.delete',
    );
    debugPrint('☁️ [JOURNAL_SYNC] Deleted entry $id from cloud');
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
