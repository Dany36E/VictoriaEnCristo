import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/bible_verses.dart';
import '../models/bible/saved_verse.dart';
import '../utils/bible_reference_parser.dart';
import '../utils/result.dart';
import 'bible/bible_user_data_service.dart';
import 'favorites_migration.dart';

/// Un elemento de «Mis Favoritos»: un versículo guardado de la Biblia (lo
/// normal) o un favorito antiguo cuya referencia no se pudo interpretar.
class FavoriteEntry {
  /// Forma antigua (texto + referencia), la que usan compartir y copiar.
  final BibleVerse verse;

  /// Versículo guardado de la Biblia (null = favorito antiguo sin migrar).
  final SavedVerse? saved;

  const FavoriteEntry(this.verse, this.saved);
}

/// ═══════════════════════════════════════════════════════════════════════════════
/// FAVORITES SERVICE — «Mis Favoritos», ahora unificado con la Biblia
/// ═══════════════════════════════════════════════════════════════════════════════
///
/// Antes había dos sistemas: «Mis Favoritos» (lista local) y los versículos
/// «Guardados» de la Biblia (Firestore). Ahora los favoritos SON los
/// versículos guardados de la Biblia ([BibleUserDataService]):
///   - Agregar/quitar un favorito guarda/quita el versículo en la Biblia.
///   - La lista antigua se migra una sola vez por cuenta, sin perder nada
///     (ver [FavoritesMigration]); lo que no se pudo interpretar se conserva
///     en la lista local y se sigue mostrando.
///   - Sin sesión de la Biblia (antes de iniciarla), se usa la lista local.
/// ═══════════════════════════════════════════════════════════════════════════════
class FavoritesService extends ChangeNotifier {
  static final FavoritesService _instance = FavoritesService._internal();
  factory FavoritesService() => _instance;
  FavoritesService._internal() {
    BibleUserDataService.I.savedVersesNotifier.addListener(notifyListeners);
  }

  static const String _storageKey = 'favorite_verses';
  static const String _migratedPrefix = 'favorites_migrated_refs_v1.';

  /// Lista antigua (local + respaldo en la nube por FavoritesSyncAdapter).
  List<BibleVerse> _legacy = [];
  bool _isInitialized = false;
  Future<void>? _migrating;

  /// Callback para sincronización write-through (usado por FavoritesSyncAdapter)
  void Function(List<BibleVerse> favorites)? onFavoritesChanged;

  BibleUserDataService get _bible => BibleUserDataService.I;
  bool get _unified => _bible.currentUid != null;

  /// Favoritos: versículos guardados de la Biblia + antiguos sin interpretar.
  List<FavoriteEntry> get entries {
    if (!_unified) {
      return [for (final v in _legacy) FavoriteEntry(v, null)];
    }
    return [
      for (final s in _bible.savedVersesNotifier.value)
        FavoriteEntry(_toLegacy(s), s),
      for (final v in _legacy)
        if (BibleReferenceParser.parse(v.reference)?.verse == null)
          FavoriteEntry(v, null),
    ];
  }

  /// Lista de versículos favoritos (forma antigua).
  List<BibleVerse> get favorites =>
      List.unmodifiable(entries.map((e) => e.verse));

  /// Número de favoritos
  int get count => entries.length;

  /// Indica si ya se inicializó
  bool get isInitialized => _isInitialized;

  static BibleVerse _toLegacy(SavedVerse s) =>
      BibleVerse(verse: s.text, reference: s.reference, category: s.version);

  /// Inicializa el servicio cargando la lista antigua.
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
        _legacy = loaded;
      }

      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
      _legacy = [];
      _isInitialized = true;
    }
  }

  /// Migra la lista antigua a los versículos guardados de la Biblia (una vez
  /// por referencia y por cuenta). La llama BibleUserDataService al iniciar
  /// y también [restoreFromCloud].
  Future<void> migrateToBible() {
    return _migrating ??= _migrate().whenComplete(() => _migrating = null);
  }

  Future<void> _migrate() async {
    final uid = _bible.currentUid;
    if (uid == null) return;
    await init();
    if (_legacy.isEmpty) return;
    // Esperar a la nube para no duplicar lo que ya estaba guardado.
    await _bible.savedVersesSynced.timeout(
      const Duration(seconds: 10),
      onTimeout: () {},
    );
    if (_bible.currentUid != uid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_migratedPrefix$uid';
      final plan = FavoritesMigration.plan(
        legacyFavorites: _legacy,
        isSaved: _bible.isVerseSaved,
        alreadyMigrated: (prefs.getStringList(key) ?? const []).toSet(),
      );
      // Guardar del más antiguo al más reciente para conservar el orden
      // (la lista antigua tiene el más reciente primero).
      final now = DateTime.now();
      final items = plan.toSave.reversed.toList();
      for (var i = 0; i < items.length; i++) {
        final r = items[i].reference;
        await _bible.saveVerse(
          bookNumber: r.bookNumber,
          chapter: r.chapter,
          verse: r.verse!,
          endVerse: r.endVerse,
          bookName: r.bookName,
          text: items[i].favorite.verse,
          version: 'RVR1960',
          savedAt: now.subtract(Duration(seconds: items.length - i)),
        );
      }
      await prefs.setStringList(key, plan.migrated.toList());
      if (plan.toSave.isNotEmpty) {
        debugPrint(
          '⭐ [FAV_SERVICE] ${plan.toSave.length} favoritos migrados a la Biblia',
        );
      }
      notifyListeners();
    } catch (e) {
      debugPrint('⭐ [FAV_SERVICE] Error migrando favoritos: $e');
    }
  }

  /// Verifica si un versículo está en favoritos
  bool isFavorite(BibleVerse verse) {
    final ref = _unified ? BibleReferenceParser.parse(verse.reference) : null;
    if (ref != null && ref.verse != null) {
      return _bible.isVerseSaved(ref.bookNumber, ref.chapter, ref.verse!);
    }
    return _legacy.any((v) => v.reference == verse.reference);
  }

  /// Agrega un versículo a favoritos (= lo guarda en la Biblia).
  Future<Result<bool>> addFavorite(BibleVerse verse) async {
    if (isFavorite(verse)) return const Success(false);
    final ref = _unified ? BibleReferenceParser.parse(verse.reference) : null;
    if (ref != null && ref.verse != null) {
      try {
        final added = await _bible.saveVerse(
          bookNumber: ref.bookNumber,
          chapter: ref.chapter,
          verse: ref.verse!,
          endVerse: ref.endVerse,
          bookName: ref.bookName,
          text: verse.verse,
          version: 'RVR1960',
        );
        return Success(added);
      } catch (e, st) {
        return Failure('Error guardando favorito', error: e, stackTrace: st);
      }
    }
    _legacy.insert(0, verse);
    notifyListeners();
    final saveResult = await _saveToStorage();
    onFavoritesChanged?.call(List.unmodifiable(_legacy));
    return saveResult.map((_) => true);
  }

  /// Elimina un versículo de favoritos
  Future<Result<bool>> removeFavorite(BibleVerse verse) async {
    final ref = _unified ? BibleReferenceParser.parse(verse.reference) : null;
    if (ref != null && ref.verse != null) {
      await _bible.removeSavedVerse(ref.bookNumber, ref.chapter, ref.verse!);
    }
    // También de la lista antigua, para que no vuelva por la migración.
    final before = _legacy.length;
    _legacy.removeWhere((v) => v.reference == verse.reference);
    notifyListeners();
    if (_legacy.length == before) return const Success(true);
    final saveResult = await _saveToStorage();
    onFavoritesChanged?.call(List.unmodifiable(_legacy));
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

  /// Guarda la lista antigua en almacenamiento local
  Future<Result<void>> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = _legacy.map((v) => v.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      return const Success(null);
    } catch (e, st) {
      debugPrint('Error saving favorites: $e');
      return Failure('Error guardando favoritos', error: e, stackTrace: st);
    }
  }

  /// Restaurar la lista antigua desde la nube (usado por DataBootstrapper).
  /// Lo restaurado se migra a la Biblia si ya hay sesión.
  Future<void> restoreFromCloud(List<BibleVerse> cloudFavorites) async {
    _legacy = List.from(cloudFavorites);
    await _saveToStorage();
    notifyListeners();
    debugPrint(
      '⭐ [FAV_SERVICE] Restored ${cloudFavorites.length} favorites from cloud',
    );
    if (_unified) unawaited(migrateToBible());
  }

  /// Limpia la lista antigua (al cerrar sesión).
  Future<void> clearAll() async {
    try {
      _legacy.clear();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing favorites: $e');
    }
  }
}
