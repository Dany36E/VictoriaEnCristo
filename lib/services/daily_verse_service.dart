/// ═══════════════════════════════════════════════════════════════════════════
/// DAILY VERSE SERVICE - Servicio de Versículo del Día
///
/// - Rotación determinística por fecha local sobre ≥366 referencias curadas
///   ([versiculosDiarios]); dos días seguidos nunca repiten tema. Widget,
///   notificación e Inicio muestran siempre el mismo versículo para la fecha.
/// - El TEXTO se carga de la versión de la Biblia activa del usuario mediante
///   `BibleParserService`. Mientras tanto (o sin conexión, en el primer
///   arranque o en pruebas) se usa el texto RVR1960 incluido en la lista.
/// - El texto de la versión activa se guarda en caché por fecha y versión
///   para que Inicio lo pinte al instante en el siguiente arranque.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/bible_verses.dart';
import '../data/versiculos_diarios.dart';
import '../models/bible/bible_version.dart';
import '../utils/time_utils.dart';
import 'bible/bible_download_service.dart';
import 'bible/bible_parser_service.dart';
import 'bible/bible_user_data_service.dart';

/// Carga el texto de [ref] en [version]. Devuelve `null` si no se pudo.
typedef CargadorTextoVersiculo =
    Future<String?> Function(VersiculoDiario ref, BibleVersion version);

class DailyVerseService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final DailyVerseService _instance = DailyVerseService._internal();
  factory DailyVerseService() => _instance;
  DailyVerseService._internal();

  static DailyVerseService get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Caché del texto en la versión activa: {fecha, version, texto}.
  static const String _keyCache = 'daily_verse_cache_v2';

  /// Claves de la versión anterior (índice sobre la lista vieja de 48).
  static const List<String> _legacyKeys = [
    'daily_verse_date',
    'daily_verse_index',
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Texto cargado de la versión activa para la fecha [_textoFecha].
  String? _textoFecha;
  String? _textoVersion;
  String? _texto;

  /// Inyectables para pruebas.
  CargadorTextoVersiculo? _cargador;
  BibleVersion Function()? _versionActiva;

  bool get isInitialized => _isInitialized;

  // ═══════════════════════════════════════════════════════════════════════════
  // SELECCIÓN DETERMINÍSTICA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Índice en [versiculosDiarios] para la fecha local [fecha].
  ///
  /// Cuenta días desde la época (sin horas ni zona horaria), así que dos
  /// fechas consecutivas dan índices consecutivos: como la lista intercala
  /// temas, nunca se repite tema dos días seguidos.
  static int indiceParaFecha(DateTime fecha) {
    final dias =
        DateTime.utc(fecha.year, fecha.month, fecha.day).millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    return dias % versiculosDiarios.length;
  }

  /// Referencia del versículo para [fecha].
  static VersiculoDiario referenciaParaFecha(DateTime fecha) =>
      versiculosDiarios[indiceParaFecha(fecha)];

  /// Versículo de [fecha] con el texto RVR1960 de respaldo.
  static BibleVerse versiculoRvrParaFecha(DateTime fecha) {
    final ref = referenciaParaFecha(fecha);
    return _aBibleVerse(ref, ref.textoRvr, BibleVersion.rvr1960);
  }

  static BibleVerse _aBibleVerse(
    VersiculoDiario ref,
    String texto,
    BibleVersion version,
  ) {
    final limpio = texto.trim();
    return BibleVerse(
      // Algunos versículos empiezan a mitad de frase («pero los que…»).
      verse: limpio.isEmpty
          ? limpio
          : limpio[0].toUpperCase() + limpio.substring(1),
      reference: ref.referencia,
      category: ref.tema.etiqueta,
      version: version.shortName,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      _prefs = await SharedPreferences.getInstance();
      for (final k in _legacyKeys) {
        if (_prefs!.containsKey(k)) await _prefs!.remove(k);
      }
      final raw = _prefs!.getString(_keyCache);
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is Map<String, dynamic>) {
          _textoFecha = data['fecha'] as String?;
          _textoVersion = data['version'] as String?;
          _texto = data['texto'] as String?;
        }
      }
    } catch (e) {
      debugPrint('📖 [DAILY_VERSE] init sin caché: $e');
    }
    _isInitialized = true;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // OBTENER VERSÍCULO DEL DÍA
  // ═══════════════════════════════════════════════════════════════════════════

  BibleVersion _version() {
    try {
      final v =
          (_versionActiva ??
              () => BibleUserDataService.I.preferredVersionNotifier.value)();
      return BibleDownloadService.I.isAvailable(v) ? v : BibleVersion.rvr1960;
    } catch (_) {
      return BibleVersion.rvr1960;
    }
  }

  /// Versión síncrona para uso inmediato: texto de la versión activa si ya
  /// está en caché para hoy, o el RVR1960 de respaldo.
  BibleVerse getForTodaySync() {
    final hoy = TimeUtils.now();
    final ref = referenciaParaFecha(hoy);
    final version = _version();
    final texto = _textoEnCache(TimeUtils.dateToISO(hoy), version);
    if (texto != null) return _aBibleVerse(ref, texto, version);
    return _aBibleVerse(ref, ref.textoRvr, BibleVersion.rvr1960);
  }

  /// Versículo del día con el texto de la versión activa del usuario.
  /// Si no se puede cargar, devuelve el RVR1960 de respaldo.
  Future<BibleVerse> getForToday() async {
    if (!_isInitialized) await init();
    final hoy = TimeUtils.now();
    final iso = TimeUtils.dateToISO(hoy);
    final ref = referenciaParaFecha(hoy);
    final version = _version();

    if (version == BibleVersion.rvr1960) {
      return _aBibleVerse(ref, ref.textoRvr, version);
    }
    final enCache = _textoEnCache(iso, version);
    if (enCache != null) return _aBibleVerse(ref, enCache, version);

    try {
      final texto = await (_cargador ?? _cargarDeLaBiblia)(
        ref,
        version,
      ).timeout(const Duration(seconds: 12));
      if (texto != null && texto.trim().isNotEmpty) {
        await _guardarCache(iso, version, texto);
        return _aBibleVerse(ref, texto, version);
      }
    } catch (e) {
      debugPrint('📖 [DAILY_VERSE] Texto ${version.id} no disponible: $e');
    }
    return _aBibleVerse(ref, ref.textoRvr, BibleVersion.rvr1960);
  }

  String? _textoEnCache(String iso, BibleVersion version) {
    if (version == BibleVersion.rvr1960) return null;
    if (_textoFecha == iso && _textoVersion == version.id) return _texto;
    return null;
  }

  Future<void> _guardarCache(
    String iso,
    BibleVersion version,
    String texto,
  ) async {
    _textoFecha = iso;
    _textoVersion = version.id;
    _texto = texto;
    try {
      await _prefs?.setString(
        _keyCache,
        jsonEncode({'fecha': iso, 'version': version.id, 'texto': texto}),
      );
    } catch (_) {
      // Sin persistencia: se recalcula en el próximo arranque.
    }
  }

  /// Carga el pasaje (uno o varios versículos) con el parser de la Biblia.
  static Future<String?> _cargarDeLaBiblia(
    VersiculoDiario ref,
    BibleVersion version,
  ) async {
    final capitulo = await BibleParserService.I.getChapter(
      version: version,
      bookNumber: ref.libro,
      chapter: ref.capitulo,
    );
    final partes = <String>[];
    for (var v = ref.versoInicio; v <= ref.versoFin; v++) {
      final verso = capitulo.where((e) => e.verse == v);
      if (verso.isEmpty) return null;
      partes.add(verso.first.text.trim());
    }
    return partes.join(' ');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Llamado al detectar cambio de día. El versículo se calcula por fecha,
  /// así que basta con olvidar el texto cacheado del día anterior.
  void refreshToday() {
    final hoy = TimeUtils.todayISO();
    if (_textoFecha != hoy) {
      _textoFecha = null;
      _textoVersion = null;
      _texto = null;
    }
    debugPrint(
      '📖 [DAILY_VERSE] refreshToday() → '
      '${referenciaParaFecha(TimeUtils.now()).referencia}',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRUEBAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sustituye el cargador de texto y la versión activa en pruebas.
  @visibleForTesting
  void configurarParaPruebas({
    CargadorTextoVersiculo? cargador,
    BibleVersion Function()? versionActiva,
  }) {
    _cargador = cargador;
    _versionActiva = versionActiva;
    _textoFecha = null;
    _textoVersion = null;
    _texto = null;
  }

  /// Solo para testing: olvida la caché.
  Future<void> debugForceNewDay() async {
    _textoFecha = null;
    _textoVersion = null;
    _texto = null;
    await _prefs?.remove(_keyCache);
  }

  /// Sincroniza el versículo del día con el widget de Android
  Future<void> updateHomeWidget() async {
    try {
      final verse = await getForToday();
      await HomeWidget.saveWidgetData('verse_widget_text', verse.verse);
      await HomeWidget.saveWidgetData('verse_widget_reference', verse.reference);
      await HomeWidget.updateWidget(androidName: 'VerseOfDayWidgetProvider');
      debugPrint('📱 [DAILY_VERSE] Widget actualizado: ${verse.reference}');
    } catch (e) {
      debugPrint('📱 [DAILY_VERSE] Error actualizando widget: $e');
    }
  }
}
