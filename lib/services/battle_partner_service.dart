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
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/battle_partner_data.dart';
import '../constants/battle_messages.dart';
import 'victory_scoring_service.dart';

/// Máximo de compañeros por usuario
const int kMaxBattlePartners = 5;

/// Máximo de mensajes al mismo compañero en 24h
const int kMaxMessagesPerDay = 3;

/// Caracteres permitidos para inviteCode (sin O/0/I/1)
const String _codeChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

class BattlePartnerService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final BattlePartnerService _instance = BattlePartnerService._internal();
  factory BattlePartnerService() => _instance;
  BattlePartnerService._internal();

  static BattlePartnerService get I => _instance;

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

    _startListening();
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

    partnersNotifier.value = [];
    pendingInvitesNotifier.value = [];
    unreadMessagesNotifier.value = [];

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
    );

    // Invitaciones pendientes
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
      },
      onError: (e) => debugPrint('🤝 [BATTLE] Messages stream error: $e'),
    );
  }

  /// Cuando cambian los partners, fetch su publicProgress para cada uno
  Future<void> _onPartnersChanged(QuerySnapshot snapshot) async {
    try {
      final List<BattlePartnerData> partners = [];

      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final partnerUid = data['partnerUid'] as String? ?? '';
        if (partnerUid.isEmpty) continue;

        // Leer publicProgress del compañero
        Map<String, dynamic>? progressData;
        try {
          final progressDoc = await _db
              .collection('users')
              .doc(partnerUid)
              .collection('publicProgress')
              .doc('latest')
              .get();
          if (progressDoc.exists) {
            progressData = progressDoc.data();
          }
        } catch (e) {
          debugPrint('🤝 [BATTLE] Error reading progress for $partnerUid: $e');
        }

        partners.add(BattlePartnerData.fromFirestore(
          data,
          progressDoc: progressData,
        ));
      }

      // Ordenar: inactivos al final
      partners.sort((a, b) {
        if (a.isInactive && !b.isInactive) return 1;
        if (!a.isInactive && b.isInactive) return -1;
        return b.streakDays.compareTo(a.streakDays);
      });

      partnersNotifier.value = partners;
      debugPrint('🤝 [BATTLE] ${partners.length} compañeros activos');
    } catch (e) {
      debugPrint('🤝 [BATTLE] Error procesando partners: $e');
    }
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

      final batch = _db.batch();

      // Actualizar invitación a accepted
      batch.update(
        _db.collection('users').doc(uid).collection('partnerInvites').doc(invite.inviteId),
        {'status': 'accepted'},
      );

      // Crear partner en MI lista (status=active)
      batch.set(
        _db.collection('users').doc(uid).collection('battlePartners').doc(invite.fromUid),
        {
          'partnerUid': invite.fromUid,
          'partnerName': invite.fromName,
          'status': 'active',
          'addedAt': FieldValue.serverTimestamp(),
        },
      );

      // Actualizar status del partner en la lista del OTRO (pending → active)
      batch.update(
        _db.collection('users').doc(invite.fromUid).collection('battlePartners').doc(uid),
        {
          'status': 'active',
          'partnerName': myName,
        },
      );

      await batch.commit();

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
      final batch = _db.batch();

      // Marcar invitación como rechazada
      batch.update(
        _db.collection('users').doc(uid).collection('partnerInvites').doc(invite.inviteId),
        {'status': 'rejected'},
      );

      // Actualizar el partner doc del otro lado si existe
      try {
        batch.update(
          _db.collection('users').doc(invite.fromUid).collection('battlePartners').doc(uid),
          {'status': 'rejected'},
        );
      } catch (e) {
        debugPrint('🤝 [BATTLE] Error updating other side rejection: $e');
      }

      await batch.commit();
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
      final batch = _db.batch();

      batch.update(
        _db.collection('users').doc(uid).collection('battlePartners').doc(partnerUid),
        {'status': 'removed'},
      );

      // También en el otro lado
      try {
        batch.update(
          _db.collection('users').doc(partnerUid).collection('battlePartners').doc(uid),
          {'status': 'removed'},
        );
      } catch (e) {
        debugPrint('🤝 [BATTLE] Error updating partner side removal: $e');
      }

      await batch.commit();
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

  Future<void> syncPublicProgress() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      final scoring = VictoryScoringService.I;
      final streak = scoring.getCurrentStreak();
      final victoryToday = scoring.isLoggedToday();

      await _db
          .collection('users')
          .doc(uid)
          .collection('publicProgress')
          .doc('latest')
          .set({
        'streakDays': streak,
        'victoryToday': victoryToday,
        'lastOpenedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('🤝 [BATTLE] Public progress synced: streak=$streak, today=$victoryToday');
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

      // Actualizar lastMessageSentAt
      try {
        await _db
            .collection('users')
            .doc(uid)
            .collection('battlePartners')
            .doc(toUid)
            .update({'lastMessageSentAt': FieldValue.serverTimestamp()});
      } catch (e) {
        debugPrint('🤝 [BATTLE] Error updating lastMessageSentAt: $e');
      }

      // Registrar rate-limit
      _recordMessageSent(toUid);

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
}
