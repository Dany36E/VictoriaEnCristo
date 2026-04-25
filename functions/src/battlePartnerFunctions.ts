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

interface FcmTokenDoc {
  token: string;
  platform?: string;
}

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
