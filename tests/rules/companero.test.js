// Reglas de Firestore: compañero de batalla, rendición de cuentas y Muro.
// Requiere el emulador: desde functions/ → `npm run test:rules`.
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  doc, getDoc, setDoc, updateDoc, deleteDoc, deleteField, serverTimestamp,
  collectionGroup, query, where, getDocs,
} = require("firebase/firestore");

let env;

test.before(async () => {
  env = await initializeTestEnvironment({
    projectId: "demo-victoria",
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, "../../firestore.rules"), "utf8"),
    },
  });
});
test.after(async () => env && env.cleanup());
test.beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // A y B vinculados.
    await setDoc(doc(db, "users/A/battlePartners/B"), {partnerUid: "B", status: "active"});
    await setDoc(doc(db, "users/B/battlePartners/A"), {
      partnerUid: "A", status: "active", streakDays: 3, victoryToday: true,
    });
    await setDoc(doc(db, "users/A/publicProgress/latest"), {streakDays: 3});
    // C invitó a A (vínculo pendiente en C).
    await setDoc(doc(db, "users/C/battlePartners/A"), {partnerUid: "A", status: "pending"});
    await setDoc(doc(db, "wallPosts/p1/comments/c1"), {status: "pending", body: "hola"});
    await setDoc(doc(db, "users/ADMIN"), {isAdmin: true});
  });
});

const como = (uid) => env.authenticatedContext(uid).firestore();

test("A puede liberar el vínculo en el doc de B y borrar su reflejo", async () => {
  await assertSucceeds(updateDoc(doc(como("A"), "users/B/battlePartners/A"), {
    status: "removed",
    updatedAt: serverTimestamp(),
    streakDays: deleteField(),
    victoryToday: deleteField(),
  }));
});

test("liberado, B pierde acceso al progreso de A", async () => {
  await assertSucceeds(getDoc(doc(como("B"), "users/A/publicProgress/latest")));
  await updateDoc(doc(como("A"), "users/A/battlePartners/B"), {status: "removed"});
  await assertFails(getDoc(doc(como("B"), "users/A/publicProgress/latest")));
});

test("un compañero liberado no puede reactivar el vínculo", async () => {
  await updateDoc(doc(como("A"), "users/A/battlePartners/B"), {status: "removed"});
  await assertFails(updateDoc(doc(como("B"), "users/A/battlePartners/B"), {status: "active"}));
});

test("el compañero solo refleja campos válidos (gracia con fecha)", async () => {
  const ref = doc(como("A"), "users/B/battlePartners/A");
  await assertSucceeds(updateDoc(ref, {
    dayState: "grace", dayKey: "2026-10-23", utcOffsetMin: -360, victoryToday: false,
  }));
  await assertFails(updateDoc(ref, {dayState: "otro"}));
  await assertFails(updateDoc(ref, {partnerName: "hack"}));
});

test("el invitado puede borrar el vínculo pendiente del remitente (rechazo)", async () => {
  await assertSucceeds(deleteDoc(doc(como("A"), "users/C/battlePartners/A")));
  // Pero no uno activo.
  await assertFails(deleteDoc(doc(como("A"), "users/B/battlePartners/A")));
});

test("shieldStatus: solo el dueño y con hora del servidor", async () => {
  const datos = {enabledByUser: true, vpnActive: false, lastSeenAt: serverTimestamp()};
  await assertSucceeds(setDoc(doc(como("A"), "shieldStatus/A"), datos));
  await assertFails(setDoc(doc(como("B"), "shieldStatus/A"), datos));
  await assertFails(setDoc(doc(como("A"), "shieldStatus/A"), {
    enabledByUser: true, vpnActive: true, lastSeenAt: new Date(2020, 0, 1),
  }));
  await assertFails(getDoc(doc(como("B"), "shieldStatus/A")));
});

test("accountability: solo el dueño y máximo 5 compañeros", async () => {
  await assertSucceeds(setDoc(doc(como("A"), "accountability/A"), {
    shieldAlertPartners: ["B"], weeklyEnabled: false, timezone: "America/Mexico_City",
  }));
  await assertFails(setDoc(doc(como("A"), "accountability/A"), {
    shieldAlertPartners: ["1", "2", "3", "4", "5", "6"],
  }));
  await assertFails(getDoc(doc(como("B"), "accountability/A")));
  await assertFails(getDoc(doc(como("A"), "accountabilityState/A")));
});

test("la cola de comentarios pendientes es solo para admin", async () => {
  const q = (db) => query(collectionGroup(db, "comments"), where("status", "==", "pending"));
  await assertSucceeds(getDocs(q(como("ADMIN"))));
  await assertFails(getDocs(q(como("A"))));
});
