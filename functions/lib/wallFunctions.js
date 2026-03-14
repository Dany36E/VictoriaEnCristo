"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * WALL FUNCTIONS - Muro de Batalla
 * Anonimato total: genera aliases, hash de abuso, moderación pre-publicación.
 * NUNCA guarda UID del autor de forma legible.
 * ═══════════════════════════════════════════════════════════════════════════
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.banAbuseHash = exports.reportContent = exports.moderateContent = exports.createWallComment = exports.createWallPost = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const crypto = require("crypto");
const db = admin.firestore();
// ═══════════════════════════════════════════════════════════════════════════
// CONFIGURACIÓN
// ═══════════════════════════════════════════════════════════════════════════
// Salt secreto para hashing — en producción usar functions.config() o Secret Manager
const SERVER_SECRET_SALT = process.env.WALL_ABUSE_SALT ||
    "VeC_s4lt_2026_m@k3_h4sh_1rr3v3rs1bl3";
const VALID_GIANTS = [
    "digital", "sexual", "health", "substances", "mental", "emotions",
];
const VALID_REPORT_REASONS = [
    "offensive", "spam", "toxic", "off_topic", "other",
];
const MAX_POST_LENGTH = 500;
const MAX_COMMENT_LENGTH = 300;
const MAX_POSTS_PER_DAY = 5;
// Palabras bloqueadas (contenido dañino, insultos graves, URLs)
const BLOCKED_PATTERNS = [
    /https?:\/\//i,
    /www\./i,
    /\.com\b/i,
    /\bput[o@]s?\b/i,
    /\bmierda\b/i,
    /\bhijue?putas?\b/i,
    /\bpend?ej[oa]s?\b/i,
    /\bmal ?parido\b/i,
    /\bgonorrea\b/i,
    /\bmaric[oó]n\b/i,
    /\bsuicid(ar|ate|io)\b/i,
    /\bautolesion/i,
    /\bcort(ar|ate)\s*(las?\s*venas?|te)\b/i,
];
// ═══════════════════════════════════════════════════════════════════════════
// HELPERS
// ═══════════════════════════════════════════════════════════════════════════
function computeAbuseHash(uid) {
    return crypto
        .createHash("sha256")
        .update(uid + SERVER_SECRET_SALT)
        .digest("hex")
        .substring(0, 16);
}
function generateAlias() {
    const num = Math.floor(Math.random() * 9000) + 1000; // 1000-9999
    return `Guerrero #${num}`;
}
function sanitizeBody(text, maxLen) {
    return text.trim().substring(0, maxLen);
}
function containsBlockedContent(text) {
    const lower = text.toLowerCase();
    return BLOCKED_PATTERNS.some((pat) => pat.test(lower));
}
async function isUserAdmin(uid) {
    var _a;
    try {
        const doc = await db.collection("users").doc(uid).get();
        return doc.exists && ((_a = doc.data()) === null || _a === void 0 ? void 0 : _a.isAdmin) === true;
    }
    catch (_b) {
        return false;
    }
}
async function isAbuseHashBanned(hash) {
    const doc = await db.collection("abuseHashes").doc(hash).get();
    return doc.exists;
}
async function countRecentPosts(abuseHash, hoursBack = 24) {
    const cutoff = admin.firestore.Timestamp.fromDate(new Date(Date.now() - hoursBack * 60 * 60 * 1000));
    const snap = await db
        .collection("wallPosts")
        .where("abuseHash", "==", abuseHash)
        .where("createdAt", ">=", cutoff)
        .get();
    return snap.size;
}
// ═══════════════════════════════════════════════════════════════════════════
// 1. CREATE WALL POST
// ═══════════════════════════════════════════════════════════════════════════
exports.createWallPost = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
    // Auth check
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    try {
        const uid = context.auth.uid;
        const { giantId, body } = data;
        // Validate giantId
        if (!giantId || !VALID_GIANTS.includes(giantId)) {
            throw new functions.https.HttpsError("invalid-argument", "Gigante inválido.");
        }
        // Validate body
        if (!body || typeof body !== "string" || body.trim().length === 0) {
            throw new functions.https.HttpsError("invalid-argument", "El texto no puede estar vacío.");
        }
        if (body.length > MAX_POST_LENGTH) {
            throw new functions.https.HttpsError("invalid-argument", `Máximo ${MAX_POST_LENGTH} caracteres.`);
        }
        // Compute abuse hash
        const abuseHash = computeAbuseHash(uid);
        // Check ban
        if (await isAbuseHashBanned(abuseHash)) {
            throw new functions.https.HttpsError("permission-denied", "Tu cuenta no tiene permiso para publicar.");
        }
        // Rate limit
        const recentCount = await countRecentPosts(abuseHash);
        if (recentCount >= MAX_POSTS_PER_DAY) {
            throw new functions.https.HttpsError("resource-exhausted", "Límite de publicaciones alcanzado. Intenta mañana.");
        }
        // Content filter
        const sanitized = sanitizeBody(body, MAX_POST_LENGTH);
        if (containsBlockedContent(sanitized)) {
            // Auto-reject without telling user exactly why
            const postRef = db.collection("wallPosts").doc();
            await postRef.set({
                alias: generateAlias(),
                abuseHash,
                giantId,
                body: sanitized,
                status: "rejected",
                rejectionReason: "Contenido bloqueado automáticamente",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                commentCount: 0,
                reportCount: 0,
            });
            // Return success to not reveal the filter
            return {
                success: true,
                postId: postRef.id,
                message: "Tu publicación está en revisión.",
            };
        }
        // Create post with status=pending
        const postRef = db.collection("wallPosts").doc();
        await postRef.set({
            alias: generateAlias(),
            abuseHash,
            giantId,
            body: sanitized,
            status: "pending",
            rejectionReason: null,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedAt: null,
            approvedBy: null,
            commentCount: 0,
            reportCount: 0,
        });
        console.log(`[WALL] New post ${postRef.id} by hash ${abuseHash}`);
        return {
            success: true,
            postId: postRef.id,
            message: "Tu publicación está en revisión.",
        };
    }
    catch (err) {
        if (err instanceof functions.https.HttpsError)
            throw err;
        console.error("[WALL] createWallPost unexpected error:", err);
        throw new functions.https.HttpsError("internal", "Error interno al crear publicación.");
    }
});
// ═══════════════════════════════════════════════════════════════════════════
// 2. CREATE WALL COMMENT
// ═══════════════════════════════════════════════════════════════════════════
exports.createWallComment = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
    var _a;
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    try {
        const uid = context.auth.uid;
        const { postId, body } = data;
        if (!postId || typeof postId !== "string") {
            throw new functions.https.HttpsError("invalid-argument", "Post ID inválido.");
        }
        if (!body || typeof body !== "string" || body.trim().length === 0) {
            throw new functions.https.HttpsError("invalid-argument", "El comentario no puede estar vacío.");
        }
        if (body.length > MAX_COMMENT_LENGTH) {
            throw new functions.https.HttpsError("invalid-argument", `Máximo ${MAX_COMMENT_LENGTH} caracteres.`);
        }
        // Verify post exists and is approved
        const postDoc = await db.collection("wallPosts").doc(postId).get();
        if (!postDoc.exists || ((_a = postDoc.data()) === null || _a === void 0 ? void 0 : _a.status) !== "approved") {
            throw new functions.https.HttpsError("not-found", "Publicación no encontrada.");
        }
        const abuseHash = computeAbuseHash(uid);
        if (await isAbuseHashBanned(abuseHash)) {
            throw new functions.https.HttpsError("permission-denied", "Tu cuenta no tiene permiso para comentar.");
        }
        const sanitized = sanitizeBody(body, MAX_COMMENT_LENGTH);
        // Content filter — auto-reject silently
        if (containsBlockedContent(sanitized)) {
            const commentRef = db
                .collection("wallPosts")
                .doc(postId)
                .collection("comments")
                .doc();
            await commentRef.set({
                alias: generateAlias(),
                abuseHash,
                body: sanitized,
                status: "rejected",
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
                approvedAt: null,
            });
            return {
                success: true,
                commentId: commentRef.id,
                message: "Tu comentario está en revisión.",
            };
        }
        const commentRef = db
            .collection("wallPosts")
            .doc(postId)
            .collection("comments")
            .doc();
        await commentRef.set({
            alias: generateAlias(),
            abuseHash,
            body: sanitized,
            status: "pending",
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            approvedAt: null,
        });
        console.log(`[WALL] New comment ${commentRef.id} on post ${postId}`);
        return {
            success: true,
            commentId: commentRef.id,
            message: "Tu comentario está en revisión.",
        };
    }
    catch (err) {
        if (err instanceof functions.https.HttpsError)
            throw err;
        console.error("[WALL] createWallComment unexpected error:", err);
        throw new functions.https.HttpsError("internal", "Error interno al crear comentario.");
    }
});
// ═══════════════════════════════════════════════════════════════════════════
// 3. MODERATE CONTENT (admin only)
// ═══════════════════════════════════════════════════════════════════════════
exports.moderateContent = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    try {
        const adminUid = context.auth.uid;
        if (!(await isUserAdmin(adminUid))) {
            throw new functions.https.HttpsError("permission-denied", "No tienes permisos de administrador.");
        }
        // Accept both 'type' and 'contentType' for compatibility
        const type = data.type || data.contentType;
        const { postId, commentId, action, rejectionReason } = data;
        if (!["post", "comment"].includes(type)) {
            throw new functions.https.HttpsError("invalid-argument", "Tipo inválido.");
        }
        if (!["approve", "reject"].includes(action)) {
            throw new functions.https.HttpsError("invalid-argument", "Acción inválida.");
        }
        if (!postId || typeof postId !== "string") {
            throw new functions.https.HttpsError("invalid-argument", "Post ID requerido.");
        }
        const now = admin.firestore.FieldValue.serverTimestamp();
        if (type === "post") {
            const postRef = db.collection("wallPosts").doc(postId);
            const postDoc = await postRef.get();
            if (!postDoc.exists) {
                throw new functions.https.HttpsError("not-found", "Post no encontrado.");
            }
            if (action === "approve") {
                await postRef.update({
                    status: "approved",
                    approvedAt: now,
                    approvedBy: adminUid,
                });
                console.log(`[WALL] Post ${postId} approved by ${adminUid}`);
            }
            else {
                await postRef.update({
                    status: "rejected",
                    rejectionReason: rejectionReason || "Rechazado por moderador",
                });
                console.log(`[WALL] Post ${postId} rejected by ${adminUid}`);
            }
        }
        else {
            // Comment
            if (!commentId || typeof commentId !== "string") {
                throw new functions.https.HttpsError("invalid-argument", "Comment ID requerido.");
            }
            const commentRef = db
                .collection("wallPosts")
                .doc(postId)
                .collection("comments")
                .doc(commentId);
            const commentDoc = await commentRef.get();
            if (!commentDoc.exists) {
                throw new functions.https.HttpsError("not-found", "Comentario no encontrado.");
            }
            if (action === "approve") {
                await commentRef.update({
                    status: "approved",
                    approvedAt: now,
                });
                // Increment commentCount on parent post
                await db
                    .collection("wallPosts")
                    .doc(postId)
                    .update({
                    commentCount: admin.firestore.FieldValue.increment(1),
                });
                console.log(`[WALL] Comment ${commentId} on ${postId} approved`);
            }
            else {
                await commentRef.update({
                    status: "rejected",
                });
                console.log(`[WALL] Comment ${commentId} on ${postId} rejected`);
            }
        }
        return { success: true };
    }
    catch (err) {
        if (err instanceof functions.https.HttpsError)
            throw err;
        console.error("[WALL] moderateContent unexpected error:", err);
        throw new functions.https.HttpsError("internal", "Error interno al moderar contenido.");
    }
});
// ═══════════════════════════════════════════════════════════════════════════
// 4. REPORT CONTENT
// ═══════════════════════════════════════════════════════════════════════════
exports.reportContent = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    try {
        const uid = context.auth.uid;
        const { postId, commentId, reason } = data;
        if (!postId || typeof postId !== "string") {
            throw new functions.https.HttpsError("invalid-argument", "Post ID requerido.");
        }
        if (!reason || !VALID_REPORT_REASONS.includes(reason)) {
            throw new functions.https.HttpsError("invalid-argument", "Razón de reporte inválida.");
        }
        const reporterHash = computeAbuseHash(uid);
        // Create report
        await db.collection("wallReports").add({
            postId,
            commentId: commentId || null,
            reporterHash,
            reason,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            resolved: false,
        });
        // Increment reportCount on the post
        const postRef = db.collection("wallPosts").doc(postId);
        await postRef.update({
            reportCount: admin.firestore.FieldValue.increment(1),
        });
        console.log(`[WALL] Report on post ${postId} reason=${reason}`);
        return { success: true, message: "Reporte enviado. Gracias." };
    }
    catch (err) {
        if (err instanceof functions.https.HttpsError)
            throw err;
        console.error("[WALL] reportContent unexpected error:", err);
        throw new functions.https.HttpsError("internal", "Error interno al reportar contenido.");
    }
});
// ═══════════════════════════════════════════════════════════════════════════
// 5. BAN USER (admin only)
// ═══════════════════════════════════════════════════════════════════════════
exports.banAbuseHash = functions
    .region("us-central1")
    .https.onCall(async (data, context) => {
    if (!context.auth) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    try {
        const adminUid = context.auth.uid;
        if (!(await isUserAdmin(adminUid))) {
            throw new functions.https.HttpsError("permission-denied", "No tienes permisos de administrador.");
        }
        const { abuseHash, reason } = data;
        if (!abuseHash || typeof abuseHash !== "string") {
            throw new functions.https.HttpsError("invalid-argument", "abuseHash requerido.");
        }
        // Create ban record
        await db.collection("abuseHashes").doc(abuseHash).set({
            bannedAt: admin.firestore.FieldValue.serverTimestamp(),
            reason: reason || "Baneado por moderador",
            bannedBy: adminUid,
        });
        // Auto-reject all pending posts from this hash
        const pendingPosts = await db
            .collection("wallPosts")
            .where("abuseHash", "==", abuseHash)
            .where("status", "==", "pending")
            .get();
        const batch = db.batch();
        for (const doc of pendingPosts.docs) {
            batch.update(doc.ref, {
                status: "rejected",
                rejectionReason: "Autor baneado",
            });
        }
        await batch.commit();
        console.log(`[WALL] Hash ${abuseHash} banned. ${pendingPosts.size} posts rejected.`);
        return {
            success: true,
            rejectedCount: pendingPosts.size,
        };
    }
    catch (err) {
        if (err instanceof functions.https.HttpsError)
            throw err;
        console.error("[WALL] banAbuseHash unexpected error:", err);
        throw new functions.https.HttpsError("internal", "Error interno al banear usuario.");
    }
});
//# sourceMappingURL=wallFunctions.js.map