import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import 'user_pref_cloud_sync_service.dart';

/// Cómo se elige el papel: siempre claro, siempre oscuro o según el teléfono.
enum ModoTema { claro, oscuro, automatico }

/// Tema de la app: el papel claro o uno de los papeles oscuros (kraft o
/// noche), según el [ModoTema] que elija la persona.
class ThemeService extends ChangeNotifier with WidgetsBindingObserver {
  static const String _modoKey = 'tema_modo';
  static const String _papelOscuroKey = 'tema_papel_oscuro';
  static const String _lecturaManuscritaKey = 'papel_lectura_manuscrita';

  // Claves de antes (10 temas y tema automático por hora): solo para migrar.
  static const String _legacyThemeModeKey = 'theme_mode';
  static const String _legacyThemeIdKey = 'app_theme_id';
  static const String _legacyAutoThemeKey = 'auto_theme';

  // Singleton con ChangeNotifier
  static final ThemeService _instance = ThemeService._internal();
  factory ThemeService() => _instance;
  ThemeService._internal();

  ModoTema _modo = ModoTema.claro;
  String _papelOscuro = AppThemeData.paperKraft.id;
  String _themeId = AppThemeData.paper.id;
  bool _observando = false;

  /// Versículos y apuntes se leen en Lora; con esta opción
  /// usan la letra manuscrita del kit (Patrick Hand).
  final ValueNotifier<bool> lecturaManuscrita = ValueNotifier(false);

  /// Id del tema que se ve ahora ('papel', 'papel_kraft' o 'papel_noche').
  final ValueNotifier<String> themeIdNotifier = ValueNotifier('papel');

  String get themeId => _themeId;
  ModoTema get modo => _modo;

  /// El papel oscuro elegido (se usa en modo oscuro y en automático de noche).
  String get papelOscuro => _papelOscuro;
  AppThemeData get currentTheme => AppThemeData.fromId(_themeId);
  bool get isDarkMode => currentTheme.oscuro;
  ThemeMode get themeMode => isDarkMode ? ThemeMode.dark : ThemeMode.light;

  /// Inicializar servicio
  Future<void> initialize() async {
    await _loadSettings();
    if (!_observando) {
      // En automático, el papel cambia cuando el teléfono cambia de modo.
      WidgetsBinding.instance.addObserver(this);
      _observando = true;
    }
    _recalcular();
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (_modo == ModoTema.automatico && _recalcular()) notifyListeners();
  }

  /// Cargar configuración guardada (con migración de los temas de antes)
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modo = prefs.getString(_modoKey);
    if (modo != null) {
      _modo = ModoTema.values.firstWhere(
        (m) => m.name == modo,
        orElse: () => ModoTema.claro,
      );
      _papelOscuro = _papelOscuroValido(prefs.getString(_papelOscuroKey));
    } else {
      _migrar(prefs);
      await _guardar(prefs);
    }
    lecturaManuscrita.value = prefs.getBool(_lecturaManuscritaKey) ?? false;
  }

  /// Los temas de antes pasan al papel: los oscuros (noche pura, carbón,
  /// sepia nocturno) al papel kraft y los claros al papel claro. El tema
  /// automático por hora pasa a seguir al teléfono.
  void _migrar(SharedPreferences prefs) {
    // Desde cero: el servicio es uno solo para toda la app y puede traer el
    // papel de la cuenta anterior (al cerrar sesión se borran las claves).
    _modo = ModoTema.claro;
    _papelOscuro = AppThemeData.paperKraft.id;
    var id = prefs.getString(_legacyThemeIdKey);
    if (id == null) {
      // Sistema más viejo: 0 = sistema, 1 = claro, 2 = oscuro.
      final indice = prefs.getInt(_legacyThemeModeKey);
      if (indice == 2) id = 'night_pure';
    }
    const oscurosDeAntes = {'night_pure', 'charcoal_editorial', 'sepia_night'};
    if (id == AppThemeData.paperKraft.id || id == AppThemeData.paperNoche.id) {
      _modo = ModoTema.oscuro;
      _papelOscuro = id!;
    } else if (oscurosDeAntes.contains(id)) {
      _modo = ModoTema.oscuro;
    }
    if (prefs.getBool(_legacyAutoThemeKey) ?? false) {
      _modo = ModoTema.automatico;
    }
  }

  String _papelOscuroValido(String? id) =>
      id == AppThemeData.paperNoche.id ? id! : AppThemeData.paperKraft.id;

  Future<void> _guardar([SharedPreferences? prefs]) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.setString(_modoKey, _modo.name);
    await prefs.setString(_papelOscuroKey, _papelOscuro);
    UserPrefCloudSyncService.I.markDirty();
  }

  /// Calcula el tema que se ve con el modo y el papel oscuro. Devuelve si
  /// cambió.
  bool _recalcular() {
    final oscuro = switch (_modo) {
      ModoTema.claro => false,
      ModoTema.oscuro => true,
      ModoTema.automatico =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark,
    };
    final id = oscuro ? _papelOscuro : AppThemeData.paper.id;
    final cambio = id != _themeId;
    _themeId = id;
    // Los colores del kit (VecColores) siguen al papel del tema. Quien
    // escucha el cambio vuelve a construir todo (ver main.dart).
    VecColores.actual = currentTheme.paleta;
    themeIdNotifier.value = id;
    return cambio;
  }

  /// Elegir claro, oscuro o automático (según el teléfono).
  Future<void> setModo(ModoTema modo) async {
    if (_modo == modo) return;
    _modo = modo;
    _recalcular();
    await _guardar();
    notifyListeners();
  }

  /// Elegir el papel oscuro ('papel_kraft' o 'papel_noche').
  Future<void> setPapelOscuro(String id) async {
    final valido = _papelOscuroValido(id);
    if (_papelOscuro == valido) return;
    _papelOscuro = valido;
    _recalcular();
    await _guardar();
    notifyListeners();
  }

  /// Poner un tema por su id: el papel claro es el modo claro y los papeles
  /// oscuros, el modo oscuro con ese papel.
  Future<void> setTheme(String id) async {
    if (id == AppThemeData.paper.id) {
      await setModo(ModoTema.claro);
      return;
    }
    final papel = _papelOscuroValido(id);
    if (_modo == ModoTema.oscuro && _papelOscuro == papel) return;
    _modo = ModoTema.oscuro;
    _papelOscuro = papel;
    _recalcular();
    await _guardar();
    notifyListeners();
  }

  /// Elegir la letra de lectura del papel (Lora o manuscrita).
  Future<void> setLecturaManuscrita(bool manuscrita) async {
    if (lecturaManuscrita.value == manuscrita) return;
    lecturaManuscrita.value = manuscrita;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_lecturaManuscritaKey, manuscrita);
    notifyListeners();
  }
}
