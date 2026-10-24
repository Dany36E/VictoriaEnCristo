"use strict";
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
exports.liberarCandadosVencidos = exports.cancelarRetiroCandado = exports.removeBattlePartner = void 0;
const adminFirestore = __importStar(require("firebase-admin/firestore"));
const functions = __importStar(require("firebase-functions/v1"));
const limites_1 = require("./limites");
const battlePartnerFunctions_1 = require("./battlePartnerFunctions");
const guardianFunctions_1 = require("./guardianFunctions");
const candadoLogica_1 = require("./candadoLogica");
const db = () => adminFirestore.getFirestore();
function requireAuth(context) {
    var _a;
    const uid = (_a = context.auth) === null || _a === void 0 ? void 0 : _a.uid;
    if (!uid) {
        throw new functions.https.HttpsError("unauthenticated", "Debes iniciar sesión.");
    }
    return uid;
}
function leerCandado(data) {
    if (!data)
        return undefined;
    const release = data.releaseAt;
    return {
        active: data.active === true,
        guardianUid: typeof data.guardianUid === "string" ? data.guardianUid : undefined,
        pendingGuardianUid: typeof data.pendingGuardianUid === "string" ?
            data.pendingGuardianUid : undefined,
        releaseAtMs: release instanceof adminFirestore.Timestamp ? release.toMillis() : undefined,
    };
}
function statusRef(protegeUid) {
    return db().collection("users").doc(protegeUid).collection("security").doc("guardianLock");
}
// ═══════════════════════════════════════════════════════════════════════════
// removeBattlePartner
// ═══════════════════════════════════════════════════════════════════════════
exports.removeBattlePartner = (0, limites_1.enRegion)()
    .https.onCall(async (data, context) => {
    var _a, _b;
    const uid = requireAuth(context);
    const partnerUid = typeof (data === null || data === void 0 ? void 0 : data.partnerUid) === "string" ? data.partnerUid.trim() : "";
    if (partnerUid.length === 0 || partnerUid.length > 128 || partnerUid === uid) {
        throw new functions.https.HttpsError("invalid-argument", "Compañero inválido.");
    }
    const pin = typeof (data === null || data === void 0 ? void 0 : data.pin) === "string" ? data.pin : "";
    const conEspera = (data === null || data === void 0 ? void 0 : data.liberarCandadoEnEspera) === true;
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
    const esMiGuardian = (miCandado === null || miCandado === void 0 ? void 0 : miCandado.active) === true && miCandado.guardianUid === partnerUid;
    let pinValido = false;
    if (esMiGuardian && pin.length > 0) {
        const r = await (0, guardianFunctions_1.verificarPinGuardian)(uid, pin);
        if (!r.ok) {
            throw new functions.https.HttpsError("permission-denied", "PIN incorrecto.", {
                motivo: "pin",
                lockedUntil: (_a = r.lockedUntil) !== null && _a !== void 0 ? _a : null,
            });
        }
        pinValido = true;
    }
    const ahora = Date.now();
    const decision = (0, candadoLogica_1.decidirCandadoAlLiberar)(miCandado, partnerUid, {
        pinValido,
        conEspera,
        ahoraMs: ahora,
    });
    if (decision.accion === "rechazar") {
        throw new functions.https.HttpsError("failed-precondition", "Tu compañero es tu guardián del Escudo. Para liberarlo necesitas su PIN " +
            "o pedir que el candado se retire en 72 horas.", { motivo: "guardian_lock" });
    }
    // 3. Liberar el vínculo en ambos lados (y las listas de avisos).
    const batch = db().batch();
    batch.set(myRef, (0, battlePartnerFunctions_1.datosLiberado)(), { merge: true });
    batch.set(otherRef, (0, battlePartnerFunctions_1.datosLiberado)(), { merge: true });
    const quitar = (de, a) => {
        batch.set(db().collection("accountability").doc(de), {
            shieldAlertPartners: adminFirestore.FieldValue.arrayRemove(a),
            weeklyReportPartners: adminFirestore.FieldValue.arrayRemove(a),
        }, { merge: true });
    };
    quitar(uid, partnerUid);
    quitar(partnerUid, uid);
    await batch.commit();
    // 4. Si yo era guardián del compañero, mi candado sobre él se retira.
    const suCandadoSnap = await db().collection("guardianLocks").doc(partnerUid).get();
    const suCandado = leerCandado(suCandadoSnap.data());
    if ((0, candadoLogica_1.guardianPuedeRetirar)(suCandado, uid)) {
        await (0, battlePartnerFunctions_1.retirarCandadoEntre)(partnerUid, uid);
    }
    // 5. Mi propio candado (si él es mi guardián).
    if (decision.accion === "retirar") {
        await (0, battlePartnerFunctions_1.retirarCandadoEntre)(uid, partnerUid);
    }
    else if (decision.accion === "programar" && decision.releaseAtMs !== undefined) {
        const releaseAt = adminFirestore.Timestamp.fromMillis(decision.releaseAtMs);
        const cambios = { releaseAt, updatedAt: adminFirestore.FieldValue.serverTimestamp() };
        await miCandadoRef.set(cambios, { merge: true });
        await statusRef(uid).set(cambios, { merge: true });
        const nombre = await (0, battlePartnerFunctions_1.publicNameFor)(uid, "Tu compañero");
        await (0, battlePartnerFunctions_1.pushToUser)(partnerUid, {
            title: "🔓 Candado del Escudo",
            body: `El candado del Escudo de Pureza de ${nombre} se retirará en 72 horas.`,
        }, { type: "guardian_release_scheduled" }, { priority: "normal" });
    }
    return {
        ok: true,
        candado: decision.accion,
        releaseAtMs: (_b = decision.releaseAtMs) !== null && _b !== void 0 ? _b : null,
    };
});
// ═══════════════════════════════════════════════════════════════════════════
// cancelarRetiroCandado — solo el protegido puede cancelar el retiro con espera
// ═══════════════════════════════════════════════════════════════════════════
exports.cancelarRetiroCandado = (0, limites_1.enRegion)()
    .https.onCall(async (_data, context) => {
    var _a;
    const uid = requireAuth(context);
    const ref = db().collection("guardianLocks").doc(uid);
    const snap = await ref.get();
    if (!snap.exists || ((_a = snap.data()) === null || _a === void 0 ? void 0 : _a.releaseAt) === undefined)
        return { ok: true };
    await ref.update({ releaseAt: adminFirestore.FieldValue.delete() });
    await statusRef(uid).set({ releaseAt: adminFirestore.FieldValue.delete() }, { merge: true });
    return { ok: true };
});
// ═══════════════════════════════════════════════════════════════════════════
// liberarCandadosVencidos — cada hora
// ═══════════════════════════════════════════════════════════════════════════
exports.liberarCandadosVencidos = (0, limites_1.enRegion)({ maxInstances: 1 })
    .pubsub.schedule("every 60 minutes")
    .timeZone("Etc/UTC")
    .onRun(async () => {
    var _a, _b;
    const ahora = Date.now();
    const snap = await db()
        .collection("guardianLocks")
        .where("releaseAt", "<=", adminFirestore.Timestamp.fromMillis(ahora))
        .limit(200)
        .get();
    for (const doc of snap.docs) {
        try {
            const candado = leerCandado(doc.data());
            if (!(0, candadoLogica_1.retiroVencido)(candado, ahora) || !(candado === null || candado === void 0 ? void 0 : candado.guardianUid))
                continue;
            // Si volvieron a vincularse antes de que venciera, el retiro se anula.
            const [a, b] = await Promise.all([
                db().collection("users").doc(doc.id).collection("battlePartners")
                    .doc(candado.guardianUid).get(),
                db().collection("users").doc(candado.guardianUid).collection("battlePartners")
                    .doc(doc.id).get(),
            ]);
            if (((_a = a.data()) === null || _a === void 0 ? void 0 : _a.status) === "active" && ((_b = b.data()) === null || _b === void 0 ? void 0 : _b.status) === "active") {
                await doc.ref.update({ releaseAt: adminFirestore.FieldValue.delete() });
                await statusRef(doc.id).set({ releaseAt: adminFirestore.FieldValue.delete() }, { merge: true });
                continue;
            }
            await (0, battlePartnerFunctions_1.retirarCandadoEntre)(doc.id, candado.guardianUid);
            await (0, battlePartnerFunctions_1.pushToUser)(doc.id, {
                title: "🔓 Candado del Escudo retirado",
                body: "Pasaron las 72 horas: el candado del guardián se retiró.",
            }, { type: "guardian_removed" }, { priority: "normal" });
        }
        catch (err) {
            console.error("[CANDADO] No se pudo retirar un candado vencido:", err);
        }
    }
});
//# sourceMappingURL=liberarCompanero.js.map