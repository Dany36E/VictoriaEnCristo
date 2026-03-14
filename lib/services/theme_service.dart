import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar el tema de la aplicación (claro/oscuro)
class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _autoThemeKey = 'auto_theme';

  // Singleton con ChangeNotifier
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  ThemeMode _themeMode = ThemeMode.light;
  bool _autoTheme = false; // Cambio automático según hora

  ThemeMode get themeMode => _themeMode;
  bool get autoTheme => _autoTheme;
  bool get isDarkMode => _themeMode == ThemeMode.dark;

  /// Inicializar servicio
  Future<void> initialize() async {
    await _loadSettings();
    if (_autoTheme) {
      _applyAutoTheme();
    }
  }

  /// Cargar configuración guardada
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt(_themeModeKey) ?? 0;
    _themeMode = ThemeMode.values[themeModeIndex];
    _autoTheme = prefs.getBool(_autoThemeKey) ?? false;
  }

  /// Guardar configuración
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, _themeMode.index);
    await prefs.setBool(_autoThemeKey, _autoTheme);
  }

  /// Cambiar modo de tema
  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _saveSettings();
    notifyListeners();
  }

  /// Alternar entre claro y oscuro
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _saveSettings();
    notifyListeners();
  }

  /// Habilitar/deshabilitar tema automático
  Future<void> setAutoTheme(bool enabled) async {
    _autoTheme = enabled;
    await _saveSettings();
    if (enabled) {
      _applyAutoTheme();
    }
    notifyListeners();
  }

  /// Aplicar tema según la hora del día
  void _applyAutoTheme() {
    final hour = DateTime.now().hour;
    // Oscuro de 7pm a 6am
    if (hour >= 19 || hour < 6) {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
    notifyListeners();
  }

  /// Verificar y actualizar tema automático (llamar periódicamente)
  void checkAutoTheme() {
    if (_autoTheme) {
      _applyAutoTheme();
    }
  }
}
