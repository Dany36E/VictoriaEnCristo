/**
 * ═══════════════════════════════════════════════════════════════════════════
 * DELETE USER DATA - Cloud Function
 * Elimina todos los datos del usuario en Firestore y su cuenta de Auth
 *
 * SUBCOLLECTIONS que se eliminan:
 * - /users/{uid}/victoryDays
 * - /users/{uid}/journalEntries
 * - /users/{uid}/plansProgress
 * - /users/{uid}/widgetConfig
 *
 * Luego elimina:
 * - /users/{uid} (documento principal)
 * - Usuario de Firebase Auth
 * ═══════════════════════════════════════════════════════════════════════════
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

const db = admin.firestore();
const auth = admin.auth();

// Subcollections conocidas del usuario
const USER_SUBCOLLECTIONS = [
  "victoryDays",
  "journalEntries",
  "plansProgress",
  "widgetConfig",
];

/**
 * Elimina todos los documentos de una subcolección usando BulkWriter
 */
async function deleteSubcollection(
  userDocRef: FirebaseFirestore.DocumentReference,
  subcollectionName: string
): Promise<number> {
  const bulkWriter = db.bulkWriter();
  const collectionRef = userDocRef.collection(subcollectionName);

  let deletedCount = 0;
  let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;

  // Borrar en lotes de 500
  while (true) {
    let query = collectionRef.limit(500);
    if (lastDoc) {
      query = query.startAfter(lastDoc);
    }

    const snapshot = await query.get();

    if (snapshot.empty) {
      break;
    }

    snapshot.docs.forEach((doc) => {
      bulkWriter.delete(doc.ref);
      deletedCount++;
    });

    lastDoc = snapshot.docs[snapshot.docs.length - 1];

    // Commit lote
    await bulkWriter.close();
  }

  return deletedCount;
}

/**
 * Callable function: deleteUserData
 *
 * Requiere que el usuario esté autenticado.
 * Solo puede eliminar sus propios datos (validado por context.auth.uid).
 *
 * Pasos:
 * 1. Validar autenticación
 * 2. Eliminar todas las subcolecciones
 * 3. Eliminar documento principal del usuario
 * 4. Eliminar usuario de Firebase Auth
 *
 * Retorna: { success: true, deletedSubcollections: {...} }
 */
export const deleteUserData = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    // 1. Validar autenticación
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Debes iniciar sesión para eliminar tu cuenta."
      );
    }

    const uid = context.auth.uid;
    console.log(`🗑️ [DELETE] Starting account deletion for UID: ${uid}`);

    const deletionStats: Record<string, number> = {};

    try {
      const userDocRef = db.collection("users").doc(uid);

      // 2. Eliminar todas las subcolecciones conocidas
      for (const subcollection of USER_SUBCOLLECTIONS) {
        try {
          const count = await deleteSubcollection(userDocRef, subcollection);
          deletionStats[subcollection] = count;
          console.log(`🗑️ [DELETE] Deleted ${count} docs from ${subcollection}`);
        } catch (err) {
          console.warn(
            `⚠️ [DELETE] Error deleting ${subcollection}:`,
            err
          );
          deletionStats[subcollection] = -1; // Indica error
        }
      }

      // 3. Eliminar documento principal del usuario
      try {
        await userDocRef.delete();
        console.log(`🗑️ [DELETE] Deleted user document: /users/${uid}`);
        deletionStats["userDocument"] = 1;
      } catch (err) {
        console.error(`❌ [DELETE] Error deleting user document:`, err);
        deletionStats["userDocument"] = -1;
      }

      // 4. Eliminar usuario de Firebase Auth
      try {
        await auth.deleteUser(uid);
        console.log(`🗑️ [DELETE] Deleted Auth user: ${uid}`);
        deletionStats["authUser"] = 1;
      } catch (err) {
        // Puede fallar si el usuario ya fue eliminado o si hay issues de tokens
        console.error(`❌ [DELETE] Error deleting Auth user:`, err);
        deletionStats["authUser"] = -1;
      }

      console.log(`✅ [DELETE] Account deletion complete for UID: ${uid}`);
      console.log(`📊 [DELETE] Stats:`, deletionStats);

      return {
        success: true,
        message: "Cuenta y datos eliminados correctamente",
        deletedSubcollections: deletionStats,
      };
    } catch (error) {
      console.error(`❌ [DELETE] Fatal error:`, error);
      throw new functions.https.HttpsError(
        "internal",
        "Error al eliminar la cuenta. Por favor, contacta soporte.",
        {error: String(error)}
      );
    }
  });
