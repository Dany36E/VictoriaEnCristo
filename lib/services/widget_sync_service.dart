/// ═══════════════════════════════════════════════════════════════════════════
/// WIDGET SYNC SERVICE - Sincronización con Widgets Nativos
/// Envía datos a Android AppWidget y iOS WidgetKit
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/widget_constants.dart';
import '../models/widget_config.dart';
import '../data/bible_verses.dart';
import '../vec/vec_tema.dart';
import '../widgets/jesus_streak_widget.dart';
import 'atajos_service.dart';
import 'bible/bible_user_data_service.dart';
import 'theme_service.dart';
import 'widget_snapshot_renderer.dart';
import 'daily_verse_service.dart';
import 'jesus_widget_service.dart';
import 'user_pref_cloud_sync_service.dart';
import 'victory_scoring_service.dart';
import '../utils/platform_capabilities.dart';

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
  static const String _keyJesusVictoryToday = 'jesus_victory_today';
  static const String _keyJesusMessage = 'jesus_widget_message';
  static const String _keyJesusSpritePath = 'jesus_sprite_path';
  static const String _keyJesusBgPath = 'jesus_bg_path';
  static const String _keyJesusBadgeText = 'jesus_badge_text';
  static const String _keyJesusBadgeColor = 'jesus_badge_color';
  static const String _keyJesusStreakColor = 'jesus_streak_color';
  static const String _keyJesusCheckinDone = 'jesus_checkin_done';

  // Imágenes de la tarjeta de racha (la misma de Inicio) para el widget Jesús.
  // «hoy» vale para [_keyJesusImgFecha]; «manana» es la del día siguiente
  // (día sin registrar), para que a medianoche el widget no siga diciendo
  // «Hoy ✓» aunque la app no se abra.
  static const String _keyJesusImgFecha = 'jesus_img_fecha';
  static const String _keyJesusImgFirma = 'jesus_img_firma';
  static const String _keyJesusA11yHoy = 'jesus_a11y_hoy';
  static const String _keyJesusA11yManana = 'jesus_a11y_manana';

  /// Versículos de los próximos días (JSON) para que el widget nativo cambie
  /// de versículo a medianoche sin abrir la app.
  static const String _keyVerseSchedule = 'verse_widget_schedule';
  static const String _keyVerseVersion = 'verse_widget_version';
  static const String _keyWidgetTemplate = 'widget_template';
  static const String _keyWidgetLine2 = 'widget_line2';

  /// Días de versículos que se dejan guardados para el widget.
  static const int diasVersiculosWidget = 14;

  /// Tamaños lógicos de las imágenes de la tarjeta de racha: ancha (4×2) y
  /// alta (3×3). El widget nativo elige la que mejor llena su espacio.
  static const Size tamanoRachaAncha = Size(380, 200);
  static const Size tamanoRachaAlta = Size(340, 330);

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  SharedPreferences? _prefs;
  WidgetConfig _config = WidgetConfig.defaultConfig();
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;
  WidgetConfig get currentConfig => _config;
  bool get isSupported => PlatformCapabilities.supportsHomeWidgets;

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      _prefs = await SharedPreferences.getInstance();

      // Cargar configuración guardada
      await _loadConfig();

      if (!isSupported) {
        _isInitialized = true;
        debugPrint(
          '📱 [WIDGET] Skipped on ${PlatformCapabilities.currentLabel}',
        );
        return;
      }

      // Configurar App Group para iOS
      await HomeWidget.setAppGroupId(iOSAppGroup);

      // Cambiar el papel (claro/oscuro) o la versión de la Biblia cambia lo
      // que se ve en los widgets.
      ThemeService().themeIdNotifier.addListener(_alCambiarAlgo);
      BibleUserDataService.I.preferredVersionNotifier.addListener(
        _alCambiarAlgo,
      );

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
    UserPrefCloudSyncService.I.markDirty();

    // Sincronizar con widgets nativos
    await syncWidget();

    debugPrint('📱 [WIDGET] Config saved: ${_config.template.name}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SINCRONIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  void _alCambiarAlgo() => unawaited(syncWidget());

  Future<void>? _sincronizando;
  bool _pendiente = false;

  /// Sincroniza datos con los widgets nativos. Si ya hay una sincronización
  /// en curso, se hace otra al terminar (con los datos nuevos).
  Future<void> syncWidget() async {
    final enCurso = _sincronizando;
    if (enCurso != null) {
      _pendiente = true;
      return enCurso;
    }
    final completer = Completer<void>();
    _sincronizando = completer.future;
    try {
      do {
        _pendiente = false;
        await _syncWidget();
      } while (_pendiente);
    } finally {
      _sincronizando = null;
      completer.complete();
    }
  }

  Future<void> _syncWidget() async {
    if (!_isInitialized) {
      await init();
    }

    if (!isSupported) return;

    try {
      // Construir payload
      final payload = await _buildPayload();

      // Widget 2×2 (Recordatorio)
      await HomeWidget.saveWidgetData(_keyWidgetTitle, payload.title);
      await HomeWidget.saveWidgetData(_keyWidgetLine1, payload.line1);
      await HomeWidget.saveWidgetData(_keyWidgetStreak, payload.streakValue);
      await HomeWidget.saveWidgetData(_keyWidgetIsLight, payload.isLightTheme);
      await HomeWidget.saveWidgetData(
        _keyWidgetIsDiscreet,
        payload.isDiscreetMode,
      );
      await HomeWidget.saveWidgetData(_keyWidgetDate, payload.dateISO);
      await HomeWidget.saveWidgetData(_keyWidgetLine2, payload.line2);
      await HomeWidget.saveWidgetData(
        _keyWidgetTemplate,
        _config.template.name,
      );

      // Colores del papel activo de la app (claro, kraft o noche), para que
      // los widgets nativos usen los mismos que Inicio.
      await guardarPaleta(VecColores.actual);

      // Widget 4×2 (Versículo del día)
      await HomeWidget.saveWidgetData(_keyVerseText, payload.verseText);
      await HomeWidget.saveWidgetData(_keyVerseRef, payload.verseReference);
      await HomeWidget.saveWidgetData(_keyVerseIsLight, !VecColores.oscuro);
      await HomeWidget.saveWidgetData(_keyVerseVersion, payload.verseVersion);
      await _guardarVersiculosProximos();

      // Widget Jesús (racha con sprite)
      final completedToday = VictoryScoringService.I.isLoggedToday();
      final victoryToday = VictoryScoringService.I.isTodayVictory();
      final isNewUser = payload.streakValue == 0 && !completedToday;
      // Detectar si hizo el devocional matutino hoy
      final checkinLast = _prefs?.getString('morning_checkin_last_shown') ?? '';
      final todayISO = payload.dateISO;
      final checkinDone = checkinLast == todayISO;
      final canRegister =
          !completedToday && VictoryScoringService.I.canLogVictoryNow();
      final jesusMessage = JesusWidgetService.I.getMessage(
        streakDays: payload.streakValue,
        completedToday: completedToday,
        victoryToday: victoryToday,
        isNewUser: isNewUser,
      );
      await HomeWidget.saveWidgetData(_keyJesusStreak, payload.streakValue);
      await HomeWidget.saveWidgetData(_keyJesusCompleted, completedToday);
      await HomeWidget.saveWidgetData(_keyJesusVictoryToday, victoryToday);
      await HomeWidget.saveWidgetData(_keyJesusMessage, jesusMessage);
      await HomeWidget.saveWidgetData(_keyJesusCheckinDone, checkinDone);

      // Texto del botón: el mismo que la tarjeta de Inicio.
      final finalBadgeText = TarjetaRachaPapel.etiquetaBoton(
        completedToday: completedToday,
        victoryToday: victoryToday,
        canRegister: canRegister,
        isNewUser: isNewUser,
        checkinDone: checkinDone,
      );
      await HomeWidget.saveWidgetData(_keyJesusBadgeText, finalBadgeText);
      await HomeWidget.saveWidgetData(
        _keyJesusBadgeColor,
        VecColores.terracota.toARGB32(),
      );
      await HomeWidget.saveWidgetData(
        _keyJesusStreakColor,
        VecColores.terracota.toARGB32(),
      );

      // Sprite y fondo sueltos: respaldo si la imagen de la tarjeta falla.
      final spritePath = JesusWidgetService.I.getSprite(
        streakDays: payload.streakValue,
        completedToday: completedToday && victoryToday,
        isNewUser: isNewUser,
      );
      final bgPath = JesusWidgetService.I.getBackground(
        streakDays: payload.streakValue,
      );
      final spriteFile = await _saveAssetToWidgetDir(
        spritePath,
        'jesus_sprite.png',
      );
      final bgFile = await _saveAssetToWidgetDir(bgPath, 'jesus_bg.png');
      if (spriteFile != null) {
        await HomeWidget.saveWidgetData(_keyJesusSpritePath, spriteFile);
      }
      if (bgFile != null) {
        await HomeWidget.saveWidgetData(_keyJesusBgPath, bgFile);
      }

      // La tarjeta de Inicio dibujada a imagen (hoy y mañana).
      await _guardarImagenesRacha(
        fecha: todayISO,
        streakDays: payload.streakValue,
        completedToday: completedToday,
        victoryToday: victoryToday,
        isNewUser: isNewUser,
        checkinDone: checkinDone,
        mensaje: jesusMessage,
        etiqueta: finalBadgeText,
        recursos: [spritePath, bgPath],
      );

      // JSON completo como backup
      await HomeWidget.saveWidgetData(
        _keyWidgetPayload,
        payload.toJsonString(),
      );

      // Forzar actualización de widgets
      await _updateWidgets();

      debugPrint(
        '📱 [WIDGET] Synced: "${payload.title}" streak=${payload.streakValue}',
      );
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
    final dateISO =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

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
        // El versículo completo: el widget ajusta la letra para que quepa.
        line1 = verse.verse;
        break;
      case WidgetTemplate.streak:
        line1 = _config.getStreakText(streak);
        break;
      case WidgetTemplate.combo:
        line1 = '${_config.getStreakText(streak)}\n${verse.verse}';
        break;
    }
    final muestraCita =
        _config.template == WidgetTemplate.verse ||
        _config.template == WidgetTemplate.combo;

    return WidgetPayload(
      title: title,
      line1: line1,
      streakValue: streak,
      verseText: verse.verse,
      verseReference: verse.reference,
      verseVersion: verse.version,
      line2: muestraCita ? verse.reference : '',
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

  // ═══════════════════════════════════════════════════════════════════════════
  // PAPEL, VERSÍCULOS E IMÁGENES PARA LOS WIDGETS NATIVOS
  // ═══════════════════════════════════════════════════════════════════════════

  static String _hex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

  /// Colores del papel [paleta] tal como los lee el código nativo
  /// (`vec_*`, en `#AARRGGBB`).
  @visibleForTesting
  static Map<String, Object> datosPaleta(VecPaleta paleta) => {
    'vec_oscuro': paleta.oscura,
    'vec_papel': _hex(paleta.papel),
    'vec_crema': _hex(paleta.crema),
    'vec_crema_oscuro': _hex(paleta.cremaOscuro),
    'vec_tinta': _hex(paleta.tinta),
    'vec_gris': _hex(paleta.gris),
    'vec_terracota': _hex(paleta.terracota),
    'vec_azul': _hex(paleta.azul),
    'vec_verde': _hex(paleta.verde),
    'vec_mostaza': _hex(paleta.mostaza),
  };

  /// Guarda los colores del papel activo para los widgets nativos.
  Future<void> guardarPaleta(VecPaleta paleta) async {
    for (final e in datosPaleta(paleta).entries) {
      await HomeWidget.saveWidgetData(e.key, e.value);
    }
  }

  /// JSON con los versículos de los próximos días: `[{f, t, r, v}]` (fecha
  /// ISO, texto completo, cita y versión).
  @visibleForTesting
  static String jsonVersiculos(List<({String fecha, BibleVerse verse})> dias) =>
      jsonEncode([
        for (final d in dias)
          {
            'f': d.fecha,
            't': d.verse.verse,
            'r': d.verse.reference,
            'v': d.verse.version,
          },
      ]);

  Future<void> _guardarVersiculosProximos() async {
    try {
      if (!DailyVerseService.I.isInitialized) return;
      final dias = await DailyVerseService.I.proximosDias(diasVersiculosWidget);
      await HomeWidget.saveWidgetData(_keyVerseSchedule, jsonVersiculos(dias));
    } catch (e) {
      debugPrint('📱 [WIDGET] Versículos próximos error: $e');
    }
  }

  /// La tarjeta de racha de Inicio, enmarcada para dibujarla a imagen del
  /// tamaño del widget (con aire para la cinta y la sombra del papel).
  static Widget tarjetaRachaParaWidget({
    required bool apaisada,
    required int streakDays,
    required bool completedToday,
    required bool victoryToday,
    required bool isNewUser,
    required bool checkinDone,
    required bool puedeRegistrar,
    required String mensaje,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
      // Con letra más alta o un mensaje largo, la tarjeta entera se achica
      // un poco en vez de cortarse.
      child: LayoutBuilder(
        builder: (context, c) => FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: c.maxWidth,
            child: TarjetaRachaPapel(
              streakDays: streakDays,
              completedToday: completedToday,
              victoryToday: victoryToday,
              isNewUser: isNewUser,
              checkinDone: checkinDone,
              puedeRegistrar: puedeRegistrar,
              mensaje: mensaje,
              apaisada: apaisada,
              // Con callback para que el botón se vea activo, como en Inicio.
              onRegisterVictory: () {},
            ),
          ),
        ),
      ),
    );
  }

  /// Densidad de las imágenes: la del teléfono, sin pasar de 3 (el nativo
  /// las reduce al tamaño real del widget).
  double get _densidad {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    return (view?.devicePixelRatio ?? 2.5).clamp(1.5, 3.0);
  }

  Future<void> _guardarImagenesRacha({
    required String fecha,
    required int streakDays,
    required bool completedToday,
    required bool victoryToday,
    required bool isNewUser,
    required bool checkinDone,
    required String mensaje,
    required String etiqueta,
    required List<String> recursos,
  }) async {
    try {
      final mensajeManana = JesusWidgetService.I.getMessage(
        streakDays: streakDays,
        completedToday: false,
        victoryToday: false,
        isNewUser: isNewUser,
      );
      final densidad = _densidad;
      final firma = jsonEncode([
        fecha,
        streakDays,
        completedToday,
        victoryToday,
        isNewUser,
        checkinDone,
        mensaje,
        etiqueta,
        mensajeManana,
        VecColores.actual.papel.toARGB32(),
        densidad,
      ]);
      final dir = await _widgetDir();
      String ruta(String dia, String forma) =>
          '${dir.path}/jesus_${dia}_$forma.png';
      final rutas = [
        for (final dia in const ['hoy', 'manana'])
          for (final forma in const ['ancha', 'alta']) ruta(dia, forma),
      ];
      final yaEstan =
          _prefs?.getString(_keyJesusImgFirma) == firma &&
          rutas.every((r) => File(r).existsSync());

      if (!yaEstan) {
        await WidgetSnapshotRenderer.precargar(recursos, pixelRatio: densidad);
        for (final dia in const ['hoy', 'manana']) {
          final hoy = dia == 'hoy';
          for (final forma in const ['ancha', 'alta']) {
            final ancha = forma == 'ancha';
            final png = await WidgetSnapshotRenderer.renderPng(
              tarjetaRachaParaWidget(
                apaisada: ancha,
                streakDays: streakDays,
                completedToday: hoy && completedToday,
                victoryToday: hoy && victoryToday,
                isNewUser: isNewUser,
                checkinDone: hoy && checkinDone,
                puedeRegistrar: hoy
                    ? !completedToday &&
                          VictoryScoringService.I.canLogVictoryNow()
                    : true,
                mensaje: hoy ? mensaje : mensajeManana,
              ),
              logicalSize: ancha ? tamanoRachaAncha : tamanoRachaAlta,
              pixelRatio: densidad,
            );
            if (png == null) return;
            await File(ruta(dia, forma)).writeAsBytes(png, flush: true);
          }
        }
        await _prefs?.setString(_keyJesusImgFirma, firma);
      }

      for (final dia in const ['hoy', 'manana']) {
        for (final forma in const ['ancha', 'alta']) {
          await HomeWidget.saveWidgetData(
            'jesus_img_${dia}_$forma',
            ruta(dia, forma),
          );
        }
      }
      await HomeWidget.saveWidgetData(_keyJesusImgFecha, fecha);
      final dias = isNewUser ? 0 : streakDays;
      await HomeWidget.saveWidgetData(
        _keyJesusA11yHoy,
        'Racha: $dias ${dias == 1 ? 'día' : 'días'} de victoria. '
        '$mensaje. $etiqueta',
      );
      await HomeWidget.saveWidgetData(
        _keyJesusA11yManana,
        'Racha: $dias ${dias == 1 ? 'día' : 'días'} de victoria. '
        '$mensajeManana. Registrar día',
      );
    } catch (e) {
      debugPrint('📱 [WIDGET] Imágenes de racha error: $e');
    }
  }

  Future<Directory> _widgetDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final widgetDir = Directory('${dir.path}/widget_images');
    if (!widgetDir.existsSync()) await widgetDir.create(recursive: true);
    return widgetDir;
  }

  /// Mensaje contextual por hora del día
  String _getTimeOfDayMessage(int hour, {required bool discreet}) {
    final hasVictory = VictoryScoringService.I.isTodayVictory();

    if (discreet) {
      if (hour < 6) return 'Descansa bien.';
      if (hour < 12) return 'Nuevo día, nuevo inicio.';
      if (hour < 18) return 'Sigue firme.';
      if (hasVictory) return 'Buen cierre de día.';
      return 'Hora de cerrar el día.';
    }

    if (hour < 6) return 'Descansa en paz, Dios vela por ti.';
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

    if (!isSupported) return;

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

      // Widget de atajos (claro/oscuro según widget_is_light)
      await HomeWidget.updateWidget(
        androidName: kAndroidAtajosWidgetProvider,
        qualifiedAndroidName: kAndroidAtajosWidgetQualifiedName,
      );
    } catch (e) {
      debugPrint('📱 [WIDGET] Update error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILIDADES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Copia un Flutter asset a un directorio accesible por el widget nativo
  Future<String?> _saveAssetToWidgetDir(
    String assetPath,
    String filename,
  ) async {
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
  Future<void> registerInteractionCallback({
    GlobalKey<NavigatorState>? navigatorKey,
  }) async {
    if (!isSupported) return;
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
    if (!isSupported) return;
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
      await HomeWidget.saveWidgetData(
        _keyVerseText,
        'Todo lo puedo en Cristo que me fortalece.',
      );
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
    if (!isSupported) return false;
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
    if (!isSupported) return false;
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
      debugPrint(
        '📱 [WIDGET] Requesting pin for: $kAndroidWidget2x2QualifiedName',
      );

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

  static const String _keyAtajos = 'atajos_widget_json';
  static const MethodChannel _canalAtajos = MethodChannel('victoria/atajos');

  /// Pasa los primeros atajos elegidos al widget «Atajos» y a los accesos
  /// del ícono de la app (Android). Sin atajos elegidos usa los
  /// predeterminados, para que el widget nunca quede vacío.
  Future<void> sincronizarAtajos(List<String> ids) async {
    if (!isSupported) return;
    final atajos = (ids.isEmpty ? AtajosService.predeterminados : ids)
        .map(AtajosService.porId)
        .whereType<Atajo>()
        .take(AtajosService.maximoTelefono)
        .map((a) => {'id': a.id, 'titulo': a.tituloCorto})
        .toList(growable: false);
    try {
      await HomeWidget.saveWidgetData(_keyAtajos, jsonEncode(atajos));
      await HomeWidget.updateWidget(
        androidName: kAndroidAtajosWidgetProvider,
        qualifiedAndroidName: kAndroidAtajosWidgetQualifiedName,
      );
      await _canalAtajos.invokeMethod<bool>('actualizar', atajos);
    } catch (e) {
      debugPrint('📱 [WIDGET] Atajos sync error: $e');
    }
  }

  /// Solicita al usuario que añada el widget de atajos (Android).
  /// Retorna false si el sistema no admite pedirlo desde la app.
  Future<bool> requestAtajosPin() async {
    if (!isSupported) return false;
    try {
      if (await HomeWidget.isRequestPinWidgetSupported() != true) return false;
      await HomeWidget.requestPinWidget(
        androidName: kAndroidAtajosWidgetProvider,
        qualifiedAndroidName: kAndroidAtajosWidgetQualifiedName,
      );
      return true;
    } catch (e) {
      debugPrint('📱 [WIDGET] Atajos pin request error: $e');
      return false;
    }
  }
}
