/**
 * ═══════════════════════════════════════════════════════════════════════════
 * CANDADO DEL GUARDIÁN (remoto) - Cloud Functions
 *
 * Permite que un Compañero de Batalla ponga, desde su propio teléfono, un PIN
 * que protege el "Escudo de Pureza" del protegido. El PIN se verifica SIEMPRE
 * en el servidor: el hash + salt viven en `guardianLocks/{protegeUid}`, una
 * colección que NINGÚN cliente puede leer (reglas: deny all). Así el protegido
 * no puede leer el hash ni adivinar por fuerza bruta un PIN corto.
 *
 * Espejos legibles (solo para UI, sin secretos):
 *   users/{protege}/security/guardianLock   -> estado del candado del protegido
 *   users/{guardian}/guardianRequests/{P}   -> solicitudes entrantes
 *   users/{guardian}/guardianOf/{P}         -> a quién protege
 *
 * Roles: P = protegido (tiene el Escudo). G = guardián (tiene el PIN).
 * ═══════════════════════════════════════════════════════════════════════════
 */

import * as admin from "firebase-admin";
import * as functions from "firebase-functions";
import * as crypto from "crypto";
import {publicNameFor, assertActivePartners, pushToUser} from "./battlePartnerFunctions";

const db = () => admin.firestore();
const pinPattern = /^\d{4,8}$/;
const maxAttempts = 5;
const lockoutMs = 15 * 60 * 1000;

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return uid;
}

function lockRef(protegeUid: string) {
  return db().collection("guardianLocks").doc(protegeUid);
}

function statusRef(protegeUid: string) {
  return db().collection("users").doc(protegeUid).collection("security").doc("guardianLock");
}

function requestRef(guardianUid: string, protegeUid: string) {
  return db().collection("users").doc(guardianUid).collection("guardianRequests").doc(protegeUid);
}

function guardianOfRef(guardianUid: string, protegeUid: string) {
  return db().collection("users").doc(guardianUid).collection("guardianOf").doc(protegeUid);
}

function hashPin(pin: string, saltHex: string): string {
  return crypto.createHash("sha256").update(`${saltHex}|${pin}`).digest("hex");
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. requestGuardianLock — P pide a un compañero (G) que sea su guardián.
// ─────────────────────────────────────────────────────────────────────────────
export const requestGuardianLock = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const protegeUid = requireAuth(context);
    const guardianUid = typeof data?.guardianUid === "string" ? data.guardianUid : "";
    if (!guardianUid || guardianUid === protegeUid) {
      throw new functions.https.HttpsError("invalid-argument", "Compañero inválido.");
    }
    await assertActivePartners(protegeUid, guardianUid);

    const existing = await lockRef(protegeUid).get();
    if (existing.exists && existing.data()?.active === true) {
      throw new functions.https.HttpsError("already-exists", "Ya tienes un candado activo.");
    }

    const guardianName = await publicNameFor(guardianUid, "Tu compañero");
    const protegeName = await publicNameFor(protegeUid, "Un compañero");
    const now = admin.firestore.FieldValue.serverTimestamp();

    await lockRef(protegeUid).set(
      {
        pendingGuardianUid: guardianUid,
        active: existing.data()?.active === true,
        updatedAt: now,
        createdAt: existing.exists ? existing.data()?.createdAt ?? now : now,
      },
      {merge: true}
    );
    await statusRef(protegeUid).set(
      {
        pending: true,
        guardianUid,
        guardianName,
        active: existing.data()?.active === true,
        updatedAt: now,
      },
      {merge: true}
    );
    await requestRef(guardianUid, protegeUid).set({
      protegeUid,
      protegeName,
      createdAt: now,
    });

    await pushToUser(
      guardianUid,
      {
        title: "🛡️ Te pidieron ser guardián",
        body: `${protegeName} te pide poner un PIN para proteger su pureza.`,
      },
      {type: "guardian_request", protegeUid, protegeName},
      {priority: "normal"}
    );

    return {ok: true};
  });

// ─────────────────────────────────────────────────────────────────────────────
// 2. setGuardianPin — G define (o cambia) el PIN del protegido.
// ─────────────────────────────────────────────────────────────────────────────
export const setGuardianPin = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const guardianUid = requireAuth(context);
    const protegeUid = typeof data?.protegeUid === "string" ? data.protegeUid : "";
    const pin = typeof data?.pin === "string" ? data.pin : "";
    if (!protegeUid || protegeUid === guardianUid) {
      throw new functions.https.HttpsError("invalid-argument", "Protegido inválido.");
    }
    if (!pinPattern.test(pin)) {
      throw new functions.https.HttpsError("invalid-argument", "El PIN debe tener de 4 a 8 dígitos.");
    }
    await assertActivePartners(guardianUid, protegeUid);

    const lockSnap = await lockRef(protegeUid).get();
    const lock = lockSnap.data() ?? {};
    const isPendingForMe = lock.pendingGuardianUid === guardianUid;
    const isCurrentGuardian = lock.guardianUid === guardianUid && lock.active === true;
    if (!isPendingForMe && !isCurrentGuardian) {
      throw new functions.https.HttpsError("permission-denied", "No tienes una solicitud de este usuario.");
    }

    const saltHex = crypto.randomBytes(16).toString("hex");
    const hashHex = hashPin(pin, saltHex);
    const guardianName = await publicNameFor(guardianUid, "Tu compañero");
    const protegeName = await publicNameFor(protegeUid, "Un compañero");
    const now = admin.firestore.FieldValue.serverTimestamp();

    await lockRef(protegeUid).set(
      {
        active: true,
        guardianUid,
        guardianName,
        saltHex,
        hashHex,
        failCount: 0,
        lockUntil: 0,
        pendingGuardianUid: admin.firestore.FieldValue.delete(),
        updatedAt: now,
        createdAt: lockSnap.exists ? lock.createdAt ?? now : now,
      },
      {merge: true}
    );
    await statusRef(protegeUid).set(
      {active: true, pending: false, guardianUid, guardianName, updatedAt: now},
      {merge: true}
    );
    await guardianOfRef(guardianUid, protegeUid).set({
      protegeUid,
      protegeName,
      active: true,
      updatedAt: now,
    });
    await requestRef(guardianUid, protegeUid).delete().catch(() => undefined);

    await pushToUser(
      protegeUid,
      {
        title: "🔒 Candado del guardián activado",
        body: `${guardianName} activó tu candado de pureza.`,
      },
      {type: "guardian_set", guardianUid, guardianName},
      {priority: "normal"}
    );

    return {ok: true};
  });

// ─────────────────────────────────────────────────────────────────────────────
// 3. verifyGuardianPin — P intenta desbloquear. Verificación + rate-limit server.
// ─────────────────────────────────────────────────────────────────────────────
export const verifyGuardianPin = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const protegeUid = requireAuth(context);
    const pin = typeof data?.pin === "string" ? data.pin : "";
    const ref = lockRef(protegeUid);

    return db().runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists || snap.data()?.active !== true) {
        throw new functions.https.HttpsError("failed-precondition", "No hay candado activo.");
      }
      const lock = snap.data() ?? {};
      const now = Date.now();
      const lockUntil = typeof lock.lockUntil === "number" ? lock.lockUntil : 0;
      if (lockUntil > now) {
        return {ok: false, lockedUntil: lockUntil};
      }
      const saltHex = String(lock.saltHex ?? "");
      const hashHex = String(lock.hashHex ?? "");
      if (saltHex && hashHex && hashPin(pin, saltHex) === hashHex) {
        tx.update(ref, {failCount: 0, lockUntil: 0, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
        return {ok: true};
      }
      const fails = (typeof lock.failCount === "number" ? lock.failCount : 0) + 1;
      if (fails >= maxAttempts) {
        const until = now + lockoutMs;
        tx.update(ref, {failCount: 0, lockUntil: until, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
        return {ok: false, lockedUntil: until};
      }
      tx.update(ref, {failCount: fails, updatedAt: admin.firestore.FieldValue.serverTimestamp()});
      return {ok: false};
    });
  });

// ─────────────────────────────────────────────────────────────────────────────
// 4. removeGuardianPin — G quita el candado (sin PIN); P puede quitarlo con PIN.
// ─────────────────────────────────────────────────────────────────────────────
export const removeGuardianPin = functions
  .region("us-central1")
  .https.onCall(async (data, context) => {
    const callerUid = requireAuth(context);
    const protegeUid = typeof data?.protegeUid === "string" ? data.protegeUid : "";
    const pin = typeof data?.pin === "string" ? data.pin : "";
    if (!protegeUid) {
      throw new functions.https.HttpsError("invalid-argument", "Protegido inválido.");
    }
    const snap = await lockRef(protegeUid).get();
    if (!snap.exists) {
      return {ok: true};
    }
    const lock = snap.data() ?? {};
    const guardianUid = String(lock.guardianUid ?? "");

    const isGuardian = callerUid === guardianUid;
    const isProtege = callerUid === protegeUid;
    if (!isGuardian && !isProtege) {
      throw new functions.https.HttpsError("permission-denied", "No autorizado.");
    }
    // El protegido debe conocer el PIN para quitarlo (respeta el bloqueo).
    if (isProtege && !isGuardian) {
      const now = Date.now();
      const lockUntil = typeof lock.lockUntil === "number" ? lock.lockUntil : 0;
      if (lockUntil > now) {
        return {ok: false, lockedUntil: lockUntil};
      }
      const saltHex = String(lock.saltHex ?? "");
      const hashHex = String(lock.hashHex ?? "");
      if (!(saltHex && hashHex && hashPin(pin, saltHex) === hashHex)) {
        const fails = (typeof lock.failCount === "number" ? lock.failCount : 0) + 1;
        if (fails >= maxAttempts) {
          await lockRef(protegeUid).update({failCount: 0, lockUntil: now + lockoutMs});
          return {ok: false, lockedUntil: now + lockoutMs};
        }
        await lockRef(protegeUid).update({failCount: fails});
        return {ok: false};
      }
    }

    const now = admin.firestore.FieldValue.serverTimestamp();
    await lockRef(protegeUid).delete();
    await statusRef(protegeUid).set(
      {active: false, pending: false, guardianUid: admin.firestore.FieldValue.delete(), updatedAt: now},
      {merge: true}
    );
    if (guardianUid) {
      await guardianOfRef(guardianUid, protegeUid).delete().catch(() => undefined);
    }

    // Notificar a la otra parte.
    const targetUid = isGuardian ? protegeUid : guardianUid;
    if (targetUid) {
      await pushToUser(
        targetUid,
        {
          title: "🔓 Candado del guardián retirado",
          body: "El candado de pureza fue desactivado.",
        },
        {type: "guardian_removed"},
        {priority: "normal"}
      );
    }
    return {ok: true};
  });
