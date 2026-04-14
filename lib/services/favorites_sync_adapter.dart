/// ═══════════════════════════════════════════════════════════════════════════
/// FAVORITES SYNC ADAPTER
/// Puente entre FavoritesService (local) y FavoritesRepository (cloud)
/// 
/// Estrategia:
/// - FavoritesService sigue siendo la fuente primaria para la UI
/// - Este adapter sincroniza cambios a Firestore en segundo plano
/// - OPTIMIZADO: envía la lista COMPLETA en un solo write (1 documento)
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import '../data/bible_verses.dart';
import '../repositories/favorites_repository.dart';
import 'favorites_service.dart';

class FavoritesSyncAdapter {
  // Singleton
  static final FavoritesSyncAdapter _instance = FavoritesSyncAdapter._internal();
  factory FavoritesSyncAdapter() => _instance;
  FavoritesSyncAdapter._internal();
  static FavoritesSyncAdapter get I => _instance;

  bool _isListening = false;

  /// Inicializar (modo pasivo + write-through)
  void init() {
    if (_isListening) return;
    _isListening = true;

    // Write-through: cada vez que el usuario cambia favoritos,
    // sincronizar automáticamente a Firestore (un solo documento)
    FavoritesService().onFavoritesChanged = (List<BibleVerse> favorites) {
      _syncToCloud(favorites);
    };

    debugPrint('🔄 [FAV_SYNC] Initialized (passive mode + write-through)');
  }

  /// Sincronizar favoritos a cloud
  Future<void> _syncToCloud(List<BibleVerse> favorites) async {
    try {
      await FavoritesRepository.I.saveAllToCloud(favorites);
    } catch (e) {
      debugPrint('❌ [FAV_SYNC] Sync error: $e');
    }
  }

  /// Forzar sincronización completa de LOCAL → CLOUD
  Future<void> forceSyncAll() async {
    try {
      final favorites = FavoritesService().favorites;
      await FavoritesRepository.I.saveAllToCloud(favorites);
      debugPrint('✅ [FAV_SYNC] Force sync uploaded ${favorites.length} favorites');
    } catch (e) {
      debugPrint('❌ [FAV_SYNC] Force sync error: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    FavoritesService().onFavoritesChanged = null;
    _isListening = false;
  }
}
