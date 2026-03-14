/// ═══════════════════════════════════════════════════════════════════════════
/// JOURNAL REPOSITORY - Repositorio de diario con Cloud Sync
/// Fuente de verdad: Firestore /users/{uid}/journalEntries/{id}
/// Cache local: SharedPreferences
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/journal_entry_cloud.dart';
import '../utils/time_utils.dart';

class JournalRepository {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════
  
  static final JournalRepository _instance = JournalRepository._internal();
  factory JournalRepository() => _instance;
  JournalRepository._internal();
  
  static JournalRepository get I => _instance;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static const String _keyJournalCache = 'journal_cache_v1';
  static const String _keyPendingWrites = 'journal_pending_writes';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  bool _isInitialized = false;
  
  /// Cache: id -> JournalEntryCloud
  Map<String, JournalEntryCloud> _cache = {};
  
  /// Acceso de solo lectura al cache (para hidratar JournalService)
  Map<String, JournalEntryCloud> get cachedEntries => Map.unmodifiable(_cache);
  
  /// Cola de operaciones pendientes
  List<Map<String, dynamic>> _pendingOps = [];
  
  /// Suscripción a cambios
  StreamSubscription<QuerySnapshot>? _realtimeSubscription;

  /// Guard contra connectUser concurrente (race condition)
  String? _connectingUid;
  Future<void>? _connectFuture;
  
  /// Notificador de cambios
  final ValueNotifier<List<JournalEntryCloud>> entriesNotifier = ValueNotifier([]);
  
  bool get isInitialized => _isInitialized;
  String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;
  
  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> init() async {
    if (_isInitialized) return;
    
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadLocalCache();
      await _loadPendingOps();
      
      _isInitialized = true;
      _updateNotifier();
      
      debugPrint('📓 [JOURNAL_REPO] Initialized with ${_cache.length} cached entries');
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Init error: $e');
      _isInitialized = true;
    }
  }
  
  /// Conectar con usuario y sincronizar
  /// CLOUD-FIRST: Siempre descargar desde Firestore, nunca subir cache stale
  Future<void> connectUser(String uid) async {
    // Guard: si ya hay un connectUser en progreso para este UID, esperar
    if (_connectingUid == uid && _connectFuture != null) {
      debugPrint('📓 [JOURNAL_REPO] connectUser already in progress for $uid, awaiting...');
      await _connectFuture;
      return;
    }
    
    _connectingUid = uid;
    _connectFuture = _doConnectUser(uid);
    await _connectFuture;
  }
  
  Future<void> _doConnectUser(String uid) async {
    if (!_isInitialized) await init();
    
    try {
      debugPrint('📓 [JOURNAL_REPO] Connecting user: $uid');
      
      await _realtimeSubscription?.cancel();
      
      // CRÍTICO: Limpiar cache local antes de descargar de cloud.
      _cache.clear();
      _pendingOps.clear();
      
      // Sincronizar con nube (PULL-ONLY)
      await _syncWithCloud(uid);
      
      _startRealtimeSync(uid);
      _updateNotifier();
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Connect error: $e');
    } finally {
      _connectingUid = null;
      _connectFuture = null;
    }
  }
  
  /// Desconectar usuario (NO borra datos)
  Future<void> disconnectUser() async {
    debugPrint('📓 [JOURNAL_REPO] Disconnecting (keeping data)');
    _connectingUid = null;
    _connectFuture = null;
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
  }
  
  /// Limpiar cache local (usado al cambiar de cuenta)
  Future<void> clearLocalCache() async {
    debugPrint('📓 [JOURNAL_REPO] Clearing local cache');
    
    _connectingUid = null;
    _connectFuture = null;
    
    // Cancelar listener
    await _realtimeSubscription?.cancel();
    _realtimeSubscription = null;
    
    // Limpiar cache en memoria
    _cache.clear();
    _pendingOps.clear();
    
    // Limpiar SharedPreferences
    await _prefs?.remove(_keyJournalCache);
    await _prefs?.remove(_keyPendingWrites);
    
    // Reset notifier
    entriesNotifier.value = [];
    
    debugPrint('📓 [JOURNAL_REPO] ✅ Local cache cleared');
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LECTURA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener todas las entradas ordenadas por fecha
  List<JournalEntryCloud> getAll() {
    final list = _cache.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
  
  /// Obtener entrada por ID
  JournalEntryCloud? getById(String id) {
    return _cache[id];
  }
  
  /// Obtener entradas de un día
  List<JournalEntryCloud> getByDate(DateTime date) {
    final dateISO = _dateToISO(date);
    return _cache.values
        .where((e) => e.dateISO == dateISO)
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  /// Obtener entradas de hoy
  List<JournalEntryCloud> getTodayEntries() {
    return getByDate(DateTime.now());
  }
  
  /// Buscar entradas por contenido
  List<JournalEntryCloud> search(String query) {
    final lowerQuery = query.toLowerCase();
    return _cache.values
        .where((e) => e.content.toLowerCase().contains(lowerQuery))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // ESCRITURA
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Agregar nueva entrada
  Future<JournalEntryCloud> add({
    required String content,
    required String mood,
    List<String> triggers = const [],
    bool hadVictory = true,
    String? verseOfDay,
  }) async {
    if (!_isInitialized) await init();
    
    final entry = JournalEntryCloud.create(
      content: content,
      mood: mood,
      triggers: triggers,
      hadVictory: hadVictory,
      verseOfDay: verseOfDay,
    );
    
    _cache[entry.id] = entry;
    await _saveLocalCache();
    
    final uid = _currentUid;
    if (uid != null) {
      await _saveToCloud(uid, entry);
    } else {
      _addPendingOp({'type': 'add', 'id': entry.id});
    }
    
    _updateNotifier();
    
    debugPrint('📓 [JOURNAL_REPO] Added entry: ${entry.id}');
    return entry;
  }
  
  /// Actualizar entrada existente
  Future<bool> update(String id, {
    String? content,
    String? mood,
    List<String>? triggers,
    bool? hadVictory,
    String? verseOfDay,
  }) async {
    final existing = _cache[id];
    if (existing == null) return false;
    
    final updated = existing.copyWith(
      content: content,
      mood: mood,
      triggers: triggers,
      hadVictory: hadVictory,
      verseOfDay: verseOfDay,
    );
    
    _cache[id] = updated;
    await _saveLocalCache();
    
    final uid = _currentUid;
    if (uid != null) {
      await _saveToCloud(uid, updated);
    } else {
      _addPendingOp({'type': 'update', 'id': id});
    }
    
    _updateNotifier();
    
    debugPrint('📓 [JOURNAL_REPO] Updated entry: $id');
    return true;
  }
  
  /// Eliminar entrada
  Future<bool> delete(String id) async {
    if (!_cache.containsKey(id)) return false;
    
    _cache.remove(id);
    await _saveLocalCache();
    
    final uid = _currentUid;
    if (uid != null) {
      await _deleteFromCloud(uid, id);
    } else {
      _addPendingOp({'type': 'delete', 'id': id});
    }
    
    _updateNotifier();
    
    debugPrint('📓 [JOURNAL_REPO] Deleted entry: $id');
    return true;
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUD OPERATIONS
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _syncWithCloud(String uid) async {
    try {
      // CLOUD-FIRST: Siempre descargar desde Firestore como fuente de verdad.
      // NUNCA subir cache local durante el sync — un cache vacío post-logout
      // NO debe sobreescribir datos existentes en la nube.
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .orderBy('timestamp', descending: true)
          .get(const GetOptions(source: Source.server));
      
      if (snapshot.docs.isNotEmpty) {
        // Nube tiene datos -> SIEMPRE usar como fuente de verdad
        debugPrint('📓 [JOURNAL_REPO] Loading ${snapshot.docs.length} entries from cloud');
        
        _cache.clear();
        for (final doc in snapshot.docs) {
          _cache[doc.id] = JournalEntryCloud.fromFirestore(doc);
        }
        await _saveLocalCache();
      } else {
        // Nube vacía -> usuario nuevo o sin datos, empezar limpio
        debugPrint('📓 [JOURNAL_REPO] Cloud empty, starting fresh (NOT uploading local cache)');
        _cache.clear();
        await _saveLocalCache();
      }
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Sync error (server): $e');
      // Si falla el server, intentar desde cache de Firestore SDK
      try {
        final fallback = await _firestore
            .collection('users')
            .doc(uid)
            .collection('journalEntries')
            .orderBy('timestamp', descending: true)
            .get(const GetOptions(source: Source.cache));
        if (fallback.docs.isNotEmpty) {
          debugPrint('📓 [JOURNAL_REPO] Using Firestore SDK cache as fallback');
          _cache.clear();
          for (final doc in fallback.docs) {
            _cache[doc.id] = JournalEntryCloud.fromFirestore(doc);
          }
          await _saveLocalCache();
        }
      } catch (_) {
        debugPrint('📓 [JOURNAL_REPO] Firestore cache fallback also failed');
      }
    }
  }
  
  Future<void> _saveToCloud(String uid, JournalEntryCloud entry) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .doc(entry.id)
          .set(entry.toFirestore());
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Cloud save error: $e');
      _addPendingOp({'type': 'update', 'id': entry.id});
    }
  }
  
  Future<void> _deleteFromCloud(String uid, String id) async {
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('journalEntries')
          .doc(id)
          .delete();
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Cloud delete error: $e');
    }
  }
  
  void _startRealtimeSync(String uid) {
    _realtimeSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('journalEntries')
        .snapshots()
        .listen(
      (snapshot) {
        for (final change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.removed) {
            _cache.remove(change.doc.id);
          } else {
            _cache[change.doc.id] = JournalEntryCloud.fromFirestore(change.doc);
          }
        }
        _saveLocalCache();
        _updateNotifier();
      },
      onError: (e) {
        debugPrint('📓 [JOURNAL_REPO] Realtime sync error: $e');
      },
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // PENDING OPS
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _addPendingOp(Map<String, dynamic> op) {
    _pendingOps.add(op);
    _savePendingOps();
  }
  
  Future<void> _loadPendingOps() async {
    final json = _prefs?.getString(_keyPendingWrites);
    if (json != null) {
      _pendingOps = List<Map<String, dynamic>>.from(
        (jsonDecode(json) as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }
  }
  
  Future<void> _savePendingOps() async {
    await _prefs?.setString(_keyPendingWrites, jsonEncode(_pendingOps));
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // LOCAL CACHE
  // ═══════════════════════════════════════════════════════════════════════════
  
  Future<void> _loadLocalCache() async {
    try {
      final json = _prefs?.getString(_keyJournalCache);
      if (json != null && json.isNotEmpty) {
        final data = jsonDecode(json) as Map<String, dynamic>;
        _cache = data.map((id, entryData) => MapEntry(
          id,
          JournalEntryCloud.fromLocal(entryData as Map<String, dynamic>),
        ));
      }
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Local cache load error: $e');
      _cache = {};
    }
  }
  
  Future<void> _saveLocalCache() async {
    try {
      final data = _cache.map((id, entry) => MapEntry(id, entry.toLocal()));
      await _prefs?.setString(_keyJournalCache, jsonEncode(data));
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Local cache save error: $e');
    }
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICADOR
  // ═══════════════════════════════════════════════════════════════════════════
  
  void _updateNotifier() {
    entriesNotifier.value = getAll();
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  // Delegado a TimeUtils centralizado
  String _dateToISO(DateTime date) => TimeUtils.dateToISO(date);
  
  // ═══════════════════════════════════════════════════════════════════════════
  // MIGRACIÓN LEGACY
  // ═══════════════════════════════════════════════════════════════════════════
  
  /// Migrar desde JournalService legacy
  Future<void> migrateFromLegacy(SharedPreferences prefs) async {
    try {
      if (_cache.isNotEmpty) {
        debugPrint('📓 [JOURNAL_REPO] Already has data, skipping migration');
        return;
      }
      
      final legacyJson = prefs.getString('journal_entries');
      if (legacyJson == null || legacyJson.isEmpty) {
        debugPrint('📓 [JOURNAL_REPO] No legacy data to migrate');
        return;
      }
      
      final legacyList = jsonDecode(legacyJson) as List;
      
      for (final entryData in legacyList) {
        final data = entryData as Map<String, dynamic>;
        final entry = JournalEntryCloud(
          id: data['id'] ?? '${DateTime.now().millisecondsSinceEpoch}',
          dateISO: _dateToISO(DateTime.parse(data['date'])),
          timestamp: DateTime.parse(data['date']),
          content: data['content'] ?? '',
          mood: data['mood'] ?? 'neutral',
          triggers: List<String>.from(data['triggers'] ?? []),
          hadVictory: data['hadVictory'] ?? true,
          verseOfDay: data['verseOfDay'],
          updatedAt: DateTime.now(),
        );
        
        _cache[entry.id] = entry;
      }
      
      await _saveLocalCache();
      _updateNotifier();
      
      debugPrint('📓 [JOURNAL_REPO] ✅ Migrated ${_cache.length} entries from legacy');
    } catch (e) {
      debugPrint('📓 [JOURNAL_REPO] Migration error: $e');
    }
  }
}
