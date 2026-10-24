/**
 * ═══════════════════════════════════════════════════════════════════════════
 * RENDICIÓN DE CUENTAS — funciones programadas (opcionales para el usuario).
 *
 * 1. vigilarEscudo (cada hora): revisa `shieldStatus/{uid}` de quienes
 *    activaron avisos. Si el Escudo de Pureza está apagado, estuvo apagado
 *    un tiempo o no da señal desde hace más de 24 h, avisa a los compañeros
 *    que el usuario eligió (FCM + mensaje en la app). Sin detalles: ni sitios
 *    ni horas exactas. Un aviso por episodio y como mucho uno cada 6 h.
 *
 * 2. enviarResumenSemanal (cada hora): el domingo desde las 19 h (hora del
 *    usuario) envía a los compañeros elegidos el resumen de la semana, solo
 *    con lo que el usuario decidió compartir.
 *
 * Solo se envía a compañeros con vínculo ACTIVO en ambos sentidos. El estado
 * de envíos vive en `accountabilityState/{uid}` (ningún cliente lo lee).
 * ═══════════════════════════════════════════════════════════════════════════
 */

import * as adminFirestore from "firebase-admin/firestore";
import {enRegion} from "./limites";
import {publicNameFor} from "./battlePartnerFunctions";
import {
  clavesSemana,
  construirTextoResumen,
  debeEnviarResumen,
  evaluarAvisoEscudo,
  leerCompartir,
  resumirSemana,
  sumarBloqueos,
  textoAvisoEscudo,
  EstadoEscudo,
  TipoAviso,
} from "./rendicionCuentasLogica";

const db = () => adminFirestore.getFirestore();
const MAX_COMPANEROS = 5;
const LOTE = 300;
const MAX_DOCS = 5000;

// Recorre todos los documentos de la consulta por páginas (orden por id).
async function* recorrer(
  base: adminFirestore.Query,
): AsyncGenerator<adminFirestore.QueryDocumentSnapshot> {
  let ultimo: adminFirestore.QueryDocumentSnapshot | undefined;
  let vistos = 0;
  while (vistos < MAX_DOCS) {
    let q = base.orderBy(adminFirestore.FieldPath.documentId()).limit(LOTE);
    if (ultimo) q = q.startAfter(ultimo);
    const snap = await q.get();
    for (const d of snap.docs) yield d;
    vistos += snap.size;
    if (snap.size < LOTE) return;
    ultimo = snap.docs[snap.docs.length - 1];
  }
}

function ms(v: unknown): number | undefined {
  return v instanceof adminFirestore.Timestamp ? v.toMillis() : undefined;
}

function listaUids(v: unknown): string[] {
  if (!Array.isArray(v)) return [];
  return v
    .filter((x): x is string => typeof x === "string" && x.length > 0 && x.length <= 128)
    .slice(0, MAX_COMPANEROS);
}

// Compañeros de la lista con vínculo activo en ambos sentidos.
async function companerosActivos(uid: string, candidatos: string[]): Promise<string[]> {
  const verificados: string[] = [];
  await Promise.all(
    candidatos.map(async (otro) => {
      if (otro === uid) return;
      const [mio, suyo] = await Promise.all([
        db().collection("users").doc(uid).collection("battlePartners").doc(otro).get(),
        db().collection("users").doc(otro).collection("battlePartners").doc(uid).get(),
      ]);
      if (mio.data()?.status === "active" && suyo.data()?.status === "active") {
        verificados.push(otro);
      }
    }),
  );
  return verificados;
}

// Mensaje en la app del compañero (el trigger onBattleMessageCreated manda el push).
async function enviarMensaje(
  destinos: string[],
  fromUid: string,
  fromName: string,
  messageKey: "shield_alert" | "weekly_report",
  text: string,
): Promise<void> {
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
export const vigilarEscudo = enRegion({maxInstances: 1, timeoutSeconds: 300})
  .pubsub.schedule("every 60 minutes")
  .timeZone("Etc/UTC")
  .onRun(async () => {
    const ahora = Date.now();
    let enviados = 0;
    const consulta = db().collection("shieldStatus").where("alertsEnabled", "==", true);
    for await (const doc of recorrer(consulta)) {
      try {
        const uid = doc.id;
        const d = doc.data();
        const estado: EstadoEscudo = {
          enabledByUser: d.enabledByUser === true,
          vpnActive: d.vpnActive === true,
          alertsEnabled: d.alertsEnabled === true,
          lastSeenAtMs: ms(d.lastSeenAt),
          lastOffAtMs: ms(d.lastOffAt),
          lastOffReason: typeof d.lastOffReason === "string" ? d.lastOffReason : undefined,
          lastOnAtMs: ms(d.lastOnAt),
        };
        const estadoRef = db().collection("accountabilityState").doc(uid);
        const previo = (await estadoRef.get()).data() ?? {};
        const decision = evaluarAvisoEscudo(
          estado,
          {
            ultimoAvisoMs: ms(previo.lastShieldAlertAt),
            ultimoEpisodio: typeof previo.lastShieldEpisode === "string" ?
              previo.lastShieldEpisode : undefined,
          },
          ahora,
        );
        if (!decision.enviar || !decision.tipo || !decision.episodio) continue;

        const ajustes = (await db().collection("accountability").doc(uid).get()).data() ?? {};
        const destinos = await companerosActivos(uid, listaUids(ajustes.shieldAlertPartners));
        // Se marca el episodio aunque no haya destinatarios para no reintentar cada hora.
        await estadoRef.set(
          {
            lastShieldEpisode: decision.episodio,
            lastShieldAlertAt: adminFirestore.Timestamp.fromMillis(ahora),
          },
          {merge: true},
        );
        if (destinos.length === 0) continue;
        const nombre = await publicNameFor(uid, "Tu compañero");
        await enviarMensaje(
          destinos,
          uid,
          nombre,
          "shield_alert",
          textoAvisoEscudo(decision.tipo as TipoAviso, nombre),
        );
        enviados += destinos.length;
      } catch (err) {
        console.error("[ESCUDO] Error revisando un usuario:", err);
      }
    }
    if (enviados > 0) console.log(`[ESCUDO] ${enviados} aviso(s) enviados`);
  });

// ═══════════════════════════════════════════════════════════════════════════
// 2. enviarResumenSemanal
// ═══════════════════════════════════════════════════════════════════════════
export const enviarResumenSemanal = enRegion({maxInstances: 1, timeoutSeconds: 300})
  .pubsub.schedule("every 60 minutes")
  .timeZone("Etc/UTC")
  .onRun(async () => {
    const ahora = Date.now();
    let enviados = 0;
    const consulta = db().collection("accountability").where("weeklyEnabled", "==", true);
    for await (const doc of recorrer(consulta)) {
      try {
        const uid = doc.id;
        const ajustes = doc.data();
        const zona = typeof ajustes.timezone === "string" ? ajustes.timezone : "UTC";
        const estadoRef = db().collection("accountabilityState").doc(uid);
        const previo = (await estadoRef.get()).data() ?? {};
        const {enviar, claveSemana} = debeEnviarResumen(
          ahora,
          zona,
          typeof previo.lastWeeklyKey === "string" ? previo.lastWeeklyKey : undefined,
        );
        if (!enviar) continue;
        await estadoRef.set({lastWeeklyKey: claveSemana}, {merge: true});

        const destinos = await companerosActivos(uid, listaUids(ajustes.weeklyReportPartners));
        if (destinos.length === 0) continue;

        const claves = clavesSemana(claveSemana);
        const userRef = db().collection("users").doc(uid);
        const [diasSnap, progreso, escudo] = await Promise.all([
          db().getAll(...claves.map((k) => userRef.collection("victoryDays").doc(k))),
          userRef.collection("publicProgress").doc("latest").get(),
          db().collection("shieldStatus").doc(uid).get(),
        ]);
        const datos = resumirSemana(
          diasSnap
            .filter((s) => s.exists)
            .map((s) => ({isVictoryDay: s.data()?.isVictoryDay === true})),
        );
        const racha = progreso.data()?.streakDays;
        if (typeof racha === "number") datos.racha = racha;
        const e = escudo.data();
        if (e && (e.enabledByUser === true || e.vpnActive === true)) {
          datos.escudoActivo = e.vpnActive === true;
          datos.bloqueos = sumarBloqueos(e.blocksByDay, claves);
        }

        const nombre = await publicNameFor(uid, "Tu compañero");
        const texto = construirTextoResumen(nombre, datos, leerCompartir(ajustes.share));
        await enviarMensaje(destinos, uid, nombre, "weekly_report", texto);
        enviados += destinos.length;
      } catch (err) {
        console.error("[RESUMEN] Error con un usuario:", err);
      }
    }
    if (enviados > 0) console.log(`[RESUMEN] ${enviados} resumen(es) enviados`);
  });
