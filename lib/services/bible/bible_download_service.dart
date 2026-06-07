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
/// RVR1960 se extrae desde assets al directorio local del app. Las demás
/// versiones se descargan desde URLs remotas configuradas en Firestore.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleDownloadService {
  // ── Singleton ──
  static final BibleDownloadService _instance =
      BibleDownloadService._internal();
  factory BibleDownloadService() => _instance;
  static BibleDownloadService get I => _instance;
  BibleDownloadService._internal();

  // ── Estado ──
  bool _initialized = false;
  Future<void>? _initFuture;
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
  /// Si una versión no base no tiene URL, se marca como no disponible para no
  /// obligar a empaquetar todos los XML en el bundle inicial.
  final Map<String, String> _remoteUrls = {};
  static const Set<String> _bundledFileNames = {
    'Reina Valera 1960.xml',
    'NVI.xml',
    'LBLA.xml',
    'NTV.xml',
    'TLA.xml',
  };

  static const _prefsKeyPrefix = 'bible_downloaded_';

  // ══════════════════════════════════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initInternal();
    await _initFuture;
  }

  Future<void> _initInternal() async {
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

  Future<void> ensureInitialized() => init();

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

  /// RVR1960 queda incluida en el bundle como versión base offline.
  bool isBundled(BibleVersion version) =>
      _bundledFileNames.contains(version.fileName);

  /// ¿Hay una URL remota configurada para descargar esta versión?
  bool hasRemoteSource(BibleVersion version) =>
      _remoteUrls.containsKey(version.id);

  /// ¿Existe una fuente válida para guardar esta versión localmente?
  bool canDownload(BibleVersion version) =>
      isBundled(version) || hasRemoteSource(version);

  /// ¿Puede usarse ya esta versión? RVR1960 puede leerse desde assets aunque
  /// todavía no se haya copiado al directorio local.
  bool isAvailable(BibleVersion version) =>
      isBundled(version) || isDownloaded(version);

  /// Versiones utilizables en este momento.
  List<BibleVersion> get availableVersions =>
      BibleVersion.values.where(isAvailable).toList(growable: false);

  /// Fallback seguro para una versión preferida que todavía no está descargada.
  BibleVersion bestAvailableVersion(BibleVersion preferred) {
    return isAvailable(preferred) ? preferred : BibleVersion.rvr1960;
  }

  /// Escoge una segunda versión disponible para comparar/estudiar.
  BibleVersion bestAvailableSecondary(BibleVersion primary) {
    const preference = [
      BibleVersion.nvi,
      BibleVersion.lbla,
      BibleVersion.ntv,
      BibleVersion.tla,
      BibleVersion.rvr1960,
    ];
    for (final version in preference) {
      if (version != primary && isAvailable(version)) return version;
    }
    return primary;
  }

  /// Ruta local del archivo XML descargado (null si no descargado)
  String? getLocalPath(BibleVersion version) {
    if (!isDownloaded(version)) return null;
    return '$_bibleDirPath/${version.fileName}';
  }

  /// Tamaño del archivo descargado en bytes (0 si no existe)
  Future<int> getDownloadedSize(BibleVersion version) async {
    await ensureInitialized();
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
    await ensureInitialized();
    int total = 0;
    for (final version in BibleVersion.values) {
      total += await getDownloadedSize(version);
    }
    return total;
  }

  /// Descargar versión: intenta HTTP (si hay URL remota configurada)
  /// y sólo cae a leer del asset bundle para RVR1960. El archivo queda en el
  /// directorio local del app para lectura rápida posterior.
  Future<bool> downloadVersion(BibleVersion version) async {
    await ensureInitialized();
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
        final resp = await http.Client()
            .send(req)
            .timeout(const Duration(seconds: 60));
        if (resp.statusCode != 200) {
          throw HttpException(
            'HTTP ${resp.statusCode} al descargar ${version.id}',
          );
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
        if (!isBundled(version)) {
          debugPrint(
            '📥 [BIBLE-DL] ${version.id} has no remote URL and is not bundled',
          );
          _updateState(version, DownloadState.notDownloaded);
          downloadingNotifier.value = null;
          progressNotifier.value = null;
          return false;
        }
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
      debugPrint(
        '📥 [BIBLE-DL] ${version.id} downloaded from $sourceLabel ($byteLength bytes)',
      );
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
    await ensureInitialized();
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
    await ensureInitialized();
    for (final version in BibleVersion.values) {
      if (!isDownloaded(version) && canDownload(version)) {
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
      final isDownloaded =
          prefs.getBool('$_prefsKeyPrefix${version.id}') ?? false;

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
enum DownloadState { notDownloaded, downloading, downloaded }
