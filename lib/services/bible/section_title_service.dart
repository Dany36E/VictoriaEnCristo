import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Servicio que provee subtítulos de perícopa (secciones) para la lectura
/// de la Biblia. Los títulos base residen en `assets/bible/section_titles.json`
/// y los ajustes por versión en `assets/bible/section_title_overrides.json`.
///
/// Formato base: `{ "<bookNumber>:<chapter>:<startVerse>": "Título" }`.
/// Formato de overrides: `{ "RVR1960": { "49:6:10": "..." } }`.
///
/// Uso típico desde el lector:
/// ```dart
/// final title = SectionTitleService.I.titleAt(version.id, book.number, chapter.number, verse.number);
/// if (title != null) {
///   // renderizar subtítulo antes del versículo
/// }
/// ```
class SectionTitleService {
  SectionTitleService._();
  static final SectionTitleService I = SectionTitleService._();

  static const String _baseAssetPath = 'assets/bible/section_titles.json';
  static const String _overridesAssetPath = 'assets/bible/section_title_overrides.json';

  Map<String, String>? _baseTitles;
  Map<String, Map<String, String>> _versionTitles = const {};
  Future<void>? _loading;

  /// Se incrementa cada vez que se (re)carga el JSON, para que los widgets
  /// puedan escuchar y rerenderizar.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Asegura que el JSON haya sido cargado en memoria. Llamadas concurrentes
  /// comparten el mismo Future.
  Future<void> ensureLoaded() {
    if (_baseTitles != null) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      _baseTitles = await _loadFlatMap(_baseAssetPath);
      _versionTitles = await _loadVersionMap(_overridesAssetPath);
    } catch (_) {
      // Si falta el asset o está corrupto, degradamos silenciosamente: el
      // lector seguirá funcionando sin subtítulos.
      _baseTitles = const {};
      _versionTitles = const {};
    } finally {
      _loading = null;
      revision.value++;
    }
  }

  Future<Map<String, String>> _loadFlatMap(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <String, String>{};
      decoded.forEach((key, value) {
        if (key is String && value is String && !key.startsWith('_')) {
          out[key] = value;
        }
      });
      return Map.unmodifiable(out);
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, Map<String, String>>> _loadVersionMap(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const {};
      final out = <String, Map<String, String>>{};
      decoded.forEach((versionId, value) {
        if (versionId is! String || versionId.startsWith('_') || value is! Map) {
          return;
        }
        final versionMap = <String, String>{};
        value.forEach((key, title) {
          if (key is String && title is String && !key.startsWith('_')) {
            versionMap[key] = title;
          }
        });
        out[versionId.toUpperCase()] = Map.unmodifiable(versionMap);
      });
      return Map.unmodifiable(out);
    } catch (_) {
      return const {};
    }
  }

  /// Devuelve el subtítulo a renderizar **antes** del versículo indicado,
  /// o `null` si no hay título para esa posición.
  String? titleAt(String versionId, int bookNumber, int chapter, int verse) {
    final base = _baseTitles;
    if (base == null) return null;
    final key = '$bookNumber:$chapter:$verse';
    final versionMap = _versionTitles[versionId.toUpperCase()];
    return versionMap?[key] ?? base[key];
  }

  /// Variante sincrónica que devuelve `null` si aún no se ha cargado el JSON.
  /// Útil para call-sites que prefieren no esperar y rerenderizar luego.
  String? titleAtSync(String versionId, int bookNumber, int chapter, int verse) =>
      titleAt(versionId, bookNumber, chapter, verse);
}
