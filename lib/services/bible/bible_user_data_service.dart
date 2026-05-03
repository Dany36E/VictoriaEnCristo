import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/highlight.dart';
import '../../models/bible/bible_note.dart';
import '../../models/bible/saved_verse.dart';
import '../../models/bible/verse_prayer.dart';
import '../../models/bible/bible_version.dart';
import '../theme_service.dart';

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
  SharedPreferences? _prefs;

  static const String _cachePrefix = 'bible_user_data_cache_v1';

  // ── Notifiers reactivos ──
  final ValueNotifier<Map<String, Highlight>> highlightsNotifier = ValueNotifier({});
  final ValueNotifier<Map<String, BibleNote>> notesNotifier = ValueNotifier({});
  final ValueNotifier<List<SavedVerse>> savedVersesNotifier = ValueNotifier([]);
  final ValueNotifier<Map<String, VersePrayer>> prayersNotifier = ValueNotifier({});

  // ── Preferencias ──
  final ValueNotifier<BibleVersion> preferredVersionNotifier = ValueNotifier(BibleVersion.rvr1960);
  final ValueNotifier<double> fontSizeNotifier = ValueNotifier(20.0);
  final ValueNotifier<String> readerThemeNotifier = ValueNotifier('dark');
  final ValueNotifier<bool> redLettersEnabledNotifier = ValueNotifier(true);
  final ValueNotifier<bool> useAppThemeNotifier = ValueNotifier(true);

  // ── Subscriptions ──
  final List<StreamSubscription> _subscriptions = [];

  // ══════════════════════════════════════════════════════════════════════════
  // INIT / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init(String uid) async {
    if (_uid == uid) return; // Ya inicializado para este usuario
    stop(); // Limpiar anterior si había

    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    debugPrint('📖 [BIBLE-DATA] init for $uid');

    // Cargar cache local primero para que el lector funcione sin red.
    await _loadLocalCache(uid);

    // Cargar preferencias
    await _loadPreferences();

    // Vincular tema de la Biblia al tema de la app si useAppTheme está activo
    _syncBibleThemeToApp();

    // Escuchar colecciones
    _listenHighlights();
    _listenNotes();
    _listenSavedVerses();
    _listenPrayers();
  }

  void stop() {
    ThemeService().themeIdNotifier.removeListener(_onAppThemeChanged);
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
    // Límite duro a 2000 highlights más recientes para acotar lecturas en
    // cuentas con mucho histórico. Cualquier highlight más antiguo sigue
    // existiendo en Firestore (no se borra) pero no se descarga.
    final sub = _col('bibleHighlights')
        .orderBy('createdAt', descending: true)
        .limit(2000)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty && snap.metadata.isFromCache && highlightsNotifier.value.isNotEmpty) {
        debugPrint('📖 [BIBLE-DATA] Keeping cached highlights while offline');
        return;
      }
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
      unawaited(_saveHighlightsCache(map));
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

    final existing = highlightsNotifier.value[key];
    final doc = _col('bibleHighlights').doc();
    final highlight = Highlight(
      id: doc.id,
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      colorHex: colorHex,
      createdAt: DateTime.now(),
    );

    final next = Map<String, Highlight>.from(highlightsNotifier.value);
    if (existing != null) {
      next.remove(key);
    }
    next[key] = highlight;
    highlightsNotifier.value = Map.unmodifiable(next);
    await _saveHighlightsCache(next);

    if (existing != null) {
      await _col('bibleHighlights').doc(existing.id).delete();
    }

    await doc.set(highlight.toMap());
  }

  Future<void> removeHighlight(int bookNumber, int chapter, int verse) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = highlightsNotifier.value[key];
    if (existing != null) {
      final next = Map<String, Highlight>.from(highlightsNotifier.value)..remove(key);
      highlightsNotifier.value = Map.unmodifiable(next);
      await _saveHighlightsCache(next);
      await _col('bibleHighlights').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTES
  // ══════════════════════════════════════════════════════════════════════════

  void _listenNotes() {
    final sub = _col('bibleNotes')
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty && snap.metadata.isFromCache && notesNotifier.value.isNotEmpty) {
        debugPrint('📖 [BIBLE-DATA] Keeping cached notes while offline');
        return;
      }
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
      unawaited(_saveNotesCache(map));
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
    final next = Map<String, BibleNote>.from(notesNotifier.value);

    if (existing != null) {
      final updated = existing.copyWith(text: text, updatedAt: now);
      next[key] = updated;
      notesNotifier.value = Map.unmodifiable(next);
      await _saveNotesCache(next);
      // Update
      await _col(
        'bibleNotes',
      ).doc(existing.id).update({'text': text, 'updatedAt': Timestamp.fromDate(now)});
    } else {
      final doc = _col('bibleNotes').doc();
      final note = BibleNote(
        id: doc.id,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        text: text,
        createdAt: now,
        updatedAt: now,
      );
      next[key] = note;
      notesNotifier.value = Map.unmodifiable(next);
      await _saveNotesCache(next);
      // Create
      await doc.set(note.toMap());
    }
  }

  Future<void> deleteNote(int bookNumber, int chapter, int verse) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = notesNotifier.value[key];
    if (existing != null) {
      final next = Map<String, BibleNote>.from(notesNotifier.value)..remove(key);
      notesNotifier.value = Map.unmodifiable(next);
      await _saveNotesCache(next);
      await _col('bibleNotes').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVED VERSES (Marcadores)
  // ══════════════════════════════════════════════════════════════════════════

  void _listenSavedVerses() {
    final sub = _col('savedVerses')
        .orderBy('savedAt', descending: true)
        .limit(500)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty && snap.metadata.isFromCache && savedVersesNotifier.value.isNotEmpty) {
        debugPrint('📖 [BIBLE-DATA] Keeping cached saved verses while offline');
        return;
      }
      final list = <SavedVerse>[];
      for (final doc in snap.docs) {
        try {
          list.add(SavedVerse.fromMap(doc.id, doc.data() as Map<String, dynamic>));
        } catch (e) {
          debugPrint('[BIBLE-DATA] SavedVerse parse error: $e');
        }
      }
      savedVersesNotifier.value = List.unmodifiable(list);
      unawaited(_saveSavedVersesCache(list));
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
      final next = savedVersesNotifier.value
          .where((s) => s.id != existing.first.id)
          .toList(growable: false);
      savedVersesNotifier.value = List.unmodifiable(next);
      await _saveSavedVersesCache(next);
      await _col('savedVerses').doc(existing.first.id).delete();
    } else {
      final doc = _col('savedVerses').doc();
      final saved = SavedVerse(
        id: doc.id,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        text: text,
        version: version,
        savedAt: DateTime.now(),
      );
      final next = [saved, ...savedVersesNotifier.value];
      savedVersesNotifier.value = List.unmodifiable(next);
      await _saveSavedVersesCache(next);
      // Add
      await doc.set(saved.toMap());
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRAYERS
  // ══════════════════════════════════════════════════════════════════════════

  void _listenPrayers() {
    final sub = _col('versePrayers')
        .orderBy('createdAt', descending: true)
        .limit(500)
        .snapshots()
        .listen((snap) {
      if (snap.docs.isEmpty && snap.metadata.isFromCache && prayersNotifier.value.isNotEmpty) {
        debugPrint('📖 [BIBLE-DATA] Keeping cached verse prayers while offline');
        return;
      }
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
      unawaited(_savePrayersCache(map));
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
    final next = Map<String, VersePrayer>.from(prayersNotifier.value);

    if (existing != null) {
      final updated = VersePrayer(
        id: existing.id,
        bookNumber: existing.bookNumber,
        chapter: existing.chapter,
        verse: existing.verse,
        bookName: existing.bookName,
        prayerText: prayerText,
        createdAt: existing.createdAt,
      );
      next[key] = updated;
      prayersNotifier.value = Map.unmodifiable(next);
      await _savePrayersCache(next);
      await _col('versePrayers').doc(existing.id).update({'prayerText': prayerText});
    } else {
      final doc = _col('versePrayers').doc();
      final prayer = VersePrayer(
        id: doc.id,
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        prayerText: prayerText,
        createdAt: DateTime.now(),
      );
      next[key] = prayer;
      prayersNotifier.value = Map.unmodifiable(next);
      await _savePrayersCache(next);
      await doc.set(prayer.toMap());
    }
  }

  Future<void> deletePrayer(int bookNumber, int chapter, int verse) async {
    if (_uid == null) return;
    final key = '$bookNumber:$chapter:$verse';
    final existing = prayersNotifier.value[key];
    if (existing != null) {
      final next = Map<String, VersePrayer>.from(prayersNotifier.value)..remove(key);
      prayersNotifier.value = Map.unmodifiable(next);
      await _savePrayersCache(next);
      await _col('versePrayers').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PREFERENCES (Bible Settings)
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> _loadPreferences() async {
    if (_uid == null) return;
    await _loadLocalPreferences(_uid!);
    try {
      final doc = await _settingsDoc().get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          preferredVersionNotifier.value = BibleVersion.fromId(
            data['preferredVersion'] as String? ?? 'RVR1960',
          );
          fontSizeNotifier.value = (data['fontSize'] as num?)?.toDouble() ?? 20.0;
          readerThemeNotifier.value = data['readerTheme'] as String? ?? 'dark';
          redLettersEnabledNotifier.value = data['redLettersEnabled'] as bool? ?? true;
          useAppThemeNotifier.value = data['useAppTheme'] as bool? ?? true;

          // Restore recent colors from Firestore to SharedPreferences
          final cloudColors = (data['recentColors'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList();
          if (cloudColors != null && cloudColors.isNotEmpty) {
            await _prefs?.setStringList('bible_recent_colors', cloudColors);
          }
          await _saveLocalPreferences(recentColors: cloudColors);
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
    // Si el usuario elige manualmente un tema de Biblia, desactivar "usar tema de app"
    if (useAppThemeNotifier.value) {
      useAppThemeNotifier.value = false;
      ThemeService().themeIdNotifier.removeListener(_onAppThemeChanged);
    }
    await _savePreferences();
  }

  Future<void> setRedLettersEnabled(bool enabled) async {
    redLettersEnabledNotifier.value = enabled;
    await _savePreferences();
  }

  /// Activar/desactivar "Usar tema de la app" para la Biblia
  Future<void> setUseAppTheme(bool enabled) async {
    useAppThemeNotifier.value = enabled;
    _syncBibleThemeToApp();
    await _savePreferences();
  }

  /// Sincroniza el tema de la Biblia con el de la app
  void _syncBibleThemeToApp() {
    final ts = ThemeService();
    // Siempre remover primero para evitar duplicados
    ts.themeIdNotifier.removeListener(_onAppThemeChanged);
    if (useAppThemeNotifier.value) {
      readerThemeNotifier.value = ts.themeId;
      ts.themeIdNotifier.addListener(_onAppThemeChanged);
    }
  }

  void _onAppThemeChanged() {
    if (useAppThemeNotifier.value) {
      readerThemeNotifier.value = ThemeService().themeId;
    }
  }

  Future<void> _savePreferences() async {
    if (_uid == null) return;
    await _saveLocalPreferences();
    await _settingsDoc().set({
      'preferredVersion': preferredVersionNotifier.value.id,
      'fontSize': fontSizeNotifier.value,
      'readerTheme': readerThemeNotifier.value,
      'redLettersEnabled': redLettersEnabledNotifier.value,
      'useAppTheme': useAppThemeNotifier.value,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Sync recent highlight colors to Firestore
  Future<void> updateRecentColors(List<String> colors) async {
    if (_uid == null) return;
    await _prefs?.setStringList('bible_recent_colors', colors);
    await _saveLocalPreferences(recentColors: colors);
    await _settingsDoc().set({
      'recentColors': colors,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // LOCAL CACHE (desktop/offline-first)
  // ══════════════════════════════════════════════════════════════════════════

  String _cacheKey(String uid, String name) => '$_cachePrefix.$uid.$name';

  Future<void> _loadLocalCache(String uid) async {
    try {
      final highlights = _decodeList(
        _cacheKey(uid, 'highlights'),
      ).map(_highlightFromLocal).whereType<Highlight>();
      final notes = _decodeList(_cacheKey(uid, 'notes')).map(_noteFromLocal).whereType<BibleNote>();
      final savedVerses =
          _decodeList(
              _cacheKey(uid, 'savedVerses'),
            ).map(_savedVerseFromLocal).whereType<SavedVerse>().toList()
            ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      final prayers = _decodeList(
        _cacheKey(uid, 'prayers'),
      ).map(_prayerFromLocal).whereType<VersePrayer>();

      highlightsNotifier.value = Map.unmodifiable({for (final h in highlights) h.verseKey: h});
      notesNotifier.value = Map.unmodifiable({for (final n in notes) n.verseKey: n});
      savedVersesNotifier.value = List.unmodifiable(savedVerses);
      prayersNotifier.value = Map.unmodifiable({for (final p in prayers) p.verseKey: p});
    } catch (e) {
      debugPrint('📖 [BIBLE-DATA] Local cache load error: $e');
    }
  }

  List<dynamic> _decodeList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    return decoded is List ? decoded : const [];
  }

  Future<void> _saveHighlightsCache(Map<String, Highlight> data) async {
    final uid = _uid;
    if (uid == null) return;
    await _prefs?.setString(
      _cacheKey(uid, 'highlights'),
      jsonEncode(data.values.map(_highlightToLocal).toList()),
    );
  }

  Future<void> _saveNotesCache(Map<String, BibleNote> data) async {
    final uid = _uid;
    if (uid == null) return;
    await _prefs?.setString(
      _cacheKey(uid, 'notes'),
      jsonEncode(data.values.map(_noteToLocal).toList()),
    );
  }

  Future<void> _saveSavedVersesCache(List<SavedVerse> data) async {
    final uid = _uid;
    if (uid == null) return;
    await _prefs?.setString(
      _cacheKey(uid, 'savedVerses'),
      jsonEncode(data.map(_savedVerseToLocal).toList()),
    );
  }

  Future<void> _savePrayersCache(Map<String, VersePrayer> data) async {
    final uid = _uid;
    if (uid == null) return;
    await _prefs?.setString(
      _cacheKey(uid, 'prayers'),
      jsonEncode(data.values.map(_prayerToLocal).toList()),
    );
  }

  Future<void> _loadLocalPreferences(String uid) async {
    final raw = _prefs?.getString(_cacheKey(uid, 'preferences'));
    if (raw == null || raw.isEmpty) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      preferredVersionNotifier.value = BibleVersion.fromId(
        data['preferredVersion'] as String? ?? 'RVR1960',
      );
      fontSizeNotifier.value = (data['fontSize'] as num?)?.toDouble() ?? 20.0;
      readerThemeNotifier.value = data['readerTheme'] as String? ?? 'dark';
      redLettersEnabledNotifier.value = data['redLettersEnabled'] as bool? ?? true;
      useAppThemeNotifier.value = data['useAppTheme'] as bool? ?? true;
      final recentColors = (data['recentColors'] as List?)?.map((e) => e.toString()).toList();
      if (recentColors != null && recentColors.isNotEmpty) {
        await _prefs?.setStringList('bible_recent_colors', recentColors);
      }
    } catch (e) {
      debugPrint('📖 [BIBLE-DATA] Local preferences load error: $e');
    }
  }

  Future<void> _saveLocalPreferences({List<String>? recentColors}) async {
    final uid = _uid;
    if (uid == null) return;
    final colors = recentColors ?? _prefs?.getStringList('bible_recent_colors') ?? const <String>[];
    await _prefs?.setString(
      _cacheKey(uid, 'preferences'),
      jsonEncode({
        'preferredVersion': preferredVersionNotifier.value.id,
        'fontSize': fontSizeNotifier.value,
        'readerTheme': readerThemeNotifier.value,
        'redLettersEnabled': redLettersEnabledNotifier.value,
        'useAppTheme': useAppThemeNotifier.value,
        'recentColors': colors,
      }),
    );
  }

  Map<String, dynamic> _highlightToLocal(Highlight h) => {
    'id': h.id,
    'bookNumber': h.bookNumber,
    'chapter': h.chapter,
    'verse': h.verse,
    'colorHex': h.colorHex,
    'createdAtMs': h.createdAt.millisecondsSinceEpoch,
  };

  Highlight? _highlightFromLocal(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      return Highlight(
        id: data['id'] as String? ?? '',
        bookNumber: _asInt(data['bookNumber']),
        chapter: _asInt(data['chapter']),
        verse: _asInt(data['verse']),
        colorHex: data['colorHex'] as String? ?? '#FFF176',
        createdAt: _dateFromMs(data['createdAtMs']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _noteToLocal(BibleNote n) => {
    'id': n.id,
    'bookNumber': n.bookNumber,
    'chapter': n.chapter,
    'verse': n.verse,
    'bookName': n.bookName,
    'text': n.text,
    'createdAtMs': n.createdAt.millisecondsSinceEpoch,
    'updatedAtMs': n.updatedAt.millisecondsSinceEpoch,
  };

  BibleNote? _noteFromLocal(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      return BibleNote(
        id: data['id'] as String? ?? '',
        bookNumber: _asInt(data['bookNumber']),
        chapter: _asInt(data['chapter']),
        verse: _asInt(data['verse']),
        bookName: data['bookName'] as String? ?? '',
        text: data['text'] as String? ?? '',
        createdAt: _dateFromMs(data['createdAtMs']),
        updatedAt: _dateFromMs(data['updatedAtMs']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _savedVerseToLocal(SavedVerse s) => {
    'id': s.id,
    'bookNumber': s.bookNumber,
    'chapter': s.chapter,
    'verse': s.verse,
    'bookName': s.bookName,
    'text': s.text,
    'version': s.version,
    'savedAtMs': s.savedAt.millisecondsSinceEpoch,
  };

  SavedVerse? _savedVerseFromLocal(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      return SavedVerse(
        id: data['id'] as String? ?? '',
        bookNumber: _asInt(data['bookNumber']),
        chapter: _asInt(data['chapter']),
        verse: _asInt(data['verse']),
        bookName: data['bookName'] as String? ?? '',
        text: data['text'] as String? ?? '',
        version: data['version'] as String? ?? 'RVR1960',
        savedAt: _dateFromMs(data['savedAtMs']),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _prayerToLocal(VersePrayer p) => {
    'id': p.id,
    'bookNumber': p.bookNumber,
    'chapter': p.chapter,
    'verse': p.verse,
    'bookName': p.bookName,
    'prayerText': p.prayerText,
    'createdAtMs': p.createdAt.millisecondsSinceEpoch,
  };

  VersePrayer? _prayerFromLocal(dynamic raw) {
    try {
      final data = Map<String, dynamic>.from(raw as Map);
      return VersePrayer(
        id: data['id'] as String? ?? '',
        bookNumber: _asInt(data['bookNumber']),
        chapter: _asInt(data['chapter']),
        verse: _asInt(data['verse']),
        bookName: data['bookName'] as String? ?? '',
        prayerText: data['prayerText'] as String? ?? '',
        createdAt: _dateFromMs(data['createdAtMs']),
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
