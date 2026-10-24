"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * RENDICIÓN DE CUENTAS — funciones programadas (opcionales para el usuario).
 *
 * 1. vigilarEscudo (cada hora): revisa `shieldStatus/{uid}` de quienes
 *    activaron avisos. Si el Escudo de Pureza está apagado, estuvo apagado
 *    un tiempo o no da señal desde hace más de 24 h, avisa a los compañeros
 *    que el usuario eligió (FCM + mensaje en la app). Sin detalles: ni sitios
 *    ni horas exactas. Un aviso por episodio y como mucho uno cada 6 h.
 *    Solo con apagados CONFIRMADOS (Android lo registró, o la app reportó el
 *    Escudo activado pero sin correr). La falta de señal espera 72 h.
 *
 * 3. avisarCambioCompartir (trigger): si el usuario quita a un compañero de
 *    los avisos o del resumen, ese compañero recibe "X dejó de compartir…",
 *    para que dejar de compartir no sirva como atajo silencioso.
 *
 * 2. enviarResumenSemanal (cada hora): el domingo desde las 19 h (hora del
 *    usuario) envía a los compañeros elegidos el resumen de la semana, solo
 *    con lo que el usuario decidió compartir.
 *
 * Solo se envía a compañeros con vínculo ACTIVO en ambos sentidos. El estado
 * de envíos vive en `accountabilityState/{uid}` (ningún cliente lo lee).
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
var __await = (this && this.__await) || function (v) { return this instanceof __await ? (this.v = v, this) : new __await(v); }
var __asyncGenerator = (this && this.__asyncGenerator) || function (thisArg, _arguments, generator) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var g = generator.apply(thisArg, _arguments || []), i, q = [];
    return i = Object.create((typeof AsyncIterator === "function" ? AsyncIterator : Object).prototype), verb("next"), verb("throw"), verb("return", awaitReturn), i[Symbol.asyncIterator] = function () { return this; }, i;
    function awaitReturn(f) { return function (v) { return Promise.resolve(v).then(f, reject); }; }
    function verb(n, f) { if (g[n]) { i[n] = function (v) { return new Promise(function (a, b) { q.push([n, v, a, b]) > 1 || resume(n, v); }); }; if (f) i[n] = f(i[n]); } }
    function resume(n, v) { try { step(g[n](v)); } catch (e) { settle(q[0][3], e); } }
    function step(r) { r.value instanceof __await ? Promise.resolve(r.value.v).then(fulfill, reject) : settle(q[0][2], r); }
    function fulfill(value) { resume("next", value); }
    function reject(value) { resume("throw", value); }
    function settle(f, v) { if (f(v), q.shift(), q.length) resume(q[0][0], q[0][1]); }
};
var __asyncValues = (this && this.__asyncValues) || function (o) {
    if (!Symbol.asyncIterator) throw new TypeError("Symbol.asyncIterator is not defined.");
    var m = o[Symbol.asyncIterator], i;
    return m ? m.call(o) : (o = typeof __values === "function" ? __values(o) : o[Symbol.iterator](), i = {}, verb("next"), verb("throw"), verb("return"), i[Symbol.asyncIterator] = function () { return this; }, i);
    function verb(n) { i[n] = o[n] && function (v) { return new Promise(function (resolve, reject) { v = o[n](v), settle(resolve, reject, v.done, v.value); }); }; }
    function settle(resolve, reject, d, v) { Promise.resolve(v).then(function(v) { resolve({ value: v, done: d }); }, reject); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.avisarCambioCompartir = exports.enviarResumenSemanal = exports.vigilarEscudo = void 0;
const adminFirestore = __importStar(require("firebase-admin/firestore"));
const limites_1 = require("./limites");
const battlePartnerFunctions_1 = require("./battlePartnerFunctions");
const rendicionCuentasLogica_1 = require("./rendicionCuentasLogica");
const db = () => adminFirestore.getFirestore();
const MAX_COMPANEROS = 5;
const LOTE = 300;
const MAX_DOCS = 5000;
// Recorre todos los documentos de la consulta por páginas (orden por id).
function recorrer(base) {
    return __asyncGenerator(this, arguments, function* recorrer_1() {
        let ultimo;
        let vistos = 0;
        while (vistos < MAX_DOCS) {
            let q = base.orderBy(adminFirestore.FieldPath.documentId()).limit(LOTE);
            if (ultimo)
                q = q.startAfter(ultimo);
            const snap = yield __await(q.get());
            for (const d of snap.docs)
                yield yield __await(d);
            vistos += snap.size;
            if (snap.size < LOTE)
                return yield __await(void 0);
            ultimo = snap.docs[snap.docs.length - 1];
        }
    });
}
function ms(v) {
    return v instanceof adminFirestore.Timestamp ? v.toMillis() : undefined;
}
function listaUids(v) {
    if (!Array.isArray(v))
        return [];
    return v
        .filter((x) => typeof x === "string" && x.length > 0 && x.length <= 128)
        .slice(0, MAX_COMPANEROS);
}
// Compañeros de la lista con vínculo activo en ambos sentidos.
async function companerosActivos(uid, candidatos) {
    const verificados = [];
    await Promise.all(candidatos.map(async (otro) => {
        var _a, _b;
        if (otro === uid)
            return;
        const [mio, suyo] = await Promise.all([
            db().collection("users").doc(uid).collection("battlePartners").doc(otro).get(),
            db().collection("users").doc(otro).collection("battlePartners").doc(uid).get(),
        ]);
        if (((_a = mio.data()) === null || _a === void 0 ? void 0 : _a.status) === "active" && ((_b = suyo.data()) === null || _b === void 0 ? void 0 : _b.status) === "active") {
            verificados.push(otro);
        }
    }));
    return verificados;
}
// Mensaje en la app del compañero (el trigger onBattleMessageCreated manda el push).
async function enviarMensaje(destinos, fromUid, fromName, messageKey, text) {
    const batch = db().batch();
    for (const toUid of destinos) {
        const ref = db().collection("users").doc(toUid).collection("battleMessages").doc();
        batch.set(ref, {
            fromUid,
            fromName,
            messageKey,
            text,
            sentAt: adminFirestore.FieldValue.serverTimestamp(),
            read: false,
        });
    }
    await batch.commit();
}
// ═══════════════════════════════════════════════════════════════════════════
// 1. vigilarEscudo
// ═══════════════════════════════════════════════════════════════════════════
exports.vigilarEscudo = (0, limites_1.enRegion)({ maxInstances: 1, timeoutSeconds: 300 })
    .pubsub.schedule("every 60 minutes")
    .timeZone("Etc/UTC")
    .onRun(async () => {
    var _a, e_1, _b, _c;
    var _d, _e;
    const ahora = Date.now();
    let enviados = 0;
    const consulta = db().collection("shieldStatus").where("alertsEnabled", "==", true);
    try {
        for (var _f = true, _g = __asyncValues(recorrer(consulta)), _h; _h = await _g.next(), _a = _h.done, !_a; _f = true) {
            _c = _h.value;
            _f = false;
            const doc = _c;
            try {
                const uid = doc.id;
                const d = doc.data();
                const estado = {
                    enabledByUser: d.enabledByUser === true,
                    vpnActive: d.vpnActive === true,
                    alertsEnabled: d.alertsEnabled === true,
                    lastSeenAtMs: ms(d.lastSeenAt),
                    lastOffAtMs: ms(d.lastOffAt),
                    lastOffReason: typeof d.lastOffReason === "string" ? d.lastOffReason : undefined,
                    lastOnAtMs: ms(d.lastOnAt),
                };
                const estadoRef = db().collection("accountabilityState").doc(uid);
                const previo = (_d = (await estadoRef.get()).data()) !== null && _d !== void 0 ? _d : {};
                const decision = (0, rendicionCuentasLogica_1.evaluarAvisoEscudo)(estado, {
                    ultimoAvisoMs: ms(previo.lastShieldAlertAt),
                    ultimoEpisodio: typeof previo.lastShieldEpisode === "string" ?
                        previo.lastShieldEpisode : undefined,
                }, ahora);
                if (!decision.enviar || !decision.tipo || !decision.episodio)
                    continue;
                const ajustes = (_e = (await db().collection("accountability").doc(uid).get()).data()) !== null && _e !== void 0 ? _e : {};
                const destinos = await companerosActivos(uid, listaUids(ajustes.shieldAlertPartners));
                // Se marca el episodio aunque no haya destinatarios para no reintentar cada hora.
                await estadoRef.set({
                    lastShieldEpisode: decision.episodio,
                    lastShieldAlertAt: adminFirestore.Timestamp.fromMillis(ahora),
                }, { merge: true });
                if (destinos.length === 0)
                    continue;
                const nombre = await (0, battlePartnerFunctions_1.publicNameFor)(uid, "Tu compañero");
                await enviarMensaje(destinos, uid, nombre, "shield_alert", (0, rendicionCuentasLogica_1.textoAvisoEscudo)(decision.tipo, nombre));
                enviados += destinos.length;
            }
            catch (err) {
                console.error("[ESCUDO] Error revisando un usuario:", err);
            }
        }
    }
    catch (e_1_1) { e_1 = { error: e_1_1 }; }
    finally {
        try {
            if (!_f && !_a && (_b = _g.return)) await _b.call(_g);
        }
        finally { if (e_1) throw e_1.error; }
    }
    if (enviados > 0)
        console.log(`[ESCUDO] ${enviados} aviso(s) enviados`);
});
// ═══════════════════════════════════════════════════════════════════════════
// 2. enviarResumenSemanal
// ═══════════════════════════════════════════════════════════════════════════
exports.enviarResumenSemanal = (0, limites_1.enRegion)({ maxInstances: 1, timeoutSeconds: 300 })
    .pubsub.schedule("every 60 minutes")
    .timeZone("Etc/UTC")
    .onRun(async () => {
    var _a, e_2, _b, _c;
    var _d, _e;
    const ahora = Date.now();
    let enviados = 0;
    const consulta = db().collection("accountability").where("weeklyEnabled", "==", true);
    try {
        for (var _f = true, _g = __asyncValues(recorrer(consulta)), _h; _h = await _g.next(), _a = _h.done, !_a; _f = true) {
            _c = _h.value;
            _f = false;
            const doc = _c;
            try {
                const uid = doc.id;
                const ajustes = doc.data();
                const zona = typeof ajustes.timezone === "string" ? ajustes.timezone : "UTC";
                const estadoRef = db().collection("accountabilityState").doc(uid);
                const previo = (_d = (await estadoRef.get()).data()) !== null && _d !== void 0 ? _d : {};
                const { enviar, claveSemana } = (0, rendicionCuentasLogica_1.debeEnviarResumen)(ahora, zona, typeof previo.lastWeeklyKey === "string" ? previo.lastWeeklyKey : undefined);
                if (!enviar)
                    continue;
                await estadoRef.set({ lastWeeklyKey: claveSemana }, { merge: true });
                const destinos = await companerosActivos(uid, listaUids(ajustes.weeklyReportPartners));
                if (destinos.length === 0)
                    continue;
                const claves = (0, rendicionCuentasLogica_1.clavesSemana)(claveSemana);
                const userRef = db().collection("users").doc(uid);
                const [diasSnap, progreso, escudo] = await Promise.all([
                    db().getAll(...claves.map((k) => userRef.collection("victoryDays").doc(k))),
                    userRef.collection("publicProgress").doc("latest").get(),
                    db().collection("shieldStatus").doc(uid).get(),
                ]);
                const datos = (0, rendicionCuentasLogica_1.resumirSemana)(diasSnap
                    .filter((s) => s.exists)
                    .map((s) => { var _a; return ({ isVictoryDay: ((_a = s.data()) === null || _a === void 0 ? void 0 : _a.isVictoryDay) === true }); }));
                const racha = (_e = progreso.data()) === null || _e === void 0 ? void 0 : _e.streakDays;
                if (typeof racha === "number")
                    datos.racha = racha;
                const e = escudo.data();
                if (e && (e.enabledByUser === true || e.vpnActive === true)) {
                    datos.escudoActivo = e.vpnActive === true;
                    datos.bloqueos = (0, rendicionCuentasLogica_1.sumarBloqueos)(e.blocksByDay, claves);
                }
                const nombre = await (0, battlePartnerFunctions_1.publicNameFor)(uid, "Tu compañero");
                const texto = (0, rendicionCuentasLogica_1.construirTextoResumen)(nombre, datos, (0, rendicionCuentasLogica_1.leerCompartir)(ajustes.share));
                await enviarMensaje(destinos, uid, nombre, "weekly_report", texto);
                enviados += destinos.length;
            }
            catch (err) {
                console.error("[RESUMEN] Error con un usuario:", err);
            }
        }
    }
    catch (e_2_1) { e_2 = { error: e_2_1 }; }
    finally {
        try {
            if (!_f && !_a && (_b = _g.return)) await _b.call(_g);
        }
        finally { if (e_2) throw e_2.error; }
    }
    if (enviados > 0)
        console.log(`[RESUMEN] ${enviados} resumen(es) enviados`);
});
// ═══════════════════════════════════════════════════════════════════════════
// 3. avisarCambioCompartir
// ═══════════════════════════════════════════════════════════════════════════
exports.avisarCambioCompartir = (0, limites_1.enRegion)()
    .firestore.document("accountability/{uid}")
    .onUpdate(async (change, context) => {
    var _a, _b;
    const uid = context.params.uid;
    const cambios = (0, rendicionCuentasLogica_1.cambiosDeCompartir)((_a = change.before.data()) !== null && _a !== void 0 ? _a : {}, (_b = change.after.data()) !== null && _b !== void 0 ? _b : {});
    if (cambios.length === 0)
        return;
    // Solo a compañeros con vínculo activo: al liberar a alguien no se le avisa.
    const afectados = [...new Set(cambios.map((c) => c.uid))];
    const activos = new Set(await companerosActivos(uid, afectados));
    const nombre = await (0, battlePartnerFunctions_1.publicNameFor)(uid, "Tu compañero");
    for (const c of cambios) {
        if (!activos.has(c.uid))
            continue;
        try {
            // Evita una ráfaga si activa y desactiva muchas veces.
            await (0, battlePartnerFunctions_1.consumeDailyLimit)(`compartir_${uid}_${c.uid}_${(0, battlePartnerFunctions_1.utcDayKey)()}`, 3);
        }
        catch (_c) {
            continue;
        }
        const texto = (0, rendicionCuentasLogica_1.textoCambioCompartir)(c.tipo, nombre);
        await enviarMensaje([c.uid], uid, nombre, "sharing_changed", texto);
    }
});
//# sourceMappingURL=rendicionCuentas.js.map