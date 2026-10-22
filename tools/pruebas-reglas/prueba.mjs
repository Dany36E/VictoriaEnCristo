// Pruebas de las reglas de Firestore y Storage (npm test). Cubren lo que
// protege el costo: cada quien escribe solo lo suyo, el reflejo del progreso
// entre compañeros y los archivos permitidos de Apuntes.

import {readFileSync} from 'node:fs';
import {initializeTestEnvironment, assertSucceeds, assertFails} from '@firebase/rules-unit-testing';
import {doc, getDoc, setDoc, updateDoc, serverTimestamp} from 'firebase/firestore';
import {ref, uploadBytes, getBytes, deleteObject} from 'firebase/storage';

const env = await initializeTestEnvironment({
  projectId: 'demo-victoria',
  // `emulators:exec` deja en el entorno dónde quedó cada emulador.
  firestore: {rules: readFileSync('../../firestore.rules', 'utf8')},
  storage: {rules: readFileSync('../../storage.rules', 'utf8')},
});
let ok = 0, mal = 0;
async function caso(nombre, fn) {
  try { await fn(); ok++; console.log('OK   ', nombre); }
  catch (e) { mal++; console.log('FALLA', nombre, '-', e.message.split('\n')[0]); }
}

await env.withSecurityRulesDisabled(async (ctx) => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/A/battlePartners/B'), {partnerUid: 'B', partnerName: 'Beto', status: 'active', addedAt: 1});
  await setDoc(doc(db, 'users/A/battlePartners/C'), {partnerUid: 'C', partnerName: 'Caro', status: 'active', addedAt: 1});
  await setDoc(doc(db, 'app_config/android'), {min_build: 1});
});

const b = env.authenticatedContext('B').firestore();
const x = env.authenticatedContext('X').firestore();
const a = env.authenticatedContext('A').firestore();
const anon = env.unauthenticatedContext().firestore();

await caso('compañero refleja su progreso', () => assertSucceeds(setDoc(doc(b, 'users/A/battlePartners/B'), {
  streakDays: 12, victoryToday: true, lastOpenedAt: serverTimestamp(), progressUpdatedAt: serverTimestamp(),
  acceptingInvites: true, sharedGiantId: 'pureza'}, {merge: true})));
await caso('compañero puede seguir pausando', () => assertSucceeds(updateDoc(doc(b, 'users/A/battlePartners/B'), {status: 'paused', updatedAt: serverTimestamp()})));
await caso('compañero NO cambia el nombre', () => assertFails(updateDoc(doc(b, 'users/A/battlePartners/B'), {partnerName: 'Otro'})));
await caso('compañero NO pone racha falsa de texto', () => assertFails(updateDoc(doc(b, 'users/A/battlePartners/B'), {streakDays: 'mucho'})));
await caso('compañero NO pone racha negativa', () => assertFails(updateDoc(doc(b, 'users/A/battlePartners/B'), {streakDays: -3})));
await caso('compañero NO toca el vínculo de otro', () => assertFails(updateDoc(doc(b, 'users/A/battlePartners/C'), {streakDays: 3})));
await caso('extraño NO escribe el reflejo', () => assertFails(updateDoc(doc(x, 'users/A/battlePartners/B'), {streakDays: 3})));
await caso('compañero NO crea vínculos', () => assertFails(setDoc(doc(b, 'users/A/battlePartners/Z'), {streakDays: 1}, {merge: true})));
await caso('dueño actualiza su vínculo', () => assertSucceeds(updateDoc(doc(a, 'users/A/battlePartners/B'), {partnerName: 'Beto G'})));
await caso('dueño guarda sus apuntes', () => assertSucceeds(setDoc(doc(a, 'users/A/sermonNotes/n1'), {title: 'x'})));
await caso('app_config se lee con sesión', () => assertSucceeds(getDoc(doc(x, 'app_config/android'))));
await caso('app_config NO se lee sin sesión', () => assertFails(getDoc(doc(anon, 'app_config/android'))));
await caso('app_config NO se escribe', () => assertFails(setDoc(doc(a, 'app_config/android'), {min_build: 99})));

const sa = env.authenticatedContext('A').storage();
const sb = env.authenticatedContext('B').storage();
const kb = (n) => new Uint8Array(n * 1024);
await caso('foto de apunte válida', () => assertSucceeds(uploadBytes(ref(sa, 'users/A/apuntes/n1/a1729560000000000.jpg'), kb(200), {contentType: 'image/jpeg'})));
await caso('dibujo de apunte válido', () => assertSucceeds(uploadBytes(ref(sa, 'users/A/apuntes/n1/a1729560000000001.svg'), kb(50), {contentType: 'image/svg+xml'})));
await caso('marcas de foto válidas', () => assertSucceeds(uploadBytes(ref(sa, 'users/A/apuntes/n1/a1729560000000000_marcas.svg'), kb(50), {contentType: 'image/svg+xml'})));
await caso('foto de más de 3 MB rechazada', () => assertFails(uploadBytes(ref(sa, 'users/A/apuntes/n1/a1729560000000002.jpg'), kb(3200), {contentType: 'image/jpeg'})));
await caso('nombre cualquiera rechazado', () => assertFails(uploadBytes(ref(sa, 'users/A/apuntes/n1/pelicula.jpg'), kb(10), {contentType: 'image/jpeg'})));
await caso('tipo cambiado rechazado', () => assertFails(uploadBytes(ref(sa, 'users/A/apuntes/n1/a1729560000000003.jpg'), kb(10), {contentType: 'video/mp4'})));
await caso('otra carpeta rechazada', () => assertFails(uploadBytes(ref(sa, 'users/A/otros/a1729560000000004.jpg'), kb(10), {contentType: 'image/jpeg'})));
await caso('carpeta ajena rechazada', () => assertFails(uploadBytes(ref(sb, 'users/A/apuntes/n1/a1729560000000005.jpg'), kb(10), {contentType: 'image/jpeg'})));
await caso('dueño lee su foto', () => assertSucceeds(getBytes(ref(sa, 'users/A/apuntes/n1/a1729560000000000.jpg'))));
await caso('otro NO lee la foto', () => assertFails(getBytes(ref(sb, 'users/A/apuntes/n1/a1729560000000000.jpg'))));
await caso('dueño borra su foto', () => assertSucceeds(deleteObject(ref(sa, 'users/A/apuntes/n1/a1729560000000000.jpg'))));

await env.cleanup();
console.log(`\n${ok} bien, ${mal} mal`);
process.exit(mal ? 1 : 0);
