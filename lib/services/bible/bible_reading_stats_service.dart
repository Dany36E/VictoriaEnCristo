import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE READING STATS SERVICE — Singleton
///
/// Tracks chapters read, streak, and percent of Bible completed.
/// Firestore: /users/{uid}/bibleReadingLog/{YYYY-MM-DD} → {chapters: [...]}
/// Firestore: /users/{uid}/bibleSettings/readingStats → {streak, lastDate, chaptersRead}
/// ═══════════════════════════════════════════════════════════════════════════
class BibleReadingStatsService {
  static final BibleReadingStatsService _instance = BibleReadingStatsService._internal();
  factory BibleReadingStatsService() => _instance;
  static BibleReadingStatsService get I => _instance;
  BibleReadingStatsService._internal();

  String? _uid;
  final _firestore = FirebaseFirestore.instance;
  StreamSubscription? _sub;

  /// Total chapters in the Bible (1189)
  static const int totalBibleChapters = 1189;

  /// Stats notifier: {streak: int, percentRead: double, chaptersRead: int, lastDate: String}
  final ValueNotifier<Map<String, dynamic>> statsNotifier = ValueNotifier({});

  /// Set of read chapter keys "bookNum:chapter"
  final ValueNotifier<Set<String>> readChaptersNotifier = ValueNotifier({});

  DocumentReference get _statsDoc =>
      _firestore.collection('users').doc(_uid!).collection('bibleSettings').doc('readingStats');

  CollectionReference get _logCol =>
      _firestore.collection('users').doc(_uid!).collection('bibleReadingLog');

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    stop();
    _uid = uid;
    _listen();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    statsNotifier.value = {};
    readChaptersNotifier.value = {};
    _uid = null;
  }

  void _listen() {
    _sub = _statsDoc.snapshots().listen((snap) {
      if (snap.exists) {
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final readSet = <String>{};
        final chapters = data['chaptersReadList'] as List<dynamic>? ?? [];
        for (final c in chapters) {
          readSet.add(c as String);
        }
        readChaptersNotifier.value = readSet;
        statsNotifier.value = {
          'streak': (data['streak'] as num?)?.toInt() ?? 0,
          'percentRead': (readSet.length / totalBibleChapters * 100),
          'chaptersRead': readSet.length,
          'lastDate': data['lastDate'] as String? ?? '',
        };
      }
    });
  }

  /// Log a chapter read. Called from BibleReaderScreen._loadChapter()
  Future<void> logChapterRead({required int bookNumber, required int chapter}) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter';
    final today = _todayStr();

    // OPTIMIZACIÓN: si el capítulo ya está marcado como leído Y la racha
    // ya fue actualizada hoy, no hay nada que escribir. Esto evita el
    // patrón read+modify+write completo cuando el usuario navega por
    // capítulos ya leídos (caso muy frecuente al abrir la Biblia).
    final alreadyRead = readChaptersNotifier.value.contains(key);
    final lastDateCached = statsNotifier.value['lastDate'] as String? ?? '';
    if (alreadyRead && lastDateCached == today) {
      return;
    }

    // Update daily log (arrayUnion es idempotente, seguro sin transacción)
    await _logCol.doc(today).set({
      'chapters': FieldValue.arrayUnion([key]),
      'date': today,
    }, SetOptions(merge: true));

    // Update aggregate stats: read+modify+merge (sin runTransaction porque
    // crashea en Windows con errores "non-platform thread"). Si el mismo
    // usuario está leyendo en dos dispositivos a la vez, una de las dos
    // escrituras puede perder un capítulo, pero arrayUnion del log diario
    // recupera el dato. Aceptable.
    try {
      final snap = await _statsDoc.get();
      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      final readList = List<String>.from(data['chaptersReadList'] as List? ?? []);
      final lastDate = data['lastDate'] as String? ?? '';
      var streak = (data['streak' ] as num?)?.toInt() ?? 0;

      final wasNew = !readList.contains(key);
      if (wasNew) {
        readList.add(key);
      }

      // Si nada cambió (capítulo ya estaba y la fecha tampoco), saltamos
      // el write para no consumir cuota.
      if (!wasNew && lastDate == today) {
        return;
      }

      // Update streak
      if (lastDate == today) {
        // Already logged today, streak unchanged
      } else if (lastDate == _yesterdayStr()) {
        streak++;
      } else if (lastDate.isEmpty) {
        streak = 1;
      } else {
        streak = 1; // Reset streak
      }

      await _statsDoc.set({
        'chaptersReadList': readList,
        'lastDate': today,
        'streak': streak,
        'totalChapters': readList.length,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[BibleStats] logChapterRead aggregate update failed: $e');
    }
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayStr() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year}-${y.month.toString().padLeft(2, '0')}-${y.day.toString().padLeft(2, '0')}';
  }
}
