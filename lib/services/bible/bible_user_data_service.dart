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
import '../favorites_service.dart';
import '../theme_service.dart';
import 'bible_user_data_merge.dart';
import 'reading_history_service.dart';

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
  static final BibleUserDataService _instance =
      BibleUserDataService._internal();
  factory BibleUserDataService() => _instance;
  static BibleUserDataService get I => _instance;
  BibleUserDataService._internal();

  // ── Estado ──
  String? _uid;
  // Perezoso: crear el singleton no exige Firebase inicializado (pruebas,
  // FavoritesService al arrancar).
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  SharedPreferences? _prefs;

  static const String _cachePrefix = 'bible_user_data_cache_v1';

  // ── Notifiers reactivos ──
  final ValueNotifier<Map<String, Highlight>> highlightsNotifier =
      ValueNotifier({});
  final ValueNotifier<Map<String, BibleNote>> notesNotifier = ValueNotifier({});
  final ValueNotifier<List<SavedVerse>> savedVersesNotifier = ValueNotifier([]);
  final ValueNotifier<Map<String, VersePrayer>> prayersNotifier = ValueNotifier(
    {},
  );

  // ── Preferencias ──
  final ValueNotifier<BibleVersion> preferredVersionNotifier = ValueNotifier(
    BibleVersion.rvr1960,
  );
  final ValueNotifier<double> fontSizeNotifier = ValueNotifier(20.0);

  /// Rango único del tamaño de letra (lector y Ajustes usaban 14-28 y 14-32:
  /// con 30 guardado desde Ajustes, el panel del lector fallaba).
  static const double minFontSize = 14;
  static const double maxFontSize = 32;
  static const int fontSizeDivisions = 9; // pasos de 2 pt
  final ValueNotifier<String> readerThemeNotifier = ValueNotifier('dark');
  final ValueNotifier<bool> redLettersEnabledNotifier = ValueNotifier(true);
  final ValueNotifier<bool> useAppThemeNotifier = ValueNotifier(true);

  // ── Subscriptions ──
  final List<StreamSubscription> _subscriptions = [];

  /// UID del usuario con datos bíblicos cargados (null si no hay sesión).
  String? get currentUid => _uid;

  /// Se completa con el primer snapshot del servidor de «savedVerses» (o si
  /// el listener falla). Lo usa la migración de favoritos antiguos para no
  /// duplicar versículos que ya estaban guardados en la nube.
  Completer<void> _savedVersesSynced = Completer<void>();
  Future<void> get savedVersesSynced => _savedVersesSynced.future;

  // ══════════════════════════════════════════════════════════════════════════
  // INIT / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init(String uid) async {
    if (_uid == uid) return; // Ya inicializado para este usuario
    stop(); // Limpiar anterior si había

    _uid = uid;
    _savedVersesSynced = Completer<void>();
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

    // «Mis Favoritos» antiguos → versículos guardados (una vez por cuenta).
    unawaited(FavoritesService().migrateToBible());
    // Historial/posiciones de esta cuenta (las preferencias ya restauradas).
    unawaited(ReadingHistoryService.I.reload());
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

  DocumentReference _settingsDoc() => _firestore
      .collection('users')
      .doc(_uid!)
      .collection('bibleSettings')
      .doc('preferences');

  // ══════════════════════════════════════════════════════════════════════════
  // HIGHLIGHTS
  // ══════════════════════════════════════════════════════════════════════════

  /// Borra en segundo plano documentos duplicados detectados al fusionar.
  void _deleteDuplicates(String collection, List<String> ids) {
    for (final id in ids) {
      if (id.isEmpty) continue;
      unawaited(
        _col(collection).doc(id).delete().catchError((Object e) {
          debugPrint('[BIBLE-DATA] No se pudo borrar $collection/$id: $e');
        }),
      );
    }
  }

  void _listenHighlights() {
    // Sin límite: antes `.limit(150)` reemplazaba todo el mapa (y la caché
    // local) y los resaltados más antiguos desaparecían del lector.
    final sub = _col('bibleHighlights').snapshots().listen((snap) {
      final incoming = <Highlight>[];
      for (final doc in snap.docs) {
        try {
          incoming.add(
            Highlight.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          );
        } catch (e) {
          debugPrint('[BIBLE-DATA] Highlight parse error: $e');
        }
      }
      final merged = BibleUserDataMerge.merge<Highlight>(
        current: highlightsNotifier.value,
        incoming: incoming,
        keyOf: (h) => h.verseKey,
        idOf: (h) => h.id,
        dateOf: (h) => h.createdAt,
        authoritative: !snap.metadata.isFromCache,
      );
      highlightsNotifier.value = Map.unmodifiable(merged.items);
      unawaited(_saveHighlightsCache(merged.items));
      _deleteDuplicates('bibleHighlights', merged.duplicateIds);
    }, onError: (Object e) => debugPrint('[BIBLE-DATA] Highlights: $e'));
    _subscriptions.add(sub);
  }

  Future<void> addHighlight({
    required String versionId,
    required int bookNumber,
    required int chapter,
    required int verse,
    required String colorHex,
  }) async {
    if (_uid == null) return;
    final key = Highlight.keyFor(versionId, bookNumber, chapter, verse);

    final existing = highlightsNotifier.value[key];
    final doc = _col('bibleHighlights').doc();
    final highlight = Highlight(
      id: doc.id,
      versionId: versionId,
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

  Future<void> removeHighlight(
    String versionId,
    int bookNumber,
    int chapter,
    int verse,
  ) async {
    if (_uid == null) return;
    final key = Highlight.keyFor(versionId, bookNumber, chapter, verse);
    final existing = highlightsNotifier.value[key];
    if (existing != null) {
      final next = Map<String, Highlight>.from(highlightsNotifier.value)
        ..remove(key);
      highlightsNotifier.value = Map.unmodifiable(next);
      await _saveHighlightsCache(next);
      await _col('bibleHighlights').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // NOTES
  // ══════════════════════════════════════════════════════════════════════════

  void _listenNotes() {
    // Sin límite (antes 200): ver _listenHighlights.
    final sub = _col('bibleNotes').snapshots().listen((snap) {
      final incoming = <BibleNote>[];
      for (final doc in snap.docs) {
        try {
          incoming.add(
            BibleNote.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          );
        } catch (e) {
          debugPrint('[BIBLE-DATA] Note parse error: $e');
        }
      }
      final merged = BibleUserDataMerge.merge<BibleNote>(
        current: notesNotifier.value,
        incoming: incoming,
        keyOf: (n) => n.verseKey,
        idOf: (n) => n.id,
        dateOf: (n) => n.updatedAt,
        authoritative: !snap.metadata.isFromCache,
      );
      notesNotifier.value = Map.unmodifiable(merged.items);
      unawaited(_saveNotesCache(merged.items));
      _deleteDuplicates('bibleNotes', merged.duplicateIds);
    }, onError: (Object e) => debugPrint('[BIBLE-DATA] Notes: $e'));
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
      await _col('bibleNotes').doc(existing.id).update({
        'text': text,
        'updatedAt': Timestamp.fromDate(now),
      });
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
      final next = Map<String, BibleNote>.from(notesNotifier.value)
        ..remove(key);
      notesNotifier.value = Map.unmodifiable(next);
      await _saveNotesCache(next);
      await _col('bibleNotes').doc(existing.id).delete();
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SAVED VERSES (Marcadores)
  // ══════════════════════════════════════════════════════════════════════════

  void _listenSavedVerses() {
    // Sin límite (antes 200): ver _listenHighlights.
    final sub = _col('savedVerses').snapshots().listen(
      (snap) {
        final incoming = <SavedVerse>[];
        for (final doc in snap.docs) {
          try {
            incoming.add(
              SavedVerse.fromMap(doc.id, doc.data() as Map<String, dynamic>),
            );
          } catch (e) {
            debugPrint('[BIBLE-DATA] SavedVerse parse error: $e');
          }
        }
        final authoritative = !snap.metadata.isFromCache;
        final merged = BibleUserDataMerge.merge<SavedVerse>(
          current: {for (final v in savedVersesNotifier.value) v.verseKey: v},
          incoming: incoming,
          keyOf: (v) => v.verseKey,
          idOf: (v) => v.id,
          dateOf: (v) => v.savedAt,
          authoritative: authoritative,
        );
        final list = BibleUserDataMerge.sortedByDateDesc<SavedVerse>(
          merged.items,
          (v) => v.savedAt,
        );
        savedVersesNotifier.value = List.unmodifiable(list);
        unawaited(_saveSavedVersesCache(list));
        _deleteDuplicates('savedVerses', merged.duplicateIds);
        if (authoritative && !_savedVersesSynced.isCompleted) {
          _savedVersesSynced.complete();
        }
      },
      onError: (Object e) {
        debugPrint('[BIBLE-DATA] SavedVerses: $e');
        if (!_savedVersesSynced.isCompleted) _savedVersesSynced.complete();
      },
    );
    _subscriptions.add(sub);
  }

  bool isVerseSaved(int bookNumber, int chapter, int verse) {
    return savedVersesNotifier.value.any(
      (s) =>
          s.bookNumber == bookNumber &&
          s.chapter == chapter &&
          s.verse == verse,
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
    if (isVerseSaved(bookNumber, chapter, verse)) {
      await removeSavedVerse(bookNumber, chapter, verse);
    } else {
      await saveVerse(
        bookNumber: bookNumber,
        chapter: chapter,
        verse: verse,
        bookName: bookName,
        text: text,
        version: version,
      );
    }
  }

  /// Guarda un versículo (o un pasaje con [endVerse]) si no estaba guardado.
  /// Devuelve false si ya existía. La escritura en la nube no se espera:
  /// Firestore la encola sin red y el estado local se actualiza al instante.
  Future<bool> saveVerse({
    required int bookNumber,
    required int chapter,
    required int verse,
    int? endVerse,
    required String bookName,
    required String text,
    required String version,
    DateTime? savedAt,
  }) async {
    if (_uid == null) return false;
    if (isVerseSaved(bookNumber, chapter, verse)) return false;
    final doc = _col('savedVerses').doc();
    final saved = SavedVerse(
      id: doc.id,
      bookNumber: bookNumber,
      chapter: chapter,
      verse: verse,
      endVerse: endVerse,
      bookName: bookName,
      text: text,
      version: version,
      savedAt: savedAt ?? DateTime.now(),
    );
    final next = BibleUserDataMerge.sortedByDateDesc<SavedVerse>({
      for (final v in savedVersesNotifier.value) v.verseKey: v,
      saved.verseKey: saved,
    }, (v) => v.savedAt);
    savedVersesNotifier.value = List.unmodifiable(next);
    await _saveSavedVersesCache(next);
    unawaited(
      doc.set(saved.toMap()).catchError((Object e) {
        debugPrint('[BIBLE-DATA] saveVerse: $e');
      }),
    );
    return true;
  }

  /// Quita el versículo guardado (y cualquier duplicado del mismo versículo).
  Future<void> removeSavedVerse(int bookNumber, int chapter, int verse) async {
    if (_uid == null) return;
    final ids = savedVersesNotifier.value
        .where(
          (s) =>
              s.bookNumber == bookNumber &&
              s.chapter == chapter &&
              s.verse == verse,
        )
        .map((s) => s.id)
        .toSet();
    if (ids.isEmpty) return;
    final next = savedVersesNotifier.value
        .where((s) => !ids.contains(s.id))
        .toList(growable: false);
    savedVersesNotifier.value = List.unmodifiable(next);
    await _saveSavedVersesCache(next);
    _deleteDuplicates('savedVerses', ids.toList());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PRAYERS
  // ══════════════════════════════════════════════════════════════════════════

  void _listenPrayers() {
    // Sin límite (antes 150): ver _listenHighlights.
    final sub = _col('versePrayers').snapshots().listen((snap) {
      final incoming = <VersePrayer>[];
      for (final doc in snap.docs) {
        try {
          incoming.add(
            VersePrayer.fromMap(doc.id, doc.data() as Map<String, dynamic>),
          );
        } catch (e) {
          debugPrint('[BIBLE-DATA] Prayer parse error: $e');
        }
      }
      final merged = BibleUserDataMerge.merge<VersePrayer>(
        current: prayersNotifier.value,
        incoming: incoming,
        keyOf: (p) => p.verseKey,
        idOf: (p) => p.id,
        dateOf: (p) => p.createdAt,
        authoritative: !snap.metadata.isFromCache,
      );
      prayersNotifier.value = Map.unmodifiable(merged.items);
      unawaited(_savePrayersCache(merged.items));
      _deleteDuplicates('versePrayers', merged.duplicateIds);
    }, onError: (Object e) => debugPrint('[BIBLE-DATA] Prayers: $e'));
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
      await _col(
        'versePrayers',
      ).doc(existing.id).update({'prayerText': prayerText});
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
      final next = Map<String, VersePrayer>.from(prayersNotifier.value)
        ..remove(key);
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
          fontSizeNotifier.value =
              (data['fontSize'] as num?)?.toDouble() ?? 20.0;
          readerThemeNotifier.value = data['readerTheme'] as String? ?? 'dark';
          redLettersEnabledNotifier.value =
              data['redLettersEnabled'] as bool? ?? true;
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

  /// El deslizador de tamaño cambia varias veces por segundo: se guarda una
  /// sola vez cuando la persona deja de moverlo (antes, una escritura en la
  /// nube por cada paso).
  Timer? _fontSizeDebounce;

  Future<void> setFontSize(double size) async {
    fontSizeNotifier.value = size;
    _fontSizeDebounce?.cancel();
    _fontSizeDebounce = Timer(
      const Duration(milliseconds: 1200),
      () => unawaited(_savePreferences()),
    );
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
      final notes = _decodeList(
        _cacheKey(uid, 'notes'),
      ).map(_noteFromLocal).whereType<BibleNote>();
      final savedVerses =
          _decodeList(
              _cacheKey(uid, 'savedVerses'),
            ).map(_savedVerseFromLocal).whereType<SavedVerse>().toList()
            ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      final prayers = _decodeList(
        _cacheKey(uid, 'prayers'),
      ).map(_prayerFromLocal).whereType<VersePrayer>();

      highlightsNotifier.value = Map.unmodifiable({
        for (final h in highlights) h.verseKey: h,
      });
      notesNotifier.value = Map.unmodifiable({
        for (final n in notes) n.verseKey: n,
      });
      savedVersesNotifier.value = List.unmodifiable(savedVerses);
      prayersNotifier.value = Map.unmodifiable({
        for (final p in prayers) p.verseKey: p,
      });
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
      redLettersEnabledNotifier.value =
          data['redLettersEnabled'] as bool? ?? true;
      useAppThemeNotifier.value = data['useAppTheme'] as bool? ?? true;
      final recentColors = (data['recentColors'] as List?)
          ?.map((e) => e.toString())
          .toList();
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
    final colors =
        recentColors ??
        _prefs?.getStringList('bible_recent_colors') ??
        const <String>[];
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
    'versionId': h.versionId,
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
        versionId: data['versionId'] as String? ?? 'RVR1960',
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
    if (s.endVerse != null) 'endVerse': s.endVerse,
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
        endVerse: data['endVerse'] == null ? null : _asInt(data['endVerse']),
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

  int _asInt(dynamic value) =>
      value is num ? value.toInt() : int.parse(value.toString());

  DateTime _dateFromMs(dynamic value) {
    if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateTime.now();
  }
}
