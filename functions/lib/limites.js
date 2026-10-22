"use strict";
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
exports.EXIGIR_APP_CHECK = exports.TOPE_INSTANCIAS = void 0;
exports.enRegion = enRegion;
/**
 * Protectores de costo compartidos por todas las funciones.
 *
 * Sin tope, Google puede levantar cientos de instancias a la vez si llega
 * una ola de llamadas (un error que se repite o alguien abusando de la app),
 * y cada una se cobra. Con el tope, las llamadas de más esperan su turno o
 * fallan, pero la factura queda acotada. Para ~300 personas al día, 10
 * instancias simultáneas por función sobran.
 */
const functions = __importStar(require("firebase-functions/v1"));
exports.TOPE_INSTANCIAS = 10;
/**
 * App Check obligatorio en las funciones que llama la app: rechaza llamadas
 * que no vengan de la app original instalada desde la tienda. Apagado por
 * defecto para poder probar con versiones de desarrollo; se enciende antes
 * de publicar con `EXIGIR_APP_CHECK=true` en `functions/.env` y volviendo a
 * desplegar (ver docs/COSTOS_FIREBASE.md).
 */
exports.EXIGIR_APP_CHECK = process.env.EXIGIR_APP_CHECK === "true";
/**
 * us-central1 (la región con cuotas gratis) con tope de instancias.
 * @param {functions.RuntimeOptions} opciones memoria, tiempo, secretos o un
 *   tope propio (`maxInstances`) que reemplaza al general.
 * @return {functions.FunctionBuilder} constructor listo para el disparador.
 */
function enRegion(opciones = {}) {
    return functions
        .region("us-central1")
        .runWith(Object.assign({ maxInstances: exports.TOPE_INSTANCIAS, enforceAppCheck: exports.EXIGIR_APP_CHECK }, opciones));
}
//# sourceMappingURL=limites.js.map