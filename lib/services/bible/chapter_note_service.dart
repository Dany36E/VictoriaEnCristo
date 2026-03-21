import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  StreamSubscription? _subscription;

  /// Mapa chapterKey → ChapterStudyNote para lookup rápido
  final ValueNotifier<Map<String, ChapterStudyNote>> notesNotifier =
      ValueNotifier({});

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid!).collection('chapterNotes');

  // ══════════════════════════════════════════════════════════════════════════
  // INIT / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
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
        .snapshots()
        .listen((snap) {
      final map = <String, ChapterStudyNote>{};
      for (final doc in snap.docs) {
        final note = ChapterStudyNote.fromMap(doc.id, doc.data());
        map[note.chapterKey] = note;
      }
      notesNotifier.value = map;
    }, onError: (e) {
      debugPrint('📝 [CHAPTER-NOTES] listen error: $e');
    });
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
    final data = ChapterStudyNote(
      id: existingId ?? '',
      versionId: versionId,
      bookNumber: bookNumber,
      bookName: bookName,
      chapter: chapter,
      title: title,
      content: content,
      tags: tags,
      colorHex: colorHex,
      createdAt: now,
      updatedAt: now,
    ).toMap();

    if (existingId != null && existingId.isNotEmpty) {
      // Update — preservar createdAt
      data.remove('createdAt');
      await _col.doc(existingId).update(data);
    } else {
      await _col.add(data);
    }
  }

  /// Eliminar nota
  Future<void> deleteNote(String noteId) async {
    if (_uid == null) return;
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
}
