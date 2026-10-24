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

const MINUTO = 60 * 1000;
const HORA = 60 * MINUTO;

/** Un apagado corto (reinicio, cambio de red) no se avisa. */
export const MIN_APAGADO_MS = 10 * MINUTO;
/**
 * Sin latido por más de esto = "sin señal". El latido sale al abrir la app,
 * así que no abrirla uno o dos días nunca dispara un aviso.
 */
export const SIN_SENAL_MS = 72 * HORA;
/** Mínimo entre dos avisos del Escudo del mismo usuario. */
export const MIN_ENTRE_AVISOS_MS = 6 * HORA;
/** Apagados más viejos que esto ya no se avisan (p. ej. al activar avisos). */
export const VENTANA_APAGADO_MS = 48 * HORA;

export interface EstadoEscudo {
  enabledByUser: boolean;
  vpnActive: boolean;
  alertsEnabled: boolean;
  lastSeenAtMs?: number;
  lastOffAtMs?: number;
  lastOffReason?: string;
  lastOnAtMs?: number;
}

export interface HistorialAvisos {
  ultimoAvisoMs?: number;
  ultimoEpisodio?: string;
}

export type TipoAviso = "apagado" | "apagado_temporal" | "sin_senal";

export interface DecisionAviso {
  enviar: boolean;
  tipo?: TipoAviso;
  episodio?: string;
}

const NO_ENVIAR: DecisionAviso = {enviar: false};

/**
 * ¿Hay que avisar a los compañeros sobre el Escudo de este usuario?
 * @param {EstadoEscudo} e estado publicado por la app.
 * @param {HistorialAvisos} h avisos ya enviados (estado del servidor).
 * @param {number} ahoraMs hora actual.
 * @return {DecisionAviso} si enviar, de qué tipo y la clave del episodio.
 */
export function evaluarAvisoEscudo(
  e: EstadoEscudo,
  h: HistorialAvisos,
  ahoraMs: number,
): DecisionAviso {
  if (!e.alertsEnabled) return NO_ENVIAR;

  let candidato: DecisionAviso = NO_ENVIAR;
  const off = e.lastOffAtMs;
  if (off !== undefined && ahoraMs - off <= VENTANA_APAGADO_MS) {
    const volvio = e.lastOnAtMs !== undefined && e.lastOnAtMs > off;
    if (!e.vpnActive && !volvio) {
      if (ahoraMs - off >= MIN_APAGADO_MS) {
        candidato = {enviar: true, tipo: "apagado", episodio: `apagado:${off}`};
      }
    } else if (volvio && (e.lastOnAtMs as number) - off >= MIN_APAGADO_MS) {
      candidato = {
        enviar: true,
        tipo: "apagado_temporal",
        episodio: `apagado:${off}`,
      };
    }
  }
  if (
    !candidato.enviar &&
    e.enabledByUser &&
    e.lastSeenAtMs !== undefined &&
    ahoraMs - e.lastSeenAtMs > SIN_SENAL_MS
  ) {
    candidato = {
      enviar: true,
      tipo: "sin_senal",
      episodio: `sin_senal:${e.lastSeenAtMs}`,
    };
  }
  if (!candidato.enviar) return NO_ENVIAR;
  if (candidato.episodio === h.ultimoEpisodio) return NO_ENVIAR;
  if (
    h.ultimoAvisoMs !== undefined &&
    ahoraMs - h.ultimoAvisoMs < MIN_ENTRE_AVISOS_MS
  ) {
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
export function textoAvisoEscudo(tipo: TipoAviso, nombre: string): string {
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
export const HORA_RESUMEN = 19;

export interface PartesLocales {
  clave: string; // AAAA-MM-DD
  diaSemana: number; // 0 = domingo … 6 = sábado
  hora: number;
}

const DIAS: Record<string, number> = {
  Sun: 0, Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6,
};

/**
 * Fecha, día de la semana y hora locales de [ahoraMs] en [zona].
 * @param {number} ahoraMs instante.
 * @param {string} zona zona IANA (p. ej. "America/Mexico_City").
 * @return {PartesLocales} partes locales (UTC si la zona no es válida).
 */
export function partesLocales(ahoraMs: number, zona: string): PartesLocales {
  let fmt: Intl.DateTimeFormat;
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
  } catch {
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
  const p: Record<string, string> = {};
  for (const parte of fmt.formatToParts(new Date(ahoraMs))) {
    p[parte.type] = parte.value;
  }
  return {
    clave: `${p.year}-${p.month}-${p.day}`,
    diaSemana: DIAS[p.weekday] ?? 0,
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
export function debeEnviarResumen(
  ahoraMs: number,
  zona: string,
  ultimaSemana: string | undefined,
): {enviar: boolean; claveSemana: string} {
  const local = partesLocales(ahoraMs, zona);
  const enviar = local.diaSemana === 0 &&
    local.hora >= HORA_RESUMEN &&
    local.clave !== ultimaSemana;
  return {enviar, claveSemana: local.clave};
}

/**
 * Claves de lunes a domingo de la semana que termina en [claveDomingo].
 * @param {string} claveDomingo "AAAA-MM-DD" del domingo.
 * @return {string[]} siete claves en orden.
 */
export function clavesSemana(claveDomingo: string): string[] {
  const [a, m, d] = claveDomingo.split("-").map(Number);
  const claves: string[] = [];
  for (let i = 6; i >= 0; i--) {
    const f = new Date(Date.UTC(a, m - 1, d - i));
    claves.push(f.toISOString().slice(0, 10));
  }
  return claves;
}

export interface DiaRegistrado {
  isVictoryDay: boolean;
}

export interface DatosResumen {
  diasRegistrados: number;
  victorias: number;
  gracias: number;
  racha?: number;
  escudoActivo?: boolean;
  bloqueos?: number;
}

export interface CompartirResumen {
  registro: boolean;
  victoriaGracia: boolean;
  racha: boolean;
  escudo: boolean;
}

/**
 * Cuenta días registrados, de victoria y de gracia.
 * @param {DiaRegistrado[]} dias días que tienen registro.
 * @return {DatosResumen} conteos.
 */
export function resumirSemana(dias: DiaRegistrado[]): DatosResumen {
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
export function leerCompartir(valor: unknown): CompartirResumen {
  const m = (typeof valor === "object" && valor !== null ?
    valor : {}) as Record<string, unknown>;
  const b = (k: string) => m[k] !== false;
  return {
    registro: b("registro"),
    victoriaGracia: b("victoriaGracia"),
    racha: b("racha"),
    escudo: b("escudo"),
  };
}

const plural = (n: number, uno: string, varios: string) =>
  n === 1 ? uno : varios;

/**
 * Texto del resumen semanal (igual a `textoResumenSemanal` en Dart).
 * @param {string} nombre nombre público.
 * @param {DatosResumen} datos datos de la semana.
 * @param {CompartirResumen} compartir lo que el usuario decidió compartir.
 * @return {string} texto.
 */
export function construirTextoResumen(
  nombre: string,
  datos: DatosResumen,
  compartir: CompartirResumen,
): string {
  const lineas = [`Resumen semanal de ${nombre}`];
  if (compartir.registro) {
    lineas.push(`• Registró ${datos.diasRegistrados} de 7 días.`);
  }
  if (compartir.victoriaGracia) {
    lineas.push(
      `• ${datos.victorias} ${plural(datos.victorias, "día", "días")} ` +
      `de victoria y ${datos.gracias} de gracia.`,
    );
  }
  if (compartir.racha && datos.racha !== undefined) {
    lineas.push(
      `• Racha actual: ${datos.racha} ${plural(datos.racha, "día", "días")}.`,
    );
  }
  if (compartir.escudo && datos.escudoActivo !== undefined) {
    const detalle = datos.bloqueos === undefined ? "" :
      ` · ${datos.bloqueos} ${plural(datos.bloqueos, "bloqueo", "bloqueos")} ` +
      "esta semana";
    lineas.push(
      `• Escudo de Pureza: ${datos.escudoActivo ? "activo" : "apagado"}` +
      `${detalle}.`,
    );
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
export function sumarBloqueos(
  porDia: unknown,
  claves: string[],
): number | undefined {
  if (typeof porDia !== "object" || porDia === null) return undefined;
  const m = porDia as Record<string, unknown>;
  let total = 0;
  for (const k of claves) {
    const v = m[k];
    if (typeof v === "number" && Number.isFinite(v) && v > 0) total += v;
  }
  return total;
}

// ═══════════════════════════════════════════════════════════════════════════
// CAMBIOS EN LO QUE SE COMPARTE (dejar de compartir no es silencioso)
// ═══════════════════════════════════════════════════════════════════════════

export type TipoCambioCompartir = "avisos_escudo" | "resumen_semanal" | "escudo_en_resumen";

export interface CambioCompartir {
  uid: string;
  tipo: TipoCambioCompartir;
}

interface AjustesCompartir {
  shieldAlertPartners?: unknown;
  weeklyReportPartners?: unknown;
  share?: unknown;
}

function uids(v: unknown): Set<string> {
  return new Set(Array.isArray(v) ? v.filter((x): x is string => typeof x === "string") : []);
}

/**
 * Compañeros a los que avisar porque el usuario dejó de compartirles algo.
 * @param {AjustesCompartir} antes documento anterior de accountability.
 * @param {AjustesCompartir} despues documento nuevo.
 * @return {CambioCompartir[]} un aviso por compañero y tipo.
 */
export function cambiosDeCompartir(
  antes: AjustesCompartir,
  despues: AjustesCompartir,
): CambioCompartir[] {
  const cambios: CambioCompartir[] = [];
  const escudoDespues = uids(despues.shieldAlertPartners);
  for (const u of uids(antes.shieldAlertPartners)) {
    if (!escudoDespues.has(u)) cambios.push({uid: u, tipo: "avisos_escudo"});
  }
  const resumenAntes = uids(antes.weeklyReportPartners);
  const resumenDespues = uids(despues.weeklyReportPartners);
  for (const u of resumenAntes) {
    if (!resumenDespues.has(u)) cambios.push({uid: u, tipo: "resumen_semanal"});
  }
  if (leerCompartir(antes.share).escudo && !leerCompartir(despues.share).escudo) {
    for (const u of resumenDespues) {
      if (resumenAntes.has(u)) cambios.push({uid: u, tipo: "escudo_en_resumen"});
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
export function textoCambioCompartir(tipo: TipoCambioCompartir, nombre: string): string {
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
