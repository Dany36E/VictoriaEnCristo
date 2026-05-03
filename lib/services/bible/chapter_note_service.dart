import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/chapter_study_note.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CHAPTER NOTE SERVICE - Singleton
/// Gestiona notas de estudio por capítulo en Firestore.
///
/// Colección: /users/{uid}/chapterNotes/{docId}
/// ═══════════════════════════════════════════════════════════════════════════
class ChapterNoteService {
  // ── Singleton ──
  static final ChapterNoteService _instance = ChapterNoteService._internal();
  factory ChapterNoteService() => _instance;
  static ChapterNoteService get I => _instance;
  ChapterNoteService._internal();

  // ── Estado ──
  String? _uid;
  final _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  StreamSubscription? _subscription;
  static const String _cachePrefix = 'chapter_notes_cache_v1';

  /// Mapa chapterKey → ChapterStudyNote para lookup rápido
  final ValueNotifier<Map<String, ChapterStudyNote>> notesNotifier = ValueNotifier({});

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid!).collection('chapterNotes');

  // ══════════════════════════════════════════════════════════════════════════
  // INIT / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    await _loadLocalCache(uid);
    debugPrint('📝 [CHAPTER-NOTES] init for $uid');
    _listen();
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    notesNotifier.value = {};
    _uid = null;
  }

  void _listen() {
    _subscription = _col
        .orderBy('updatedAt', descending: true)
        .limit(300)
        .snapshots()
        .listen(
          (snap) {
            if (snap.docs.isEmpty && snap.metadata.isFromCache && notesNotifier.value.isNotEmpty) {
              debugPrint('📝 [CHAPTER-NOTES] Keeping cached notes while offline');
              return;
            }
            final map = <String, ChapterStudyNote>{};
            for (final doc in snap.docs) {
              try {
                final note = ChapterStudyNote.fromMap(doc.id, doc.data());
                map[note.chapterKey] = note;
              } catch (e) {
                debugPrint('📝 [CHAPTER-NOTES] parse error: $e');
              }
            }
            notesNotifier.value = Map.unmodifiable(map);
            unawaited(_saveLocalCache(map));
          },
          onError: (e) {
            debugPrint('📝 [CHAPTER-NOTES] listen error: $e');
          },
        );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Obtener nota para un capítulo específico (desde cache local)
  ChapterStudyNote? getNoteForChapter(int bookNumber, int chapter) {
    return notesNotifier.value['$bookNumber:$chapter'];
  }

  /// Guardar o actualizar nota
  Future<void> saveNote({
    String? existingId,
    required String versionId,
    required int bookNumber,
    required String bookName,
    required int chapter,
    required String title,
    required String content,
    List<String> tags = const [],
    String colorHex = 'D4A853',
  }) async {
    if (_uid == null) return;

    final now = DateTime.now();
    final existing = _findById(existingId);
    final hasExistingId = existingId != null && existingId.isNotEmpty;
    final doc = hasExistingId ? _col.doc(existingId) : _col.doc();
    final note = ChapterStudyNote(
      id: existing?.id ?? doc.id,
      versionId: versionId,
      bookNumber: bookNumber,
      bookName: bookName,
      chapter: chapter,
      title: title,
      content: content,
      tags: tags,
      colorHex: colorHex,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );

    final next = Map<String, ChapterStudyNote>.from(notesNotifier.value);
    next[note.chapterKey] = note;
    notesNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);

    final data = note.toMap();

    if (hasExistingId) {
      // Update — preservar createdAt
      data.remove('createdAt');
      await doc.update(data);
    } else {
      await doc.set(data);
    }
  }

  /// Eliminar nota
  Future<void> deleteNote(String noteId) async {
    if (_uid == null) return;
    final next = Map<String, ChapterStudyNote>.from(notesNotifier.value);
    next.removeWhere((_, note) => note.id == noteId);
    notesNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    await _col.doc(noteId).delete();
  }

  /// Buscar notas por texto (title + content)
  List<ChapterStudyNote> searchNotes(String query) {
    if (query.trim().isEmpty) return allNotes;
    final q = query.toLowerCase();
    return allNotes.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Todas las notas ordenadas por updatedAt desc
  List<ChapterStudyNote> get allNotes {
    final list = notesNotifier.value.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Notas filtradas por libro
  List<ChapterStudyNote> notesForBook(int bookNumber) {
    return allNotes.where((n) => n.bookNumber == bookNumber).toList();
  }

  ChapterStudyNote? _findById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final note in notesNotifier.value.values) {
      if (note.id == id) return note;
    }
    return null;
  }

  String _cacheKey(String uid) => '$_cachePrefix.$uid';

  Future<void> _loadLocalCache(String uid) async {
    try {
      final raw = _prefs?.getString(_cacheKey(uid));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final notes = decoded.map(_fromLocal).whereType<ChapterStudyNote>();
      notesNotifier.value = Map.unmodifiable({for (final n in notes) n.chapterKey: n});
    } catch (e) {
      debugPrint('📝 [CHAPTER-NOTES] local cache load error: $e');
    }
  }

  Future<void> _saveLocalCache(Map<String, ChapterStudyNote> notes) async {
    final uid = _uid;
    if (uid == null) return;
    await _prefs?.setString(_cacheKey(uid), jsonEncode(notes.values.map(_toLocal).toList()));
  }

  Map<String, dynamic> _toLocal(ChapterStudyNote note) => {
    'id': note.id,
    'versionId': note.versionId,
    'bookNumber': note.bookNumber,
    'bookName': note.bookName,
    'chapter': note.chapter,
    'title': note.title,
    'content': note.content,
    'tags': note.tags,
    'colorHex': note.colorHex,
    'createdAtMs': note.createdAt.millisecondsSinceEpoch,
    'updatedAtMs': note.updatedAt.millisecondsSinceEpoch,
  };

  ChapterStudyNote? _fromLocal(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      return ChapterStudyNote(
        id: data['id'] as String? ?? '',
        versionId: data['versionId'] as String? ?? 'RVR1960',
        bookNumber: _asInt(data['bookNumber']),
        bookName: data['bookName'] as String? ?? '',
        chapter: _asInt(data['chapter']),
        title: data['title'] as String? ?? '',
        content: data['content'] as String? ?? '',
        tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        colorHex: data['colorHex'] as String? ?? 'D4A853',
        createdAt: _dateFromMs(data['createdAtMs']),
        updatedAt: _dateFromMs(data['updatedAtMs']),
      );
    } catch (_) {
      return null;
    }
  }

  int _asInt(dynamic value) => value is num ? value.toInt() : int.parse(value.toString());

  DateTime _dateFromMs(dynamic value) {
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.now();
  }
}
