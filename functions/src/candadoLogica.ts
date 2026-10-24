/**
 * ═══════════════════════════════════════════════════════════════════════════
 * CANDADO DEL GUARDIÁN AL LIBERAR UN COMPAÑERO — lógica pura, probada en
 * functions/test/candadoLogica.test.js.
 *
 * Liberar a un compañero NO puede servir para saltarse el candado del
 * Escudo (el PIN que tiene el guardián):
 * - Si quien libera es el GUARDIÁN del otro, su candado se retira al momento.
 * - Si el otro es TU guardián con candado activo:
 *     · con el PIN correcto del guardián → se retira al momento;
 *     · sin PIN → se rechaza, salvo que pidas el retiro con espera: el
 *       vínculo se libera ya (deja de ver tu progreso), pero el candado sigue
 *       72 h. Se avisa al guardián y solo tú puedes cancelarlo. Así una
 *       persona en un vínculo dañino puede salir sin depender de ella, y el
 *       candado no se vuelve un botón de "apagar ya".
 * - Una solicitud pendiente (sin candado activo) se retira sin más.
 * ═══════════════════════════════════════════════════════════════════════════
 */

export const ESPERA_RETIRO_MS = 72 * 60 * 60 * 1000;

export interface CandadoGuardian {
  active?: boolean;
  guardianUid?: string;
  pendingGuardianUid?: string;
  releaseAtMs?: number;
}

export type AccionCandado =
  | "ninguna" // el compañero no tiene candado sobre quien libera
  | "retirar" // se puede retirar ya
  | "programar" // retiro con espera de 72 h
  | "rechazar"; // falta el PIN (o pedir el retiro con espera)

export interface DecisionCandado {
  accion: AccionCandado;
  releaseAtMs?: number;
}

/**
 * ¿Qué hacer con el candado que [partnerUid] tiene sobre quien libera?
 * @param {CandadoGuardian | undefined} candado guardianLocks/{quienLibera}.
 * @param {string} partnerUid compañero que se libera.
 * @param {{pinValido: boolean, conEspera: boolean, ahoraMs: number}} op
 *   opciones de la solicitud.
 * @return {DecisionCandado} acción a tomar.
 */
export function decidirCandadoAlLiberar(
  candado: CandadoGuardian | undefined,
  partnerUid: string,
  op: {pinValido: boolean; conEspera: boolean; ahoraMs: number},
): DecisionCandado {
  if (!candado) return {accion: "ninguna"};
  const esGuardianActivo = candado.active === true &&
    candado.guardianUid === partnerUid;
  if (!esGuardianActivo) {
    // Solo una solicitud pendiente (aún sin PIN): se retira sin más.
    return candado.pendingGuardianUid === partnerUid ?
      {accion: "retirar"} : {accion: "ninguna"};
  }
  if (op.pinValido) return {accion: "retirar"};
  if (op.conEspera) {
    // Si ya había un retiro programado, se conserva la fecha original.
    const releaseAtMs = candado.releaseAtMs !== undefined &&
      candado.releaseAtMs > op.ahoraMs ?
      candado.releaseAtMs : op.ahoraMs + ESPERA_RETIRO_MS;
    return {accion: "programar", releaseAtMs};
  }
  return {accion: "rechazar"};
}

/**
 * ¿Quien libera es el guardián del compañero? Entonces puede retirar el
 * candado del compañero (es su propio PIN el que se va).
 * @param {CandadoGuardian | undefined} candadoDelCompanero guardianLocks/{partner}.
 * @param {string} quienLibera uid de quien libera.
 * @return {boolean} true si se debe retirar.
 */
export function guardianPuedeRetirar(
  candadoDelCompanero: CandadoGuardian | undefined,
  quienLibera: string,
): boolean {
  if (!candadoDelCompanero) return false;
  return candadoDelCompanero.guardianUid === quienLibera ||
    candadoDelCompanero.pendingGuardianUid === quienLibera;
}

/**
 * ¿Ya venció un retiro programado?
 * @param {CandadoGuardian | undefined} candado candado del protegido.
 * @param {number} ahoraMs hora actual.
 * @return {boolean} true si hay que retirarlo.
 */
export function retiroVencido(
  candado: CandadoGuardian | undefined,
  ahoraMs: number,
): boolean {
  return candado?.releaseAtMs !== undefined && candado.releaseAtMs <= ahoraMs;
}
