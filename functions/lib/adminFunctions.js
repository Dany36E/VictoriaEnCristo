"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * ADMIN FUNCTIONS
 * - setAdminClaim: solo un admin existente puede otorgar/revocar claims a otro
 *   uid. El primer admin debe configurarse manualmente con un script gcloud:
 *     gcloud auth login
 *     node scripts/grant-first-admin.js <uid>
 * - cleanStaleFcmTokens: scheduled diario, borra tokens FCM con `updatedAt`
 *   más antiguo que 90 días.
 * ═══════════════════════════════════════════════════════════════════════════
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.signOutAllDevices = exports.cleanStaleFcmTokens = exports.setAdminClaim = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const db = admin.firestore();
const auth = admin.auth();
const STALE_TOKEN_DAYS = 90;
/**
 * Otorga o revoca el custom claim `admin` a otro usuario.
 * Solo callable por usuarios con `admin === true` en su token actual.
 */
exports.setAdminClaim = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
    var _a, _b, _c;
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const callerIsAdmin = ((_a = context.auth.token) === null || _a === void 0 ? void 0 : _a.admin) === true;
    if (!callerIsAdmin) {
        // Fallback: leer Firestore (compat durante migración)
        const callerDoc = await db.collection("users").doc(context.auth.uid).get();
        if (!(callerDoc.exists && ((_b = callerDoc.data()) === null || _b === void 0 ? void 0 : _b.isAdmin) === true)) {
            throw new functions.https.HttpsError("permission-denied", "Solo admins pueden otorgar privilegios.");
        }
    }
    const targetUid = typeof (data === null || data === void 0 ? void 0 : data.uid) === "string" ? data.uid : null;
    const grant = (data === null || data === void 0 ? void 0 : data.grant) !== false; // default true
    if (!targetUid) {
        throw new functions.https.HttpsError("invalid-argument", "uid del destinatario requerido.");
    }
    const user = await auth.getUser(targetUid);
    const existingClaims = (_c = user.customClaims) !== null && _c !== void 0 ? _c : {};
    const newClaims = Object.assign(Object.assign({}, existingClaims), { admin: grant });
    await auth.setCustomUserClaims(targetUid, newClaims);
    // Reflejar en Firestore para legibilidad
    await db.collection("users").doc(targetUid).set({
        isAdmin: grant,
        adminUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        adminUpdatedBy: context.auth.uid,
    }, { merge: true });
    console.log(`[ADMIN] ${grant ? "granted" : "revoked"} admin to ${targetUid.substring(0, 8)}…` +
        ` by ${context.auth.uid.substring(0, 8)}…`);
    return { success: true, uid: targetUid, admin: grant };
});
/**
 * Borra tokens FCM con updatedAt más antiguo que STALE_TOKEN_DAYS días.
 * Tokens viejos pueden estar registrados en dispositivos perdidos / desinstalados.
 *
 * Schedule: cada día a las 03:00 UTC.
 */
exports.cleanStaleFcmTokens = functions
    .region("us-central1")
    .runWith({ timeoutSeconds: 540, memory: "512MB" })
    .pubsub.schedule("0 3 * * *")
    .timeZone("UTC")
    .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(new Date(Date.now() - STALE_TOKEN_DAYS * 24 * 60 * 60 * 1000));
    const stale = await db.collectionGroup("fcmTokens")
        .where("updatedAt", "<", cutoff)
        .limit(500)
        .get();
    if (stale.empty) {
        console.log("[FCM-CLEAN] No stale tokens.");
        return null;
    }
    const writer = db.bulkWriter();
    for (const doc of stale.docs) {
        writer.delete(doc.ref);
    }
    await writer.close();
    console.log(`[FCM-CLEAN] Deleted ${stale.size} stale FCM tokens.`);
    return null;
});
/**
 * Cierra sesión en TODOS los dispositivos del usuario actual.
 *
 * Uso típico: usuario sospecha que su cuenta fue comprometida.
 * Acciones:
 *  1. `auth.revokeRefreshTokens(uid)` invalida todos los refresh tokens
 *     existentes (los ID tokens activos siguen siendo válidos hasta 1h
 *     más, salvo que las reglas Firestore comprueben `auth.token.auth_time`).
 *  2. Borra todos los documentos en `users/{uid}/fcmTokens` para detener
 *     notificaciones a dispositivos viejos.
 */
exports.signOutAllDevices = functions
    .region("us-central1")
    .https.onCall(async (_data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    const uid = context.auth.uid;
    try {
        await auth.revokeRefreshTokens(uid);
    }
    catch (err) {
        console.error("[SIGNOUT-ALL] revoke error:", err);
        throw new functions.https.HttpsError("internal", "No se pudieron invalidar los tokens.");
    }
    // Borrar todos los FCM tokens del usuario.
    try {
        const tokensSnap = await db.collection("users").doc(uid)
            .collection("fcmTokens").limit(100).get();
        if (!tokensSnap.empty) {
            const writer = db.bulkWriter();
            tokensSnap.forEach((d) => writer.delete(d.ref));
            await writer.close();
        }
    }
    catch (err) {
        console.error("[SIGNOUT-ALL] fcm cleanup error:", err);
        // No bloqueamos: tokens viejos serán purgados por cleanStaleFcmTokens.
    }
    return { success: true };
});
//# sourceMappingURL=adminFunctions.js.map