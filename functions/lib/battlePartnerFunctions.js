"use strict";
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
Object.defineProperty(exports, "__esModule", { value: true });
exports.purgeOldPartnerInvites = exports.onBattleMessageCreated = exports.onPartnerInviteCreated = void 0;
const admin = require("firebase-admin");
const functions = require("firebase-functions");
const db = () => admin.firestore();
/**
 * Lee todos los tokens FCM del usuario objetivo.
 */
async function getUserTokens(uid) {
    const snap = await db().collection("users").doc(uid).collection("fcmTokens").get();
    const tokens = [];
    snap.forEach((d) => {
        const data = d.data();
        if (data && typeof data.token === "string" && data.token.length > 0) {
            tokens.push(data.token);
        }
    });
    return tokens;
}
/**
 * Elimina tokens inválidos devueltos por FCM.
 */
async function cleanupInvalidTokens(uid, responses, tokens) {
    const toDelete = [];
    responses.forEach((r, idx) => {
        var _a, _b;
        if (r.success)
            return;
        const code = (_b = (_a = r.error) === null || _a === void 0 ? void 0 : _a.code) !== null && _b !== void 0 ? _b : "";
        if (code === "messaging/invalid-registration-token" ||
            code === "messaging/registration-token-not-registered") {
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
async function pushToUser(uid, notification, data, options = {}) {
    const tokens = await getUserTokens(uid);
    if (tokens.length === 0)
        return;
    const msg = {
        tokens,
        notification,
        data,
        android: {
            priority: options.priority === "high" ? "high" : "normal",
            notification: {
                channelId: data["type"] === "battle_sos"
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
                    "interruption-level": data["type"] === "battle_sos" ? "time-sensitive" : "active",
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
exports.onPartnerInviteCreated = functions
    .region("us-central1")
    .firestore.document("users/{uid}/partnerInvites/{inviteId}")
    .onCreate(async (snap, context) => {
    var _a, _b, _c;
    const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
    const uid = context.params.uid;
    const status = (_b = data.status) !== null && _b !== void 0 ? _b : "pending";
    if (status !== "pending")
        return;
    const fromName = (_c = data.fromName) !== null && _c !== void 0 ? _c : "Alguien";
    await pushToUser(uid, {
        title: "🛡️ Nueva invitación de compañero",
        body: `${fromName} quiere acompañarte en la batalla.`,
    }, {
        type: "battle_invite",
        fromName,
    }, { priority: "normal" });
});
// ═══════════════════════════════════════════════════════════════════════════
// 2. onBattleMessageCreated
// ═══════════════════════════════════════════════════════════════════════════
exports.onBattleMessageCreated = functions
    .region("us-central1")
    .firestore.document("users/{uid}/battleMessages/{messageId}")
    .onCreate(async (snap, context) => {
    var _a, _b, _c, _d;
    const data = (_a = snap.data()) !== null && _a !== void 0 ? _a : {};
    const uid = context.params.uid;
    const messageKey = (_b = data.messageKey) !== null && _b !== void 0 ? _b : "";
    const priority = (_c = data.priority) !== null && _c !== void 0 ? _c : "normal";
    const fromName = (_d = data.fromName) !== null && _d !== void 0 ? _d : "Tu compañero";
    const isSos = messageKey === "sos_prayer" || priority === "sos";
    if (isSos) {
        await pushToUser(uid, {
            title: "🆘 Tu compañero necesita oración",
            body: `${fromName} está pidiendo oración AHORA. Ora con él.`,
        }, {
            type: "battle_sos",
            fromName,
        }, { priority: "high" });
    }
    else {
        await pushToUser(uid, {
            title: `💬 ${fromName}`,
            body: "Te envió un mensaje de aliento",
        }, {
            type: "battle_message",
            fromName,
        }, { priority: "normal" });
    }
});
// ═══════════════════════════════════════════════════════════════════════════
// 3. purgeOldPartnerInvites — scheduled 1x/día
// Borra invites con status != 'pending' y >30 días de antigüedad.
// ═══════════════════════════════════════════════════════════════════════════
exports.purgeOldPartnerInvites = functions
    .region("us-central1")
    .pubsub.schedule("every 24 hours")
    .timeZone("Etc/UTC")
    .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const q = db()
        .collectionGroup("partnerInvites")
        .where("status", "in", ["accepted", "rejected"])
        .where("createdAt", "<", cutoff)
        .limit(500);
    const snap = await q.get();
    if (snap.empty)
        return;
    const batch = db().batch();
    snap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
    console.log(`[purgeOldPartnerInvites] Deleted ${snap.size} stale invites`);
});
//# sourceMappingURL=battlePartnerFunctions.js.map