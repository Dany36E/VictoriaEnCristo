/**
 * ═══════════════════════════════════════════════════════════════════════════
 * BATTLE PARTNER - Cloud Functions
 *
 * 1. onPartnerInviteCreated — dispara push al destinatario cuando entra un
 *    invite nuevo en /users/{uid}/partnerInvites/{inviteId} con status pending.
 *
 * 2. onBattleMessageCreated — dispara push al destinatario cuando entra un
 *    sticker o SOS. Prioridad alta si messageKey === 'sos_prayer'.
 *
 * 3. purgeOldPartnerInvites — scheduled (1x/día) que borra invites con
 *    status != pending y createdAt > 30 días.
 *
 * Nota: los clientes Flutter también escuchan estos subdocs y pintan la
 * notificación local (fallback si FCM falla). Estas funciones añaden push
 * a dispositivo apagado/en background.
 * ═══════════════════════════════════════════════════════════════════════════
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

const db = () => admin.firestore();
const maxBattlePartners = 5;
const maxMessagesPerDay = 3;
const maxSosPerDay = 1;
const inviteCodePattern = /^[A-HJ-NP-Z2-9]{8}$/;
const messageKeyPattern = /^[a-z0-9_:-]{1,32}$/;
const sosMessageKey = "sos_prayer";

interface FcmTokenDoc {
  token: string;
  platform?: string;
}

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return uid;
}

function utcDayKey(): string {
  return new Date().toISOString().slice(0, 10);
}

function safeText(value: unknown, fallback: string, maxLength = 160): string {
  if (typeof value !== "string") return fallback;
  const trimmed = value.trim();
  if (trimmed.length === 0) return fallback;
  return trimmed.slice(0, maxLength);
}

function safeMessageKey(value: unknown): string {
  if (typeof value !== "string" || !messageKeyPattern.test(value)) {
    throw new functions.https.HttpsError("invalid-argument", "Mensaje inválido.");
  }
  return value;
}

async function publicNameFor(uid: string, fallback: string): Promise<string> {
  const snap = await db().collection("users").doc(uid).get();
  const data = snap.data() ?? {};
  return safeText(data["publicName"] ?? data["displayName"], fallback, 48);
}

async function assertActivePartners(fromUid: string, toUid: string): Promise<void> {
  const [senderDoc, targetDoc] = await Promise.all([
    db().collection("users").doc(fromUid).collection("battlePartners").doc(toUid).get(),
    db().collection("users").doc(toUid).collection("battlePartners").doc(fromUid).get(),
  ]);
  if (senderDoc.data()?.status !== "active" || targetDoc.data()?.status !== "active") {
    throw new functions.https.HttpsError("permission-denied", "Compañero no activo.");
  }
}

async function consumeDailyLimit(key: string, maxCount: number): Promise<void> {
  const ref = db().collection("battleRateLimits").doc(key);
  await db().runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const current = snap.exists && typeof snap.get("count") === "number" ? snap.get("count") : 0;
    if (current >= maxCount) {
      throw new functions.https.HttpsError("resource-exhausted", "Límite diario alcanzado.");
    }
    tx.set(
      ref,
      {
        count: current + 1,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      {merge: true}
    );
  });
}

function partnerQuery(uid: string) {
  return db()
    .collection("users")
    .doc(uid)
    .collection("battlePartners")
    .where("status", "in", ["active", "pending"]);
}

async function partnerCount(tx: admin.firestore.Transaction, uid: string): Promise<number> {
  const snap = await tx.get(partnerQuery(uid));
  return snap.size;
}

// ═══════════════════════════════════════════════════════════════════════════
// Callable hardening: invites, accepts, messages, SOS.
// These functions are the only write path allowed by Firestore rules for
// critical partner creates/messages, so modified clients cannot skip limits.
// ═══════════════════════════════════════════════════════════════════════════

export const sendPartnerInvite = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const inviteCode = safeText(data?.inviteCode, "", 8).toUpperCase();
    if (!inviteCodePattern.test(inviteCode)) {
      throw new functions.https.HttpsError("invalid-argument", "Código inválido.");
    }

    const codeRef = db().collection("inviteCodes").doc(inviteCode);

    return db().runTransaction(async (tx) => {
      const codeSnap = await tx.get(codeRef);
      if (!codeSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Código no encontrado.");
      }
      const codeData = codeSnap.data() ?? {};
      const targetUid = codeData["uid"] as string | undefined;
      const targetName = safeText(codeData["publicName"], "Usuario", 48);
      if (!targetUid || targetUid === uid) {
        throw new functions.https.HttpsError("failed-precondition", "Invitación inválida.");
      }

      const senderCount = await partnerCount(tx, uid);
      const targetCount = await partnerCount(tx, targetUid);
      const existingDoc = await tx.get(
        db().collection("users").doc(uid).collection("battlePartners").doc(targetUid)
      );
      const publicProgress = await tx.get(
        db().collection("users").doc(targetUid).collection("publicProgress").doc("latest")
      );

      if (senderCount >= maxBattlePartners || targetCount >= maxBattlePartners) {
        throw new functions.https.HttpsError("resource-exhausted", "Límite de compañeros alcanzado.");
      }
      const existingStatus = existingDoc.data()?.status;
      if (existingStatus === "active" || existingStatus === "pending") {
        throw new functions.https.HttpsError("already-exists", "Ya existe una invitación o vínculo.");
      }
      if (publicProgress.exists && publicProgress.data()?.acceptingInvites === false) {
        throw new functions.https.HttpsError("failed-precondition", "El usuario pausó invitaciones.");
      }

      const myName = await publicNameFor(uid, "Un compañero");
  const targetInviteRef = db().collection("users").doc(targetUid).collection("partnerInvites").doc();

      tx.set(db().collection("users").doc(uid).collection("battlePartners").doc(targetUid), {
        partnerUid: targetUid,
        partnerName: targetName,
        status: "pending",
        addedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(targetInviteRef, {
        fromUid: uid,
        fromName: myName,
        inviteCode,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return {targetUid, targetName};
    });
  });

export const acceptPartnerInvite = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const inviteId = safeText(data?.inviteId, "", 128);
    if (inviteId.length === 0) {
      throw new functions.https.HttpsError("invalid-argument", "Invitación inválida.");
    }

    const inviteRef = db().collection("users").doc(uid).collection("partnerInvites").doc(inviteId);
    await db().runTransaction(async (tx) => {
      const inviteSnap = await tx.get(inviteRef);
      if (!inviteSnap.exists) {
        throw new functions.https.HttpsError("not-found", "Invitación no encontrada.");
      }
      const invite = inviteSnap.data() ?? {};
      if (invite.status !== "pending") {
        throw new functions.https.HttpsError("failed-precondition", "Invitación no pendiente.");
      }
      const fromUid = invite.fromUid as string | undefined;
      const fromName = safeText(invite.fromName, "Compañero", 48);
      if (!fromUid || fromUid === uid) {
        throw new functions.https.HttpsError("failed-precondition", "Invitación inválida.");
      }

      const myCount = await partnerCount(tx, uid);
      const senderCount = await partnerCount(tx, fromUid);
      const senderPartnerRef = db()
        .collection("users")
        .doc(fromUid)
        .collection("battlePartners")
        .doc(uid);
      const senderPartnerDoc = await tx.get(senderPartnerRef);
      const senderWouldCreate = !senderPartnerDoc.exists;
      if (myCount >= maxBattlePartners || (senderWouldCreate ? senderCount >= maxBattlePartners : senderCount > maxBattlePartners)) {
        throw new functions.https.HttpsError("resource-exhausted", "Límite de compañeros alcanzado.");
      }

      const myName = await publicNameFor(uid, "Compañero");
      tx.delete(inviteRef);
      tx.set(
        db().collection("users").doc(uid).collection("battlePartners").doc(fromUid),
        {
          partnerUid: fromUid,
          partnerName: fromName,
          status: "active",
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
      tx.set(
        senderPartnerRef,
        {
          partnerUid: uid,
          partnerName: myName,
          status: "active",
          addedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        {merge: true}
      );
    });
    return {ok: true};
  });

export const sendBattleMessage = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const toUid = safeText(data?.toUid, "", 128);
    const messageKey = safeMessageKey(data?.messageKey);
    if (toUid.length === 0 || toUid === uid || messageKey === sosMessageKey) {
      throw new functions.https.HttpsError("invalid-argument", "Mensaje inválido.");
    }

    await assertActivePartners(uid, toUid);
    await consumeDailyLimit(`msg_${uid}_${toUid}_${utcDayKey()}`, maxMessagesPerDay);

    const fromName = await publicNameFor(uid, "Tu compañero");
    const text = safeText(data?.text, "Te envió un mensaje de aliento", 160);
    await db().collection("users").doc(toUid).collection("battleMessages").add({
      fromUid: uid,
      fromName,
      messageKey,
      text,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      read: false,
    });
    await db().collection("users").doc(uid).collection("battlePartners").doc(toUid).set(
      {lastMessageSentAt: admin.firestore.FieldValue.serverTimestamp()},
      {merge: true}
    );
    return {ok: true};
  });

export const sendBattleSos = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const partners = await db()
      .collection("users")
      .doc(uid)
      .collection("battlePartners")
      .where("status", "==", "active")
      .limit(maxBattlePartners)
      .get();
    if (partners.empty) return {recipients: 0};

    const verifiedTargets: string[] = [];
    await Promise.all(
      partners.docs.map(async (partner) => {
        const toUid = (partner.data().partnerUid as string | undefined) ?? partner.id;
        const targetDoc = await db()
          .collection("users")
          .doc(toUid)
          .collection("battlePartners")
          .doc(uid)
          .get();
        if (targetDoc.data()?.status === "active") {
          verifiedTargets.push(toUid);
        }
      })
    );
    if (verifiedTargets.length === 0) return {recipients: 0};

    await consumeDailyLimit(`sos_${uid}_${utcDayKey()}`, maxSosPerDay);

    const fromName = await publicNameFor(uid, "Tu compañero");
    const text = safeText(data?.text, "Necesito oración ahora", 160);
    const batch = db().batch();
    verifiedTargets.forEach((toUid) => {
      const ref = db().collection("users").doc(toUid).collection("battleMessages").doc();
      batch.set(ref, {
        fromUid: uid,
        fromName,
        messageKey: sosMessageKey,
        text,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        priority: "sos",
      });
    });
    await batch.commit();
    return {recipients: verifiedTargets.length};
  });

/**
 * Lee todos los tokens FCM del usuario objetivo.
 */
async function getUserTokens(uid: string): Promise<string[]> {
  const snap = await db().collection("users").doc(uid).collection("fcmTokens").get();
  const tokens: string[] = [];
  snap.forEach((d) => {
    const data = d.data() as FcmTokenDoc;
    if (data && typeof data.token === "string" && data.token.length > 0) {
      tokens.push(data.token);
    }
  });
  return tokens;
}

/**
 * Elimina tokens inválidos devueltos por FCM.
 */
async function cleanupInvalidTokens(
  uid: string,
  responses: admin.messaging.SendResponse[],
  tokens: string[]
): Promise<void> {
  const toDelete: Promise<unknown>[] = [];
  responses.forEach((r, idx) => {
    if (r.success) return;
    const code = r.error?.code ?? "";
    if (
      code === "messaging/invalid-registration-token" ||
      code === "messaging/registration-token-not-registered"
    ) {
      const tokenToRemove = tokens[idx];
      const q = db()
        .collection("users")
        .doc(uid)
        .collection("fcmTokens")
        .where("token", "==", tokenToRemove)
        .limit(5);
      toDelete.push(q.get().then((s) => Promise.all(s.docs.map((d) => d.ref.delete()))));
    }
  });
  if (toDelete.length > 0) {
    await Promise.all(toDelete).catch(() => undefined);
  }
}

/**
 * Push helper: envía a todos los tokens del usuario.
 */
async function pushToUser(
  uid: string,
  notification: admin.messaging.Notification,
  data: Record<string, string>,
  options: {priority?: "high" | "normal"} = {}
): Promise<void> {
  const tokens = await getUserTokens(uid);
  if (tokens.length === 0) return;

  const msg: admin.messaging.MulticastMessage = {
    tokens,
    notification,
    data,
    android: {
      priority: options.priority === "high" ? "high" : "normal",
      notification: {
        channelId:
          data["type"] === "battle_sos"
            ? "battle_partner_sos"
            : data["type"] === "battle_message"
            ? "battle_partner_messages"
            : "battle_partner_invites",
      },
    },
    apns: {
      headers: {
        "apns-priority": options.priority === "high" ? "10" : "5",
      },
      payload: {
        aps: {
          sound: data["type"] === "battle_sos" ? "default" : "default",
          "interruption-level":
            data["type"] === "battle_sos" ? "time-sensitive" : "active",
        },
      },
    },
  };

  const res = await admin.messaging().sendEachForMulticast(msg);
  if (res.failureCount > 0) {
    await cleanupInvalidTokens(uid, res.responses, tokens);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// 1. onPartnerInviteCreated
// ═══════════════════════════════════════════════════════════════════════════
export const onPartnerInviteCreated = functions
  .region("us-central1")
  .firestore.document("users/{uid}/partnerInvites/{inviteId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() ?? {};
    const uid = context.params.uid as string;
    const inviteId = context.params.inviteId as string;
    const status = (data.status as string) ?? "pending";
    if (status !== "pending") return;
    const fromName = (data.fromName as string) ?? "Alguien";
    await pushToUser(
      uid,
      {
        title: "🛡️ Nueva invitación de compañero",
        body: `${fromName} quiere acompañarte en la batalla.`,
      },
      {
        type: "battle_invite",
        inviteId,
        fromName,
      },
      {priority: "normal"}
    );
  });

// ═══════════════════════════════════════════════════════════════════════════
// 2. onBattleMessageCreated
// ═══════════════════════════════════════════════════════════════════════════
export const onBattleMessageCreated = functions
  .region("us-central1")
  .firestore.document("users/{uid}/battleMessages/{messageId}")
  .onCreate(async (snap, context) => {
    const data = snap.data() ?? {};
    const uid = context.params.uid as string;
    const messageId = context.params.messageId as string;
    const messageKey = (data.messageKey as string) ?? "";
    const priority = (data.priority as string) ?? "normal";
    const fromName = (data.fromName as string) ?? "Tu compañero";
    const isSos = messageKey === "sos_prayer" || priority === "sos";
    const text = (data.text as string) ??
      (isSos ? "Necesito oración ahora" : "Te envió un mensaje de aliento");

    if (isSos) {
      await pushToUser(
        uid,
        {
          title: "🆘 Tu compañero necesita oración",
          body: `${fromName} está pidiendo oración AHORA. Ora con él.`,
        },
        {
          type: "battle_sos",
          messageId,
          messageKey,
          priority: "sos",
          fromName,
          text,
        },
        {priority: "high"}
      );
    } else {
      await pushToUser(
        uid,
        {
          title: `💬 ${fromName}`,
          body: text,
        },
        {
          type: "battle_message",
          messageId,
          messageKey,
          fromName,
          text,
        },
        {priority: "normal"}
      );
    }
  });

// ═══════════════════════════════════════════════════════════════════════════
// 3. purgeOldPartnerInvites — scheduled 1x/día
// Borra invites con status != 'pending' y >30 días de antigüedad.
// ═══════════════════════════════════════════════════════════════════════════
export const purgeOldPartnerInvites = functions
  .region("us-central1")
  .pubsub.schedule("every 24 hours")
  .timeZone("Etc/UTC")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 30 * 24 * 60 * 60 * 1000
    );
    const q = db()
      .collectionGroup("partnerInvites")
      .where("status", "in", ["accepted", "rejected"])
      .where("createdAt", "<", cutoff)
      .limit(500);
    const snap = await q.get();
    if (snap.empty) return;
    const batch = db().batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    console.log(`[purgeOldPartnerInvites] Deleted ${snap.size} stale invites`);
  });
