"use strict";
/**
 * ═══════════════════════════════════════════════════════════════════════════
 * MURO — filtros de contenido (lógica pura, probada en
 * functions/test/wallModeracion.test.js).
 *
 * - Crisis (autolesión / suicidio): NO se publica, pero tampoco se esconde
 *   en silencio. La función responde `status: "crisis"` y la app muestra al
 *   momento una hoja de ayuda (líneas de crisis, avisar al compañero,
 *   pantalla de emergencia).
 * - Bloqueado (insultos, enlaces): se rechaza automáticamente.
 * ═══════════════════════════════════════════════════════════════════════════
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.RESPUESTA_CRISIS = void 0;
exports.detectarCrisis = detectarCrisis;
exports.contieneBloqueado = contieneBloqueado;
/** Señales de riesgo de autolesión o suicidio (español, sin acentos o con ellos). */
// Se buscan intenciones en primera persona y presente: un testimonio
// ("hace años pensé en el suicidio y Cristo me rescató") o "morir a mí
// mismo" (Gálatas 2:20) no deben bloquearse.
const PATRONES_CRISIS = [
    /\bsuicidarme\b/i,
    /\bme\s+voy\s+a\s+suicidar\b/i,
    /\b(pienso|estoy\s+pensando|quiero|tengo\s+ganas\s+de)\s+(en\s+)?(el\s+)?suicid/i,
    /\b(quiero|vuelvo\s+a|estoy)\s+autolesion/i,
    /\bquitarme\s+la\s+vida\b/i,
    /\bme\s+quiero\s+quitar\s+la\s+vida\b/i,
    /\bacabar\s+con\s+mi\s+vida\b/i,
    /\bno\s+quiero\s+(seguir\s+)?vivir(\s*[.,!?]|\s*$|\s+m[aá]s\b)/i,
    /\bno\s+quiero\s+seguir\s+viviendo\b/i,
    /\bquiero\s+morir(me)?\b(?!\s+(a|al)\s+(m[ií]\s+mismo|yo|ego|pecado|carne))/i,
    /\b(quiero|voy\s+a|ganas\s+de)\s+matarme\b(?!\s+(de\s+risa|estudiando|trabajando))/i,
    /\bme\s+quiero\s+matar\b/i,
    /\bcort(ar|arme|arte)\s+(las?\s+)?venas?\b/i,
    /\bcortarme\s+(los\s+brazos|las\s+mu[nñ]ecas|la\s+piel)\b/i,
    /\bhacerme\s+da[nñ]o\b/i,
];
/** Contenido que se rechaza sin publicar (no es crisis). */
const PATRONES_BLOQUEADOS = [
    /https?:\/\//i,
    /www\./i,
    /\.com\b/i,
    /\bput[o@]s?\b/i,
    /\bmierda\b/i,
    /\bhijue?putas?\b/i,
    /\bpend?ej[oa]s?\b/i,
    /\bmal ?parido\b/i,
    /\bgonorrea\b/i,
    /\bmaric[oó]n\b/i,
];
/**
 * ¿El texto sugiere riesgo de autolesión o suicidio?
 * @param {string} texto texto del usuario.
 * @return {boolean} true si hay señales de crisis.
 */
function detectarCrisis(texto) {
    return PATRONES_CRISIS.some((p) => p.test(texto));
}
/**
 * ¿El texto tiene insultos o enlaces que se rechazan?
 * @param {string} texto texto del usuario.
 * @return {boolean} true si se debe rechazar.
 */
function contieneBloqueado(texto) {
    return PATRONES_BLOQUEADOS.some((p) => p.test(texto));
}
/** Respuesta para la app cuando se detecta una crisis. */
exports.RESPUESTA_CRISIS = {
    success: false,
    status: "crisis",
    crisis: true,
    message: "Lo que escribiste importa y no lo vamos a publicar. " +
        "No tienes que pasar esto solo: hay ayuda ahora mismo.",
};
//# sourceMappingURL=wallModeracion.js.map