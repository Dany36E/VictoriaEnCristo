"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * DELETE USER DATA - Cloud Function
 * Elimina recursivamente todos los datos del usuario en Firestore + Auth.
 *
 * Uso de admin.firestore().recursiveDelete() para asegurar que TODAS las
 * subcolecciones (conocidas y futuras) sean borradas, evitando huérfanos.
 *
 * Política:
 * - Si Firestore falla, NO se borra Auth (evita inconsistencia). El cliente
 *   puede reintentar.
 * - Auth se borra al final para que en caso de error parcial el usuario aún
 *   pueda autenticarse y reintentar.
 * ═══════════════════════════════════════════════════════════════════════════
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteUserData = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const db = admin.firestore();
const auth = admin.auth();
/**
 * Subcolecciones explícitas que enumeramos para reportar telemetría.
 * recursiveDelete las borra automáticamente; aquí solo contamos.
 */
const KNOWN_USER_SUBCOLLECTIONS = [
    "victoryDays",
    "journalEntries",
    "plansProgress",
    "widgetConfig",
    "fcmTokens",
    "battlePartners",
    "partnerInvites",
    "battleMessages",
    "publicProgress",
    "bibleHighlights",
    "bibleNotes",
    "savedVerses",
    "versePrayers",
    "bibleSettings",
    "appState",
    "talents",
    "badges",
    "favorites",
    "chapterNotes",
    "verseCollections",
    "learning",
];
async function countSubcollection(userDocRef, subcollectionName) {
    try {
        const snap = await userDocRef.collection(subcollectionName).count().get();
        return snap.data().count;
    }
    catch (_) {
        return 0;
    }
}
/**
 * Callable function: deleteUserData
 * Borra los datos del propio usuario (uid del token).
 */
exports.deleteUserData = functions
    .region("us-central1")
    .runWith({ timeoutSeconds: 540, memory: "512MB" })
    .https.onCall(async (_data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión para eliminar tu cuenta.");
    }
    const uid = context.auth.uid;
    const uidShort = uid.substring(0, 8);
    console.log(`🗑️ [DELETE] Starting deletion for ${uidShort}…`);
    const deletionStats = {};
    const userDocRef = db.collection("users").doc(uid);
    // Telemetría previa
    for (const sub of KNOWN_USER_SUBCOLLECTIONS) {
        deletionStats[sub] = await countSubcollection(userDocRef, sub);
    }
    // Borrado recursivo (incluye TODAS las subcolecciones, listadas o no)
    try {
        await db.recursiveDelete(userDocRef);
        deletionStats["firestoreRecursive"] = 1;
        console.log(`🗑️ [DELETE] Firestore OK for ${uidShort}…`);
    }
    catch (err) {
        console.error(`❌ [DELETE] recursiveDelete failed:`, err);
        throw new functions.https.HttpsError("internal", "No se pudieron eliminar todos los datos. Intenta de nuevo en unos minutos.", { phase: "firestore" });
    }
    // Borrar códigos de invitación del usuario en /inviteCodes (colección
    // top-level, fuera del árbol de /users/{uid}, así que recursiveDelete no
    // la cubre). Sin esto quedan códigos huérfanos apuntando a un uid que ya
    // no existe, y las rules impiden borrarlos desde cliente.
    try {
        const codesSnap = await db
            .collection("inviteCodes")
            .where("uid", "==", uid)
            .get();
        for (const doc of codesSnap.docs) {
            await doc.ref.delete();
        }
        deletionStats["inviteCodes"] = codesSnap.size;
        if (codesSnap.size > 0) {
            console.log(`🗑️ [DELETE] ${codesSnap.size} inviteCode(s) deleted for ${uidShort}…`);
        }
    }
    catch (err) {
        // No bloquear el borrado de Auth por esto: el código huérfano es
        // inofensivo (no resuelve a ningún usuario) y preferimos completar
        // la eliminación de la cuenta.
        console.error(`⚠️ [DELETE] inviteCodes cleanup failed:`, err);
        deletionStats["inviteCodes"] = -1;
    }
    // Borrar usuario de Auth
    // Los datos de Firestore ya fueron eliminados. Si auth.deleteUser falla
    // por user-not-found, es idempotente (OK). Si falla por otro motivo,
    // retornamos éxito parcial para que el cliente informe al usuario y
    // permita reintentar — no es un error total porque los datos ya no existen.
    let authDeletionFailed = false;
    try {
        await auth.deleteUser(uid);
        deletionStats["authUser"] = 1;
        console.log(`🗑️ [DELETE] Auth deleted ${uidShort}…`);
    }
    catch (err) {
        if ((err === null || err === void 0 ? void 0 : err.code) === "auth/user-not-found") {
            // Ya eliminado previamente — idempotente, OK.
            deletionStats["authUser"] = 0;
        }
        else {
            console.error(`❌ [DELETE] Auth deletion failed for ${uidShort}:`, err);
            deletionStats["authUser"] = -1;
            authDeletionFailed = true;
        }
    }
    console.log(`✅ [DELETE] Done ${uidShort}… stats:`, deletionStats);
    if (authDeletionFailed) {
        return {
            success: false,
            partialSuccess: true,
            message: "Tus datos fueron eliminados, pero no se pudo cerrar tu cuenta de autenticación. " +
                "Puedes intentarlo de nuevo desde Ajustes → Eliminar cuenta.",
            deletedSubcollections: deletionStats,
        };
    }
    return {
        success: true,
        partialSuccess: false,
        message: "Cuenta y datos eliminados correctamente",
        deletedSubcollections: deletionStats,
    };
});
//# sourceMappingURL=deleteUserData.js.map