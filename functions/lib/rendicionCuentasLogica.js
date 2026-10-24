"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * RENDICIÓN DE CUENTAS — lógica pura (sin Firebase), probada en
 * functions/test/rendicionCuentasLogica.test.js.
 *
 * - Avisos del Escudo: decide si un cambio del Escudo de Pureza amerita
 *   avisar a los compañeros, sin repetir el mismo episodio y con un mínimo
 *   de horas entre avisos.
 * - Resumen semanal: decide cuándo enviarlo (domingo por la tarde en la zona
 *   horaria del usuario) y arma el texto. El texto es idéntico al que la app
 *   muestra en "Lo que verá tu compañero" (lib/utils/resumen_semanal.dart).
 * ═══════════════════════════════════════════════════════════════════════════
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.HORA_RESUMEN = exports.VENTANA_APAGADO_MS = exports.MIN_ENTRE_AVISOS_MS = exports.SIN_SENAL_MS = exports.MIN_APAGADO_MS = void 0;
exports.evaluarAvisoEscudo = evaluarAvisoEscudo;
exports.textoAvisoEscudo = textoAvisoEscudo;
exports.partesLocales = partesLocales;
exports.debeEnviarResumen = debeEnviarResumen;
exports.clavesSemana = clavesSemana;
exports.resumirSemana = resumirSemana;
exports.leerCompartir = leerCompartir;
exports.construirTextoResumen = construirTextoResumen;
exports.sumarBloqueos = sumarBloqueos;
exports.cambiosDeCompartir = cambiosDeCompartir;
exports.textoCambioCompartir = textoCambioCompartir;
const MINUTO = 60 * 1000;
const HORA = 60 * MINUTO;
/** Un apagado corto (reinicio, cambio de red) no se avisa. */
exports.MIN_APAGADO_MS = 10 * MINUTO;
/**
 * Sin latido por más de esto = "sin señal". El latido sale al abrir la app,
 * así que no abrirla uno o dos días nunca dispara un aviso.
 */
exports.SIN_SENAL_MS = 72 * HORA;
/** Mínimo entre dos avisos del Escudo del mismo usuario. */
exports.MIN_ENTRE_AVISOS_MS = 6 * HORA;
/** Apagados más viejos que esto ya no se avisan (p. ej. al activar avisos). */
exports.VENTANA_APAGADO_MS = 48 * HORA;
const NO_ENVIAR = { enviar: false };
/**
 * ¿Hay que avisar a los compañeros sobre el Escudo de este usuario?
 * @param {EstadoEscudo} e estado publicado por la app.
 * @param {HistorialAvisos} h avisos ya enviados (estado del servidor).
 * @param {number} ahoraMs hora actual.
 * @return {DecisionAviso} si enviar, de qué tipo y la clave del episodio.
 */
function evaluarAvisoEscudo(e, h, ahoraMs) {
    if (!e.alertsEnabled)
        return NO_ENVIAR;
    let candidato = NO_ENVIAR;
    const off = e.lastOffAtMs;
    if (off !== undefined && ahoraMs - off <= exports.VENTANA_APAGADO_MS) {
        const volvio = e.lastOnAtMs !== undefined && e.lastOnAtMs > off;
        if (!e.vpnActive && !volvio) {
            if (ahoraMs - off >= exports.MIN_APAGADO_MS) {
                candidato = { enviar: true, tipo: "apagado", episodio: `apagado:${off}` };
            }
        }
        else if (volvio && e.lastOnAtMs - off >= exports.MIN_APAGADO_MS) {
            candidato = {
                enviar: true,
                tipo: "apagado_temporal",
                episodio: `apagado:${off}`,
            };
        }
    }
    if (!candidato.enviar &&
        e.enabledByUser &&
        e.lastSeenAtMs !== undefined &&
        ahoraMs - e.lastSeenAtMs > exports.SIN_SENAL_MS) {
        candidato = {
            enviar: true,
            tipo: "sin_senal",
            episodio: `sin_senal:${e.lastSeenAtMs}`,
        };
    }
    if (!candidato.enviar)
        return NO_ENVIAR;
    if (candidato.episodio === h.ultimoEpisodio)
        return NO_ENVIAR;
    if (h.ultimoAvisoMs !== undefined &&
        ahoraMs - h.ultimoAvisoMs < exports.MIN_ENTRE_AVISOS_MS) {
        return NO_ENVIAR;
    }
    return candidato;
}
/**
 * Texto del aviso para el compañero: breve, sin sitios ni horas exactas.
 * @param {TipoAviso} tipo tipo de aviso.
 * @param {string} nombre nombre público de quien tiene el Escudo.
 * @return {string} texto del mensaje.
 */
function textoAvisoEscudo(tipo, nombre) {
    switch (tipo) {
        case "apagado":
            return `El Escudo de Pureza de ${nombre} está apagado. ` +
                "Puede ser un buen momento para escribirle con cariño y orar juntos.";
        case "apagado_temporal":
            return `El Escudo de Pureza de ${nombre} estuvo apagado un tiempo ` +
                "(ya está activo otra vez). Un mensaje de ánimo puede ayudar.";
        case "sin_senal":
        default:
            return `No hemos recibido señal del Escudo de ${nombre} en 3 días. ` +
                "Puede que solo no haya abierto la app; un saludo nunca sobra.";
    }
}
// ═══════════════════════════════════════════════════════════════════════════
// RESUMEN SEMANAL
// ═══════════════════════════════════════════════════════════════════════════
/** Hora local (0-23) a partir de la cual se envía el domingo. */
exports.HORA_RESUMEN = 19;
const DIAS = {
    Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
};
/**
 * Fecha, día de la semana y hora locales de [ahoraMs] en [zona].
 * @param {number} ahoraMs instante.
 * @param {string} zona zona IANA (p. ej. "America/Mexico_City").
 * @return {PartesLocales} partes locales (UTC si la zona no es válida).
 */
function partesLocales(ahoraMs, zona) {
    var _a;
    let fmt;
    try {
        fmt = new Intl.DateTimeFormat("en-US", {
            timeZone: zona,
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            weekday: "short",
            hour: "2-digit",
            hourCycle: "h23",
        });
    }
    catch (_b) {
        fmt = new Intl.DateTimeFormat("en-US", {
            timeZone: "UTC",
            year: "numeric",
            month: "2-digit",
            day: "2-digit",
            weekday: "short",
            hour: "2-digit",
            hourCycle: "h23",
        });
    }
    const p = {};
    for (const parte of fmt.formatToParts(new Date(ahoraMs))) {
        p[parte.type] = parte.value;
    }
    return {
        clave: `${p.year}-${p.month}-${p.day}`,
        diaSemana: (_a = DIAS[p.weekday]) !== null && _a !== void 0 ? _a : 0,
        hora: Number(p.hour) % 24,
    };
}
/**
 * ¿Toca enviar el resumen? Domingo desde las 19 h locales, una vez por semana.
 * @param {number} ahoraMs instante.
 * @param {string} zona zona horaria del usuario.
 * @param {string | undefined} ultimaSemana clave del último domingo enviado.
 * @return {{enviar: boolean, claveSemana: string}} decisión y clave.
 */
function debeEnviarResumen(ahoraMs, zona, ultimaSemana) {
    const local = partesLocales(ahoraMs, zona);
    const enviar = local.diaSemana === 0 &&
        local.hora >= exports.HORA_RESUMEN &&
        local.clave !== ultimaSemana;
    return { enviar, claveSemana: local.clave };
}
/**
 * Claves de lunes a domingo de la semana que termina en [claveDomingo].
 * @param {string} claveDomingo "AAAA-MM-DD" del domingo.
 * @return {string[]} siete claves en orden.
 */
function clavesSemana(claveDomingo) {
    const [a, m, d] = claveDomingo.split("-").map(Number);
    const claves = [];
    for (let i = 6; i >= 0; i--) {
        const f = new Date(Date.UTC(a, m - 1, d - i));
        claves.push(f.toISOString().slice(0, 10));
    }
    return claves;
}
/**
 * Cuenta días registrados, de victoria y de gracia.
 * @param {DiaRegistrado[]} dias días que tienen registro.
 * @return {DatosResumen} conteos.
 */
function resumirSemana(dias) {
    const victorias = dias.filter((d) => d.isVictoryDay).length;
    return {
        diasRegistrados: dias.length,
        victorias,
        gracias: dias.length - victorias,
    };
}
/**
 * Lee qué se comparte (todo verdadero salvo que diga lo contrario).
 * @param {unknown} valor campo `share` del documento.
 * @return {CompartirResumen} banderas.
 */
function leerCompartir(valor) {
    const m = (typeof valor === "object" && valor !== null ?
        valor : {});
    const b = (k) => m[k] !== false;
    return {
        registro: b("registro"),
        victoriaGracia: b("victoriaGracia"),
        racha: b("racha"),
        escudo: b("escudo"),
    };
}
const plural = (n, uno, varios) => n === 1 ? uno : varios;
/**
 * Texto del resumen semanal (igual a `textoResumenSemanal` en Dart).
 * @param {string} nombre nombre público.
 * @param {DatosResumen} datos datos de la semana.
 * @param {CompartirResumen} compartir lo que el usuario decidió compartir.
 * @return {string} texto.
 */
function construirTextoResumen(nombre, datos, compartir) {
    const lineas = [`Resumen semanal de ${nombre}`];
    if (compartir.registro) {
        lineas.push(`• Registró ${datos.diasRegistrados} de 7 días.`);
    }
    if (compartir.victoriaGracia) {
        lineas.push(`• ${datos.victorias} ${plural(datos.victorias, "día", "días")} ` +
            `de victoria y ${datos.gracias} de gracia.`);
    }
    if (compartir.racha && datos.racha !== undefined) {
        lineas.push(`• Racha actual: ${datos.racha} ${plural(datos.racha, "día", "días")}.`);
    }
    if (compartir.escudo && datos.escudoActivo !== undefined) {
        const detalle = datos.bloqueos === undefined ? "" :
            ` · ${datos.bloqueos} ${plural(datos.bloqueos, "bloqueo", "bloqueos")} ` +
                "esta semana";
        lineas.push(`• Escudo de Pureza: ${datos.escudoActivo ? "activo" : "apagado"}` +
            `${detalle}.`);
    }
    if (lineas.length === 1) {
        lineas.push("• Sigue en la batalla esta semana.");
    }
    lineas.push(`Ora por ${nombre} y anímale esta semana.`);
    return lineas.join("\n");
}
/**
 * Suma los bloqueos de las claves dadas.
 * @param {unknown} porDia mapa "AAAA-MM-DD" → cantidad.
 * @param {string[]} claves días a sumar.
 * @return {number | undefined} total, o undefined si no hay datos.
 */
function sumarBloqueos(porDia, claves) {
    if (typeof porDia !== "object" || porDia === null)
        return undefined;
    const m = porDia;
    let total = 0;
    for (const k of claves) {
        const v = m[k];
        if (typeof v === "number" && Number.isFinite(v) && v > 0)
            total += v;
    }
    return total;
}
function uids(v) {
    return new Set(Array.isArray(v) ? v.filter((x) => typeof x === "string") : []);
}
/**
 * Compañeros a los que avisar porque el usuario dejó de compartirles algo.
 * @param {AjustesCompartir} antes documento anterior de accountability.
 * @param {AjustesCompartir} despues documento nuevo.
 * @return {CambioCompartir[]} un aviso por compañero y tipo.
 */
function cambiosDeCompartir(antes, despues) {
    const cambios = [];
    const escudoDespues = uids(despues.shieldAlertPartners);
    for (const u of uids(antes.shieldAlertPartners)) {
        if (!escudoDespues.has(u))
            cambios.push({ uid: u, tipo: "avisos_escudo" });
    }
    const resumenAntes = uids(antes.weeklyReportPartners);
    const resumenDespues = uids(despues.weeklyReportPartners);
    for (const u of resumenAntes) {
        if (!resumenDespues.has(u))
            cambios.push({ uid: u, tipo: "resumen_semanal" });
    }
    if (leerCompartir(antes.share).escudo && !leerCompartir(despues.share).escudo) {
        for (const u of resumenDespues) {
            if (resumenAntes.has(u))
                cambios.push({ uid: u, tipo: "escudo_en_resumen" });
        }
    }
    return cambios;
}
/**
 * Texto para el compañero cuando se deja de compartir algo con él.
 * @param {TipoCambioCompartir} tipo qué se dejó de compartir.
 * @param {string} nombre nombre público de quien comparte.
 * @return {string} texto.
 */
function textoCambioCompartir(tipo, nombre) {
    switch (tipo) {
        case "avisos_escudo":
            return `${nombre} dejó de compartirte los avisos de su Escudo de Pureza.`;
        case "resumen_semanal":
            return `${nombre} dejó de compartirte su resumen semanal.`;
        case "escudo_en_resumen":
        default:
            return `${nombre} dejó de incluir el Escudo de Pureza en su resumen semanal.`;
    }
}
//# sourceMappingURL=rendicionCuentasLogica.js.map