import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/highlight.dart';
import '../../models/bible/bible_note.dart';
import '../../models/bible/saved_verse.dart';
import '../../models/bible/verse_prayer.dart';
import '../../models/bible/bible_version.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE USER DATA SERVICE - Singleton
/// Gestiona highlights, notas, versículos guardados, oraciones y settings
/// del usuario en Firestore.
///
/// Subcolecciones bajo /users/{uid}/:
///   - bibleHighlights/{docId}
///   - bibleNotes/{docId}
///   - savedVerses/{docId}
///   - versePrayers/{docId}
///   - bibleSettings/preferences  (documento único)
/// ═══════════════════════════════════════════════════════════════════════════
class BibleUserDataService {
  // ── Singleton ──
  static final BibleUserDataService _instance = BibleUserDataService._internal();
  factory BibleUserDataService() => _instance;
  static BibleUserDataService get I => _instance;
  BibleUserDataService._internal();

  // ── Estado ──
  String? _uid;
  final _firestore = FirebaseFirestore.instance;

  // ── Notifiers reactivos ──
  final ValueNotifier<Map<String, Highlight>> highlightsNotifier =
      ValueNotifier({});
  final ValueNotifier<Map<String, BibleNote>> notesNotifier =
      ValueNotifier({});
  final ValueNotifier<List<SavedVerse>> savedVersesNotifier =
      ValueNotifier([]);
  final ValueNotifier<Map<String, VersePrayer>> prayersNotifier =
      ValueNotifier({});

  // ── Preferencias ──
  final ValueNotifier<BibleVersion> preferredVersionNotifier =
      ValueNotifier(BibleVersion.rvr1960);
  final ValueNotifier<double> fontSizeNotifier = ValueNotifier(20.0);
  final ValueNotifier<String> readerThemeNotifier = ValueNotifier('dark');
  final ValueNotifier<bool> redLettersEnabledNotifier = ValueNotifier(true);

  // ── Subscriptions ──
  final List<StreamSubscription> _subscriptions = [];

  // ══════════════════════════════════════════════════════════════════════════
  // INIT / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init(String uid) async {
    if (_uid == uid) return; // Ya inicializado para este usuario
    stop(); // Limpiar anterior si había

    _uid = uid;
    debugPrint('📖 [BIBLE-DATA] init for $uid');

    // Cargar preferencias
    await _loadPreferences();

    // Escuchar colecciones
    _listenHighlights();
    _listenNotes();
    _listenSavedVerses();
    _listenPrayers();
  }

  void stop() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    highlightsNotifier.value = {};
    notesNotifier.value = {};
    savedVersesNotifier.value = [];
    prayersNotifier.value = {};
    preferredVersionNotifier.value = BibleVersion.rvr1960;
    fontSizeNotifier.value = 20.0;
    readerThemeNotifier.value = 'dark';
    redLettersEnabledNotifier.value = true;
    _uid = null;
    debugPrint('📖 [BIBLE-DATA] stopped');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REF HELPERS
  // ══════════════════════════════════════════════════════════════════════════

  CollectionReference _col(String name) =>
      _firestore.collection('users').doc(_uid!).collection(name);

  DocumentReference _settingsDoc() =>
      _firestore.collection('users').doc(_uid!).collection('bibleSettings').doc('preferences');

  // ══════════════════════════════════════════════════════════════════════════
  // HIGHLIGHTS
  // ══════════════════════════════════════════════════════════════════════════

  void _listenHighlights() {
    final sub = _col('bibleHighlights').snapshots().listen((snap) {
      final map = <String, Highlight>{};
      for (final doc in snap.docs) {
        try {
          final h = Highlight.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          map[h.verseKey] = h;
        } catch (e) {
          debugPrint('[BIBLE-DATA] Highlight parse error: $e');
        }
      }
      highlightsNotifier.value = Map.unmodifiable(map);
    });
    _subscriptions.add(sub);
  }

  Future<void> addHighlight({
    required int bookNumber,
    required int chapter,
    required int verse,
    required String colorHex,
  }) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';

    // Remove existing highlight for this verse if any
    final existing = highlightsNotifier.value[key];
    if (existing != null) {
      await _col('bibleHighlights').doc(existing.id).delete();
    }

    await _col('bibleHighlights').add(Highlight(
      id: '',
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      colorHex: colorHex,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Future<void> removeHighlight(int bookNumber, int chapter, int verse) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = highlightsNotifier.value[key];
    if (existing != null) {
      await _col('bibleHighlights').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTES
  // ══════════════════════════════════════════════════════════════════════════

  void _listenNotes() {
    final sub = _col('bibleNotes').snapshots().listen((snap) {
      final map = <String, BibleNote>{};
      for (final doc in snap.docs) {
        try {
          final n = BibleNote.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          map[n.verseKey] = n;
        } catch (e) {
          debugPrint('[BIBLE-DATA] Note parse error: $e');
        }
      }
      notesNotifier.value = Map.unmodifiable(map);
    });
    _subscriptions.add(sub);
  }

  Future<void> saveNote({
    required int bookNumber,
    required int chapter,
    required int verse,
    required String bookName,
    required String text,
  }) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = notesNotifier.value[key];
    final now = DateTime.now();

    if (existing != null) {
      // Update
      await _col('bibleNotes').doc(existing.id).update({
        'text': text,
        'updatedAt': Timestamp.fromDate(now),
      });
    } else {
      // Create
      await _col('bibleNotes').add(BibleNote(
        id: '',
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        text: text,
        createdAt: now,
        updatedAt: now,
      ).toMap());
    }
  }

  Future<void> deleteNote(int bookNumber, int chapter, int verse) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = notesNotifier.value[key];
    if (existing != null) {
      await _col('bibleNotes').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVED VERSES (Marcadores)
  // ══════════════════════════════════════════════════════════════════════════

  void _listenSavedVerses() {
    final sub = _col('savedVerses')
        .orderBy('savedAt', descending: true)
        .snapshots()
        .listen((snap) {
      final list = <SavedVerse>[];
      for (final doc in snap.docs) {
        try {
          list.add(SavedVerse.fromMap(doc.id, doc.data() as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[BIBLE-DATA] SavedVerse parse error: $e');
        }
      }
      savedVersesNotifier.value = List.unmodifiable(list);
    });
    _subscriptions.add(sub);
  }

  bool isVerseSaved(int bookNumber, int chapter, int verse) {
    return savedVersesNotifier.value.any(
      (s) => s.bookNumber == bookNumber && s.chapter == chapter && s.verse == verse,
    );
  }

  Future<void> toggleSavedVerse({
    required int bookNumber,
    required int chapter,
    required int verse,
    required String bookName,
    required String text,
    required String version,
  }) async {
    if (_uid == null) return;
    final existing = savedVersesNotifier.value.where(
      (s) => s.bookNumber == bookNumber && s.chapter == chapter && s.verse == verse,
    );

    if (existing.isNotEmpty) {
      // Remove
      await _col('savedVerses').doc(existing.first.id).delete();
    } else {
      // Add
      await _col('savedVerses').add(SavedVerse(
        id: '',
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        text: text,
        version: version,
        savedAt: DateTime.now(),
      ).toMap());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRAYERS
  // ══════════════════════════════════════════════════════════════════════════

  void _listenPrayers() {
    final sub = _col('versePrayers').snapshots().listen((snap) {
      final map = <String, VersePrayer>{};
      for (final doc in snap.docs) {
        try {
          final p = VersePrayer.fromMap(doc.id, doc.data() as Map<String, dynamic>);
          map[p.verseKey] = p;
        } catch (e) {
          debugPrint('[BIBLE-DATA] Prayer parse error: $e');
        }
      }
      prayersNotifier.value = Map.unmodifiable(map);
    });
    _subscriptions.add(sub);
  }

  Future<void> savePrayer({
    required int bookNumber,
    required int chapter,
    required int verse,
    required String bookName,
    required String prayerText,
  }) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = prayersNotifier.value[key];

    if (existing != null) {
      await _col('versePrayers').doc(existing.id).update({
        'prayerText': prayerText,
      });
    } else {
      await _col('versePrayers').add(VersePrayer(
        id: '',
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        prayerText: prayerText,
        createdAt: DateTime.now(),
      ).toMap());
    }
  }

  Future<void> deletePrayer(int bookNumber, int chapter, int verse) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = prayersNotifier.value[key];
    if (existing != null) {
      await _col('versePrayers').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PREFERENCES (Bible Settings)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadPreferences() async {
    if (_uid == null) return;
    try {
      final doc = await _settingsDoc().get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          preferredVersionNotifier.value =
              BibleVersion.fromId(data['preferredVersion'] as String? ?? 'RVR1960');
          fontSizeNotifier.value = (data['fontSize'] as num?)?.toDouble() ?? 20.0;
          readerThemeNotifier.value = data['readerTheme'] as String? ?? 'dark';
          redLettersEnabledNotifier.value = data['redLettersEnabled'] as bool? ?? true;

          // Restore recent colors from Firestore to SharedPreferences
          final cloudColors = (data['recentColors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList();
          if (cloudColors != null && cloudColors.isNotEmpty) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setStringList('bible_recent_colors', cloudColors);
          }
        }
      }
    } catch (e) {
      debugPrint('📖 [BIBLE-DATA] Error loading preferences: $e');
    }
  }

  Future<void> setPreferredVersion(BibleVersion version) async {
    preferredVersionNotifier.value = version;
    await _savePreferences();
  }

  Future<void> setFontSize(double size) async {
    fontSizeNotifier.value = size;
    await _savePreferences();
  }

  Future<void> setReaderTheme(String theme) async {
    readerThemeNotifier.value = theme;
    await _savePreferences();
  }

  Future<void> setRedLettersEnabled(bool enabled) async {
    redLettersEnabledNotifier.value = enabled;
    await _savePreferences();
  }

  Future<void> _savePreferences() async {
    if (_uid == null) return;
    await _settingsDoc().set({
      'preferredVersion': preferredVersionNotifier.value.id,
      'fontSize': fontSizeNotifier.value,
      'readerTheme': readerThemeNotifier.value,
      'redLettersEnabled': redLettersEnabledNotifier.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Sync recent highlight colors to Firestore
  Future<void> updateRecentColors(List<String> colors) async {
    if (_uid == null) return;
    await _settingsDoc().set({
      'recentColors': colors,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
