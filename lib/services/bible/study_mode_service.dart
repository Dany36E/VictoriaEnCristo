import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/study_chapter_answers.dart';
import '../../models/bible/study_word_highlight.dart';
import 'bible_user_data_service.dart';
import 'chapter_note_service.dart';
import 'notas_sync.dart';
import 'study_room_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// STUDY MODE SERVICE — Singleton
///
/// Persiste el estado del Modo Estudio del usuario:
///   - Respuestas a las 6 preguntas por capítulo
///       /users/{uid}/studyAnswers/{bookNumber}_{chapter}
///   - Subrayados granulares (palabra/frase) por capítulo
///       /users/{uid}/studyHighlights/{docId}
///
/// Sincroniza con el ecosistema:
///   - Cada subrayado de palabra refleja un Highlight a nivel versículo en
///     `BibleUserDataService` para que aparezca en la lectura normal.
///   - Las respuestas se exportan como `ChapterStudyNote` (taggeada
///     `modo-estudio`) en `ChapterNoteService`, para que aparezcan en la
///     sección Notas / Estudio capítulos.
/// ═══════════════════════════════════════════════════════════════════════════
class StudyModeService {
  StudyModeService._internal();
  static final StudyModeService _instance = StudyModeService._internal();
  factory StudyModeService() => _instance;
  static StudyModeService get I => _instance;

  String? _uid;
  SharedPreferences? _prefs;
  StreamSubscription? _answersSub;
  StreamSubscription? _highlightsSub;

  static const _answersCachePrefix = 'study_answers_cache_v1';
  static const _highlightsCachePrefix = 'study_highlights_cache_v1';
  static const _onboardingKey = 'study_mode_onboarding_seen_v1';

  /// chapterKey ('book:chapter' o studyId) → respuestas.
  /// A partir de la migración de "estudios independientes" la clave principal
  /// es el `studyId` propio de cada estudio. Los documentos legacy (sin
  /// studyId) siguen usando la clave `'$bookNumber:$chapter'`.
  final ValueNotifier<Map<String, StudyChapterAnswers>> answersNotifier = ValueNotifier(const {});

  /// Lista plana de subrayados granulares
  final ValueNotifier<List<StudyWordHighlight>> highlightsNotifier = ValueNotifier(const []);
  final ValueNotifier<bool> canUndoHighlightsNotifier = ValueNotifier(false);
  final ValueNotifier<bool> canRedoHighlightsNotifier = ValueNotifier(false);

  final List<List<StudyWordHighlight>> _undoHighlightStack = [];
  final List<List<StudyWordHighlight>> _redoHighlightStack = [];

  // ──────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('📖 [STUDY-MODE] init for $uid');

    await NotasSync.I.cargar();
    await _loadAnswersCache(uid);
    await _loadHighlightsCache(uid);
    _reenviarPendientes(uid);

    _listenAnswers();
    _listenHighlights();

    // Migración única: limpia highlights a nivel-versículo creados por la
    // versión antigua del mirror (que pintaba el versículo completo).
    unawaited(_purgeLegacyMirroredHighlights());
  }

  void stop() {
    _answersSub?.cancel();
    _highlightsSub?.cancel();
    _answersSub = null;
    _highlightsSub = null;
    answersNotifier.value = const {};
    highlightsNotifier.value = const [];
    _undoHighlightStack.clear();
    _redoHighlightStack.clear();
    _updateHighlightHistoryState();
    _uid = null;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Refs
  // ──────────────────────────────────────────────────────────────────────

  // Firestore se pide solo al usarlo: las pruebas no lo necesitan.
  CollectionReference<Map<String, dynamic>> get _answersCol => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid!)
      .collection('studyAnswers');

  CollectionReference<Map<String, dynamic>> get _highlightsCol =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(_uid!)
          .collection('studyHighlights');

  String _prefijoRespuestas(String uid) => 'users/$uid/studyAnswers/';
  String _prefijoSubrayados(String uid) => 'users/$uid/studyHighlights/';

  /// Id del documento de un estudio a partir de su clave en el mapa
  /// (`studyId`, o `libro:capítulo` para los estudios antiguos).
  static String docIdDeClave(String clave) =>
      clave.contains(':') ? clave.replaceFirst(':', '_') : clave;

  // Escrituras sin esperar al servidor (ver NotasSync): sin conexión la
  // pantalla ya no se queda bloqueada al cambiar de capítulo.
  void _guardarRespuestas(StudyChapterAnswers a) {
    final uid = _uid;
    if (uid == null) return;
    unawaited(
      NotasSync.I.guardar('${_prefijoRespuestas(uid)}${a.docId}', a.toMap()),
    );
  }

  void _borrarRespuestas(String docId) {
    final uid = _uid;
    if (uid == null) return;
    unawaited(NotasSync.I.borrar('${_prefijoRespuestas(uid)}$docId'));
  }

  void _guardarSubrayado(StudyWordHighlight h) {
    final uid = _uid;
    if (uid == null) return;
    unawaited(
      NotasSync.I.guardar(
        '${_prefijoSubrayados(uid)}${h.id}',
        h.toMap(),
        fusionar: false,
      ),
    );
  }

  void _borrarSubrayado(String id) {
    final uid = _uid;
    if (uid == null) return;
    unawaited(NotasSync.I.borrar('${_prefijoSubrayados(uid)}$id'));
  }

  String _nuevoIdSubrayado() {
    try {
      return _highlightsCol.doc().id;
    } catch (_) {
      return 'sh_${DateTime.now().microsecondsSinceEpoch}';
    }
  }

  /// Vuelve a lanzar lo que quedó sin confirmar en una sesión anterior.
  void _reenviarPendientes(String uid) {
    final pr = _prefijoRespuestas(uid);
    final porDocId = {
      for (final a in answersNotifier.value.values) a.docId: a,
    };
    for (final id in NotasSync.I.idsPendientes(pr, borrados: false)) {
      final a = porDocId[id];
      if (a != null) unawaited(NotasSync.I.guardar('$pr$id', a.toMap()));
    }
    for (final id in NotasSync.I.idsPendientes(pr, borrados: true)) {
      unawaited(NotasSync.I.borrar('$pr$id'));
    }
    final ps = _prefijoSubrayados(uid);
    final subrayados = {for (final h in highlightsNotifier.value) h.id: h};
    for (final id in NotasSync.I.idsPendientes(ps, borrados: false)) {
      final h = subrayados[id];
      if (h != null) {
        unawaited(NotasSync.I.guardar('$ps$id', h.toMap(), fusionar: false));
      }
    }
    for (final id in NotasSync.I.idsPendientes(ps, borrados: true)) {
      unawaited(NotasSync.I.borrar('$ps$id'));
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Listeners
  // ──────────────────────────────────────────────────────────────────────

  // Sin límite: con `.limit(500)` los estudios y subrayados más viejos
  // desaparecían de la vista (y de la cache local) al pasar de 500.
  void _listenAnswers() {
    final uid = _uid;
    if (uid == null) return;
    try {
      _answersSub = _answersCol
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
            if (_uid != uid) return;
            final remoto = <String, StudyChapterAnswers>{};
            for (final d in snap.docs) {
              try {
                final a = StudyChapterAnswers.fromMap(d.data());
                remoto[a.chapterKey] = a;
              } catch (e) {
                debugPrint('[STUDY-MODE] answers parse error: $e');
              }
            }
            aplicarSnapshotRespuestas(
              remoto,
              desdeCache: snap.metadata.isFromCache,
            );
          }, onError: (e) => debugPrint('[STUDY-MODE] answers stream error: $e'));
    } catch (e) {
      debugPrint('[STUDY-MODE] No se pudo escuchar estudios: $e');
    }
  }

  void _listenHighlights() {
    final uid = _uid;
    if (uid == null) return;
    try {
      _highlightsSub = _highlightsCol
          .snapshots(includeMetadataChanges: true)
          .listen((snap) {
            if (_uid != uid) return;
            final remoto = <String, StudyWordHighlight>{};
            for (final d in snap.docs) {
              try {
                remoto[d.id] = StudyWordHighlight.fromMap(d.id, d.data());
              } catch (e) {
                debugPrint('[STUDY-MODE] highlight parse error: $e');
              }
            }
            aplicarSnapshotSubrayados(
              remoto,
              desdeCache: snap.metadata.isFromCache,
            );
          }, onError: (e) => debugPrint('[STUDY-MODE] highlights stream error: $e'));
    } catch (e) {
      debugPrint('[STUDY-MODE] No se pudo escuchar subrayados: $e');
    }
  }

  /// Une un snapshot COMPLETO de estudios con lo que hay en el teléfono.
  @visibleForTesting
  void aplicarSnapshotRespuestas(
    Map<String, StudyChapterAnswers> remoto, {
    required bool desdeCache,
  }) {
    final uid = _uid;
    if (uid == null) return;
    final prefijo = _prefijoRespuestas(uid);
    final unidos = fusionarConServidor<StudyChapterAnswers>(
      local: answersNotifier.value,
      remoto: remoto,
      desdeCache: desdeCache,
      guardadoPendiente: (k) =>
          NotasSync.I.guardadoPendiente('$prefijo${docIdDeClave(k)}'),
      borradoPendiente: (k) =>
          NotasSync.I.borradoPendiente('$prefijo${docIdDeClave(k)}'),
    );
    answersNotifier.value = Map.unmodifiable(unidos);
    unawaited(_saveAnswersCache(unidos));
  }

  /// Une un snapshot COMPLETO de subrayados con lo que hay en el teléfono.
  @visibleForTesting
  void aplicarSnapshotSubrayados(
    Map<String, StudyWordHighlight> remoto, {
    required bool desdeCache,
  }) {
    final uid = _uid;
    if (uid == null) return;
    final prefijo = _prefijoSubrayados(uid);
    final unidos = fusionarConServidor<StudyWordHighlight>(
      local: {for (final h in highlightsNotifier.value) h.id: h},
      remoto: remoto,
      desdeCache: desdeCache,
      guardadoPendiente: (id) => NotasSync.I.guardadoPendiente('$prefijo$id'),
      borradoPendiente: (id) => NotasSync.I.borradoPendiente('$prefijo$id'),
    );
    final lista = unidos.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    highlightsNotifier.value = List.unmodifiable(lista);
    unawaited(_saveHighlightsCache(lista));
  }

  /// Prepara el servicio para pruebas: sin escuchar Firestore.
  @visibleForTesting
  Future<void> initSinNube(String uid) async {
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    await NotasSync.I.cargar();
    await _loadAnswersCache(uid);
    await _loadHighlightsCache(uid);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Answers API
  // ──────────────────────────────────────────────────────────────────────

  /// Devuelve el estudio más reciente (por `updatedAt`) que coincida con
  /// el libro y capítulo indicados. Si no hay ninguno, retorna null.
  /// Mantenido por compatibilidad con llamadores antiguos; los nuevos
  /// caminos deberían resolver por `studyId` vía `answersForStudyId`.
  StudyChapterAnswers? answersFor(int bookNumber, int chapter) {
    StudyChapterAnswers? best;
    for (final a in answersNotifier.value.values) {
      if (a.bookNumber != bookNumber || a.chapter != chapter) continue;
      if (best == null || a.updatedAt.isAfter(best.updatedAt)) {
        best = a;
      }
    }
    return best;
  }

  /// Devuelve el estudio con el `studyId` indicado (o null).
  StudyChapterAnswers? answersForStudyId(String? studyId) {
    if (studyId == null) return null;
    return answersNotifier.value[studyId];
  }

  /// Lista todos los estudios guardados para un libro/capítulo, ordenados por
  /// fecha de actualización descendente. Útil para el selector de estudios
  /// guardados y para segmentar notas espejo en la lectura normal.
  List<StudyChapterAnswers> studiesForChapter(int bookNumber, int chapter) {
    final list = answersNotifier.value.values
        .where((a) => a.bookNumber == bookNumber && a.chapter == chapter)
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Estudios cuyo rango cubre un versículo concreto (para segmentar notas).
  List<StudyChapterAnswers> studiesCoveringVerse(int bookNumber, int chapter, int verse) {
    final list = answersNotifier.value.values
        .where((a) => a.coversVerse(bookNumber, chapter, verse))
        .toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Elimina un estudio guardado y sus notas espejo. Por defecto conserva los
  /// subrayados palabra-por-palabra para evitar pérdida accidental de tinta.
  Future<void> deleteStudy(StudyChapterAnswers study, {bool deleteHighlights = false}) async {
    if (_uid == null) return;

    final key = study.chapterKey;
    final previous = answersNotifier.value[key] ?? study;
    final next = Map<String, StudyChapterAnswers>.from(answersNotifier.value)..remove(key);
    answersNotifier.value = Map.unmodifiable(next);
    await _saveAnswersCache(next);

    _borrarRespuestas(study.docId);

    // Las copias en notas se limpian en segundo plano: no deben bloquear la
    // pantalla sin conexión.
    unawaited(_clearMirroredVerseNotes(previous));
    unawaited(_clearMirroredChapterNote(previous));

    if (deleteHighlights) {
      await clearChapterHighlights(bookNumber: study.bookNumber, chapter: study.chapter);
    }
  }

  /// Guarda (debounced en UI) las respuestas del capítulo.
  /// Si todas están vacías, elimina el documento.
  Future<void> saveAnswers(StudyChapterAnswers answers) async {
    if (_uid == null) return;

    final cleaned = <String, String>{};
    answers.answers.forEach((k, v) {
      final t = v.trim();
      if (t.isNotEmpty) cleaned[k] = t;
    });
    final generalNotes = answers.generalNotes.trim();
    final hopeMessage = answers.hopeMessage.trim();
    final mainVerses = answers.sortedMainVerses;

    final key = answers.chapterKey;
    final next = Map<String, StudyChapterAnswers>.from(answersNotifier.value);
    final previous = next[key];

    final hasRange = answers.rangedPassages.isNotEmpty;

    if (cleaned.isEmpty &&
        generalNotes.isEmpty &&
        hopeMessage.isEmpty &&
        mainVerses.isEmpty &&
        !hasRange) {
      next.remove(key);
      answersNotifier.value = Map.unmodifiable(next);
      await _saveAnswersCache(next);
      _borrarRespuestas(answers.docId);
      // Limpia notas espejo si las había
      unawaited(_clearMirroredVerseNotes(previous));
      return;
    }

    final updated = answers.copyWith(
      answers: cleaned,
      generalNotes: generalNotes,
      hopeMessage: hopeMessage,
      mainVerses: mainVerses,
      updatedAt: DateTime.now(),
    );
    next[key] = updated;
    answersNotifier.value = Map.unmodifiable(next);
    await _saveAnswersCache(next);

    _guardarRespuestas(updated);

    // Espejo seguro a Notas a nivel CAPÍTULO (sólo si no hay nota manual).
    if (updated.hasContent) {
      unawaited(_mirrorToChapterNote(updated));
    }

    // Espejo a notas POR VERSÍCULO en el rango estudiado.
    unawaited(_mirrorToVerseNotes(previous: previous, current: updated));
  }

  /// Actualiza únicamente el rango estudiado, sin tocar las respuestas.
  /// Si se proporciona `studyId`, se opera sobre ese estudio concreto;
  /// de lo contrario se crea uno nuevo (mantén la semántica de "nuevo
  /// estudio" del modo Setup).
  Future<void> setStudyRange({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String versionId,
    required int? startVerse,
    required int? endVerse,
    String? studyId,
  }) async {
    if (_uid == null) return;
    final base = studyId != null && answersNotifier.value[studyId] != null
        ? answersNotifier.value[studyId]!
        : StudyChapterAnswers.empty(
            studyId: studyId,
            bookNumber: bookNumber,
            bookName: bookName,
            chapter: chapter,
            versionId: versionId,
          );
    final key = base.chapterKey;
    final clear = startVerse == null || endVerse == null;
    final updated = base.copyWith(
      versionId: versionId,
      studyStartVerse: clear ? null : startVerse,
      studyEndVerse: clear ? null : endVerse,
      clearRange: clear,
    );

    final next = Map<String, StudyChapterAnswers>.from(answersNotifier.value);
    next[key] = updated;
    answersNotifier.value = Map.unmodifiable(next);
    await _saveAnswersCache(next);

    // Si nunca había documento (todo vacío y sin rango antes), no escribimos.
    if (updated.hasContent || updated.rangedPassages.isNotEmpty || !clear) {
      _guardarRespuestas(updated);
    }

    unawaited(_mirrorToVerseNotes(previous: base, current: updated));
  }

  Future<void> _mirrorToChapterNote(StudyChapterAnswers a) async {
    try {
      // Un capítulo puede tener varias notas: se actualiza la copia del Modo
      // Estudio si ya existe; si no, solo se crea cuando no hay nota manual.
      final delCapitulo = ChapterNoteService.I.notesForChapter(a.bookNumber, a.chapter);
      final existing = delCapitulo
          .where((n) => n.tags.contains('modo-estudio'))
          .firstOrNull;
      final hayManual = delCapitulo.any((n) => !n.tags.contains('modo-estudio'));
      if (existing == null && hayManual) return; // respetamos nota manual

      // Agregamos TODOS los estudios del capítulo, ordenados por fecha de
      // creación, para que la nota a nivel capítulo refleje cada estudio
      // independiente en una sección propia.
      final all = studiesForChapter(a.bookNumber, a.chapter).where((s) => s.hasContent).toList()
        ..sort((x, y) => x.createdAt.compareTo(y.createdAt));

      if (all.isEmpty) {
        if (existing != null) {
          await ChapterNoteService.I.deleteNote(existing.id);
        }
        return;
      }

      final buf = StringBuffer();
      for (var i = 0; i < all.length; i++) {
        final s = all[i];
        buf.writeln('## ${i + 1}. ${s.reference}');
        buf.writeln();
        buf.writeln(s.toMarkdown());
        if (i < all.length - 1) {
          buf.writeln();
          buf.writeln('---');
          buf.writeln();
        }
      }

      final title = all.length == 1
          ? 'Modo Estudio · ${all.first.reference}'
          : 'Modo Estudio · ${a.bookName} ${a.chapter}';

      await ChapterNoteService.I.saveNote(
        existingId: existing?.id,
        versionId: a.versionId,
        bookNumber: a.bookNumber,
        bookName: a.bookName,
        chapter: a.chapter,
        title: title,
        content: buf.toString().trimRight(),
        tags: const ['modo-estudio'],
        colorHex: 'D4A853',
      );
    } catch (e) {
      debugPrint('[STUDY-MODE] mirror chapter note error: $e');
    }
  }

  /// Marcador para reconocer notas creadas por Modo Estudio en el cuerpo.
  /// `BibleNote` no tiene tags, así que usamos un prefijo invisible.
  static const String _verseNoteMarker = '⟦modo-estudio⟧';

  Future<void> _mirrorToVerseNotes({
    required StudyChapterAnswers? previous,
    required StudyChapterAnswers current,
  }) async {
    try {
      final prevRefs = {
        for (final ref in previous?.verseRefsInStudy() ?? const <StudyVerseRef>[]) ref.key: ref,
      };
      final currRefs = {for (final ref in current.verseRefsInStudy()) ref.key: ref};
      // Recalculamos el cuerpo agregado de TODOS los versículos afectados
      // (los que están en el rango actual, los que estaban antes pero ya no,
      // o ambos). Cada versículo puede tener varias notas de estudios
      // independientes que coexisten — segmentadas con separadores.
      final affected = {...prevRefs.keys, ...currRefs.keys};
      for (final key in affected) {
        final ref = currRefs[key] ?? prevRefs[key]!;
        await _recomputeMirrorForVerse(
          bookNumber: ref.bookNumber,
          bookName: ref.bookName,
          chapter: ref.chapter,
          verse: ref.verse,
        );
      }
    } catch (e) {
      debugPrint('[STUDY-MODE] mirror verse notes error: $e');
    }
  }

  /// Recalcula la nota espejo de un versículo a partir de todos los estudios
  /// del capítulo cuyo rango lo cubre. Si no hay estudios con contenido, la
  /// nota espejo se elimina (respetando notas manuales del usuario).
  Future<void> _recomputeMirrorForVerse({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required int verse,
  }) async {
    final covering = studiesCoveringVerse(
      bookNumber,
      chapter,
      verse,
    ).where((s) => s.hasContent).toList();

    final existing = BibleUserDataService.I.notesNotifier.value['$bookNumber:$chapter:$verse'];
    // Si hay nota manual del usuario (sin marcador), no la tocamos.
    if (existing != null && !existing.text.startsWith(_verseNoteMarker)) {
      return;
    }

    if (covering.isEmpty) {
      if (existing != null) {
        await BibleUserDataService.I.deleteNote(bookNumber, chapter, verse);
      }
      return;
    }

    // Ordenamos por fecha de creación (estudio más antiguo primero) para
    // que la lectura de la nota tenga un orden estable.
    covering.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final buf = StringBuffer('$_verseNoteMarker Estudios sobre v.$verse\n');
    for (var i = 0; i < covering.length; i++) {
      final s = covering[i];
      buf.writeln();
      buf.writeln('### ${i + 1}. ${s.reference}');
      buf.writeln();
      buf.writeln(s.toMarkdown());
      if (i < covering.length - 1) {
        buf.writeln();
        buf.writeln('---');
      }
    }

    await BibleUserDataService.I.saveNote(
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      bookName: bookName,
      text: buf.toString().trimRight(),
    );
  }

  Future<void> _clearMirroredVerseNotes(StudyChapterAnswers? prev) async {
    if (prev == null) return;
    // Tras eliminar un estudio, recalculamos cada vers\u00edculo de su rango;
    // si otros estudios siguen cubri\u00e9ndolo, la nota espejo queda con esas
    // entradas; si no, se elimina.
    for (final ref in prev.verseRefsInStudy()) {
      await _recomputeMirrorForVerse(
        bookNumber: ref.bookNumber,
        bookName: ref.bookName,
        chapter: ref.chapter,
        verse: ref.verse,
      );
    }
  }

  Future<void> _clearMirroredChapterNote(StudyChapterAnswers study) async {
    try {
      final remaining = studiesForChapter(
        study.bookNumber,
        study.chapter,
      ).where((s) => s.hasContent).toList();
      if (remaining.isNotEmpty) {
        await _mirrorToChapterNote(remaining.first);
        return;
      }
      for (final copia in ChapterNoteService.I
          .notesForChapter(study.bookNumber, study.chapter)
          .where((n) => n.tags.contains('modo-estudio'))) {
        await ChapterNoteService.I.deleteNote(copia.id);
      }
    } catch (e) {
      debugPrint('[STUDY-MODE] clear mirrored chapter note error: $e');
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Highlights API
  // ──────────────────────────────────────────────────────────────────────

  List<StudyWordHighlight> highlightsForChapter(String versionId, int bookNumber, int chapter) {
    return highlightsNotifier.value
        .where(
          (h) => h.versionId == versionId && h.bookNumber == bookNumber && h.chapter == chapter,
        )
        .toList(growable: false);
  }

  List<StudyWordHighlight> highlightsForVerse(
    String versionId,
    int bookNumber,
    int chapter,
    int verse,
  ) {
    return highlightsNotifier.value
        .where(
          (h) =>
              h.versionId == versionId &&
              h.bookNumber == bookNumber &&
              h.chapter == chapter &&
              h.verse == verse,
        )
        .toList(growable: false);
  }

  /// Añade un subrayado granular y refleja el versículo en la lectura normal.
  Future<StudyWordHighlight> addHighlight({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required int startWord,
    required int endWord,
    required StudyHighlightCode code,
  }) async {
    assert(endWord > startWord, 'endWord debe ser > startWord');
    _rememberHighlightState();
    final h = StudyWordHighlight(
      id: _nuevoIdSubrayado(),
      versionId: versionId,
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      startWord: startWord,
      endWord: endWord,
      code: code.key,
      ownerUid: _uid,
      ownerName: _currentDisplayName,
      createdAt: DateTime.now(),
    );

    final next = List<StudyWordHighlight>.from(highlightsNotifier.value)..add(h);
    highlightsNotifier.value = List.unmodifiable(next);
    await _saveHighlightsCache(next);

    _guardarSubrayado(h);

    unawaited(
      _syncMirroredVerseHighlight(
        versionId: versionId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        source: next,
      ),
    );
    unawaited(StudyRoomService.I.publishHighlight(h));

    return h;
  }

  /// Elimina un subrayado por id. Si era el último del versículo, también
  /// retira el highlight a nivel versículo.
  Future<void> removeHighlight(String id, {bool recordHistory = true}) async {
    final list = highlightsNotifier.value;
    StudyWordHighlight? target;
    for (final h in list) {
      if (h.id == id) {
        target = h;
        break;
      }
    }
    if (target == null) return;

    if (recordHistory) {
      _rememberHighlightState();
    }

    final next = list.where((h) => h.id != id).toList(growable: false);
    highlightsNotifier.value = List.unmodifiable(next);
    await _saveHighlightsCache(next);

    _borrarSubrayado(id);
    unawaited(StudyRoomService.I.deleteHighlight(id));

    unawaited(
      _syncMirroredVerseHighlight(
        versionId: target.versionId,
        bookNumber: target.bookNumber,
        chapter: target.chapter,
        verse: target.verse,
        source: next,
      ),
    );
  }

  Future<void> clearHighlightRange({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required int startWord,
    required int endWord,
  }) async {
    if (endWord <= startWord) return;
    final current = highlightsNotifier.value;
    final affected = current
        .where(
          (h) =>
              h.versionId == versionId &&
              h.bookNumber == bookNumber &&
              h.chapter == chapter &&
              h.verse == verse &&
              h.overlapsRange(startWord, endWord),
        )
        .toList(growable: false);
    if (affected.isEmpty) return;

    _rememberHighlightState();
    final replacements = <StudyWordHighlight>[];
    for (final highlight in affected) {
      if (highlight.startWord < startWord) {
        replacements.add(highlight.copyWith(id: _nuevoIdSubrayado(), endWord: startWord));
      }
      if (endWord < highlight.endWord) {
        replacements.add(highlight.copyWith(id: _nuevoIdSubrayado(), startWord: endWord));
      }
    }

    final affectedIds = affected.map((h) => h.id).toSet();
    final next = [
      for (final h in current)
        if (!affectedIds.contains(h.id)) h,
      ...replacements,
    ];
    highlightsNotifier.value = List.unmodifiable(next);
    await _saveHighlightsCache(next);

    for (final highlight in affected) {
      _borrarSubrayado(highlight.id);
    }
    replacements.forEach(_guardarSubrayado);
    for (final highlight in affected) {
      unawaited(StudyRoomService.I.deleteHighlight(highlight.id));
    }
    for (final replacement in replacements) {
      unawaited(StudyRoomService.I.publishHighlight(replacement));
    }

    unawaited(
      _syncMirroredVerseHighlight(
        versionId: versionId,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        source: next,
      ),
    );
  }

  /// Limpia todos los subrayados Modo-Estudio del versículo (por ejemplo al
  /// pulsar "borrar" en la barra flotante).
  Future<void> clearVerseHighlights(
    String versionId,
    int bookNumber,
    int chapter,
    int verse,
  ) async {
    final ids = highlightsNotifier.value
        .where(
          (h) =>
              h.versionId == versionId &&
              h.bookNumber == bookNumber &&
              h.chapter == chapter &&
              h.verse == verse,
        )
        .map((h) => h.id)
        .toList();
    if (ids.isEmpty) return;
    _rememberHighlightState();
    for (final id in ids) {
      await removeHighlight(id, recordHistory: false);
    }
  }

  /// Limpia todos los subrayados de Modo Estudio de un capítulo.
  Future<void> clearChapterHighlights({
    required int bookNumber,
    required int chapter,
    String? versionId,
  }) async {
    final current = highlightsNotifier.value;
    final affected = current
        .where(
          (h) =>
              h.bookNumber == bookNumber &&
              h.chapter == chapter &&
              (versionId == null || h.versionId == versionId),
        )
        .toList(growable: false);
    if (affected.isEmpty) return;

    _rememberHighlightState();
    final affectedIds = affected.map((h) => h.id).toSet();
    final next = current.where((h) => !affectedIds.contains(h.id)).toList(growable: false);
    highlightsNotifier.value = List.unmodifiable(next);
    await _saveHighlightsCache(next);

    for (final highlight in affected) {
      _borrarSubrayado(highlight.id);
    }

    final affectedVerseKeys = <String>{};
    for (final highlight in affected) {
      unawaited(StudyRoomService.I.deleteHighlight(highlight.id));
      affectedVerseKeys.add(
        '${highlight.versionId}|${highlight.bookNumber}|${highlight.chapter}|${highlight.verse}',
      );
    }
    for (final key in affectedVerseKeys) {
      final parts = key.split('|');
      if (parts.length != 4) continue;
      unawaited(
        _syncMirroredVerseHighlight(
          versionId: parts[0],
          bookNumber: int.tryParse(parts[1]) ?? 0,
          chapter: int.tryParse(parts[2]) ?? 0,
          verse: int.tryParse(parts[3]) ?? 0,
          source: next,
        ),
      );
    }
  }

  Future<void> undoHighlightChange() async {
    if (_undoHighlightStack.isEmpty) return;
    final current = List<StudyWordHighlight>.from(highlightsNotifier.value);
    final previous = _undoHighlightStack.removeLast();
    _redoHighlightStack.add(current);
    await _replaceHighlightState(previous, current);
    _updateHighlightHistoryState();
  }

  Future<void> redoHighlightChange() async {
    if (_redoHighlightStack.isEmpty) return;
    final current = List<StudyWordHighlight>.from(highlightsNotifier.value);
    final next = _redoHighlightStack.removeLast();
    _undoHighlightStack.add(current);
    await _replaceHighlightState(next, current);
    _updateHighlightHistoryState();
  }

  void _rememberHighlightState() {
    _undoHighlightStack.add(List<StudyWordHighlight>.from(highlightsNotifier.value));
    if (_undoHighlightStack.length > 50) {
      _undoHighlightStack.removeAt(0);
    }
    _redoHighlightStack.clear();
    _updateHighlightHistoryState();
  }

  void _updateHighlightHistoryState() {
    canUndoHighlightsNotifier.value = _undoHighlightStack.isNotEmpty;
    canRedoHighlightsNotifier.value = _redoHighlightStack.isNotEmpty;
  }

  Future<void> _replaceHighlightState(
    List<StudyWordHighlight> target,
    List<StudyWordHighlight> previous,
  ) async {
    highlightsNotifier.value = List.unmodifiable(target);
    await _saveHighlightsCache(target);

    final previousById = {for (final h in previous) h.id: h};
    final targetById = {for (final h in target) h.id: h};
    final affectedVerseKeys = <String>{};
    void mark(StudyWordHighlight h) =>
        affectedVerseKeys.add('${h.versionId}|${h.bookNumber}|${h.chapter}|${h.verse}');
    previous.forEach(mark);
    target.forEach(mark);

    for (final id in previousById.keys) {
      if (!targetById.containsKey(id)) _borrarSubrayado(id);
    }
    // Solo se reescriben los que cambiaron (antes se reescribían todos).
    for (final highlight in target) {
      final antes = previousById[highlight.id];
      if (antes == null ||
          antes.startWord != highlight.startWord ||
          antes.endWord != highlight.endWord ||
          antes.code != highlight.code) {
        _guardarSubrayado(highlight);
      }
    }
    for (final id in previousById.keys) {
      if (!targetById.containsKey(id)) {
        unawaited(StudyRoomService.I.deleteHighlight(id));
      }
    }
    unawaited(StudyRoomService.I.publishHighlights(target));

    for (final key in affectedVerseKeys) {
      final parts = key.split('|');
      if (parts.length != 4) continue;
      unawaited(
        _syncMirroredVerseHighlight(
          versionId: parts[0],
          bookNumber: int.tryParse(parts[1]) ?? 0,
          chapter: int.tryParse(parts[2]) ?? 0,
          verse: int.tryParse(parts[3]) ?? 0,
          source: target,
        ),
      );
    }
  }

  /// Limpia highlights legacy a nivel-versículo creados por la versión antigua
  /// del Modo Estudio (que pintaba el versículo completo). Hoy los subrayados
  /// granulares se renderizan palabra por palabra desde
  /// [highlightsNotifier], así que el highlight a nivel verso ya no es
  /// necesario y, si existe con un color de Modo Estudio, se elimina.
  Future<void> _syncMirroredVerseHighlight({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required List<StudyWordHighlight> source,
  }) async {
    if (bookNumber <= 0 || chapter <= 0 || verse <= 0) return;
    final existing =
        BibleUserDataService.I.highlightsNotifier.value['$versionId:$bookNumber:$chapter:$verse'];
    if (existing == null) return;
    final studyHexes = StudyHighlightCode.values.map((c) => c.colorHex.toUpperCase()).toSet();
    if (studyHexes.contains(existing.colorHex.toUpperCase())) {
      await BibleUserDataService.I.removeHighlight(versionId, bookNumber, chapter, verse);
    }
  }

  String get _currentDisplayName {
    final name = FirebaseAuth.instance.currentUser?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Compañero';
  }

  /// Migración única: al iniciar el Modo Estudio, recorre los highlights
  /// a nivel-versículo y elimina los que parecen creados por la versión
  /// antigua del mirror (color coincide con un StudyHighlightCode y existe
  /// un StudyWordHighlight para el mismo verso).
  Future<void> _purgeLegacyMirroredHighlights() async {
    final wordHighlights = highlightsNotifier.value;
    if (wordHighlights.isEmpty) return;
    final studyHexes = StudyHighlightCode.values.map((c) => c.colorHex.toUpperCase()).toSet();
    final wordKeys = wordHighlights
        .map((h) => '${h.versionId}:${h.bookNumber}:${h.chapter}:${h.verse}')
        .toSet();
    final verseHighlights = Map<String, dynamic>.from(
      BibleUserDataService.I.highlightsNotifier.value,
    );
    for (final entry in verseHighlights.entries) {
      final h = entry.value;
      if (!wordKeys.contains(entry.key)) continue;
      if (!studyHexes.contains(h.colorHex.toString().toUpperCase())) continue;
      await BibleUserDataService.I.removeHighlight(
        h.versionId as String,
        h.bookNumber as int,
        h.chapter as int,
        h.verse as int,
      );
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Onboarding
  // ──────────────────────────────────────────────────────────────────────

  Future<bool> hasSeenOnboarding() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!.getBool(_onboardingKey) ?? false;
  }

  Future<void> markOnboardingSeen() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setBool(_onboardingKey, true);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Local cache
  // ──────────────────────────────────────────────────────────────────────

  String _answersKey(String uid) => '$_answersCachePrefix.$uid';
  String _highlightsKey(String uid) => '$_highlightsCachePrefix.$uid';

  Future<void> _loadAnswersCache(String uid) async {
    try {
      final raw = _prefs?.getString(_answersKey(uid));
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final map = <String, StudyChapterAnswers>{};
      for (final item in list) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          // El cache local usa millis -> Timestamp para reusar fromMap
          m['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(
            (m['createdAtMs'] ?? DateTime.now().millisecondsSinceEpoch) as int,
          );
          m['updatedAt'] = Timestamp.fromMillisecondsSinceEpoch(
            (m['updatedAtMs'] ?? DateTime.now().millisecondsSinceEpoch) as int,
          );
          final a = StudyChapterAnswers.fromMap(m);
          map[a.chapterKey] = a;
        }
      }
      answersNotifier.value = Map.unmodifiable(map);
    } catch (e) {
      debugPrint('[STUDY-MODE] answers cache load error: $e');
    }
  }

  Future<void> _saveAnswersCache(Map<String, StudyChapterAnswers> data) async {
    final uid = _uid;
    if (uid == null) return;
    final list = data.values
        .map(
          (a) => {
            if (a.studyId != null) 'studyId': a.studyId,
            'bookNumber': a.bookNumber,
            'bookName': a.bookName,
            'chapter': a.chapter,
            'versionId': a.versionId,
            'answers': a.answers,
            'generalNotes': a.generalNotes,
            'hopeMessage': a.hopeMessage,
            'mainVerses': a.sortedMainVerses,
            'studyStartVerse': a.studyStartVerse,
            'studyEndVerse': a.studyEndVerse,
            if (a.additionalPassages.isNotEmpty)
              'additionalPassages': a.additionalPassages.map((p) => p.toMap()).toList(),
            'createdAtMs': a.createdAt.millisecondsSinceEpoch,
            'updatedAtMs': a.updatedAt.millisecondsSinceEpoch,
          },
        )
        .toList();
    try {
      await _prefs?.setString(_answersKey(uid), jsonEncode(list));
    } catch (e) {
      debugPrint('[STUDY-MODE] answers cache save error: $e');
    }
  }

  Future<void> _loadHighlightsCache(String uid) async {
    try {
      final raw = _prefs?.getString(_highlightsKey(uid));
      if (raw == null || raw.isEmpty) return;
      final list = jsonDecode(raw);
      if (list is! List) return;
      final out = <StudyWordHighlight>[];
      for (final item in list) {
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          m['createdAt'] = Timestamp.fromMillisecondsSinceEpoch(
            (m['createdAtMs'] ?? DateTime.now().millisecondsSinceEpoch) as int,
          );
          out.add(StudyWordHighlight.fromMap(m['id'] as String, m));
        }
      }
      highlightsNotifier.value = List.unmodifiable(out);
    } catch (e) {
      debugPrint('[STUDY-MODE] highlights cache load error: $e');
    }
  }

  Future<void> _saveHighlightsCache(List<StudyWordHighlight> data) async {
    final uid = _uid;
    if (uid == null) return;
    final list = data
        .map(
          (h) => {
            'id': h.id,
            'versionId': h.versionId,
            'bookNumber': h.bookNumber,
            'chapter': h.chapter,
            'verse': h.verse,
            'startWord': h.startWord,
            'endWord': h.endWord,
            'code': h.code,
            'ownerUid': h.ownerUid,
            'ownerName': h.ownerName,
            'createdAtMs': h.createdAt.millisecondsSinceEpoch,
          },
        )
        .toList();
    try {
      await _prefs?.setString(_highlightsKey(uid), jsonEncode(list));
    } catch (e) {
      debugPrint('[STUDY-MODE] highlights cache save error: $e');
    }
  }
}
