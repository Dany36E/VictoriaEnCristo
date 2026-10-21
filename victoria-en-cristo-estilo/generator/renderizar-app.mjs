// Dibuja a Jesús (4 poses) y los 20 avatares de perfil de la app como PNG transparentes.
// Uso (Node 18+ con Playwright):  node renderizar-app.mjs [carpetaSalida]
// Luego, para la app: los avatares se reducen a 384 px y todo se guarda como WebP calidad 90
// en assets/vec/personajes/ (p. ej. `cwebp -q 90 -resize 384 384 avatar_h01.png -o avatar_h01.webp`).
import fs from 'node:fs';
import { chromium } from 'playwright';
import { jesusPoses } from './personajes-app.mjs';
import { avatarItems } from './avatares-app.mjs';

const salida = process.argv[2] || 'salida';
fs.mkdirSync(salida, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage({ deviceScaleFactor: 1 });
for (const { name, svg } of [...jesusPoses, ...avatarItems]) {
  await page.setContent(`<html><body style="margin:0;background:transparent">${svg}</body></html>`);
  await page.locator('svg').screenshot({ path: `${salida}/${name}.png`, omitBackground: true });
}
await browser.close();
console.log(`listo: ${jesusPoses.length + avatarItems.length} imágenes en ${salida}/`);
