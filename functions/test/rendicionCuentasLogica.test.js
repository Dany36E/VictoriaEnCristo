// Pruebas de la lógica pura de rendición de cuentas (node --test).
// Se ejecutan sobre lib/ compilado: `npm test` compila antes.
const test = require("node:test");
const assert = require("node:assert/strict");
const L = require("../lib/rendicionCuentasLogica");

const MIN = 60 * 1000;
const HORA = 60 * MIN;
const AHORA = Date.UTC(2026, 9, 25, 12, 0, 0);

const base = {
  enabledByUser: true,
  vpnActive: true,
  alertsEnabled: true,
  lastSeenAtMs: AHORA - HORA,
};

test("sin avisos activados no se envía nada", () => {
  const d = L.evaluarAvisoEscudo(
    {...base, alertsEnabled: false, vpnActive: false, lastOffAtMs: AHORA - HORA},
    {},
    AHORA,
  );
  assert.equal(d.enviar, false);
});

test("Escudo apagado más de 10 min: aviso 'apagado'", () => {
  const off = AHORA - 30 * MIN;
  const d = L.evaluarAvisoEscudo(
    {...base, vpnActive: false, lastOffAtMs: off, lastOffReason: "user_off"},
    {},
    AHORA,
  );
  assert.deepEqual(d, {enviar: true, tipo: "apagado", episodio: `apagado:${off}`});
});

test("apagado de pocos minutos no avisa", () => {
  const d = L.evaluarAvisoEscudo(
    {...base, vpnActive: false, lastOffAtMs: AHORA - 3 * MIN},
    {},
    AHORA,
  );
  assert.equal(d.enviar, false);
});

test("estuvo apagado con la app cerrada y ya volvió: 'apagado_temporal'", () => {
  const off = AHORA - 8 * HORA;
  const d = L.evaluarAvisoEscudo(
    {...base, vpnActive: true, lastOffAtMs: off, lastOnAtMs: AHORA - HORA},
    {},
    AHORA,
  );
  assert.equal(d.tipo, "apagado_temporal");
});

test("el mismo episodio no se avisa dos veces", () => {
  const off = AHORA - 2 * HORA;
  const e = {...base, vpnActive: false, lastOffAtMs: off};
  const h = {ultimoEpisodio: `apagado:${off}`, ultimoAvisoMs: AHORA - 20 * HORA};
  assert.equal(L.evaluarAvisoEscudo(e, h, AHORA).enviar, false);
});

test("respeta el mínimo de 6 h entre avisos", () => {
  const e = {...base, vpnActive: false, lastOffAtMs: AHORA - HORA};
  assert.equal(L.evaluarAvisoEscudo(e, {ultimoAvisoMs: AHORA - 2 * HORA}, AHORA).enviar, false);
  assert.equal(L.evaluarAvisoEscudo(e, {ultimoAvisoMs: AHORA - 7 * HORA}, AHORA).enviar, true);
});

test("apagados de hace más de 48 h ya no se avisan", () => {
  const e = {...base, vpnActive: false, lastOffAtMs: AHORA - 50 * HORA, lastSeenAtMs: AHORA - HORA};
  assert.equal(L.evaluarAvisoEscudo(e, {}, AHORA).enviar, false);
});

test("uno o dos días sin abrir la app no disparan ningún aviso", () => {
  for (const horas of [25, 48, 71]) {
    const d = L.evaluarAvisoEscudo({...base, lastSeenAtMs: AHORA - horas * HORA}, {}, AHORA);
    assert.equal(d.enviar, false, `${horas} h`);
  }
});

test("sin señal por más de 72 h: 'sin_senal' con texto suave", () => {
  assert.match(L.textoAvisoEscudo("sin_senal", "Juan"), /en 3 días/);
  const visto = AHORA - 73 * HORA;
  const d = L.evaluarAvisoEscudo({...base, lastSeenAtMs: visto}, {}, AHORA);
  assert.deepEqual(d, {enviar: true, tipo: "sin_senal", episodio: `sin_senal:${visto}`});
});

test("sin señal no avisa si el usuario no quiere el Escudo encendido", () => {
  const d = L.evaluarAvisoEscudo(
    {...base, enabledByUser: false, lastSeenAtMs: AHORA - 80 * HORA},
    {},
    AHORA,
  );
  assert.equal(d.enviar, false);
});

test("los textos de aviso no incluyen detalles sensibles", () => {
  for (const tipo of ["apagado", "apagado_temporal", "sin_senal"]) {
    const t = L.textoAvisoEscudo(tipo, "Juan");
    assert.match(t, /Juan/);
    assert.doesNotMatch(t, /http|\.com|\d{1,2}:\d{2}/);
  }
});

test("resumen: solo domingo desde las 19 h locales y una vez por semana", () => {
  // Domingo 25 oct 2026, 19:30 en Ciudad de México = 01:30 UTC del lunes.
  const domingoTarde = Date.UTC(2026, 9, 26, 1, 30);
  const r = L.debeEnviarResumen(domingoTarde, "America/Mexico_City", undefined);
  assert.deepEqual(r, {enviar: true, claveSemana: "2026-10-25"});
  assert.equal(L.debeEnviarResumen(domingoTarde, "America/Mexico_City", "2026-10-25").enviar, false);
  // Domingo 18:00 local todavía no.
  assert.equal(L.debeEnviarResumen(Date.UTC(2026, 9, 26, 0, 0), "America/Mexico_City").enviar, false);
  // En Madrid ese instante ya es lunes.
  assert.equal(L.debeEnviarResumen(domingoTarde, "Europe/Madrid").enviar, false);
});

test("resumen: zona horaria inválida usa UTC sin fallar", () => {
  const r = L.debeEnviarResumen(Date.UTC(2026, 9, 25, 20, 0), "No/Existe", undefined);
  assert.equal(r.enviar, true);
});

test("clavesSemana devuelve lunes a domingo, cruzando mes y cambio de horario", () => {
  assert.deepEqual(L.clavesSemana("2026-11-01"), [
    "2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29",
    "2026-10-30", "2026-10-31", "2026-11-01",
  ]);
});

test("resumirSemana cuenta victorias y gracias", () => {
  const d = L.resumirSemana([
    {isVictoryDay: true}, {isVictoryDay: true}, {isVictoryDay: false},
  ]);
  assert.deepEqual(d, {diasRegistrados: 3, victorias: 2, gracias: 1});
});

test("sumarBloqueos solo suma la semana pedida", () => {
  const porDia = {"2026-10-18": 9, "2026-10-20": 2, "2026-10-25": 1, "x": "a"};
  assert.equal(L.sumarBloqueos(porDia, L.clavesSemana("2026-10-25")), 3);
  assert.equal(L.sumarBloqueos(undefined, []), undefined);
});

// Mismo ejemplo que test/utils/resumen_semanal_test.dart: si cambia una
// frase de un lado, ambas pruebas deben actualizarse juntas.
test("texto del resumen igual al de la app", () => {
  const texto = L.construirTextoResumen(
    "Daniel",
    {diasRegistrados: 6, victorias: 5, gracias: 1, racha: 12, escudoActivo: true, bloqueos: 1},
    {registro: true, victoriaGracia: true, racha: true, escudo: true},
  );
  assert.equal(
    texto,
    "Resumen semanal de Daniel\n" +
    "• Registró 6 de 7 días.\n" +
    "• 5 días de victoria y 1 de gracia.\n" +
    "• Racha actual: 12 días.\n" +
    "• Escudo de Pureza: activo · 1 bloqueo esta semana.\n" +
    "Ora por Daniel y anímale esta semana.",
  );
});

test("el resumen respeta lo que el usuario no comparte", () => {
  const texto = L.construirTextoResumen(
    "Ana",
    {diasRegistrados: 1, victorias: 1, gracias: 0, racha: 1, escudoActivo: false, bloqueos: 4},
    L.leerCompartir({registro: false, victoriaGracia: false, racha: false, escudo: false}),
  );
  assert.equal(
    texto,
    "Resumen semanal de Ana\n• Sigue en la batalla esta semana.\nOra por Ana y anímale esta semana.",
  );
  assert.deepEqual(L.leerCompartir(undefined), {
    registro: true, victoriaGracia: true, racha: true, escudo: true,
  });
});

test("dejar de compartir avisa a cada compañero afectado", () => {
  const antes = {
    shieldAlertPartners: ["a", "b"],
    weeklyReportPartners: ["a", "c"],
    share: {escudo: true},
  };
  const despues = {shieldAlertPartners: ["b"], weeklyReportPartners: ["c"], share: {escudo: false}};
  assert.deepEqual(L.cambiosDeCompartir(antes, despues), [
    {uid: "a", tipo: "avisos_escudo"},
    {uid: "a", tipo: "resumen_semanal"},
    {uid: "c", tipo: "escudo_en_resumen"},
  ]);
  assert.deepEqual(L.cambiosDeCompartir(despues, antes), [], "agregar no avisa");
  assert.match(L.textoCambioCompartir("avisos_escudo", "Ana"), /^Ana dejó de compartirte/);
});

test("solo apagados confirmados: Escudo activo y con latido reciente no avisa", () => {
  const d = L.evaluarAvisoEscudo({...base, vpnActive: true}, {}, AHORA);
  assert.equal(d.enviar, false);
});
