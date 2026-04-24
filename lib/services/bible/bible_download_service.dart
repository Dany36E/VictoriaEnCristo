import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
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

  /// Progreso 0.0–1.0 de la descarga actual (solo útil si la fuente reporta
  /// `Content-Length`; caso contrario se queda en `null`).
  final ValueNotifier<double?> progressNotifier = ValueNotifier(null);

  /// Caché en memoria de URLs remotas por versión, pobladas en init().
  /// Si la versión no tiene URL, se usa el asset bundle (comportamiento
  /// legacy). Esto permite ir migrando versiones a CDN sin romper la app.
  final Map<String, String> _remoteUrls = {};

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

    // Cargar URLs remotas opcionales desde Firestore /config/bibleDownloads.
    // Si falla (offline, sin permiso, etc.) caemos al asset bundle.
    await _loadRemoteUrls();

    // Auto-descargar RVR1960 si no está descargada
    final states = stateNotifier.value;
    if (states[BibleVersion.rvr1960] != DownloadState.downloaded) {
      await downloadVersion(BibleVersion.rvr1960);
    }

    _initialized = true;
    debugPrint('📥 [BIBLE-DL] BibleDownloadService initialized');
  }

  Future<void> _loadRemoteUrls() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('config')
          .doc('bibleDownloads')
          .get();
      final data = snap.data();
      if (data == null) return;
      final urls = data['urls'];
      if (urls is Map) {
        for (final e in urls.entries) {
          final k = e.key?.toString();
          final v = e.value?.toString();
          if (k != null && v != null && v.startsWith('http')) {
            _remoteUrls[k] = v;
          }
        }
      }
      debugPrint('📥 [BIBLE-DL] Remote URLs loaded: ${_remoteUrls.length}');
    } catch (e) {
      debugPrint('📥 [BIBLE-DL] No remote URLs (fallback to assets): $e');
    }
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

  /// Descargar versión: intenta HTTP (si hay URL remota configurada)
  /// y cae a leer del asset bundle como fallback. El archivo queda en
  /// el directorio local del app para lectura rápida posterior.
  Future<bool> downloadVersion(BibleVersion version) async {
    if (isDownloaded(version)) return true;

    try {
      downloadingNotifier.value = version;
      progressNotifier.value = null;
      _updateState(version, DownloadState.downloading);

      final file = File('$_bibleDirPath/${version.fileName}');
      final remoteUrl = _remoteUrls[version.id];
      var sourceLabel = 'asset';
      var byteLength = 0;

      if (remoteUrl != null) {
        // Descarga HTTP con progreso si el servidor expone Content-Length.
        final req = http.Request('GET', Uri.parse(remoteUrl));
        final resp = await http.Client().send(req).timeout(const Duration(seconds: 60));
        if (resp.statusCode != 200) {
          throw HttpException('HTTP ${resp.statusCode} al descargar ${version.id}');
        }
        final total = resp.contentLength ?? 0;
        final sink = file.openWrite();
        var received = 0;
        await resp.stream.listen((chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) progressNotifier.value = received / total;
        }).asFuture<void>();
        await sink.flush();
        await sink.close();
        byteLength = received;
        sourceLabel = 'remote';
      } else {
        // Fallback: leer desde assets bundled.
        final xmlString = await rootBundle.loadString(
          'assets/bible/${version.fileName}',
        );
        await file.writeAsString(xmlString);
        byteLength = xmlString.length;
      }

      // Validación mínima: archivo escrito y no vacío.
      if (!await file.exists() || await file.length() == 0) {
        throw const FileSystemException('Archivo bíblico vacío tras descarga');
      }

      _updateState(version, DownloadState.downloaded);
      await _saveState(version, true);

      downloadingNotifier.value = null;
      progressNotifier.value = null;
      debugPrint('📥 [BIBLE-DL] ${version.id} downloaded from $sourceLabel ($byteLength bytes)');
      return true;
    } catch (e) {
      _updateState(version, DownloadState.notDownloaded);
      downloadingNotifier.value = null;
      progressNotifier.value = null;
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
