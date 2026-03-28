/// ═══════════════════════════════════════════════════════════════════════════
/// WIDGET SYNC SERVICE - Sincronización con Widgets Nativos
/// Envía datos a Android AppWidget y iOS WidgetKit
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
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
      final jesusMessage = JesusWidgetService.I.getMessage(
        streakDays: payload.streakValue,
        completedToday: completedToday,
        isNewUser: payload.streakValue == 0 && !completedToday,
      );
      await HomeWidget.saveWidgetData(_keyJesusStreak, payload.streakValue);
      await HomeWidget.saveWidgetData(_keyJesusCompleted, completedToday);
      await HomeWidget.saveWidgetData(_keyJesusMessage, jesusMessage);
      
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
    final dateISO = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    debugPrint('📱 [WIDGET] Building payload: streak=$streak');
    
    final isDiscreet = _config.privacyMode == WidgetPrivacyMode.discreet;
    final title = _config.effectiveTitle;
    
    // Contenido de línea1 determinado 100% por la plantilla
    String line1;
    switch (_config.template) {
      case WidgetTemplate.discreet:
        line1 = isDiscreet ? 'Respira. Sigue hoy.' : 'Tu victoria diaria te espera.';
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
    } catch (_) {}
    
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
  
  /// Registra un callback para cuando el usuario interactúa con el widget
  Future<void> registerInteractionCallback() async {
    HomeWidget.widgetClicked.listen((uri) {
      debugPrint('📱 [WIDGET] Clicked: $uri');
      // El deep link se maneja en main.dart
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
    } catch (_) {
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
