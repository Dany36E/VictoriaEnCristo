// Liberar a un compañero no puede saltarse el candado del guardián.
const test = require("node:test");
const assert = require("node:assert/strict");
const C = require("../lib/candadoLogica");

const AHORA = Date.UTC(2026, 9, 23, 12);
const sinPin = {pinValido: false, conEspera: false, ahoraMs: AHORA};
// Candado de "yo" (protegido) cuyo guardián es "g".
const candadoActivo = {active: true, guardianUid: "g"};

test("el protegido NO puede quitar el candado liberando a su guardián", () => {
  assert.deepEqual(C.decidirCandadoAlLiberar(candadoActivo, "g", sinPin), {accion: "rechazar"});
});

test("con el PIN correcto del guardián se retira al momento", () => {
  const d = C.decidirCandadoAlLiberar(candadoActivo, "g", {...sinPin, pinValido: true});
  assert.equal(d.accion, "retirar");
});

test("retiro con espera: 72 h después, sin quitarlo ya", () => {
  const d = C.decidirCandadoAlLiberar(candadoActivo, "g", {...sinPin, conEspera: true});
  assert.equal(d.accion, "programar");
  assert.equal(d.releaseAtMs, AHORA + 72 * 60 * 60 * 1000);
  assert.equal(C.retiroVencido({...candadoActivo, releaseAtMs: d.releaseAtMs}, AHORA), false);
  assert.equal(
    C.retiroVencido({...candadoActivo, releaseAtMs: d.releaseAtMs}, d.releaseAtMs),
    true,
  );
});

test("pedir otra vez la espera no la reinicia ni la acorta", () => {
  const programado = AHORA + 10 * 60 * 60 * 1000;
  const d = C.decidirCandadoAlLiberar(
    {...candadoActivo, releaseAtMs: programado},
    "g",
    {...sinPin, conEspera: true},
  );
  assert.equal(d.releaseAtMs, programado);
});

test("el guardián sí puede retirar su candado sobre el compañero", () => {
  // Candado del compañero "p", cuyo guardián soy "yo".
  assert.equal(C.guardianPuedeRetirar({active: true, guardianUid: "yo"}, "yo"), true);
  assert.equal(C.guardianPuedeRetirar({pendingGuardianUid: "yo"}, "yo"), true);
  assert.equal(C.guardianPuedeRetirar({active: true, guardianUid: "otro"}, "yo"), false);
  assert.equal(C.guardianPuedeRetirar(undefined, "yo"), false);
});

test("si el compañero no es mi guardián, no se toca mi candado", () => {
  assert.deepEqual(
    C.decidirCandadoAlLiberar({active: true, guardianUid: "otro"}, "g", sinPin),
    {accion: "ninguna"},
  );
  assert.deepEqual(C.decidirCandadoAlLiberar(undefined, "g", sinPin), {accion: "ninguna"});
});

test("una solicitud pendiente (sin PIN puesto) se retira sin más", () => {
  assert.deepEqual(
    C.decidirCandadoAlLiberar({active: false, pendingGuardianUid: "g"}, "g", sinPin),
    {accion: "retirar"},
  );
});
