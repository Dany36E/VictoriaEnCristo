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

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

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

async function countSubcollection(
  userDocRef: FirebaseFirestore.DocumentReference,
  subcollectionName: string
): Promise<number> {
  try {
    const snap = await userDocRef.collection(subcollectionName).count().get();
    return snap.data().count;
  } catch (_) {
    return 0;
  }
}

/**
 * Callable function: deleteUserData
 * Borra los datos del propio usuario (uid del token).
 */
export const deleteUserData = functions
  .region("us-central1")
  .runWith({timeoutSeconds: 540, memory: "512MB"})
  .https.onCall(async (_data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Debes iniciar sesión para eliminar tu cuenta."
      );
    }

    const uid = context.auth.uid;
    const uidShort = uid.substring(0, 8);
    console.log(`🗑️ [DELETE] Starting deletion for ${uidShort}…`);

    const deletionStats: Record<string, number> = {};
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
    } catch (err) {
      console.error(`❌ [DELETE] recursiveDelete failed:`, err);
      throw new functions.https.HttpsError(
        "internal",
        "No se pudieron eliminar todos los datos. Intenta de nuevo en unos minutos.",
        {phase: "firestore"}
      );
    }

    // Borrar usuario de Auth
    try {
      await auth.deleteUser(uid);
      deletionStats["authUser"] = 1;
      console.log(`🗑️ [DELETE] Auth deleted ${uidShort}…`);
    } catch (err: any) {
      if (err?.code === "auth/user-not-found") {
        deletionStats["authUser"] = 0;
      } else {
        console.error(`❌ [DELETE] Auth deletion failed:`, err);
        deletionStats["authUser"] = -1;
      }
    }

    console.log(`✅ [DELETE] Done ${uidShort}… stats:`, deletionStats);

    return {
      success: true,
      message: "Cuenta y datos eliminados correctamente",
      deletedSubcollections: deletionStats,
    };
  });
