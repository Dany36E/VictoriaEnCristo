/**
 * ═══════════════════════════════════════════════════════════════════════════
 * LIBERAR COMPAÑERO — y qué pasa con el candado del guardián del Escudo.
 *
 * removeBattlePartner: ambos vínculos quedan 'removed' y se borra el reflejo
 * de progreso (el compañero deja de ver tu progreso al momento y no puede
 * escribirte). No se le notifica la liberación en sí.
 *
 * Candado del guardián (ver candadoLogica.ts):
 * - Si TÚ eres guardián del compañero, tu candado sobre él se retira.
 * - Si ÉL es tu guardián con candado activo, liberar NO lo quita: hace falta
 *   su PIN (verificado en el servidor) o pedir el retiro con espera de 72 h
 *   (se le avisa; solo tú puedes cancelarlo con cancelarRetiroCandado).
 *
 * liberarCandadosVencidos (cada hora) retira los candados cuya espera venció.
 * ═══════════════════════════════════════════════════════════════════════════
 */

import * as adminFirestore from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";
import {enRegion} from "./limites";
import {
  datosLiberado,
  publicNameFor,
  pushToUser,
  retirarCandadoEntre,
} from "./battlePartnerFunctions";
import {verificarPinGuardian} from "./guardianFunctions";
import {
  CandadoGuardian,
  decidirCandadoAlLiberar,
  guardianPuedeRetirar,
  retiroVencido,
} from "./candadoLogica";

const db = () => adminFirestore.getFirestore();

function requireAuth(context: functions.https.CallableContext): string {
  const uid = context.auth?.uid;
  if (!uid) {
    throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return uid;
}

function leerCandado(
  data: FirebaseFirestore.DocumentData | undefined,
): CandadoGuardian | undefined {
  if (!data) return undefined;
  const release = data.releaseAt;
  return {
    active: data.active === true,
    guardianUid: typeof data.guardianUid === "string" ? data.guardianUid : undefined,
    pendingGuardianUid: typeof data.pendingGuardianUid === "string" ?
      data.pendingGuardianUid : undefined,
    releaseAtMs: release instanceof adminFirestore.Timestamp ? release.toMillis() : undefined,
  };
}

function statusRef(protegeUid: string) {
  return db().collection("users").doc(protegeUid).collection("security").doc("guardianLock");
}

// ═══════════════════════════════════════════════════════════════════════════
// removeBattlePartner
// ═══════════════════════════════════════════════════════════════════════════
export const removeBattlePartner = enRegion()
  .https.onCall(async (data, context) => {
    const uid = requireAuth(context);
    const partnerUid = typeof data?.partnerUid === "string" ? data.partnerUid.trim() : "";
    if (partnerUid.length === 0 || partnerUid.length > 128 || partnerUid === uid) {
      throw new functions.https.HttpsError("invalid-argument", "Compañero inválido.");
    }
    const pin = typeof data?.pin === "string" ? data.pin : "";
    const conEspera = data?.liberarCandadoEnEspera === true;

    // 1. Ambos vínculos deben existir antes de tocar nada.
    const myRef = db().collection("users").doc(uid).collection("battlePartners").doc(partnerUid);
    const otherRef = db().collection("users").doc(partnerUid).collection("battlePartners").doc(uid);
    const [mine, other] = await Promise.all([myRef.get(), otherRef.get()]);
    if (!mine.exists || !other.exists) {
      throw new functions.https.HttpsError("not-found", "No existe ese vínculo.");
    }

    // 2. ¿El compañero tiene candado sobre mí?
    const miCandadoRef = db().collection("guardianLocks").doc(uid);
    const miCandado = leerCandado((await miCandadoRef.get()).data());
    const esMiGuardian = miCandado?.active === true && miCandado.guardianUid === partnerUid;
    let pinValido = false;
    if (esMiGuardian && pin.length > 0) {
      const r = await verificarPinGuardian(uid, pin);
      if (!r.ok) {
        throw new functions.https.HttpsError("permission-denied", "PIN incorrecto.", {
          motivo: "pin",
          lockedUntil: r.lockedUntil ?? null,
        });
      }
      pinValido = true;
    }
    const ahora = Date.now();
    const decision = decidirCandadoAlLiberar(miCandado, partnerUid, {
      pinValido,
      conEspera,
      ahoraMs: ahora,
    });
    if (decision.accion === "rechazar") {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "Tu compañero es tu guardián del Escudo. Para liberarlo necesitas su PIN " +
          "o pedir que el candado se retire en 72 horas.",
        {motivo: "guardian_lock"},
      );
    }

    // 3. Liberar el vínculo en ambos lados (y las listas de avisos).
    const batch = db().batch();
    batch.set(myRef, datosLiberado(), {merge: true});
    batch.set(otherRef, datosLiberado(), {merge: true});
    const quitar = (de: string, a: string) => {
      batch.set(
        db().collection("accountability").doc(de),
        {
          shieldAlertPartners: adminFirestore.FieldValue.arrayRemove(a),
          weeklyReportPartners: adminFirestore.FieldValue.arrayRemove(a),
        },
        {merge: true},
      );
    };
    quitar(uid, partnerUid);
    quitar(partnerUid, uid);
    await batch.commit();

    // 4. Si yo era guardián del compañero, mi candado sobre él se retira.
    const suCandadoSnap = await db().collection("guardianLocks").doc(partnerUid).get();
    const suCandado = leerCandado(suCandadoSnap.data());
    if (guardianPuedeRetirar(suCandado, uid)) {
      await retirarCandadoEntre(partnerUid, uid);
    }

    // 5. Mi propio candado (si él es mi guardián).
    if (decision.accion === "retirar") {
      await retirarCandadoEntre(uid, partnerUid);
    } else if (decision.accion === "programar" && decision.releaseAtMs !== undefined) {
      const releaseAt = adminFirestore.Timestamp.fromMillis(decision.releaseAtMs);
      const cambios = {releaseAt, updatedAt: adminFirestore.FieldValue.serverTimestamp()};
      await miCandadoRef.set(cambios, {merge: true});
      await statusRef(uid).set(cambios, {merge: true});
      const nombre = await publicNameFor(uid, "Tu compañero");
      await pushToUser(
        partnerUid,
        {
          title: "🔓 Candado del Escudo",
          body: `El candado del Escudo de Pureza de ${nombre} se retirará en 72 horas.`,
        },
        {type: "guardian_release_scheduled"},
        {priority: "normal"},
      );
    }
    return {
      ok: true,
      candado: decision.accion,
      releaseAtMs: decision.releaseAtMs ?? null,
    };
  });

// ═══════════════════════════════════════════════════════════════════════════
// cancelarRetiroCandado — solo el protegido puede cancelar el retiro con espera
// ═══════════════════════════════════════════════════════════════════════════
export const cancelarRetiroCandado = enRegion()
  .https.onCall(async (_data, context) => {
    const uid = requireAuth(context);
    const ref = db().collection("guardianLocks").doc(uid);
    const snap = await ref.get();
    if (!snap.exists || snap.data()?.releaseAt === undefined) return {ok: true};
    await ref.update({releaseAt: adminFirestore.FieldValue.delete()});
    await statusRef(uid).set({releaseAt: adminFirestore.FieldValue.delete()}, {merge: true});
    return {ok: true};
  });

// ═══════════════════════════════════════════════════════════════════════════
// liberarCandadosVencidos — cada hora
// ═══════════════════════════════════════════════════════════════════════════
export const liberarCandadosVencidos = enRegion({maxInstances: 1})
  .pubsub.schedule("every 60 minutes")
  .timeZone("Etc/UTC")
  .onRun(async () => {
    const ahora = Date.now();
    const snap = await db()
      .collection("guardianLocks")
      .where("releaseAt", "<=", adminFirestore.Timestamp.fromMillis(ahora))
      .limit(200)
      .get();
    for (const doc of snap.docs) {
      try {
        const candado = leerCandado(doc.data());
        if (!retiroVencido(candado, ahora) || !candado?.guardianUid) continue;
        // Si volvieron a vincularse antes de que venciera, el retiro se anula.
        const [a, b] = await Promise.all([
          db().collection("users").doc(doc.id).collection("battlePartners")
            .doc(candado.guardianUid).get(),
          db().collection("users").doc(candado.guardianUid).collection("battlePartners")
            .doc(doc.id).get(),
        ]);
        if (a.data()?.status === "active" && b.data()?.status === "active") {
          await doc.ref.update({releaseAt: adminFirestore.FieldValue.delete()});
          await statusRef(doc.id).set(
            {releaseAt: adminFirestore.FieldValue.delete()},
            {merge: true},
          );
          continue;
        }
        await retirarCandadoEntre(doc.id, candado.guardianUid);
        await pushToUser(
          doc.id,
          {
            title: "🔓 Candado del Escudo retirado",
            body: "Pasaron las 72 horas: el candado del guardián se retiró.",
          },
          {type: "guardian_removed"},
          {priority: "normal"},
        );
      } catch (err) {
        console.error("[CANDADO] No se pudo retirar un candado vencido:", err);
      }
    }
  });
