import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/verse_collection.dart';
import '../../models/bible/bible_verse.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// COLLECTION SERVICE - Singleton
/// Gestiona colecciones temáticas de versículos en Firestore.
/// Subcolección: /users/{uid}/verseCollections/{docId}
/// ═══════════════════════════════════════════════════════════════════════════
class CollectionService {
  static final CollectionService _instance = CollectionService._internal();
  factory CollectionService() => _instance;
  static CollectionService get I => _instance;
  CollectionService._internal();

  String? _uid;
  final _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  StreamSubscription? _sub;
  static const String _cachePrefix = 'verse_collections_cache_v1';

  final ValueNotifier<List<VerseCollection>> collectionsNotifier = ValueNotifier([]);

  CollectionReference get _col =>
      _firestore.collection('users').doc(_uid!).collection('verseCollections');

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    await _loadLocalCache(uid);
    _listen();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    collectionsNotifier.value = [];
    _uid = null;
  }

  void _listen() {
    _sub = _col.orderBy('updatedAt', descending: true).snapshots().listen((snap) {
      if (snap.docs.isEmpty && snap.metadata.isFromCache && collectionsNotifier.value.isNotEmpty) {
        debugPrint('📚 [COLLECTIONS] Keeping cached collections while offline');
        return;
      }
      final list = snap.docs
          .map((doc) => VerseCollection.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      collectionsNotifier.value = List.unmodifiable(list);
      unawaited(_saveLocalCache(list));
    });
  }

  /// Crear nueva colección
  Future<String> createCollection({
    required String name,
    String? description,
    String emoji = '📖',
  }) async {
    if (_uid == null) return '';
    final now = DateTime.now();
    final doc = _col.doc();
    final collection = VerseCollection(
      id: doc.id,
      name: name,
      description: description,
      emoji: emoji,
      createdAt: now,
      updatedAt: now,
    );
    final next = [collection, ...collectionsNotifier.value];
    collectionsNotifier.value = List.unmodifiable(next);
    await _saveLocalCache(next);
    await doc.set(collection.toMap());
    return doc.id;
  }

  /// Agregar versículo a una colección
  Future<void> addVerse({required String collectionId, required BibleVerse verse}) async {
    if (_uid == null) return;
    final docRef = _col.doc(collectionId);
    final collection = _findById(collectionId) ?? await _fetchCollection(docRef);
    if (collection == null) return;

    // Evitar duplicados
    if (collection.verses.any((v) => v.uniqueKey == verse.uniqueKey)) return;

    final newRef = VerseRef(
      bookNumber: verse.bookNumber,
      bookName: verse.bookName,
      chapter: verse.chapter,
      verse: verse.verse,
      text: verse.text,
      version: verse.version,
      addedAt: DateTime.now(),
    );

    final updated = VerseCollection(
      id: collection.id,
      name: collection.name,
      description: collection.description,
      emoji: collection.emoji,
      verses: [...collection.verses, newRef],
      createdAt: collection.createdAt,
      updatedAt: DateTime.now(),
    );
    await _replaceLocal(updated);

    await docRef.update({
      'verses': FieldValue.arrayUnion([newRef.toMap()]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Remover versículo de una colección
  Future<void> removeVerse({required String collectionId, required String verseKey}) async {
    if (_uid == null) return;
    final docRef = _col.doc(collectionId);
    final collection = _findById(collectionId) ?? await _fetchCollection(docRef);
    if (collection == null) return;

    final updated = collection.verses.where((v) => v.uniqueKey != verseKey).toList();

    await _replaceLocal(
      VerseCollection(
        id: collection.id,
        name: collection.name,
        description: collection.description,
        emoji: collection.emoji,
        verses: updated,
        createdAt: collection.createdAt,
        updatedAt: DateTime.now(),
      ),
    );

    await docRef.update({
      'verses': updated.map((v) => v.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Eliminar una colección
  Future<void> deleteCollection(String collectionId) async {
    if (_uid == null) return;
    final next = collectionsNotifier.value.where((c) => c.id != collectionId).toList();
    collectionsNotifier.value = List.unmodifiable(next);
    await _saveLocalCache(next);
    await _col.doc(collectionId).delete();
  }

  /// Renombrar colección
  Future<void> renameCollection(String collectionId, String newName) async {
    if (_uid == null) return;
    final collection = _findById(collectionId);
    if (collection != null) {
      await _replaceLocal(
        VerseCollection(
          id: collection.id,
          name: newName,
          description: collection.description,
          emoji: collection.emoji,
          verses: collection.verses,
          createdAt: collection.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
    }
    await _col.doc(collectionId).update({
      'name': newName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  VerseCollection? _findById(String id) {
    for (final collection in collectionsNotifier.value) {
      if (collection.id == id) return collection;
    }
    return null;
  }

  Future<VerseCollection?> _fetchCollection(DocumentReference docRef) async {
    final snap = await docRef.get();
    if (!snap.exists) return null;
    return VerseCollection.fromMap(snap.id, snap.data() as Map<String, dynamic>);
  }

  Future<void> _replaceLocal(VerseCollection updated) async {
    var replaced = false;
    final next = collectionsNotifier.value.map((collection) {
      if (collection.id == updated.id) {
        replaced = true;
        return updated;
      }
      return collection;
    }).toList();
    if (!replaced) {
      next.insert(0, updated);
    }
    collectionsNotifier.value = List.unmodifiable(next);
    await _saveLocalCache(next);
  }

  String _cacheKey(String uid) => '$_cachePrefix.$uid';

  Future<void> _loadLocalCache(String uid) async {
    try {
      final raw = _prefs?.getString(_cacheKey(uid));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final collections = decoded.map(_fromLocal).whereType<VerseCollection>().toList()
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      collectionsNotifier.value = List.unmodifiable(collections);
    } catch (e) {
      debugPrint('📚 [COLLECTIONS] local cache load error: $e');
    }
  }

  Future<void> _saveLocalCache(List<VerseCollection> collections) async {
    final uid = _uid;
    if (uid == null) return;
    await _prefs?.setString(_cacheKey(uid), jsonEncode(collections.map(_toLocal).toList()));
  }

  Map<String, dynamic> _toLocal(VerseCollection collection) => {
    'id': collection.id,
    'name': collection.name,
    'description': collection.description,
    'emoji': collection.emoji,
    'verses': collection.verses.map(_verseToLocal).toList(),
    'createdAtMs': collection.createdAt.millisecondsSinceEpoch,
    'updatedAtMs': collection.updatedAt.millisecondsSinceEpoch,
  };

  Map<String, dynamic> _verseToLocal(VerseRef verse) => {
    'bookNumber': verse.bookNumber,
    'bookName': verse.bookName,
    'chapter': verse.chapter,
    'verse': verse.verse,
    'text': verse.text,
    'version': verse.version,
    'addedAtMs': verse.addedAt.millisecondsSinceEpoch,
  };

  VerseCollection? _fromLocal(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      final verses = (data['verses'] as List?)?.map(_verseFromLocal).whereType<VerseRef>().toList();
      return VerseCollection(
        id: data['id'] as String? ?? '',
        name: data['name'] as String? ?? 'Sin nombre',
        description: data['description'] as String?,
        emoji: data['emoji'] as String? ?? '📖',
        verses: verses ?? const [],
        createdAt: _dateFromMs(data['createdAtMs']),
        updatedAt: _dateFromMs(data['updatedAtMs']),
      );
    } catch (_) {
      return null;
    }
  }

  VerseRef? _verseFromLocal(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      return VerseRef(
        bookNumber: _asInt(data['bookNumber']),
        bookName: data['bookName'] as String? ?? '',
        chapter: _asInt(data['chapter']),
        verse: _asInt(data['verse']),
        text: data['text'] as String? ?? '',
        version: data['version'] as String? ?? 'RVR1960',
        addedAt: _dateFromMs(data['addedAtMs']),
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
