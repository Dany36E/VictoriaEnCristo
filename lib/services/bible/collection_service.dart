import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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
  StreamSubscription? _sub;

  final ValueNotifier<List<VerseCollection>> collectionsNotifier =
      ValueNotifier([]);

  CollectionReference get _col =>
      _firestore.collection('users').doc(_uid!).collection('verseCollections');

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _listen();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    collectionsNotifier.value = [];
    _uid = null;
  }

  void _listen() {
    _sub = _col
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snap) {
      final list = snap.docs
          .map((doc) =>
              VerseCollection.fromMap(doc.id, doc.data() as Map<String, dynamic>))
          .toList();
      collectionsNotifier.value = List.unmodifiable(list);
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
    final doc = await _col.add(VerseCollection(
      id: '',
      name: name,
      description: description,
      emoji: emoji,
      createdAt: now,
      updatedAt: now,
    ).toMap());
    return doc.id;
  }

  /// Agregar versículo a una colección
  Future<void> addVerse({
    required String collectionId,
    required BibleVerse verse,
  }) async {
    if (_uid == null) return;
    final docRef = _col.doc(collectionId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final collection =
        VerseCollection.fromMap(snap.id, snap.data() as Map<String, dynamic>);

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

    await docRef.update({
      'verses': FieldValue.arrayUnion([newRef.toMap()]),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Remover versículo de una colección
  Future<void> removeVerse({
    required String collectionId,
    required String verseKey,
  }) async {
    if (_uid == null) return;
    final docRef = _col.doc(collectionId);
    final snap = await docRef.get();
    if (!snap.exists) return;

    final collection =
        VerseCollection.fromMap(snap.id, snap.data() as Map<String, dynamic>);

    final updated =
        collection.verses.where((v) => v.uniqueKey != verseKey).toList();

    await docRef.update({
      'verses': updated.map((v) => v.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Eliminar una colección
  Future<void> deleteCollection(String collectionId) async {
    if (_uid == null) return;
    await _col.doc(collectionId).delete();
  }

  /// Renombrar colección
  Future<void> renameCollection(String collectionId, String newName) async {
    if (_uid == null) return;
    await _col.doc(collectionId).update({
      'name': newName,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
