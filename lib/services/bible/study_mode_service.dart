import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/study_chapter_answers.dart';
import '../../models/bible/study_word_highlight.dart';
import 'bible_user_data_service.dart';
import 'chapter_note_service.dart';

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
  final _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  StreamSubscription? _answersSub;
  StreamSubscription? _highlightsSub;

  static const _answersCachePrefix = 'study_answers_cache_v1';
  static const _highlightsCachePrefix = 'study_highlights_cache_v1';
  static const _onboardingKey = 'study_mode_onboarding_seen_v1';

  /// chapterKey ('book:chapter') → respuestas
  final ValueNotifier<Map<String, StudyChapterAnswers>> answersNotifier =
      ValueNotifier(const {});

  /// Lista plana de subrayados granulares
  final ValueNotifier<List<StudyWordHighlight>> highlightsNotifier =
      ValueNotifier(const []);

  // ──────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ──────────────────────────────────────────────────────────────────────

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('📖 [STUDY-MODE] init for $uid');

    await _loadAnswersCache(uid);
    await _loadHighlightsCache(uid);

    _listenAnswers();
    _listenHighlights();
  }

  void stop() {
    _answersSub?.cancel();
    _highlightsSub?.cancel();
    _answersSub = null;
    _highlightsSub = null;
    answersNotifier.value = const {};
    highlightsNotifier.value = const [];
    _uid = null;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Refs
  // ──────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> get _answersCol => _firestore
      .collection('users')
      .doc(_uid!)
      .collection('studyAnswers');

  CollectionReference<Map<String, dynamic>> get _highlightsCol => _firestore
      .collection('users')
      .doc(_uid!)
      .collection('studyHighlights');

  // ──────────────────────────────────────────────────────────────────────
  // Listeners
  // ──────────────────────────────────────────────────────────────────────

  void _listenAnswers() {
    _answersSub = _answersCol
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .snapshots()
        .listen(
      (snap) {
        if (snap.docs.isEmpty &&
            snap.metadata.isFromCache &&
            answersNotifier.value.isNotEmpty) {
          return;
        }
        final map = <String, StudyChapterAnswers>{};
        for (final d in snap.docs) {
          try {
            final a = StudyChapterAnswers.fromMap(d.data());
            map[a.chapterKey] = a;
          } catch (e) {
            debugPrint('[STUDY-MODE] answers parse error: $e');
          }
        }
        answersNotifier.value = Map.unmodifiable(map);
        unawaited(_saveAnswersCache(map));
      },
      onError: (e) => debugPrint('[STUDY-MODE] answers stream error: $e'),
    );
  }

  void _listenHighlights() {
    _highlightsSub = _highlightsCol
        .orderBy('createdAt', descending: true)
        .limit(2000)
        .snapshots()
        .listen(
      (snap) {
        if (snap.docs.isEmpty &&
            snap.metadata.isFromCache &&
            highlightsNotifier.value.isNotEmpty) {
          return;
        }
        final list = <StudyWordHighlight>[];
        for (final d in snap.docs) {
          try {
            list.add(StudyWordHighlight.fromMap(d.id, d.data()));
          } catch (e) {
            debugPrint('[STUDY-MODE] highlight parse error: $e');
          }
        }
        highlightsNotifier.value = List.unmodifiable(list);
        unawaited(_saveHighlightsCache(list));
      },
      onError: (e) => debugPrint('[STUDY-MODE] highlights stream error: $e'),
    );
  }

  // ──────────────────────────────────────────────────────────────────────
  // Answers API
  // ──────────────────────────────────────────────────────────────────────

  StudyChapterAnswers? answersFor(int bookNumber, int chapter) =>
      answersNotifier.value['$bookNumber:$chapter'];

  /// Guarda (debounced en UI) las respuestas del capítulo.
  /// Si todas están vacías, elimina el documento.
  Future<void> saveAnswers(StudyChapterAnswers answers) async {
    if (_uid == null) return;

    final cleaned = <String, String>{};
    answers.answers.forEach((k, v) {
      final t = v.trim();
      if (t.isNotEmpty) cleaned[k] = t;
    });

    final key = answers.chapterKey;
    final next = Map<String, StudyChapterAnswers>.from(answersNotifier.value);
    final previous = next[key];

    if (cleaned.isEmpty) {
      next.remove(key);
      answersNotifier.value = Map.unmodifiable(next);
      await _saveAnswersCache(next);
      try {
        await _answersCol.doc(answers.docId).delete();
      } catch (_) {}
      // Limpia notas espejo si las había
      unawaited(_clearMirroredVerseNotes(previous));
      return;
    }

    final updated = answers.copyWith(answers: cleaned, updatedAt: DateTime.now());
    next[key] = updated;
    answersNotifier.value = Map.unmodifiable(next);
    await _saveAnswersCache(next);

    try {
      await _answersCol.doc(updated.docId).set(updated.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('[STUDY-MODE] saveAnswers error: $e');
    }

    // Espejo seguro a Notas a nivel CAPÍTULO (sólo si no hay nota manual).
    unawaited(_mirrorToChapterNote(updated));

    // Espejo a notas POR VERSÍCULO en el rango estudiado.
    unawaited(_mirrorToVerseNotes(previous: previous, current: updated));
  }

  /// Actualiza únicamente el rango estudiado, sin tocar las respuestas.
  Future<void> setStudyRange({
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String versionId,
    required int? startVerse,
    required int? endVerse,
  }) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter';
    final base = answersNotifier.value[key] ??
        StudyChapterAnswers.empty(
          bookNumber: bookNumber,
          bookName: bookName,
          chapter: chapter,
          versionId: versionId,
        );
    final clear = startVerse == null || endVerse == null;
    final updated = base.copyWith(
      studyStartVerse: clear ? null : startVerse,
      studyEndVerse: clear ? null : endVerse,
      clearRange: clear,
    );

    final next = Map<String, StudyChapterAnswers>.from(answersNotifier.value);
    next[key] = updated;
    answersNotifier.value = Map.unmodifiable(next);
    await _saveAnswersCache(next);

    try {
      // Si nunca había documento (todo vacío y sin rango antes), no escribimos.
      if (updated.hasContent || !clear) {
        await _answersCol
            .doc(updated.docId)
            .set(updated.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('[STUDY-MODE] setStudyRange error: $e');
    }

    unawaited(_mirrorToVerseNotes(previous: base, current: updated));
  }

  Future<void> _mirrorToChapterNote(StudyChapterAnswers a) async {
    try {
      final existing =
          ChapterNoteService.I.getNoteForChapter(a.bookNumber, a.chapter);
      final existingIsManual = existing != null &&
          !(existing.tags.contains('modo-estudio'));
      if (existingIsManual) return; // respetamos nota manual

      await ChapterNoteService.I.saveNote(
        existingId: existing?.id,
        versionId: a.versionId,
        bookNumber: a.bookNumber,
        bookName: a.bookName,
        chapter: a.chapter,
        title: 'Modo Estudio · ${a.reference}',
        content: a.toMarkdown(),
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
      final prevSet = previous?.versesInRange().toSet() ?? const <int>{};
      final currSet = current.versesInRange().toSet();

      // 1. Borrar notas-espejo de versículos que dejaron de estar en el rango.
      final removed = prevSet.difference(currSet);
      for (final v in removed) {
        await _maybeRemoveMirrorVerseNote(
          current.bookNumber,
          current.chapter,
          v,
        );
      }

      // 2. Escribir/actualizar notas en el rango actual.
      if (currSet.isEmpty) return;
      final body = current.toMarkdown();
      if (body.trim().isEmpty) {
        for (final v in currSet) {
          await _maybeRemoveMirrorVerseNote(
            current.bookNumber,
            current.chapter,
            v,
          );
        }
        return;
      }
      final mirrored =
          '$_verseNoteMarker ${current.reference}\n\n$body';
      for (final v in currSet) {
        final existing = BibleUserDataService
            .I.notesNotifier.value['${current.bookNumber}:${current.chapter}:$v'];
        // Respetar nota manual previa (sin marcador).
        if (existing != null &&
            !existing.text.startsWith(_verseNoteMarker)) {
          continue;
        }
        await BibleUserDataService.I.saveNote(
          bookNumber: current.bookNumber,
          chapter: current.chapter,
          verse: v,
          bookName: current.bookName,
          text: mirrored,
        );
      }
    } catch (e) {
      debugPrint('[STUDY-MODE] mirror verse notes error: $e');
    }
  }

  Future<void> _clearMirroredVerseNotes(StudyChapterAnswers? prev) async {
    if (prev == null) return;
    for (final v in prev.versesInRange()) {
      await _maybeRemoveMirrorVerseNote(prev.bookNumber, prev.chapter, v);
    }
  }

  Future<void> _maybeRemoveMirrorVerseNote(
      int bookNumber, int chapter, int verse) async {
    final existing = BibleUserDataService
        .I.notesNotifier.value['$bookNumber:$chapter:$verse'];
    if (existing == null) return;
    if (existing.text.startsWith(_verseNoteMarker)) {
      await BibleUserDataService.I.deleteNote(bookNumber, chapter, verse);
    }
  }

  // ──────────────────────────────────────────────────────────────────────
  // Highlights API
  // ──────────────────────────────────────────────────────────────────────

  List<StudyWordHighlight> highlightsForChapter(int bookNumber, int chapter) {
    return highlightsNotifier.value
        .where((h) => h.bookNumber == bookNumber && h.chapter == chapter)
        .toList(growable: false);
  }

  List<StudyWordHighlight> highlightsForVerse(
      int bookNumber, int chapter, int verse) {
    return highlightsNotifier.value
        .where((h) =>
            h.bookNumber == bookNumber &&
            h.chapter == chapter &&
            h.verse == verse)
        .toList(growable: false);
  }

  /// Añade un subrayado granular y refleja el versículo en la lectura normal.
  Future<StudyWordHighlight> addHighlight({
    required int bookNumber,
    required int chapter,
    required int verse,
    required int startWord,
    required int endWord,
    required StudyHighlightCode code,
  }) async {
    assert(endWord > startWord, 'endWord debe ser > startWord');
    final doc = _highlightsCol.doc();
    final h = StudyWordHighlight(
      id: doc.id,
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      startWord: startWord,
      endWord: endWord,
      code: code.key,
      createdAt: DateTime.now(),
    );

    final next = List<StudyWordHighlight>.from(highlightsNotifier.value)..add(h);
    highlightsNotifier.value = List.unmodifiable(next);
    await _saveHighlightsCache(next);

    try {
      await doc.set(h.toMap());
    } catch (e) {
      debugPrint('[STUDY-MODE] addHighlight error: $e');
    }

    // Mirror al verse-level highlight de la lectura normal.
    unawaited(BibleUserDataService.I.addHighlight(
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      colorHex: code.colorHex,
    ));

    return h;
  }

  /// Elimina un subrayado por id. Si era el último del versículo, también
  /// retira el highlight a nivel versículo.
  Future<void> removeHighlight(String id) async {
    final list = highlightsNotifier.value;
    StudyWordHighlight? target;
    for (final h in list) {
      if (h.id == id) {
        target = h;
        break;
      }
    }
    if (target == null) return;

    final next = list.where((h) => h.id != id).toList(growable: false);
    highlightsNotifier.value = List.unmodifiable(next);
    await _saveHighlightsCache(next);

    try {
      await _highlightsCol.doc(id).delete();
    } catch (e) {
      debugPrint('[STUDY-MODE] removeHighlight error: $e');
    }

    final stillHasOnVerse = next.any((h) =>
        h.bookNumber == target!.bookNumber &&
        h.chapter == target.chapter &&
        h.verse == target.verse);
    if (!stillHasOnVerse) {
      unawaited(BibleUserDataService.I
          .removeHighlight(target.bookNumber, target.chapter, target.verse));
    }
  }

  /// Limpia todos los subrayados Modo-Estudio del versículo (por ejemplo al
  /// pulsar "borrar" en la barra flotante).
  Future<void> clearVerseHighlights(
      int bookNumber, int chapter, int verse) async {
    final ids = highlightsNotifier.value
        .where((h) =>
            h.bookNumber == bookNumber &&
            h.chapter == chapter &&
            h.verse == verse)
        .map((h) => h.id)
        .toList();
    for (final id in ids) {
      await removeHighlight(id);
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
              (m['createdAtMs'] ?? DateTime.now().millisecondsSinceEpoch) as int);
          m['updatedAt'] = Timestamp.fromMillisecondsSinceEpoch(
              (m['updatedAtMs'] ?? DateTime.now().millisecondsSinceEpoch) as int);
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
    final list = data.values.map((a) => {
          'bookNumber': a.bookNumber,
          'bookName': a.bookName,
          'chapter': a.chapter,
          'versionId': a.versionId,
          'answers': a.answers,
          'createdAtMs': a.createdAt.millisecondsSinceEpoch,
          'updatedAtMs': a.updatedAt.millisecondsSinceEpoch,
        }).toList();
    await _prefs?.setString(_answersKey(uid), jsonEncode(list));
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
              (m['createdAtMs'] ?? DateTime.now().millisecondsSinceEpoch) as int);
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
    final list = data.map((h) => {
          'id': h.id,
          'bookNumber': h.bookNumber,
          'chapter': h.chapter,
          'verse': h.verse,
          'startWord': h.startWord,
          'endWord': h.endWord,
          'code': h.code,
          'createdAtMs': h.createdAt.millisecondsSinceEpoch,
        }).toList();
    await _prefs?.setString(_highlightsKey(uid), jsonEncode(list));
  }
}

