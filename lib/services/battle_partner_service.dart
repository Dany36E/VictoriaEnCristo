/// ═══════════════════════════════════════════════════════════════════════════
/// BATTLE PARTNER SERVICE - Compañero de Batalla
/// Acompañamiento espiritual con privacidad máxima.
/// NUNCA expone: diario, gigantes, score detallado, email.
/// SÍ expone: racha (int), victoria hoy (bool), inactividad.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/battle_partner_data.dart';
import '../constants/battle_messages.dart';
import 'notification_service.dart';
import 'victory_scoring_service.dart';

/// Máximo de compañeros por usuario
const int kMaxBattlePartners = 5;

/// Máximo de mensajes al mismo compañero en 24h
const int kMaxMessagesPerDay = 3;

/// Máximo de SOS de oración por día (broadcast a todos los compañeros).
const int kMaxSosPerDay = 1;

/// Caracteres permitidos para inviteCode (sin O/0/I/1)
const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

class BattlePartnerService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON — patrón unificado (solo .I) para alinear con resto de servicios.
  // ═══════════════════════════════════════════════════════════════════════════

  BattlePartnerService._();
  static final BattlePartnerService I = BattlePartnerService._();

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  SharedPreferences? _prefs;
  String? _uid;
  bool _isInitialized = false;

  StreamSubscription? _partnersSubscription;
  StreamSubscription? _invitesSubscription;
  StreamSubscription? _messagesSubscription;

  /// Lista reactiva de compañeros activos
  final ValueNotifier<List<BattlePartnerData>> partnersNotifier =
      ValueNotifier([]);

  /// Invitaciones pendientes
  final ValueNotifier<List<PartnerInvite>> pendingInvitesNotifier =
      ValueNotifier([]);

  /// Mensajes no leídos
  final ValueNotifier<List<BattleMessageData>> unreadMessagesNotifier =
      ValueNotifier([]);

  /// ¿El usuario acepta nuevas invitaciones? (modo pausa)
  /// Se persiste localmente y se replica al doc del usuario.
  final ValueNotifier<bool> acceptingInvitesNotifier = ValueNotifier(true);

  /// UID del compañero con el que se comparte "gigante en batalla" (opt-in).
  /// `null` = sin compañero de confianza configurado. Solo uno a la vez.
  final ValueNotifier<String?> trustedPartnerUidNotifier = ValueNotifier(null);

  /// Cache local de progreso público por partnerUid. Evita releer los 5 docs
  /// cada vez que cambia CUALQUIER campo en battlePartners (fix N+1 reads).
  final Map<String, Map<String, dynamic>?> _progressCache = {};

  /// Debounce del auto-sync de publicProgress al cambiar la racha.
  Timer? _publicProgressDebounce;
  /// Listener a VictoryScoringService para mantener publicProgress fresco
  /// sin escribir en cada evento (debounce 5 min).
  VoidCallback? _streakListener;

  /// Número de invitaciones pendientes (para badge)
  int get pendingInviteCount => pendingInvitesNotifier.value.length;

  /// ¿Tiene compañeros activos?
  bool get hasPartners => partnersNotifier.value.isNotEmpty;

  bool get isInitialized => _isInitialized;

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN / LIFECYCLE
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init(String uid) async {
    if (_isInitialized && _uid == uid) return;

    debugPrint('🤝 [BATTLE] Initializing for uid=$uid');
    _uid = uid;
    _prefs ??= await SharedPreferences.getInstance();

    // Cargar flags persistentes (pausa, trusted partner) antes de exponerlos.
    acceptingInvitesNotifier.value =
        _prefs?.getBool(_kAcceptingInvitesKey) ?? true;
    trustedPartnerUidNotifier.value =
        _prefs?.getString(_kTrustedPartnerKey);

    _startListening();
    _attachStreakListener();
    _isInitialized = true;
  }

  void stop() {
    debugPrint('🤝 [BATTLE] Stopping service');
    _partnersSubscription?.cancel();
    _invitesSubscription?.cancel();
    _messagesSubscription?.cancel();
    _partnersSubscription = null;
    _invitesSubscription = null;
    _messagesSubscription = null;

    _detachStreakListener();
    _publicProgressDebounce?.cancel();
    _publicProgressDebounce = null;

    partnersNotifier.value = [];
    pendingInvitesNotifier.value = [];
    unreadMessagesNotifier.value = [];
    _progressCache.clear();

    _uid = null;
    _isInitialized = false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LISTENERS EN TIEMPO REAL
  // ═══════════════════════════════════════════════════════════════════════════

  void _startListening() {
    final uid = _uid;
    if (uid == null) return;

    // Partners activos
    _partnersSubscription?.cancel();
    _partnersSubscription = _db
        .collection('users')
        .doc(uid)
        .collection('battlePartners')
        .where('status', isEqualTo: 'active')
        .snapshots()
        .listen(
      (snapshot) => _onPartnersChanged(snapshot),
      onError: (e) => debugPrint('🤝 [BATTLE] Partners stream error: $e'),
    );    // Invitaciones pendientes
    _invitesSubscription?.cancel();
    _invitesSubscription = _db
        .collection('users')
        .doc(uid)
        .collection('partnerInvites')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
      (snapshot) {
        final invites = snapshot.docs
            .map((doc) => PartnerInvite.fromFirestore(doc.id, doc.data()))
            .toList();
        pendingInvitesNotifier.value = invites;
        debugPrint('🤝 [BATTLE] ${invites.length} invitaciones pendientes');
        _maybeNotifyNewInvites(snapshot);
      },
      onError: (e) => debugPrint('🤝 [BATTLE] Invites stream error: $e'),
    );

    // Mensajes no leídos
    _messagesSubscription?.cancel();
    _messagesSubscription = _db
        .collection('users')
        .doc(uid)
        .collection('battleMessages')
        .where('read', isEqualTo: false)
        .orderBy('sentAt', descending: true)
        .limit(20)
        .snapshots()
        .listen(
      (snapshot) {
        final msgs = snapshot.docs
            .map((doc) => BattleMessageData.fromFirestore(doc.id, doc.data()))
            .toList();
        unreadMessagesNotifier.value = msgs;
        _maybeNotifyNewMessages(snapshot);
      },
      onError: (e) => debugPrint('🤝 [BATTLE] Messages stream error: $e'),
    );
  }

  /// Cuando cambian los partners, fetch su publicProgress SOLO si es doc
  /// nuevo o modificado (fix N+1 reads). Los restantes reutilizan el cache.
  Future<void> _onPartnersChanged(QuerySnapshot snapshot) async {
    try {
      // Mapear docChanges a uids que realmente requieren relectura.
      final Set<String> toRefetch = {};
      for (final ch in snapshot.docChanges) {
        if (ch.type == DocumentChangeType.removed) continue;
        final data = ch.doc.data() as Map<String, dynamic>?;
        final pUid = data?['partnerUid'] as String? ?? '';
        if (pUid.isEmpty) continue;
        // Si no tengo cache aún, hay que leerlo. Si está cacheado, solo
        // releemos cuando el cambio remoto no es una escritura local optimista.
        final hasCache = _progressCache.containsKey(pUid);
        final pending = ch.doc.metadata.hasPendingWrites;
        if (!hasCache || (!pending && ch.type == DocumentChangeType.modified)) {
          toRefetch.add(pUid);
        }
      }

      // Releer sólo los cambiados (paralelo).
      if (toRefetch.isNotEmpty) {
        await Future.wait(toRefetch.map((pUid) async {
          try {
            final doc = await _db
                .collection('users')
                .doc(pUid)
                .collection('publicProgress')
                .doc('latest')
                .get();
            _progressCache[pUid] = doc.exists ? doc.data() : null;
          } catch (e) {
            debugPrint('🤝 [BATTLE] Error reading progress for $pUid: $e');
            _progressCache.putIfAbsent(pUid, () => null);
          }
        }));
      }

      final List<BattlePartnerData> partners = [];
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final partnerUid = data['partnerUid'] as String? ?? '';
        if (partnerUid.isEmpty) continue;
        partners.add(BattlePartnerData.fromFirestore(
          data,
          progressDoc: _progressCache[partnerUid],
        ));
      }

      // Purgar cache de uids ya no presentes.
      final presentUids = partners.map((p) => p.uid).toSet();
      _progressCache.removeWhere((k, _) => !presentUids.contains(k));

      // Ordenar: inactivos al final
      partners.sort((a, b) {
        if (a.isInactive && !b.isInactive) return 1;
        if (!a.isInactive && b.isInactive) return -1;
        return b.streakDays.compareTo(a.streakDays);
      });

      partnersNotifier.value = partners;
      debugPrint('🤝 [BATTLE] ${partners.length} compañeros activos '
          '(refetched ${toRefetch.length})');
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error procesando partners: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICACIONES PUSH LOCALES
  // ─────────────────────────────────────────────────────────────────────────
  // Al detectar docs NUEVAS (type=added) en los streams de invitaciones y
  // mensajes, disparamos una notificación local. Evitamos duplicados tras
  // reconexión persistiendo el timestamp más reciente notificado por uid.
  // No generamos reads extra: reutilizamos los listeners ya activos.
  // ═══════════════════════════════════════════════════════════════════════════

  String get _kLastInviteMs => 'battle.lastNotifiedInviteMs.$_uid';
  String get _kLastMessageMs => 'battle.lastNotifiedMessageMs.$_uid';

  int _loadLastMs(String key) => _prefs?.getInt(key) ?? 0;

  Future<void> _saveLastMs(String key, int ms) async {
    await _prefs?.setInt(key, ms);
  }

  /// ID estable y positivo para flutter_local_notifications a partir del docId.
  int _notifIdFor(String prefix, String docId) {
    // Prefijo (20/21) reservado para battle; evita colisión con recordatorios
    // fijos (1001-1004) y permite distinguir invites de mensajes.
    final hash = docId.hashCode & 0x3FFFFFFF; // positivo de 30 bits
    return prefix == 'invite' ? (0x20000000 | hash) : (0x40000000 | hash);
  }

  void _maybeNotifyNewInvites(QuerySnapshot<Map<String, dynamic>> snap) {
    final lastMs = _loadLastMs(_kLastInviteMs);
    int maxSeen = lastMs;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      // hasPendingWrites=true significa que la escritura es optimista local
      // (p.ej. aceptación en este mismo cliente) → no notificar.
      if (change.doc.metadata.hasPendingWrites) continue;
      final data = change.doc.data();
      if (data == null) continue;
      final ts = data['createdAt'];
      final ms = _tsToMs(ts);
      if (ms == 0 || ms <= lastMs) continue;
      final fromName = (data['fromName'] as String?)?.trim();
      unawaited(NotificationService().showBattlePartnerInvite(
        id: _notifIdFor('invite', change.doc.id),
        fromName: (fromName == null || fromName.isEmpty)
            ? 'Alguien'
            : fromName,
      ));
      if (ms > maxSeen) maxSeen = ms;
    }
    if (maxSeen > lastMs) unawaited(_saveLastMs(_kLastInviteMs, maxSeen));
  }

  void _maybeNotifyNewMessages(QuerySnapshot<Map<String, dynamic>> snap) {
    final lastMs = _loadLastMs(_kLastMessageMs);
    int maxSeen = lastMs;
    for (final change in snap.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      if (change.doc.metadata.hasPendingWrites) continue;
      final data = change.doc.data();
      if (data == null) continue;
      final ts = data['sentAt'];
      final ms = _tsToMs(ts);
      if (ms == 0 || ms <= lastMs) continue;
      final fromUid = data['fromUid'] as String? ?? '';
      final key = data['messageKey'] as String? ?? '';
      final isSos = key == kBattleSosKey;
      final text = kBattleMessageMap[key]?.text ?? 'Te envió un mensaje';
      // Resolver nombre desde el notifier de partners (cache local, 0 lecturas).
      final fromName = partnersNotifier.value
          .firstWhere(
            (p) => p.uid == fromUid,
            orElse: () => BattlePartnerData(
              uid: fromUid,
              name: 'Un compañero',
              addedAt: DateTime.now(),
              status: PartnerStatus.active,
            ),
          )
          .name;

      // Haptic + sonido suave si la app está en foreground (#10).
      // El SOS siempre vibra aunque la pantalla esté abierta.
      if (!NotificationService.isViewingBattlePartner.value || isSos) {
        unawaited(HapticFeedback.mediumImpact());
      }

      if (isSos) {
        unawaited(NotificationService().showBattleSos(
          id: _notifIdFor('message', change.doc.id),
          fromName: fromName,
        ));
      } else {
        unawaited(NotificationService().showBattleMessage(
          id: _notifIdFor('message', change.doc.id),
          fromName: fromName,
          text: text,
        ));
      }
      if (ms > maxSeen) maxSeen = ms;
    }
    if (maxSeen > lastMs) unawaited(_saveLastMs(_kLastMessageMs, maxSeen));
  }

  /// Convierte Firestore Timestamp (o num, o DateTime, o String ISO) a millis.
  int _tsToMs(dynamic v) {
    if (v == null) return 0;
    if (v is Timestamp) return v.millisecondsSinceEpoch;
    if (v is DateTime) return v.millisecondsSinceEpoch;
    if (v is num) return v.toInt();
    if (v is String) return DateTime.tryParse(v)?.millisecondsSinceEpoch ?? 0;
    return 0;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // INVITE CODE
  // ═══════════════════════════════════════════════════════════════════════════

  /// Genera un código de invitación de 8 chars (VKJM4XR2)
  String _generateCode() {
    final random = Random.secure();
    return List.generate(
      8,
      (_) => _codeChars[random.nextInt(_codeChars.length)],
    ).join();
  }

  /// Asegura que el usuario actual tiene un inviteCode generado
  /// Retorna el código existente o uno nuevo
  Future<String?> ensureInviteCode() async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      // Verificar si ya existe
      final userDoc = await _db.collection('users').doc(uid).get();
      final existing = userDoc.data()?['inviteCode'] as String?;
      if (existing != null && existing.isNotEmpty) {
        return existing;
      }

      // Generar nuevo código
      final code = _generateCode();
      final displayName = userDoc.data()?['displayName'] as String? ?? 'Usuario';
      final publicName = userDoc.data()?['publicName'] as String? ?? displayName;

      // Guardar en perfil del usuario y en colección global
      final batch = _db.batch();

      batch.update(_db.collection('users').doc(uid), {
        'inviteCode': code,
        'publicName': publicName,
      });

      batch.set(_db.collection('inviteCodes').doc(code), {
        'uid': uid,
        'publicName': publicName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('🤝 [BATTLE] Invite code generated: $code');
      return code;
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error generating invite code: $e');
      return null;
    }
  }

  /// Obtener el inviteCode actual del usuario (desde cache Firestore)
  Future<String?> getMyInviteCode() async {
    final uid = _uid;
    if (uid == null) return null;

    try {
      final doc = await _db.collection('users').doc(uid).get();
      final code = doc.data()?['inviteCode'] as String?;
      if (code == null || code.isEmpty) {
        return ensureInviteCode();
      }
      return code;
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error getting invite code: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // VINCULACIÓN POR CÓDIGO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Buscar usuario por código de invitación (preview)
  Future<InviteResult> lookupCode(String code) async {
    final uid = _uid;
    if (uid == null) {
      return const InviteResult(type: InviteResultType.error, errorMessage: 'No autenticado');
    }

    try {
      final codeDoc = await _db.collection('inviteCodes').doc(code.toUpperCase()).get();
      if (!codeDoc.exists) {
        return const InviteResult(type: InviteResultType.notFound);
      }

      final data = codeDoc.data()!;
      final targetUid = data['uid'] as String;
      final targetName = data['publicName'] as String? ?? 'Usuario';

      // Validaciones
      if (targetUid == uid) {
        return const InviteResult(type: InviteResultType.selfInvite);
      }

      // Verificar si el destinatario pausó invitaciones (#12).
      // El flag vive en publicProgress/latest (legible por cualquier auth).
      try {
        final pubDoc = await _db
            .collection('users')
            .doc(targetUid)
            .collection('publicProgress')
            .doc('latest')
            .get();
        final accepting = pubDoc.data()?['acceptingInvites'];
        if (accepting is bool && accepting == false) {
          return const InviteResult(type: InviteResultType.targetPaused);
        }
      } catch (_) {
        // Si no hay doc o no podemos leer, asumimos que acepta. El write
        // posterior será validado por reglas.
      }

      // Verificar si ya están vinculados
      final existingDoc = await _db
          .collection('users')
          .doc(uid)
          .collection('battlePartners')
          .doc(targetUid)
          .get();

      if (existingDoc.exists) {
        final status = existingDoc.data()?['status'] as String?;
        if (status == 'active' || status == 'pending') {
          return const InviteResult(type: InviteResultType.alreadyLinked);
        }
      }

      // Verificar límite de 5
      final myPartners = await _db
          .collection('users')
          .doc(uid)
          .collection('battlePartners')
          .where('status', whereIn: ['active', 'pending'])
          .get();

      if (myPartners.docs.length >= kMaxBattlePartners) {
        return const InviteResult(type: InviteResultType.limitReached);
      }

      return InviteResult(
        type: InviteResultType.success,
        targetUid: targetUid,
        targetName: targetName,
      );
    } catch (e) {
      debugPrint('🤝 [BATTLE] Lookup error: $e');
      return InviteResult(type: InviteResultType.error, errorMessage: e.toString());
    }
  }

  /// Enviar invitación por código
  Future<InviteResult> sendInviteByCode(String code) async {
    final uid = _uid;
    if (uid == null) {
      return const InviteResult(type: InviteResultType.error, errorMessage: 'No autenticado');
    }

    // Primero validar
    final lookup = await lookupCode(code);
    if (!lookup.isSuccess) return lookup;

    final targetUid = lookup.targetUid!;
    final targetName = lookup.targetName!;

    try {
      // Obtener mi nombre público
      final myDoc = await _db.collection('users').doc(uid).get();
      final myName = myDoc.data()?['publicName'] as String? ??
          myDoc.data()?['displayName'] as String? ??
          'Un compañero';

      final batch = _db.batch();

      // Crear en mi lista con status=pending
      batch.set(
        _db.collection('users').doc(uid).collection('battlePartners').doc(targetUid),
        {
          'partnerUid': targetUid,
          'partnerName': targetName,
          'status': 'pending',
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // Crear invitación en la bandeja del destinatario
      final inviteRef = _db.collection('users').doc(targetUid).collection('partnerInvites').doc();
      batch.set(inviteRef, {
        'fromUid': uid,
        'fromName': myName,
        'inviteCode': code.toUpperCase(),
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      debugPrint('🤝 [BATTLE] Invitación enviada a $targetName');

      unawaited(_logEvent('battle_invite_sent', const {}));

      return InviteResult(
        type: InviteResultType.success,
        targetUid: targetUid,
        targetName: targetName,
      );
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error enviando invitación: $e');
      return InviteResult(type: InviteResultType.error, errorMessage: e.toString());
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACEPTAR / RECHAZAR INVITACIONES
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> acceptInvite(PartnerInvite invite) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      // Verificar límite antes de aceptar
      final myPartners = await _db
          .collection('users')
          .doc(uid)
          .collection('battlePartners')
          .where('status', whereIn: ['active', 'pending'])
          .get();

      if (myPartners.docs.length >= kMaxBattlePartners) {
        debugPrint('🤝 [BATTLE] Límite de compañeros alcanzado');
        return false;
      }

      // Obtener mi nombre público
      final myDoc = await _db.collection('users').doc(uid).get();
      final myName = myDoc.data()?['publicName'] as String? ??
          myDoc.data()?['displayName'] as String? ??
          'Compañero';

      // Detectar invitación cruzada (ambos se invitaron a la vez) y
      // auto-fusionar (#5): si yo ya envié invite al mismo `fromUid`,
      // limpiamos la mía para no dejar docs fantasma.
      try {
        final mutual = await _db
            .collection('users')
            .doc(invite.fromUid)
            .collection('partnerInvites')
            .where('fromUid', isEqualTo: uid)
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();
        if (mutual.docs.isNotEmpty) {
          // Lo borramos (mejor que dejar accepted/rejected acumulado — fix #4).
          await mutual.docs.first.reference.delete().catchError((_) {});
          debugPrint('🤝 [BATTLE] Invitación cruzada detectada y fusionada');
        }
      } catch (e) {
        debugPrint('🤝 [BATTLE] Error revisando invitación cruzada: $e');
      }

      final batch = _db.batch();

      // Borrar mi invitación entrante (en lugar de actualizar status) para
      // no acumular docs en el tiempo (fix #4).
      batch.delete(_db
          .collection('users')
          .doc(uid)
          .collection('partnerInvites')
          .doc(invite.inviteId));

      // Crear/mergear partner en MI lista (status=active)
      batch.set(
        _db.collection('users').doc(uid).collection('battlePartners').doc(invite.fromUid),
        {
          'partnerUid': invite.fromUid,
          'partnerName': invite.fromName,
          'status': 'active',
          'addedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Actualizar/crear partner doc en la lista del OTRO (idempotente).
      // set(merge:true) evita fallos si el otro limpió su doc (fix #3).
      batch.set(
        _db.collection('users').doc(invite.fromUid).collection('battlePartners').doc(uid),
        {
          'partnerUid': uid,
          'partnerName': myName,
          'status': 'active',
          'addedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      await batch.commit();

      // Analytics (#24)
      unawaited(_logEvent('battle_invite_accepted', {
        'from_uid_hash': invite.fromUid.hashCode.abs(),
      }));

      // Sincronizar mi progreso público para que el nuevo compañero lo vea
      await syncPublicProgress();

      debugPrint('🤝 [BATTLE] ✅ Invitación aceptada de ${invite.fromName}');
      return true;
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error aceptando invitación: $e');
      return false;
    }
  }

  Future<bool> rejectInvite(PartnerInvite invite) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      // Borrar la invitación (en lugar de marcar rejected): evita acumulación
      // de docs inservibles en la bandeja (fix #4).
      await _db
          .collection('users')
          .doc(uid)
          .collection('partnerInvites')
          .doc(invite.inviteId)
          .delete();

      // Actualizar el partner doc del otro lado si existe (best-effort,
      // merge para tolerar que ya no exista — fix #3).
      try {
        await _db
            .collection('users')
            .doc(invite.fromUid)
            .collection('battlePartners')
            .doc(uid)
            .set({'status': 'rejected'}, SetOptions(merge: true));
      } catch (e) {
        debugPrint('🤝 [BATTLE] Error updating other side rejection: $e');
      }

      unawaited(_logEvent('battle_invite_rejected', const {}));
      debugPrint('🤝 [BATTLE] Invitación rechazada de ${invite.fromName}');
      return true;
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error rechazando invitación: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // REMOVER COMPAÑERO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<bool> removePartner(String partnerUid) async {
    final uid = _uid;
    if (uid == null) return false;

    try {
      // Usamos set(merge:true) para tolerar que el otro lado ya haya
      // eliminado su doc (fix #3). También limpiamos trustedPartner si
      // coincide (no debe quedar una referencia huérfana).
      if (trustedPartnerUidNotifier.value == partnerUid) {
        await setTrustedPartner(null);
      }

      final batch = _db.batch();
      batch.set(
        _db.collection('users').doc(uid).collection('battlePartners').doc(partnerUid),
        {'status': 'removed'},
        SetOptions(merge: true),
      );
      batch.set(
        _db.collection('users').doc(partnerUid).collection('battlePartners').doc(uid),
        {'status': 'removed'},
        SetOptions(merge: true),
      );
      await batch.commit();

      unawaited(_logEvent('battle_partner_removed', const {}));
      debugPrint('🤝 [BATTLE] Compañero $partnerUid removido');
      return true;
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error removiendo compañero: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SYNC PUBLIC PROGRESS (PRIVACIDAD)
  // Solo expone: streakDays, victoryToday, lastOpenedAt
  // NUNCA: giants, diario, score por gigante
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> syncPublicProgress({String? sharedGiantId}) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final scoring = VictoryScoringService.I;
      final streak = scoring.getCurrentStreak();
      final victoryToday = scoring.isLoggedToday();

      final payload = <String, dynamic>{
        'streakDays': streak,
        'victoryToday': victoryToday,
        'lastOpenedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        // Flag público de "pausa" — usado por lookupCode del otro usuario.
        'acceptingInvites': acceptingInvitesNotifier.value,
      };
      // Solo exponer sharedGiantId si existe compañero de confianza (#19).
      if (trustedPartnerUidNotifier.value != null && sharedGiantId != null) {
        payload['sharedGiantId'] = sharedGiantId;
        payload['trustedPartnerUid'] = trustedPartnerUidNotifier.value;
      } else {
        // Asegurar que se quita si antes estaba.
        payload['sharedGiantId'] = FieldValue.delete();
        payload['trustedPartnerUid'] = FieldValue.delete();
      }

      await _db
          .collection('users')
          .doc(uid)
          .collection('publicProgress')
          .doc('latest')
          .set(payload, SetOptions(merge: true));

      debugPrint('🤝 [BATTLE] Public progress synced: '
          'streak=$streak, today=$victoryToday, accepting=${acceptingInvitesNotifier.value}');
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error syncing public progress: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENSAJES (STICKERS)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enviar mensaje predefinido a un compañero
  /// Rate-limit: máximo 3 al mismo compañero en 24h
  Future<bool> sendMessage(String toUid, String messageKey) async {
    final uid = _uid;
    if (uid == null) return false;

    // Validar que es un mensaje válido
    if (!isValidMessageKey(messageKey)) {
      debugPrint('🤝 [BATTLE] Invalid message key: $messageKey');
      return false;
    }
    // El SOS se envía por broadcast dedicado (sendSos), no por este path.
    if (messageKey == kBattleSosKey) {
      debugPrint('🤝 [BATTLE] sos_prayer debe enviarse con sendSos()');
      return false;
    }

    // Rate-limit local
    if (_isRateLimited(toUid)) {
      debugPrint('🤝 [BATTLE] Rate limited: ya enviaste $kMaxMessagesPerDay hoy a $toUid');
      return false;
    }

    try {
      await _db
          .collection('users')
          .doc(toUid)
          .collection('battleMessages')
          .add({
        'fromUid': uid,
        'messageKey': messageKey,
        'sentAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Actualizar lastMessageSentAt (best-effort, merge para tolerar doc ausente)
      try {
        await _db
            .collection('users')
            .doc(uid)
            .collection('battlePartners')
            .doc(toUid)
            .set(
              {'lastMessageSentAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true),
            );
      } catch (e) {
        debugPrint('🤝 [BATTLE] Error updating lastMessageSentAt: $e');
      }

      // Registrar rate-limit
      _recordMessageSent(toUid);

      // Analytics (#24)
      unawaited(_logEvent('battle_message_sent', {'message_key': messageKey}));

      debugPrint('🤝 [BATTLE] Mensaje "$messageKey" enviado a $toUid');
      return true;
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error enviando mensaje: $e');
      return false;
    }
  }

  /// Marcar mensaje como leído
  Future<void> markMessageRead(String messageId) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('battleMessages')
          .doc(messageId)
          .update({'read': true});
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error marking message read: $e');
    }
  }

  /// Marcar todos los mensajes como leídos
  Future<void> markAllMessagesRead() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final unread = await _db
          .collection('users')
          .doc(uid)
          .collection('battleMessages')
          .where('read', isEqualTo: false)
          .get();

      final batch = _db.batch();
      for (final doc in unread.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error marking all messages read: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RATE LIMITING (LOCAL)
  // ═══════════════════════════════════════════════════════════════════════════

  bool _isRateLimited(String toUid) {
    final key = _rateLimitKey(toUid);
    final timestamps = _prefs?.getStringList(key) ?? [];

    // Filtrar solo los de las últimas 24h
    final now = DateTime.now();
    final recent = timestamps.where((ts) {
      final dt = DateTime.tryParse(ts);
      if (dt == null) return false;
      return now.difference(dt).inHours < 24;
    }).toList();

    return recent.length >= kMaxMessagesPerDay;
  }

  /// Cuántos mensajes quedan hoy para este compañero
  int remainingMessagesToday(String toUid) {
    final key = _rateLimitKey(toUid);
    final timestamps = _prefs?.getStringList(key) ?? [];
    final now = DateTime.now();
    final recent = timestamps.where((ts) {
      final dt = DateTime.tryParse(ts);
      if (dt == null) return false;
      return now.difference(dt).inHours < 24;
    }).length;
    return (kMaxMessagesPerDay - recent).clamp(0, kMaxMessagesPerDay);
  }

  void _recordMessageSent(String toUid) {
    final key = _rateLimitKey(toUid);
    final timestamps = _prefs?.getStringList(key) ?? [];
    timestamps.add(DateTime.now().toIso8601String());

    // Limpiar viejos (> 48h)
    final now = DateTime.now();
    final cleaned = timestamps.where((ts) {
      final dt = DateTime.tryParse(ts);
      if (dt == null) return false;
      return now.difference(dt).inHours < 48;
    }).toList();

    _prefs?.setStringList(key, cleaned);
  }

  String _rateLimitKey(String toUid) => 'battle_msg_rate_${_uid}_$toUid';

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTUALIZAR NOMBRE PÚBLICO
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> updatePublicName(String newName) async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final batch = _db.batch();

      // Actualizar en perfil
      batch.update(_db.collection('users').doc(uid), {'publicName': newName});

      // Actualizar en inviteCodes
      final userDoc = await _db.collection('users').doc(uid).get();
      final code = userDoc.data()?['inviteCode'] as String?;
      if (code != null && code.isNotEmpty) {
        batch.update(_db.collection('inviteCodes').doc(code), {'publicName': newName});
      }

      await batch.commit();
      debugPrint('🤝 [BATTLE] Nombre público actualizado: $newName');
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error actualizando nombre: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAUSA DE INVITACIONES (#12)
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _kAcceptingInvitesKey = 'battle.acceptingInvites';

  /// Activa/desactiva la recepción de nuevas solicitudes de compañero.
  /// Persiste localmente y replica el flag a publicProgress/latest para
  /// que quien busque tu código lo vea antes de enviarte la invitación.
  Future<void> setAcceptingInvites(bool value) async {
    acceptingInvitesNotifier.value = value;
    await _prefs?.setBool(_kAcceptingInvitesKey, value);
    unawaited(_logEvent('battle_pause_toggled', {'accepting': value}));
    // Refrescar el doc público (usa merge).
    unawaited(syncPublicProgress());
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COMPAÑERO DE CONFIANZA (#19) — opt-in para compartir "gigante"
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _kTrustedPartnerKey = 'battle.trustedPartnerUid';

  /// Marca a un compañero como "de confianza": permite compartir con él
  /// (y SÓLO con él) el id del gigante actualmente en batalla. Pasar
  /// `null` para revocar. La UI llamará `syncPublicProgress(sharedGiantId:..)`
  /// cuando el usuario seleccione el gigante a compartir.
  Future<void> setTrustedPartner(String? partnerUid) async {
    trustedPartnerUidNotifier.value = partnerUid;
    if (partnerUid == null) {
      await _prefs?.remove(_kTrustedPartnerKey);
    } else {
      await _prefs?.setString(_kTrustedPartnerKey, partnerUid);
    }
    unawaited(_logEvent('battle_trusted_partner_changed',
        {'has_trusted': partnerUid != null}));
    unawaited(syncPublicProgress()); // limpia sharedGiantId si ya no hay trusted
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SOS — "Oren por mí ahora" (#16)
  // Broadcast a TODOS los compañeros activos. Rate-limit: 1/día.
  // ═══════════════════════════════════════════════════════════════════════════

  String get _kLastSosIso => 'battle.lastSosAt.$_uid';

  /// ¿Cuántos SOS le quedan hoy al usuario?
  int remainingSosToday() {
    final iso = _prefs?.getString(_kLastSosIso);
    if (iso == null) return kMaxSosPerDay;
    final last = DateTime.tryParse(iso);
    if (last == null) return kMaxSosPerDay;
    if (DateTime.now().difference(last).inHours >= 24) return kMaxSosPerDay;
    return 0;
  }

  /// Envía un "SOS de oración" a todos los compañeros activos.
  /// Retorna el número de compañeros a los que se notificó; 0 = rate-limited
  /// o no hay compañeros.
  Future<int> sendSos() async {
    final uid = _uid;
    if (uid == null) return 0;
    if (remainingSosToday() <= 0) {
      debugPrint('🤝 [BATTLE] SOS rate-limited (1/día)');
      return 0;
    }
    final partners = partnersNotifier.value
        .where((p) => p.status == PartnerStatus.active)
        .toList();
    if (partners.isEmpty) return 0;

    int sent = 0;
    final batch = _db.batch();
    for (final p in partners) {
      final ref = _db
          .collection('users')
          .doc(p.uid)
          .collection('battleMessages')
          .doc();
      batch.set(ref, {
        'fromUid': uid,
        'messageKey': kBattleSosKey,
        'sentAt': FieldValue.serverTimestamp(),
        'read': false,
        'priority': 'sos',
      });
      sent++;
    }
    try {
      await batch.commit();
      await _prefs?.setString(_kLastSosIso, DateTime.now().toIso8601String());
      unawaited(_logEvent('battle_sos_sent', {'recipients': sent}));
      debugPrint('🤝 [BATTLE] 🆘 SOS enviado a $sent compañero(s)');
      return sent;
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error enviando SOS: $e');
      return 0;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STREAK LISTENER — auto-sync publicProgress con debounce (#22)
  // ═══════════════════════════════════════════════════════════════════════════

  void _attachStreakListener() {
    _detachStreakListener();
    _streakListener = _onStreakChanged;
    VictoryScoringService.I.currentStreakNotifier
        .addListener(_streakListener!);
    VictoryScoringService.I.loggedTodayNotifier.addListener(_streakListener!);
  }

  void _detachStreakListener() {
    final l = _streakListener;
    if (l != null) {
      VictoryScoringService.I.currentStreakNotifier.removeListener(l);
      VictoryScoringService.I.loggedTodayNotifier.removeListener(l);
      _streakListener = null;
    }
  }

  void _onStreakChanged() {
    _publicProgressDebounce?.cancel();
    _publicProgressDebounce = Timer(const Duration(minutes: 5), () {
      if (_uid != null) {
        unawaited(syncPublicProgress());
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ANALYTICS HELPER (#24)
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _logEvent(String name, Map<String, Object?> params) async {
    try {
      final clean = <String, Object>{};
      params.forEach((k, v) {
        if (v is String || v is num || v is bool) {
          clean[k] = v as Object;
        }
      });
      await FirebaseAnalytics.instance
          .logEvent(name: name, parameters: clean);
    } catch (e) {
      debugPrint('🤝 [BATTLE] Analytics error ($name): $e');
    }
  }
}
