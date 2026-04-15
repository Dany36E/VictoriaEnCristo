/// ═══════════════════════════════════════════════════════════════════════════
/// WIDGET SYNC SERVICE - Sincronización con Widgets Nativos
/// Envía datos a Android AppWidget y iOS WidgetKit
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/widget_constants.dart';
import '../models/widget_config.dart';
import '../data/bible_verses.dart';
import 'daily_verse_service.dart';
import 'jesus_widget_service.dart';
import 'victory_scoring_service.dart';

class WidgetSyncService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final WidgetSyncService _instance = WidgetSyncService._internal();
  factory WidgetSyncService() => _instance;
  WidgetSyncService._internal();
  
  static WidgetSyncService get I => _instance;

  StreamSubscription<Uri?>? _widgetClickSub;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONSTANTES (usando widget_constants.dart)
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Nombre del widget Android (solo 2x2) - desde constantes centralizadas
  static String get androidWidgetName => kAndroidWidget2x2Provider;
  
  /// Nombre del widget iOS - desde constantes centralizadas
  static String get iOSWidgetName => kIOSWidgetName;
  
  /// App Group para iOS - desde constantes centralizadas
  static String get iOSAppGroup => kIOSAppGroup;
  
  // Keys para datos del widget (deben coincidir con código nativo)
  static const String _keyWidgetConfig = 'widget_config_json';
  static const String _keyWidgetPayload = 'widget_payload_json';
  static const String _keyWidgetTitle = 'widget_title';
  static const String _keyWidgetLine1 = 'widget_line1';
  static const String _keyWidgetStreak = 'widget_streak';
  static const String _keyWidgetIsLight = 'widget_is_light';
  static const String _keyWidgetIsDiscreet = 'widget_is_discreet';
  static const String _keyWidgetDate = 'widget_date';
  
  // Keys para widget 4×2 de versículo (deben coincidir con VerseOfDayWidgetProvider)
  static const String _keyVerseText = 'verse_widget_text';
  static const String _keyVerseRef = 'verse_widget_reference';
  static const String _keyVerseIsLight = 'verse_widget_is_light';

  // Keys para widget Jesús (deben coincidir con JesusWidgetProvider.kt)
  static const String _keyJesusStreak = 'jesus_streak_days';
  static const String _keyJesusCompleted = 'jesus_completed_today';
  static const String _keyJesusMessage = 'jesus_widget_message';
  static const String _keyJesusSpritePath = 'jesus_sprite_path';
  static const String _keyJesusBgPath = 'jesus_bg_path';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════
  
  SharedPreferences? _prefs;
  WidgetConfig _config = WidgetConfig.defaultConfig();
  bool _isInitialized = false;
  
  bool get isInitialized => _isInitialized;
  WidgetConfig get currentConfig => _config;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      
      // Configurar App Group para iOS
      await HomeWidget.setAppGroupId(iOSAppGroup);
      
      // Cargar configuración guardada
      await _loadConfig();
      
      _isInitialized = true;
      debugPrint('📱 [WIDGET] Service initialized');
    } catch (e) {
      debugPrint('📱 [WIDGET] Init error: $e');
      _isInitialized = true;
    }
  }
  
  Future<void> _loadConfig() async {
    final jsonStr = _prefs?.getString(_keyWidgetConfig);
    if (jsonStr != null) {
      _config = WidgetConfig.fromJsonString(jsonStr);
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Guarda la configuración y actualiza los widgets
  Future<void> saveConfig(WidgetConfig config) async {
    _config = config.copyWith(lastUpdated: DateTime.now());
    
    // Guardar en SharedPreferences local
    await _prefs?.setString(_keyWidgetConfig, _config.toJsonString());
    
    // Sincronizar con widgets nativos
    await syncWidget();
    
    debugPrint('📱 [WIDGET] Config saved: ${_config.template.name}');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // SINCRONIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Sincroniza datos con los widgets nativos
  Future<void> syncWidget() async {
    if (!_isInitialized) {
      await init();
    }
    
    try {
      // Construir payload
      final payload = await _buildPayload();
      
      // Widget 2×2 (Recordatorio)
      await HomeWidget.saveWidgetData(_keyWidgetTitle, payload.title);
      await HomeWidget.saveWidgetData(_keyWidgetLine1, payload.line1);
      await HomeWidget.saveWidgetData(_keyWidgetStreak, payload.streakValue);
      await HomeWidget.saveWidgetData(_keyWidgetIsLight, payload.isLightTheme);
      await HomeWidget.saveWidgetData(_keyWidgetIsDiscreet, payload.isDiscreetMode);
      await HomeWidget.saveWidgetData(_keyWidgetDate, payload.dateISO);
      
      // Widget 4×2 (Versículo del día)
      await HomeWidget.saveWidgetData(_keyVerseText, payload.verseText);
      await HomeWidget.saveWidgetData(_keyVerseRef, payload.verseReference);
      await HomeWidget.saveWidgetData(_keyVerseIsLight, payload.isLightTheme);
      
      // Widget Jesús (racha con sprite)
      final completedToday = VictoryScoringService.I.isLoggedToday();
      final isNewUser = payload.streakValue == 0 && !completedToday;
      final jesusMessage = JesusWidgetService.I.getMessage(
        streakDays: payload.streakValue,
        completedToday: completedToday,
        isNewUser: isNewUser,
      );
      await HomeWidget.saveWidgetData(_keyJesusStreak, payload.streakValue);
      await HomeWidget.saveWidgetData(_keyJesusCompleted, completedToday);
      await HomeWidget.saveWidgetData(_keyJesusMessage, jesusMessage);

      // Guardar imágenes de sprite y fondo para el widget nativo
      final spritePath = JesusWidgetService.I.getSprite(
        streakDays: payload.streakValue,
        completedToday: completedToday,
        isNewUser: isNewUser,
      );
      final bgPath = JesusWidgetService.I.getBackground(
        streakDays: payload.streakValue,
      );
      final spriteFile = await _saveAssetToWidgetDir(spritePath, 'jesus_sprite.png');
      final bgFile = await _saveAssetToWidgetDir(bgPath, 'jesus_bg.png');
      if (spriteFile != null) {
        await HomeWidget.saveWidgetData(_keyJesusSpritePath, spriteFile);
      }
      if (bgFile != null) {
        await HomeWidget.saveWidgetData(_keyJesusBgPath, bgFile);
      }
      
      // JSON completo como backup
      await HomeWidget.saveWidgetData(_keyWidgetPayload, payload.toJsonString());
      
      // Forzar actualización de widgets
      await _updateWidgets();
      
      debugPrint('📱 [WIDGET] Synced: "${payload.title}" streak=${payload.streakValue}');
    } catch (e) {
      debugPrint('📱 [WIDGET] Sync error: $e');
    }
  }
  
  /// Construye el payload según la configuración actual
  Future<WidgetPayload> _buildPayload() async {
    if (!VictoryScoringService.I.isInitialized) {
      await VictoryScoringService.I.init();
    }
    
    final streak = VictoryScoringService.I.getCurrentStreak();
    final verse = await _getVerseForWidget();
    final today = DateTime.now();
    final hour = today.hour;
    final dateISO = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    debugPrint('📱 [WIDGET] Building payload: streak=$streak, hour=$hour');
    
    final isDiscreet = _config.privacyMode == WidgetPrivacyMode.discreet;
    final title = _config.effectiveTitle;
    
    // Contenido de línea1 determinado por plantilla + hora del día
    String line1;
    switch (_config.template) {
      case WidgetTemplate.discreet:
        line1 = isDiscreet
            ? _getTimeOfDayMessage(hour, discreet: true)
            : _getTimeOfDayMessage(hour, discreet: false);
        break;
      case WidgetTemplate.verse:
        line1 = _truncateVerse(verse.verse, isDiscreet ? 50 : 80);
        break;
      case WidgetTemplate.streak:
        line1 = _config.getStreakText(streak);
        break;
      case WidgetTemplate.combo:
        line1 = '${_config.getStreakText(streak)}\n${_truncateVerse(verse.verse, 35)}';
        break;
    }
    
    return WidgetPayload(
      title: title,
      line1: line1,
      streakValue: streak,
      verseText: verse.verse,
      verseReference: verse.reference,
      dateISO: dateISO,
      isLightTheme: _config.theme == WidgetTheme.lightCard,
      isDiscreetMode: isDiscreet,
    );
  }
  
  /// Obtiene el versículo del día (con fallback neutral para modo discreto)
  Future<BibleVerse> _getVerseForWidget() async {
    try {
      if (DailyVerseService.I.isInitialized) {
        return await DailyVerseService.I.getForToday();
      }
    } catch (e) {
      debugPrint('📱 [WIDGET] _getVerseForWidget error: $e');
    }
    
    // Fallback neutral
    return const BibleVerse(
      verse: 'Un nuevo día, una nueva oportunidad.',
      reference: '',
      category: 'general',
    );
  }
  
  /// Trunca un versículo para que quepa en el widget
  String _truncateVerse(String verse, int maxLength) {
    if (verse.length <= maxLength) return verse;
    
    // Intentar cortar en un espacio
    final truncated = verse.substring(0, maxLength);
    final lastSpace = truncated.lastIndexOf(' ');
    
    if (lastSpace > maxLength * 0.7) {
      return '${truncated.substring(0, lastSpace)}...';
    }
    return '$truncated...';
  }

  /// Mensaje contextual por hora del día
  String _getTimeOfDayMessage(int hour, {required bool discreet}) {
    final hasVictory = VictoryScoringService.I.isTodayVictory();

    if (discreet) {
      if (hour < 6)  return 'Descansa bien.';
      if (hour < 12) return 'Nuevo día, nuevo inicio.';
      if (hour < 18) return 'Sigue firme.';
      if (hasVictory) return 'Buen cierre de día.';
      return 'Hora de cerrar el día.';
    }

    if (hour < 6)  return 'Descansa en paz, Dios vela por ti.';
    if (hour < 12) return 'Buenos días. Hoy es un día de victoria.';
    if (hour < 18) return 'Sigue firme. Tu victoria se acerca.';
    if (hasVictory) return '¡Día de victoria registrado!';
    return 'Es hora de registrar tu victoria.';
  }
  
  /// Actualiza ambos widgets en Android e iOS
  Future<void> _updateWidgets() async {
    if (!validateWidgetConstants()) {
      debugPrint('📱 [WIDGET] ⚠️ Invalid widget constants, skipping update');
      return;
    }
    
    try {
      // Widget 2×2 (Recordatorio)
      await HomeWidget.updateWidget(
        androidName: kAndroidWidget2x2Provider,
        qualifiedAndroidName: kAndroidWidget2x2QualifiedName,
        iOSName: kIOSWidgetName,
      );
      
      // Widget 4×2 (Versículo del día)
      await HomeWidget.updateWidget(
        androidName: kAndroidVerseWidgetProvider,
        qualifiedAndroidName: kAndroidVerseWidgetQualifiedName,
      );

      // Widget Jesús (racha con sprite)
      await HomeWidget.updateWidget(
        androidName: kAndroidJesusWidgetProvider,
        qualifiedAndroidName: kAndroidJesusWidgetQualifiedName,
        iOSName: kIOSJesusWidgetName,
      );
    } catch (e) {
      debugPrint('📱 [WIDGET] Update error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Copia un Flutter asset a un directorio accesible por el widget nativo
  Future<String?> _saveAssetToWidgetDir(String assetPath, String filename) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final dir = await getApplicationDocumentsDirectory();
      final widgetDir = Directory('${dir.path}/widget_images');
      if (!widgetDir.existsSync()) {
        await widgetDir.create(recursive: true);
      }
      final file = File('${widgetDir.path}/$filename');
      await file.writeAsBytes(byteData.buffer.asUint8List());
      return file.path;
    } catch (e) {
      debugPrint('📱 [WIDGET] Error saving asset $assetPath: $e');
      return null;
    }
  }

  /// Registra un callback para cuando el usuario interactúa con el widget.
  /// [navigatorKey] se usa para push de rutas según el URI del widget.
  Future<void> registerInteractionCallback({GlobalKey<NavigatorState>? navigatorKey}) async {
    await _widgetClickSub?.cancel();
    _widgetClickSub = HomeWidget.widgetClicked.listen((uri) {
      debugPrint('📱 [WIDGET] Clicked: $uri');
      if (uri == null || navigatorKey?.currentState == null) return;
      
      final uriStr = uri.toString();
      final nav = navigatorKey!.currentState!;
      
      if (uriStr.contains('emergency')) {
        nav.pushNamed('/emergency');
      } else if (uriStr.contains('bible')) {
        nav.pushNamed('/bible');
      } else if (uriStr.contains('victory') || uriStr.contains('register')) {
        // Launch app to home — the JesusStreakWidget handles the tap
        nav.pushNamedAndRemoveUntil('/', (route) => false);
      }
    });
  }
  
  /// Limpiar widget a valores por defecto discretos (cambio de cuenta)
  /// Muestra un widget neutral sin datos del usuario anterior
  Future<void> clearToDefaults() async {
    debugPrint('📱 [WIDGET] Clearing widget to defaults (account change)');
    
    try {
      // Widget 2×2 neutral
      await HomeWidget.saveWidgetData(_keyWidgetTitle, '¡Hola!');
      await HomeWidget.saveWidgetData(_keyWidgetLine1, 'Bienvenido');
      await HomeWidget.saveWidgetData(_keyWidgetStreak, 0);
      await HomeWidget.saveWidgetData(_keyWidgetIsLight, true);
      await HomeWidget.saveWidgetData(_keyWidgetIsDiscreet, true);
      await HomeWidget.saveWidgetData(_keyWidgetDate, '');
      
      // Widget 4×2 Versículo defaults
      await HomeWidget.saveWidgetData(_keyVerseText, 'Todo lo puedo en Cristo que me fortalece.');
      await HomeWidget.saveWidgetData(_keyVerseRef, 'Filipenses 4:13');
      await HomeWidget.saveWidgetData(_keyVerseIsLight, false);
      
      await HomeWidget.saveWidgetData(_keyWidgetPayload, '{}');
      
      // Forzar actualización
      await _updateWidgets();
      
      debugPrint('📱 [WIDGET] ✅ Widget cleared to defaults');
    } catch (e) {
      debugPrint('📱 [WIDGET] Clear defaults error: $e');
    }
  }
  
  /// Verifica si los widgets están instalados (Android)
  Future<bool> isWidgetInstalled() async {
    try {
      final count = await HomeWidget.getInstalledWidgets();
      return count.isNotEmpty;
    } catch (e) {
      debugPrint('📱 [WIDGET] isWidgetInstalled error: $e');
      return false;
    }
  }
  
  /// Solicita al usuario que añada el widget 2x2 (Android)
  /// Retorna true si la solicitud se realizó, false si hay error de configuración
  Future<bool> requestWidgetPin() async {
    // CRÍTICO: Validar constantes antes de intentar pin
    // Esto evita ClassNotFoundException: com.example.app_quitar.null
    if (!validateWidgetConstants()) {
      debugPrint('📱 [WIDGET] ❌ Cannot pin: invalid widget constants');
      return false;
    }
    
    if (kAndroidWidget2x2Provider.isEmpty) {
      debugPrint('📱 [WIDGET] ❌ Cannot pin: provider name is empty');
      return false;
    }
    
    try {
      debugPrint('📱 [WIDGET] Requesting pin for: $kAndroidWidget2x2QualifiedName');
      
      await HomeWidget.requestPinWidget(
        androidName: kAndroidWidget2x2Provider,
        qualifiedAndroidName: kAndroidWidget2x2QualifiedName,
      );
      
      debugPrint('📱 [WIDGET] ✅ Pin request sent');
      return true;
    } catch (e) {
      debugPrint('📱 [WIDGET] Pin request error: $e');
      return false;
    }
  }
}
