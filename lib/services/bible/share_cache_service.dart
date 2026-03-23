import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/bible_version.dart';
import '../../models/bible/share_template.dart';
import '../../widgets/bible/share_card_renderer.dart';
import 'bible_parser_service.dart';

/// Pre-caché de imágenes compartibles para los versículos más populares.
/// Renderiza offline las tarjetas al primer arranque y las almacena en disco.
class ShareCacheService {
  // ── Singleton ──
  static final ShareCacheService _instance = ShareCacheService._internal();
  factory ShareCacheService() => _instance;
  static ShareCacheService get I => _instance;
  ShareCacheService._internal();

  static const String _prefKey = 'share_cache_v1_done';
  static const String _cacheDir = 'share_cache';

  bool _running = false;
  int _cached = 0;
  int _total = 0;

  /// Progreso actual (0.0 - 1.0) para UI opcional.
  double get progress => _total > 0 ? _cached / _total : 0.0;
  bool get isRunning => _running;

  /// Intenta obtener una tarjeta pre-cacheada del disco.
  /// Retorna null si no existe en caché.
  Future<File?> getCachedCard({
    required String verseKey,
    required String templateId,
    Size cardSize = const Size(1080, 1080),
  }) async {
    try {
      final dir = await _getCacheDirectory();
      final fileName = _buildFileName(verseKey, templateId, cardSize);
      final file = File('${dir.path}/$fileName');
      if (await file.exists()) return file;
    } catch (_) {}
    return null;
  }

  /// Inicia la pre-caché en background (llamar después del login).
  /// No bloquea la UI — usa isolate-safe rendering con SchedulerBinding.
  Future<void> warmUp() async {
    if (_running) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_prefKey) == true) {
      debugPrint('🖼️ [SHARE-CACHE] Already cached, skipping');
      return;
    }

    _running = true;
    debugPrint('🖼️ [SHARE-CACHE] Starting warm-up...');

    try {
      // 1. Cargar lista de versículos populares
      final refs = await _loadPopularRefs();
      if (refs.isEmpty) {
        debugPrint('🖼️ [SHARE-CACHE] No popular verses found');
        return;
      }

      // Usamos solo la primera plantilla para el pre-caché (la más popular)
      final template = kShareTemplates.first;
      _total = refs.length;
      _cached = 0;

      final dir = await _getCacheDirectory();

      for (final ref in refs) {
        try {
          final verse = await _resolveVerse(ref);
          if (verse == null) continue;

          final fileName = _buildFileName(
            verse.uniqueKey,
            template.id,
            const Size(1080, 1080),
          );
          final file = File('${dir.path}/$fileName');
          if (await file.exists()) {
            _cached++;
            continue;
          }

          // Renderizar off-screen
          final bytes = await _renderCard(
            template: template,
            verse: verse,
            cardSize: const Size(1080, 1080),
          );

          if (bytes != null) {
            await file.writeAsBytes(bytes);
          }

          _cached++;

          // Yield al event loop cada 5 versículos para no bloquear UI
          if (_cached % 5 == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 16));
          }
        } catch (e) {
          debugPrint('🖼️ [SHARE-CACHE] Error caching $ref: $e');
          _cached++;
        }
      }

      await prefs.setBool(_prefKey, true);
      debugPrint('🖼️ [SHARE-CACHE] ✅ Warm-up complete: $_cached/$_total');
    } catch (e) {
      debugPrint('🖼️ [SHARE-CACHE] ❌ Error: $e');
    } finally {
      _running = false;
    }
  }

  /// Renderiza una tarjeta off-screen y retorna los bytes PNG.
  Future<List<int>?> _renderCard({
    required ShareCardTemplate template,
    required BibleVerse verse,
    required Size cardSize,
  }) async {
    try {
      final widget = ShareCardRenderer(
        template: template,
        verseText: verse.text,
        reference: verse.reference,
        version: verse.version,
        cardSize: cardSize,
      );

      // Crear un pipeline de render off-screen
      final renderObject = RenderRepaintBoundary();
      final renderView = _OffScreenRenderView(
        child: renderObject,
        size: cardSize,
      );

      final pipelineOwner = PipelineOwner();
      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final buildOwner = BuildOwner(focusManager: FocusManager());
      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: renderObject,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: widget,
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      final image = await renderObject.toImage(pixelRatio: 1.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      buildOwner.finalizeTree();

      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('🖼️ [SHARE-CACHE] Render error: $e');
      return null;
    }
  }

  Future<List<String>> _loadPopularRefs() async {
    try {
      final jsonStr = await rootBundle.loadString(
        'assets/bible/share/popular_verses.json',
      );
      final data = json.decode(jsonStr) as Map<String, dynamic>;
      final verses = data['verses'] as List<dynamic>;
      return verses.cast<String>();
    } catch (e) {
      debugPrint('🖼️ [SHARE-CACHE] Error loading popular verses: $e');
      return [];
    }
  }

  Future<BibleVerse?> _resolveVerse(String ref) async {
    // ref format: "bookNumber:chapter:verse"
    final parts = ref.split(':');
    if (parts.length != 3) return null;
    final book = int.tryParse(parts[0]);
    final chapter = int.tryParse(parts[1]);
    final verse = int.tryParse(parts[2]);
    if (book == null || chapter == null || verse == null) return null;

    return BibleParserService.I.getVerse(
      version: BibleVersion.rvr1960,
      bookNumber: book,
      chapter: chapter,
      verse: verse,
    );
  }

  String _buildFileName(String verseKey, String templateId, Size size) {
    // verseKey: "1:1:1", templateId: "cosmos"
    final sizeKey = '${size.width.toInt()}x${size.height.toInt()}';
    return '${verseKey.replaceAll(':', '_')}_${templateId}_$sizeKey.png';
  }

  Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/$_cacheDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}

/// RenderView simplificado para rendering off-screen.
class _OffScreenRenderView extends RenderView {
  _OffScreenRenderView({
    required RenderBox child,
    required Size size,
  }) : super(
          view: ui.PlatformDispatcher.instance.implicitView!,
        ) {
    this.child = child;
    configuration = ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      devicePixelRatio: 1.0,
    );
  }
}
