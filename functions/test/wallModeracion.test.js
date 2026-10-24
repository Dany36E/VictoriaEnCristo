// Pruebas de los filtros del Muro (node --test sobre lib/ compilado).
const test = require("node:test");
const assert = require("node:assert/strict");
const M = require("../lib/wallModeracion");

test("detecta señales de crisis", () => {
  for (const t of [
    "A veces pienso en el suicidio",
    "me quiero quitar la vida",
    "no quiero seguir viviendo",
    "quiero matarme",
    "me voy a suicidar",
    "ya no quiero vivir",
    "Quiero morirme",
    "he pensado en quitarme la vida",
    "me quiero matar",
    "pensé en cortarme las venas",
    "quiero hacerme daño",
  ]) {
    assert.equal(M.detectarCrisis(t), true, t);
  }
});

test("no confunde frases comunes con crisis", () => {
  for (const t of [
    "Hoy tuve que cortar el pasto y oré",
    "Esta tentación me quiere matar de cansancio... pero Dios es fiel",
    "No quiero vivir en pecado nunca más",
    "Quiero morir a mí mismo cada día (Gálatas 2:20)",
    "Hace años pensé en el suicidio y Cristo me rescató",
    "Mañana voy a cortarme el pelo",
    "Me voy a matar de risa con este chiste",
    "Quiero matarme de risa",
  ]) {
    assert.equal(M.detectarCrisis(t), false, t);
  }
});

test("la respuesta de crisis no dice 'en revisión' y marca el estado", () => {
  assert.equal(M.RESPUESTA_CRISIS.status, "crisis");
  assert.equal(M.RESPUESTA_CRISIS.crisis, true);
  assert.equal(M.RESPUESTA_CRISIS.success, false);
  assert.doesNotMatch(M.RESPUESTA_CRISIS.message, /revisión/);
});

test("bloquea enlaces e insultos, no texto normal", () => {
  assert.equal(M.contieneBloqueado("visita www.ejemplo.com"), true);
  assert.equal(M.contieneBloqueado("qué mierda"), true);
  assert.equal(M.contieneBloqueado("Gracias por orar por mí"), false);
});
