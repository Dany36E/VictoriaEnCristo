import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/sermon_note.dart';

class SermonNoteService {
  SermonNoteService._();
  static final SermonNoteService I = SermonNoteService._();

  final _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  StreamSubscription? _subscription;
  String? _uid;

  static const _cachePrefix = 'sermon_notes_cache_v1';

  final ValueNotifier<Map<String, SermonNote>> notesNotifier = ValueNotifier(
    const {},
  );

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('users').doc(_uid!).collection('sermonNotes');

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    await _loadLocalCache(uid);
    _listen();
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    notesNotifier.value = const {};
    _uid = null;
  }

  SermonNote? noteById(String? id) {
    if (id == null || id.isEmpty) return null;
    return notesNotifier.value[id];
  }

  List<SermonNote> get allNotes {
    final list = notesNotifier.value.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  List<String> get speakers {
    final values =
        notesNotifier.value.values
            .map((note) => note.speaker.trim())
            .where((speaker) => speaker.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return values;
  }

  Future<void> saveNote(SermonNote note) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final updated = note.copyWith();
    final next = Map<String, SermonNote>.from(notesNotifier.value);
    next[updated.id] = updated;
    notesNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    await _col.doc(updated.id).set(updated.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteNote(String id) async {
    final uid = _uid;
    if (uid == null || uid.isEmpty) return;
    final next = Map<String, SermonNote>.from(notesNotifier.value)..remove(id);
    notesNotifier.value = Map.unmodifiable(next);
    await _saveLocalCache(next);
    await _col.doc(id).delete();
  }

  void _listen() {
    _subscription = _col
        .orderBy('updatedAt', descending: true)
        .limit(300)
        .snapshots()
        .listen((snap) {
          if (snap.docs.isEmpty &&
              snap.metadata.isFromCache &&
              notesNotifier.value.isNotEmpty) {
            return;
          }
          final map = <String, SermonNote>{};
          for (final doc in snap.docs) {
            try {
              map[doc.id] = SermonNote.fromMap(doc.id, doc.data());
            } catch (e) {
              debugPrint('[SERMON-NOTES] parse error: $e');
            }
          }
          notesNotifier.value = Map.unmodifiable(map);
          unawaited(_saveLocalCache(map));
        }, onError: (e) => debugPrint('[SERMON-NOTES] listen error: $e'));
  }

  String _cacheKey(String uid) => '$_cachePrefix.$uid';

  Future<void> _loadLocalCache(String uid) async {
    try {
      final raw = _prefs?.getString(_cacheKey(uid));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final notes = decoded.whereType<Map>().map((raw) {
        final data = Map<String, dynamic>.from(raw);
        final id = data.remove('id') as String? ?? '';
        if (id.isEmpty) return null;
        return SermonNote.fromMap(id, data);
      }).whereType<SermonNote>();
      notesNotifier.value = Map.unmodifiable({for (final n in notes) n.id: n});
    } catch (e) {
      debugPrint('[SERMON-NOTES] local cache load error: $e');
    }
  }

  Future<void> _saveLocalCache(Map<String, SermonNote> notes) async {
    final uid = _uid;
    if (uid == null) return;
    final encoded = notes.values.map((note) {
      final map = note.toMap();
      map['id'] = note.id;
      map['sermonDateMs'] = note.sermonDate.millisecondsSinceEpoch;
      map['createdAtMs'] = note.createdAt.millisecondsSinceEpoch;
      map['updatedAtMs'] = note.updatedAt.millisecondsSinceEpoch;
      map.remove('sermonDate');
      map.remove('createdAt');
      map.remove('updatedAt');
      return map;
    }).toList();
    await _prefs?.setString(_cacheKey(uid), jsonEncode(encoded));
  }
}
