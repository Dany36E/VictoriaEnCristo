import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bible_verses.dart';
import '../utils/result.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// FAVORITES SERVICE - Servicio de Versículos Favoritos
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// Gestiona el almacenamiento local de versículos favoritos usando SharedPreferences.
/// Patrón Singleton para acceso global desde cualquier parte de la app.
/// ═══════════════════════════════════════════════════════════════════════════════

class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal();

  static const String _storageKey = 'favorite_verses';
  
  List<BibleVerse> _favorites = [];
  bool _isInitialized = false;

  /// Callback para sincronización write-through (usado por FavoritesSyncAdapter)
  void Function(List<BibleVerse> favorites)? onFavoritesChanged;

  /// Lista de versículos favoritos
  List<BibleVerse> get favorites => List.unmodifiable(_favorites);

  /// Número de favoritos
  int get count => _favorites.length;

  /// Indica si ya se inicializó
  bool get isInitialized => _isInitialized;

  /// Inicializa el servicio cargando los favoritos guardados
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(jsonString);
        final List<BibleVerse> loaded = [];
        for (final item in jsonList) {
          try {
            loaded.add(BibleVerse.fromJson(item));
          } catch (e) {
            debugPrint('FavoritesService: favorito corrupto ignorado: $e');
          }
        }
        _favorites = loaded;
      }
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _favorites = [];
      _isInitialized = true;
    }
  }

  /// Verifica si un versículo está en favoritos
  bool isFavorite(BibleVerse verse) {
    return _favorites.any((v) => 
      v.reference == verse.reference && v.verse == verse.verse
    );
  }

  /// Agrega un versículo a favoritos
  Future<Result<bool>> addFavorite(BibleVerse verse) async {
    if (isFavorite(verse)) return const Success(false);
    
    _favorites.insert(0, verse);
    notifyListeners();
    final saveResult = await _saveToStorage();
    onFavoritesChanged?.call(List.unmodifiable(_favorites));
    return saveResult.map((_) => true);
  }

  /// Elimina un versículo de favoritos
  Future<Result<bool>> removeFavorite(BibleVerse verse) async {
    _favorites.removeWhere((v) => 
      v.reference == verse.reference && v.verse == verse.verse
    );
    notifyListeners();
    final saveResult = await _saveToStorage();
    onFavoritesChanged?.call(List.unmodifiable(_favorites));
    return saveResult.map((_) => true);
  }

  /// Alterna el estado de favorito (agregar/quitar)
  Future<Result<bool>> toggleFavorite(BibleVerse verse) async {
    if (isFavorite(verse)) {
      return removeFavorite(verse);
    } else {
      return addFavorite(verse);
    }
  }

  /// Guarda los favoritos en almacenamiento local
  Future<Result<void>> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favorites.map((v) => v.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      return const Success(null);
    } catch (e, st) {
      debugPrint('Error saving favorites: $e');
      return Failure('Error guardando favoritos', error: e, stackTrace: st);
    }
  }

  /// Restaurar favoritos desde cloud (usado por DataBootstrapper)
  Future<void> restoreFromCloud(List<BibleVerse> cloudFavorites) async {
    if (cloudFavorites.isEmpty) return;
    
    _favorites = List.from(cloudFavorites);
    await _saveToStorage();
    notifyListeners();
    debugPrint('⭐ [FAV_SERVICE] Restored ${cloudFavorites.length} favorites from cloud');
  }

  /// Limpia todos los favoritos
  Future<void> clearAll() async {
    try {
      _favorites.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing favorites: $e');
    }
  }
}
