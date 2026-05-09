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

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const auth = admin.auth();

const STALE_TOKEN_DAYS = 90;

/**
 * Otorga o revoca el custom claim `admin` a otro usuario.
 * Solo callable por usuarios con `admin === true` en su token actual.
 */
export const setAdminClaim = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated", "Debes iniciar sesión.");
    }
    const callerIsAdmin = context.auth.token?.admin === true;
    if (!callerIsAdmin) {
      // Fallback: leer Firestore (compat durante migración)
      const callerDoc = await db.collection("users").doc(context.auth.uid).get();
      if (!(callerDoc.exists && callerDoc.data()?.isAdmin === true)) {
        throw new functions.https.HttpsError(
          "permission-denied", "Solo admins pueden otorgar privilegios.");
      }
    }

    const targetUid = typeof data?.uid === "string" ? data.uid : null;
    const grant = data?.grant !== false; // default true
    if (!targetUid) {
      throw new functions.https.HttpsError(
        "invalid-argument", "uid del destinatario requerido.");
    }

    const user = await auth.getUser(targetUid);
    const existingClaims = user.customClaims ?? {};
    const newClaims = {...existingClaims, admin: grant};
    await auth.setCustomUserClaims(targetUid, newClaims);

    // Reflejar en Firestore para legibilidad
    await db.collection("users").doc(targetUid).set({
      isAdmin: grant,
      adminUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminUpdatedBy: context.auth.uid,
    }, {merge: true});

    console.log(
      `[ADMIN] ${grant ? "granted" : "revoked"} admin to ${targetUid.substring(0, 8)}…` +
      ` by ${context.auth.uid.substring(0, 8)}…`);

    return {success: true, uid: targetUid, admin: grant};
  });

/**
 * Borra tokens FCM con updatedAt más antiguo que STALE_TOKEN_DAYS días.
 * Tokens viejos pueden estar registrados en dispositivos perdidos / desinstalados.
 *
 * Schedule: cada día a las 03:00 UTC.
 */
export const cleanStaleFcmTokens = functions
  .region("us-central1")
  .runWith({timeoutSeconds: 540, memory: "512MB"})
  .pubsub.schedule("0 3 * * *")
  .timeZone("UTC")
  .onRun(async () => {
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - STALE_TOKEN_DAYS * 24 * 60 * 60 * 1000));

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
