import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/bible_version.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE DOWNLOAD SERVICE - Singleton
/// ═══════════════════════════════════════════════════════════════════════════
///
/// Gestiona la descarga/preloading de versiones bíblicas al almacenamiento
/// local del dispositivo. Esto permite:
/// - Lectura más rápida (lee directo del filesystem, no del asset bundle)
/// - Base para futuras descargas remotas
/// - UX de gestión de espacio por versión
///
/// Las versiones se extraen de assets/bible/*.xml al directorio local
/// del app. RVR1960 se descarga automáticamente en el primer arranque.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleDownloadService {
  // ── Singleton ──
  static final BibleDownloadService _instance = BibleDownloadService._internal();
  factory BibleDownloadService() => _instance;
  static BibleDownloadService get I => _instance;
  BibleDownloadService._internal();

  // ── Estado ──
  bool _initialized = false;
  late String _bibleDirPath;

  /// Estado de descarga de cada versión (reactivo)
  final ValueNotifier<Map<BibleVersion, DownloadState>> stateNotifier =
      ValueNotifier({});

  /// Versión actualmente descargándose (para progress UI)
  final ValueNotifier<BibleVersion?> downloadingNotifier = ValueNotifier(null);

  static const _prefsKeyPrefix = 'bible_downloaded_';

  // ══════════════════════════════════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_initialized) return;

    final dir = await getApplicationDocumentsDirectory();
    _bibleDirPath = '${dir.path}/bible_offline';

    // Crear directorio si no existe
    final bibleDir = Directory(_bibleDirPath);
    if (!await bibleDir.exists()) {
      await bibleDir.create(recursive: true);
    }

    // Cargar estado de descargas desde SharedPreferences
    await _loadStates();

    // Auto-descargar RVR1960 si no está descargada
    final states = stateNotifier.value;
    if (states[BibleVersion.rvr1960] != DownloadState.downloaded) {
      await downloadVersion(BibleVersion.rvr1960);
    }

    _initialized = true;
    debugPrint('📥 [BIBLE-DL] BibleDownloadService initialized');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA
  // ══════════════════════════════════════════════════════════════════════════

  /// ¿Está descargada esta versión?
  bool isDownloaded(BibleVersion version) {
    return stateNotifier.value[version] == DownloadState.downloaded;
  }

  /// Ruta local del archivo XML descargado (null si no descargado)
  String? getLocalPath(BibleVersion version) {
    if (!isDownloaded(version)) return null;
    return '$_bibleDirPath/${version.fileName}';
  }

  /// Tamaño del archivo descargado en bytes (0 si no existe)
  Future<int> getDownloadedSize(BibleVersion version) async {
    final path = getLocalPath(version);
    if (path == null) return 0;
    final file = File(path);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Tamaño total de todas las descargas
  Future<int> getTotalDownloadedSize() async {
    int total = 0;
    for (final version in BibleVersion.values) {
      total += await getDownloadedSize(version);
    }
    return total;
  }

  /// Descargar (extraer de assets a almacenamiento local)
  Future<bool> downloadVersion(BibleVersion version) async {
    if (isDownloaded(version)) return true;

    try {
      downloadingNotifier.value = version;
      _updateState(version, DownloadState.downloading);

      // Leer XML del asset bundle
      final xmlString = await rootBundle.loadString(
        'assets/bible/${version.fileName}',
      );

      // Escribir al almacenamiento local
      final file = File('$_bibleDirPath/${version.fileName}');
      await file.writeAsString(xmlString);

      // Marcar como descargada
      _updateState(version, DownloadState.downloaded);
      await _saveState(version, true);

      downloadingNotifier.value = null;
      debugPrint('📥 [BIBLE-DL] ${version.id} downloaded (${xmlString.length} chars)');
      return true;
    } catch (e) {
      _updateState(version, DownloadState.notDownloaded);
      downloadingNotifier.value = null;
      debugPrint('📥 [BIBLE-DL] Error downloading ${version.id}: $e');
      return false;
    }
  }

  /// Eliminar versión descargada (liberar espacio)
  /// No permite eliminar RVR1960 (versión base)
  Future<bool> deleteVersion(BibleVersion version) async {
    if (version == BibleVersion.rvr1960) return false; // Proteger versión base

    try {
      final file = File('$_bibleDirPath/${version.fileName}');
      if (await file.exists()) {
        await file.delete();
      }

      _updateState(version, DownloadState.notDownloaded);
      await _saveState(version, false);

      debugPrint('📥 [BIBLE-DL] ${version.id} deleted');
      return true;
    } catch (e) {
      debugPrint('📥 [BIBLE-DL] Error deleting ${version.id}: $e');
      return false;
    }
  }

  /// Descargar todas las versiones que faltan
  Future<void> downloadAll() async {
    for (final version in BibleVersion.values) {
      if (!isDownloaded(version)) {
        await downloadVersion(version);
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // INTERNOS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadStates() async {
    final prefs = await SharedPreferences.getInstance();
    final map = <BibleVersion, DownloadState>{};

    for (final version in BibleVersion.values) {
      final isDownloaded = prefs.getBool('$_prefsKeyPrefix${version.id}') ?? false;

      // Verificar que el archivo realmente exista
      if (isDownloaded) {
        final file = File('$_bibleDirPath/${version.fileName}');
        if (await file.exists()) {
          map[version] = DownloadState.downloaded;
        } else {
          // SharedPrefs dice sí pero archivo no existe → limpiar
          map[version] = DownloadState.notDownloaded;
          await prefs.remove('$_prefsKeyPrefix${version.id}');
        }
      } else {
        map[version] = DownloadState.notDownloaded;
      }
    }

    stateNotifier.value = Map.unmodifiable(map);
  }

  void _updateState(BibleVersion version, DownloadState state) {
    final map = Map<BibleVersion, DownloadState>.from(stateNotifier.value);
    map[version] = state;
    stateNotifier.value = Map.unmodifiable(map);
  }

  Future<void> _saveState(BibleVersion version, bool downloaded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefsKeyPrefix${version.id}', downloaded);
  }
}

/// Estado de descarga de una versión bíblica
enum DownloadState {
  notDownloaded,
  downloading,
  downloaded,
}
