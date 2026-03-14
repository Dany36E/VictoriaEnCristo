import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bible_verses.dart';

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
        _favorites = jsonList.map((item) => BibleVerse.fromJson(item)).toList();
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
  Future<bool> addFavorite(BibleVerse verse) async {
    if (isFavorite(verse)) return false;
    
    try {
      _favorites.insert(0, verse); // Agregar al inicio
      await _saveToStorage();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error adding favorite: $e');
      return false;
    }
  }

  /// Elimina un versículo de favoritos
  Future<bool> removeFavorite(BibleVerse verse) async {
    try {
      _favorites.removeWhere((v) => 
        v.reference == verse.reference && v.verse == verse.verse
      );
      await _saveToStorage();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error removing favorite: $e');
      return false;
    }
  }

  /// Alterna el estado de favorito (agregar/quitar)
  Future<bool> toggleFavorite(BibleVerse verse) async {
    if (isFavorite(verse)) {
      return await removeFavorite(verse);
    } else {
      return await addFavorite(verse);
    }
  }

  /// Guarda los favoritos en almacenamiento local
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _favorites.map((v) => v.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving favorites: $e');
    }
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
