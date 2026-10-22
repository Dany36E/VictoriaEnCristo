// Dibuja los personajes y escenas propios de la app como PNG:
//  - Jesús en los 9 estados de la racha (+ bienvenida y retrato de referencia)
//  - las 8 escenas de fondo de la racha
//  - los 20 avatares de perfil
//  - los íconos de atajos (uno por cada atajo del catálogo de AtajosService)
// Uso (Node 18+ con Playwright):  node renderizar-app.mjs [carpetaSalida]
// Para la app se recortan los márgenes transparentes y se guardan como WebP
// (Jesús a 900 px de alto, fondos a 768 px, avatares a 384 px; calidad ~88):
//   assets/vec/personajes/jesus_*.webp, avatar_*.webp · assets/vec/fondos/racha_*.webp
// Los atajos se recortan 4 px por lado y van a 240 px en assets/vec/objetos/atajo_*.webp
// y a 192 px en android/app/src/main/res/drawable-nodpi/atajo_*.webp (widget de Android).
import fs from 'node:fs';
import { chromium } from 'playwright';
import { jesusSprites, jesusRetrato } from './jesus-app.mjs';
import { fondosRacha } from './fondos-racha-app.mjs';
import { avatarItems } from './avatares-app.mjs';
import { atajosItems } from './atajos-app.mjs';

const salida = process.argv[2] || 'salida';
fs.mkdirSync(salida, { recursive: true });
const todo = [...jesusSprites, jesusRetrato, ...fondosRacha, ...avatarItems, ...atajosItems];
const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
for (const { name, svg } of todo) {
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  await page.locator('svg').screenshot({ path: `${salida}/${name}.png`, omitBackground: true });
}
await browser.close();
console.log(`listo: ${todo.length} imágenes en ${salida}/`);
