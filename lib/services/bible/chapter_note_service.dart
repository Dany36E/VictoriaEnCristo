import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/bible/chapter_study_note.dart';
import 'notas_sync.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// CHAPTER NOTE SERVICE - Singleton
/// Gestiona notas de estudio por capítulo en Firestore.
///
/// Colección: /users/{uid}/chapterNotes/{docId}
///
/// Guardado local primero: cada cambio se escribe en el teléfono y se sube
/// sin esperar al servidor ([NotasSync]), así que sin conexión nunca se
/// queda «guardando». La escucha no tiene límite y une lo que llega con lo
/// que hay en el teléfono, para que ninguna nota desaparezca de la vista.
/// ═══════════════════════════════════════════════════════════════════════════
class ChapterNoteService {
  // ── Singleton ──
  static final ChapterNoteService _instance = ChapterNoteService._internal();
  factory ChapterNoteService() => _instance;
  static ChapterNoteService get I => _instance;
  ChapterNoteService._internal();

  // ── Estado ──
  String? _uid;
  SharedPreferences? _prefs;
  StreamSubscription? _subscription;
  static const String _coleccion = 'chapterNotes';
  static const String _cachePrefix = 'chapter_notes_cache_v1';

  /// TODAS las notas, por id. Un capítulo puede tener varias.
  final ValueNotifier<Map<String, ChapterStudyNote>> notasPorIdNotifier =
      ValueNotifier(const {});

  /// chapterKey → la nota más reciente de ese capítulo (lookup rápido para la
  /// lectura). Para ver todas las de un capítulo usa [notesForChapter].
  final ValueNotifier<Map<String, ChapterStudyNote>> notesNotifier =
      ValueNotifier({});

  /// Firestore se pide solo al escuchar: las pruebas no lo necesitan.
  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore
      .instance
      .collection('users')
      .doc(_uid!)
      .collection(_coleccion);

  String _prefijo(String uid) => 'users/$uid/$_coleccion/';

  // ══════════════════════════════════════════════════════════════════════════
  // INIT / STOP
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init(String uid) async {
    if (_uid == uid) return;
    await _preparar(uid);
    debugPrint('📝 [CHAPTER-NOTES] init for $uid');
    _listen();
  }

  /// Igual que [init] pero sin escuchar Firestore (para pruebas).
  @visibleForTesting
  Future<void> initSinNube(String uid) => _preparar(uid);

  Future<void> _preparar(String uid) async {
    stop();
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();
    await NotasSync.I.cargar();
    await _loadLocalCache(uid);
    _reenviarPendientes(uid);
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    _publicar(const {});
    _uid = null;
  }

  void _listen() {
    final uid = _uid;
    if (uid == null) return;
    try {
      _subscription = _col
          .snapshots(includeMetadataChanges: true)
          .listen(
            (snap) {
              if (_uid != uid) return;
              final remoto = <String, ChapterStudyNote>{};
              for (final doc in snap.docs) {
                try {
                  remoto[doc.id] = ChapterStudyNote.fromMap(doc.id, doc.data());
                } catch (e) {
                  debugPrint('📝 [CHAPTER-NOTES] parse error: $e');
                }
              }
              aplicarSnapshot(remoto, desdeCache: snap.metadata.isFromCache);
            },
            onError: (e) {
              debugPrint('📝 [CHAPTER-NOTES] listen error: $e');
            },
          );
    } catch (e) {
      debugPrint('📝 [CHAPTER-NOTES] No se pudo escuchar la nube: $e');
    }
  }

  /// Une un snapshot COMPLETO de la nube (por id) con lo del teléfono.
  @visibleForTesting
  void aplicarSnapshot(
    Map<String, ChapterStudyNote> remoto, {
    required bool desdeCache,
  }) {
    final uid = _uid;
    if (uid == null) return;
    final prefijo = _prefijo(uid);
    final unidas = fusionarConServidor<ChapterStudyNote>(
      local: notasPorIdNotifier.value,
      remoto: remoto,
      desdeCache: desdeCache,
      guardadoPendiente: (id) => NotasSync.I.guardadoPendiente('$prefijo$id'),
      borradoPendiente: (id) => NotasSync.I.borradoPendiente('$prefijo$id'),
    );
    _publicar(unidas);
    unawaited(_saveLocalCache(unidas));
  }

  void _publicar(Map<String, ChapterStudyNote> porId) {
    notasPorIdNotifier.value = Map.unmodifiable(porId);
    final porCapitulo = <String, ChapterStudyNote>{};
    for (final nota in porId.values) {
      final actual = porCapitulo[nota.chapterKey];
      if (actual == null || nota.updatedAt.isAfter(actual.updatedAt)) {
        porCapitulo[nota.chapterKey] = nota;
      }
    }
    notesNotifier.value = Map.unmodifiable(porCapitulo);
  }

  /// Vuelve a lanzar lo que quedó sin confirmar en una sesión anterior.
  void _reenviarPendientes(String uid) {
    final prefijo = _prefijo(uid);
    for (final id in NotasSync.I.idsPendientes(prefijo, borrados: false)) {
      final nota = notasPorIdNotifier.value[id];
      if (nota != null) {
        unawaited(NotasSync.I.guardar('$prefijo$id', nota.toMap()));
      }
    }
    for (final id in NotasSync.I.idsPendientes(prefijo, borrados: true)) {
      unawaited(NotasSync.I.borrar('$prefijo$id'));
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CRUD
  // ══════════════════════════════════════════════════════════════════════════

  /// Nota más reciente de un capítulo (desde cache local).
  ChapterStudyNote? getNoteForChapter(int bookNumber, int chapter) {
    return notesNotifier.value['$bookNumber:$chapter'];
  }

  /// Todas las notas de un capítulo, la más reciente primero.
  List<ChapterStudyNote> notesForChapter(int bookNumber, int chapter) {
    return allNotes
        .where((n) => n.bookNumber == bookNumber && n.chapter == chapter)
        .toList();
  }

  ChapterStudyNote? noteById(String? id) {
    if (id == null || id.isEmpty) return null;
    return notasPorIdNotifier.value[id];
  }

  /// Id nuevo para una nota que todavía no existe. Permite que el editor
  /// autoguarde varias veces sobre el MISMO documento.
  String nuevoId() => 'cn_${DateTime.now().microsecondsSinceEpoch}';

  /// Guardar o actualizar nota. Termina en cuanto queda guardada en el
  /// teléfono; la subida sigue sola. Devuelve la nota guardada.
  Future<ChapterStudyNote?> saveNote({
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
    final uid = _uid;
    if (uid == null) return null;

    final now = DateTime.now();
    final existing = noteById(existingId);
    final id = existingId != null && existingId.isNotEmpty
        ? existingId
        : nuevoId();
    final note = ChapterStudyNote(
      id: id,
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

    final next = Map<String, ChapterStudyNote>.from(notasPorIdNotifier.value);
    next[note.id] = note;
    _publicar(next);
    await _saveLocalCache(next);

    // set(merge) en lugar de update(): si la nota se borró en otro
    // dispositivo no lanza error y lo escrito aquí no se pierde.
    unawaited(NotasSync.I.guardar('${_prefijo(uid)}${note.id}', note.toMap()));
    return note;
  }

  /// Eliminar nota
  Future<void> deleteNote(String noteId) async {
    final uid = _uid;
    if (uid == null) return;
    final next = Map<String, ChapterStudyNote>.from(notasPorIdNotifier.value)
      ..remove(noteId);
    _publicar(next);
    await _saveLocalCache(next);
    unawaited(NotasSync.I.borrar('${_prefijo(uid)}$noteId'));
  }

  /// Buscar notas por texto (title + content)
  List<ChapterStudyNote> searchNotes(String query) {
    if (query.trim().isEmpty) return allNotes;
    final q = query.toLowerCase();
    return allNotes.where((n) {
      return n.title.toLowerCase().contains(q) ||
          n.content.toLowerCase().contains(q) ||
          n.reference.toLowerCase().contains(q) ||
          n.tags.any((t) => t.toLowerCase().contains(q));
    }).toList();
  }

  /// Todas las notas ordenadas por updatedAt desc
  List<ChapterStudyNote> get allNotes {
    final list = notasPorIdNotifier.value.values.toList();
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  /// Notas filtradas por libro
  List<ChapterStudyNote> notesForBook(int bookNumber) {
    return allNotes.where((n) => n.bookNumber == bookNumber).toList();
  }

  String _cacheKey(String uid) => '$_cachePrefix.$uid';

  Future<void> _loadLocalCache(String uid) async {
    try {
      final raw = _prefs?.getString(_cacheKey(uid));
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      final notes = decoded.map(_fromLocal).whereType<ChapterStudyNote>();
      _publicar({
        for (final n in notes)
          if (n.id.isNotEmpty) n.id: n,
      });
    } catch (e) {
      debugPrint('📝 [CHAPTER-NOTES] local cache load error: $e');
    }
  }

  Future<void> _saveLocalCache(Map<String, ChapterStudyNote> notes) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _prefs?.setString(
        _cacheKey(uid),
        jsonEncode(notes.values.map(_toLocal).toList()),
      );
    } catch (e) {
      debugPrint('📝 [CHAPTER-NOTES] local cache save error: $e');
    }
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
