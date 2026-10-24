"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * DELETE USER DATA - Cloud Function
 * Elimina recursivamente todos los datos del usuario en Firestore, sus
 * archivos en Cloud Storage y su cuenta de Auth.
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
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.deleteUserData = void 0;
const functions = __importStar(require("firebase-functions/v1"));
const limites_1 = require("./limites");
const adminFirestore = __importStar(require("firebase-admin/firestore"));
const auth_1 = require("firebase-admin/auth");
const storage_1 = require("firebase-admin/storage");
const crypto = __importStar(require("crypto"));
const battlePartnerFunctions_1 = require("./battlePartnerFunctions");
const db = adminFirestore.getFirestore();
const auth = (0, auth_1.getAuth)();
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
    "blockedWallAuthors",
    "sermonNotes",
    "triggerLogs",
    "sermonOutlines",
    "studyAnswers",
    "studyHighlights",
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
 * Borra lo que el usuario dejó fuera de su propio árbol:
 * - su vínculo en la lista de cada compañero (con el reflejo de su progreso),
 * - los mensajes/SOS que envió y las invitaciones pendientes que mandó,
 * - el candado del guardián (como protegido y como guardián),
 * - sus documentos de rendición de cuentas y estado del Escudo, y su
 *   aparición en las listas de avisos de otros.
 * @param {string} uid usuario que se elimina.
 * @return {Promise<number>} documentos tocados.
 */
async function limpiarRastroEnCompaneros(uid) {
    const writer = db.bulkWriter();
    let tocados = 0;
    const vinculos = await db.collection("users").doc(uid).collection("battlePartners").get();
    const companeros = new Set();
    vinculos.docs.forEach((d) => {
        var _a;
        const otro = (_a = d.data().partnerUid) !== null && _a !== void 0 ? _a : d.id;
        if (otro && otro !== uid)
            companeros.add(otro);
    });
    // Invitaciones que envié y siguen pendientes (el vínculo puede no existir aún).
    const enviadas = await db
        .collectionGroup("partnerInvites")
        .where("fromUid", "==", uid)
        .limit(50)
        .get()
        .catch(() => null);
    enviadas === null || enviadas === void 0 ? void 0 : enviadas.docs.forEach((d) => {
        writer.delete(d.ref);
        tocados++;
    });
    for (const otro of companeros) {
        const userOtro = db.collection("users").doc(otro);
        writer.delete(userOtro.collection("battlePartners").doc(uid));
        tocados++;
        const mensajes = await userOtro.collection("battleMessages")
            .where("fromUid", "==", uid).limit(500).get();
        mensajes.docs.forEach((m) => {
            writer.delete(m.ref);
            tocados++;
        });
        writer.set(db.collection("accountability").doc(otro), {
            shieldAlertPartners: adminFirestore.FieldValue.arrayRemove(uid),
            weeklyReportPartners: adminFirestore.FieldValue.arrayRemove(uid),
        }, { merge: true });
    }
    await writer.close();
    // Candado del guardián en ambos sentidos.
    for (const otro of companeros) {
        await (0, battlePartnerFunctions_1.retirarCandadoEntre)(uid, otro);
        await (0, battlePartnerFunctions_1.retirarCandadoEntre)(otro, uid);
    }
    const final = db.bulkWriter();
    final.delete(db.collection("guardianLocks").doc(uid));
    final.delete(db.collection("accountability").doc(uid));
    final.delete(db.collection("accountabilityState").doc(uid));
    final.delete(db.collection("shieldStatus").doc(uid));
    await final.close();
    return tocados + 4;
}
/**
 * Callable function: deleteUserData
 * Borra los datos del propio usuario (uid del token).
 */
exports.deleteUserData = (0, limites_1.enRegion)({
    timeoutSeconds: 540,
    memory: "512MB",
    secrets: ["WALL_ABUSE_SALT"],
    // Borrar una cuenta es raro y pesado: pocas a la vez.
    maxInstances: 3,
})
    .https.onCall(async (_data, context) => {
    var _a, _b;
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión para eliminar tu cuenta.");
    }
    const uid = context.auth.uid;
    const uidShort = uid.substring(0, 8);
    const wallSalt = process.env.WALL_ABUSE_SALT;
    if (!wallSalt || wallSalt.length < 16) {
        throw new functions.https.HttpsError("failed-precondition", "No se pudo verificar la eliminación del contenido comunitario. Intenta más tarde.");
    }
    const abuseHash = crypto
        .createHash("sha256")
        .update(uid + wallSalt)
        .digest("hex")
        .substring(0, 16);
    console.log(`🗑️ [DELETE] Starting deletion for ${uidShort}…`);
    const deletionStats = {};
    const userDocRef = db.collection("users").doc(uid);
    // El Muro usa un hash seudónimo en colecciones de nivel superior. Aunque
    // no expone el UID, sigue siendo vinculable por el servidor y por ello se
    // elimina junto con la cuenta.
    try {
        const posts = await db
            .collection("wallPosts")
            .where("abuseHash", "==", abuseHash)
            .get();
        for (const post of posts.docs)
            await db.recursiveDelete(post.ref);
        const comments = await db
            .collectionGroup("comments")
            .where("abuseHash", "==", abuseHash)
            .get();
        const reports = await db
            .collection("wallReports")
            .where("reporterHash", "==", abuseHash)
            .get();
        const cleanup = db.bulkWriter();
        for (const comment of comments.docs)
            cleanup.delete(comment.ref);
        for (const report of reports.docs)
            cleanup.delete(report.ref);
        cleanup.delete(db.collection("abuseHashes").doc(abuseHash));
        await cleanup.close();
        deletionStats["wallPosts"] = posts.size;
        deletionStats["wallComments"] = comments.size;
        deletionStats["wallReports"] = reports.size;
    }
    catch (err) {
        console.error("❌ [DELETE] Wall cleanup failed:", err);
        throw new functions.https.HttpsError("internal", "No se pudo eliminar todo el contenido comunitario. Intenta de nuevo.", { phase: "wall" });
    }
    // Compañero de batalla: lo que vive en el árbol de OTROS usuarios y en
    // colecciones de nivel superior no lo borra recursiveDelete.
    try {
        deletionStats["partnerCleanup"] = await limpiarRastroEnCompaneros(uid);
    }
    catch (err) {
        console.error("❌ [DELETE] Partner cleanup failed:", err);
        throw new functions.https.HttpsError("internal", "No se pudieron eliminar tus vínculos con compañeros. Intenta de nuevo.", { phase: "partners" });
    }
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
    // Archivos del usuario en Cloud Storage (fotos y dibujos de Apuntes,
    // bajo users/{uid}/). Si el proyecto no tiene bucket no hay nada que
    // borrar; cualquier otro error se reporta para que el cliente reintente.
    try {
        const bucket = (0, storage_1.getStorage)().bucket();
        const prefix = `users/${uid}/`;
        const [files] = await bucket.getFiles({ prefix });
        await bucket.deleteFiles({ prefix });
        deletionStats["storageFiles"] = files.length;
    }
    catch (err) {
        const status = (_a = err === null || err === void 0 ? void 0 : err.code) !== null && _a !== void 0 ? _a : (_b = err === null || err === void 0 ? void 0 : err.response) === null || _b === void 0 ? void 0 : _b.status;
        if (status === 404) {
            deletionStats["storageFiles"] = 0;
        }
        else {
            console.error(`❌ [DELETE] Storage cleanup failed:`, err);
            throw new functions.https.HttpsError("internal", "No se pudieron eliminar tus fotos y dibujos. Intenta de nuevo en unos minutos.", { phase: "storage" });
        }
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