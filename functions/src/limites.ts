/**
 * Protectores de costo compartidos por todas las funciones.
 *
 * Sin tope, Google puede levantar cientos de instancias a la vez si llega
 * una ola de llamadas (un error que se repite o alguien abusando de la app),
 * y cada una se cobra. Con el tope, las llamadas de más esperan su turno o
 * fallan, pero la factura queda acotada. Para ~300 personas al día, 10
 * instancias simultáneas por función sobran.
 */
import * as functions from "firebase-functions/v1";

export const TOPE_INSTANCIAS = 10;

/**
 * App Check obligatorio en las funciones que llama la app: rechaza llamadas
 * que no vengan de la app original instalada desde la tienda. Apagado por
 * defecto para poder probar con versiones de desarrollo; se enciende antes
 * de publicar con `EXIGIR_APP_CHECK=true` en `functions/.env` y volviendo a
 * desplegar (ver docs/COSTOS_FIREBASE.md).
 */
export const EXIGIR_APP_CHECK = process.env.EXIGIR_APP_CHECK === "true";

/**
 * us-central1 (la región con cuotas gratis) con tope de instancias.
 * @param {functions.RuntimeOptions} opciones memoria, tiempo, secretos o un
 *   tope propio (`maxInstances`) que reemplaza al general.
 * @return {functions.FunctionBuilder} constructor listo para el disparador.
 */
export function enRegion(
  opciones: functions.RuntimeOptions = {},
): functions.FunctionBuilder {
  return functions
    .region("us-central1")
    .runWith({
      maxInstances: TOPE_INSTANCIAS,
      enforceAppCheck: EXIGIR_APP_CHECK,
      ...opciones,
    });
}
