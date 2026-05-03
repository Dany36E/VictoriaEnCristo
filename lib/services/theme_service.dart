import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_data.dart';
import 'user_pref_cloud_sync_service.dart';

/// Servicio para manejar el tema seleccionable de la app (9 temas)
class ThemeService extends ChangeNotifier {
  // Legacy keys (para migración)
  static const String _legacyThemeModeKey = 'theme_mode';
  static const String _themeIdKey = 'app_theme_id';
  static const String _autoThemeKey = 'auto_theme';
  static const String _lastDarkThemeKey = 'last_dark_theme';
  static const String _lastLightThemeKey = 'last_light_theme';

  // Singleton con ChangeNotifier
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  String _themeId = 'night_pure';
  bool _autoTheme = false;
  String _lastDarkTheme = 'night_pure';
  String _lastLightTheme = 'clean_page';

  /// Notifier para escuchar cambios de tema
  final ValueNotifier<String> themeIdNotifier = ValueNotifier('night_pure');

  String get themeId => _themeId;
  bool get autoTheme => _autoTheme;
  AppThemeData get currentTheme => AppThemeData.fromId(_themeId);
  bool get isDarkMode => currentTheme.isDark;
  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Inicializar servicio
  Future<void> initialize() async {
    await _loadSettings();
    if (_autoTheme) {
      _applyAutoTheme();
    }
    notifyListeners();
  }

  /// Cargar configuración guardada (con migración de legacy)
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Migración: si existe theme_mode pero no theme_id
    final savedThemeId = prefs.getString(_themeIdKey);
    if (savedThemeId != null) {
      _themeId = savedThemeId;
    } else {
      // Migrar desde el sistema legacy light/dark
      final legacyIndex = prefs.getInt(_legacyThemeModeKey);
      if (legacyIndex != null) {
        // 0=system, 1=light, 2=dark → mapear
        _themeId = (legacyIndex == 2) ? 'night_pure' : 'clean_page';
        await prefs.setString(_themeIdKey, _themeId);
      }
    }

    _autoTheme = prefs.getBool(_autoThemeKey) ?? false;
    _lastDarkTheme = prefs.getString(_lastDarkThemeKey) ?? 'night_pure';
    _lastLightTheme = prefs.getString(_lastLightThemeKey) ?? 'clean_page';
    themeIdNotifier.value = _themeId;
  }

  /// Guardar configuración
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeIdKey, _themeId);
    await prefs.setBool(_autoThemeKey, _autoTheme);
    await prefs.setString(_lastDarkThemeKey, _lastDarkTheme);
    await prefs.setString(_lastLightThemeKey, _lastLightTheme);
    UserPrefCloudSyncService.I.markDirty();
  }

  /// Cambiar tema por ID
  Future<void> setTheme(String id) async {
    if (_themeId == id) return;
    _themeId = id;
    themeIdNotifier.value = id;

    // Recordar último tema claro/oscuro
    final theme = AppThemeData.fromId(id);
    if (theme.isDark) {
      _lastDarkTheme = id;
    } else {
      _lastLightTheme = id;
    }

    await _saveSettings();
    notifyListeners();
  }

  /// Alternar entre último tema claro y oscuro (conveniencia)
  Future<void> toggleTheme() async {
    final next = isDarkMode ? _lastLightTheme : _lastDarkTheme;
    await setTheme(next);
  }

  /// Habilitar/deshabilitar tema automático
  Future<void> setAutoTheme(bool enabled) async {
    _autoTheme = enabled;
    if (enabled) {
      _applyAutoTheme();
    }
    await _saveSettings();
    notifyListeners();
  }

  /// Aplicar tema según la hora del día
  void _applyAutoTheme() {
    final hour = DateTime.now().hour;
    // Oscuro de 7pm a 6am
    final shouldBeDark = hour >= 19 || hour < 6;
    final targetId = shouldBeDark ? _lastDarkTheme : _lastLightTheme;
    if (_themeId != targetId) {
      _themeId = targetId;
      themeIdNotifier.value = _themeId;
      notifyListeners();
    }
  }

  /// Verificar y actualizar tema automático (llamar periódicamente)
  void checkAutoTheme() {
    if (_autoTheme) {
      _applyAutoTheme();
    }
  }
}
