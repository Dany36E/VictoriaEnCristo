// Jesús «papel recortado» v2 (según la referencia: pelo ondulado con raya al
// centro, cejas gruesas, barba con la boca descubierta, cuello, túnica blanca
// con escote redondo y banda roja sobre el hombro). Sprites por estado de racha.
import fs from 'node:fs';
import { part, circ, ell, path, capsule, pencilLines, svgDoc, rng, C } from './papel-recortado.mjs';

// Objetos del kit (assets/vec/objetos) para no inventar corazón, Biblia ni estrella.
const OBJETOS = process.env.VEC_OBJETOS || new URL('../../assets/vec/objetos/', import.meta.url).pathname;
const cacheObjetos = {};
export function objetoKit(nombre, x, y, ancho, rot = 0) {
  if (!cacheObjetos[nombre]) {
    const buf = fs.readFileSync(`${OBJETOS}${nombre}.png`);
    cacheObjetos[nombre] = { b64: buf.toString('base64'), w: buf.readUInt32BE(16), h: buf.readUInt32BE(20) };
  }
  const { b64, w, h } = cacheObjetos[nombre];
  const alto = (ancho * h) / w;
  return `<g transform="translate(${x} ${y}) rotate(${rot})"><image href="data:image/png;base64,${b64}" x="${-ancho / 2}" y="${-alto / 2}" width="${ancho}" height="${alto}"/></g>`;
}
const brillo = (x, y, rx, ry, rot = 0, op = 0.5) => `<g opacity="${op}">${ell(x, y, rx, ry, '#ffffff', rot)}</g>`;
const resplandor = (x, y, r, color = C.mustardLight) =>
  [[1.6, 0.14], [1.32, 0.2], [1.1, 0.28]].map(([k, op]) => `<g opacity="${op}">${circ(x, y, r * k, color)}</g>`).join('');

const sticker = (b) => `<g filter="url(#sticker)">${b}</g>`;
const T = (x, y, s, b, rot = 0) => `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${s})">${b}</g>`;

export const J = {
  piel: '#eeb07c',
  pelo: C.leatherDark,   // #6a4128
  ceja: C.leather,       // #8a5a36
  nariz: '#a8643c',
  banda: '#b5392e',
  bandaRaya: C.tomato,
  azulLagrima: '#bcd6e6',
};

// Parte blanca: base lisa + acuarela tenue (si no, el moteado la vuelve gris).
export function parteBlanca(shapes, { outer = false, op = 0.55, sw = 3.4 } = {}) {
  const base = shapes.map((x) => x.replace(/fill="[^"]*"/, `fill="${C.paper}"`)).join('');
  const crema = shapes.map((x) => x.replace(/fill="[^"]*"/, `fill="${C.cream}"`)).join('');
  const trazo = (w) => `<g filter="url(#pen)" opacity="0.92">${shapes.map((x) => x
    .replace(/fill="[^"]*"/g, '')
    .replace(/\/>$/, ` fill="none" stroke="${C.pencil}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"/>`)).join('')}</g>`;
  const relleno = `${base}<g filter="url(#wc)" opacity="${op}">${crema}</g>`;
  return outer ? trazo(sw * 2) + relleno : relleno + trazo(sw);
}

// ---------------- Cabeza (cara centrada en 0,0; cara 100x106) ----------------
// o: { ojos: 'abiertos'|'felices'|'cerrados', boca: 'sonrisa'|'abierta'|'suave', triste, lagrima }
export function cabezaJesus(o = {}) {
  const h = J.pelo;
  // Silueta medida de la referencia: cúpula angosta arriba, más ancha a la
  // altura de las mejillas y con ondas al caer sobre los hombros.
  const lado = (k) => `C${30 * k} -162 ${60 * k} -154 ${79 * k} -128 C${96 * k} -106 ${106 * k} -86 ${111 * k} -60 ` +
    `C${116 * k} -34 ${125 * k} -6 ${130 * k} 20 C${136 * k} 42 ${130 * k} 60 ${121 * k} 72 ` +
    `C${130 * k} 90 ${127 * k} 108 ${118 * k} 118 C${123 * k} 132 ${114 * k} 144 ${100 * k} 140 ` +
    `C${92 * k} 148 ${81 * k} 146 ${76 * k} 136 L${72 * k} 60`;
  const atras = part([path(`M0 -160 ${lado(1)} L0 60 Z`, h), path(`M0 -160 ${lado(-1)} L0 60 Z`, h)], { outer: true }) +
    pencilLines(['M-108 -40 C-116 -6 -112 30 -122 60', 'M108 -40 C116 -6 112 30 122 60',
      'M-110 72 C-118 94 -108 112 -112 128', 'M110 72 C118 94 108 112 112 128'], { sw: 2.4, color: C.hair, op: 0.5 });

  const cara = part([ell(-100, 26, 15, 22, J.piel), ell(100, 26, 15, 22, J.piel)]) + part([ell(0, 0, 100, 106, J.piel)]);

  // cejas gruesas en media luna
  const ceja = (k) => o.triste
    ? `M${-80 * k} -30 C${-72 * k} -42 ${-52 * k} -50 ${-34 * k} -56 C${-32 * k} -50 ${-34 * k} -46 ${-38 * k} -44 C${-54 * k} -40 ${-68 * k} -34 ${-78 * k} -24 Z`
    : `M${-82 * k} -34 C${-74 * k} -54 ${-50 * k} -60 ${-32 * k} -48 C${-32 * k} -42 ${-36 * k} -40 ${-40 * k} -41 C${-54 * k} -47 ${-70 * k} -44 ${-80 * k} -28 Z`;
  const cejas = part([path(ceja(1), J.ceja), path(ceja(-1), J.ceja)], { sw: 3 });

  let ojos;
  if (o.ojos === 'felices') {
    ojos = pencilLines(['M-57 -4 Q-44 -18 -31 -4', 'M31 -4 Q44 -18 57 -4'], { sw: 5, color: C.ink, op: 1 });
  } else if (o.ojos === 'cerrados') {
    ojos = pencilLines(['M-57 -10 Q-44 0 -31 -10', 'M31 -10 Q44 0 57 -10'], { sw: 4.6, color: C.ink, op: 1 });
  } else {
    ojos = ell(-44, -8, 9.5, 12, C.ink) + ell(44, -8, 9.5, 12, C.ink) + circ(-40.5, -12.5, 3.4, '#ffffff') + circ(47.5, -12.5, 3.4, '#ffffff');
  }
  const nariz = pencilLines(['M-6 8 Q-17 34 -13 41 Q-4 48 10 43'], { sw: 3.8, color: J.nariz, op: 0.95 });
  const rubor = `<g opacity="0.62">${ell(-66, 26, 17, 12, C.blush)}${ell(66, 26, 17, 12, C.blush)}</g>`;

  const barba = part([path('M-99 -6 C-102 70 -60 136 0 138 C60 136 102 70 99 -6 L90 -6 C88 24 72 46 48 58 L-48 58 C-72 46 -88 24 -90 -6 Z', h)]) +
    pencilLines(['M-74 60 C-70 92 -52 114 -30 124', 'M74 60 C70 92 52 114 30 124', 'M0 112 L0 128'], { sw: 2.2, color: C.hair, op: 0.45 });
  const zonaBoca = part([path('M-34 64 C-38 90 -22 102 -10 102 C-8 111 8 111 10 102 C22 102 38 90 34 64 Z', J.piel)], { sw: 3 });
  const bigote = part([path('M-54 72 C-44 52 -16 52 0 61 C16 52 44 52 54 72 C40 76 16 74 0 72 C-16 74 -40 76 -54 72 Z', h)], { sw: 3 });
  let boca;
  if (o.boca === 'abierta') {
    boca = part([path('M-21 79 Q0 104 21 79 Q0 85 -21 79 Z', '#8e2f28')], { sw: 2.6 }) + path('M-15 81.5 Q0 85.5 15 81.5 L13.5 86 Q0 89 -13.5 86 Z', '#fbf7ee');
  } else if (o.boca === 'suave') {
    boca = pencilLines(['M-14 87 Q0 83 14 87'], { sw: 4, color: C.ink, op: 0.9 });
  } else {
    boca = pencilLines(['M-19 82 Q0 95 19 82'], { sw: 4.4, color: C.ink, op: 0.95 });
  }
  const lagrima = o.lagrima ? part([path('M-50 8 C-43 22 -41 29 -50 35 C-59 29 -57 22 -50 8 Z', J.azulLagrima)], { sw: 2.2 }) : '';

  // mechones sobre la frente: sin contorno exterior (si no parece capucha);
  // solo la línea del nacimiento del pelo, el rizo junto a la oreja y hebras
  const mechon = (k) => `M0 -152 C${-30 * k} -154 ${-58 * k} -146 ${-76 * k} -124 C${-94 * k} -102 ${-104 * k} -70 ${-110 * k} -34 ` +
    `C${-114 * k} -8 ${-114 * k} 10 ${-112 * k} 16 C${-108 * k} 28 ${-104 * k} 30 ${-100 * k} 22 ` +
    `C${-100 * k} -12 ${-92 * k} -50 ${-72 * k} -78 C${-52 * k} -102 ${-24 * k} -108 ${-1 * k} -106 Z`;
  const frente = part([path(mechon(1), h), path(mechon(-1), h)], { outline: false }) +
    pencilLines(['M-112 14 C-108 28 -104 30 -100 22 C-100 -12 -92 -50 -72 -78 C-52 -102 -24 -108 0 -106 C24 -108 52 -102 72 -78 C92 -50 100 -12 100 22 C104 30 108 28 112 14', 'M0 -152 L0 -110'], { sw: 3.4, color: C.pencil, op: 0.92 }) +
    pencilLines(['M-10 -146 C-44 -140 -78 -108 -94 -50 C-98 -28 -100 -8 -106 8', 'M10 -146 C44 -140 78 -108 94 -50 C98 -28 100 -8 106 8',
      'M-26 -152 C-56 -144 -86 -114 -102 -62', 'M26 -152 C56 -144 86 -114 102 -62'], { sw: 2.4, color: C.hair, op: 0.5 });

  return atras + cara + rubor + cejas + ojos + nariz + lagrima + barba + zonaBoca + bigote + boca + frente;
}

// ---------------- Accesorios ----------------
// Estrella del kit (star.png), girada y a varios tamaños.
export function estrellita(x, y, r = 14, rot = 0) {
  return objetoKit('star', x, y, r * 3.6, rot);
}
// Corazón del kit (heart_clean.png)
export function corazonKit(x, y, ancho, rot = 0) {
  return objetoKit('heart_clean', x, y, ancho, rot);
}
export function corona(x, y, s = 1, rot = -6) {
  const puntas = [[-76, -26], [-30, -38], [0, -50], [30, -38], [76, -26]];
  return T(x, y, s, part([path('M-66 28 L-76 -22 L-44 6 L-30 -34 L-12 2 L0 -46 L12 2 L30 -34 L44 6 L76 -22 L66 28 Z', C.mustard)], { sw: 3.2 }) +
    part(puntas.map(([px, py]) => circ(px, py, 9, C.mustardLight)), { sw: 2.4 }) +
    part([path('M-70 10 Q0 22 70 10 L67 30 Q0 42 -67 30 Z', C.mustardLight)], { sw: 2.6 }) +
    part([ell(0, 21, 10, 8, C.tomato), circ(-36, 19, 6.5, C.teal), circ(36, 19, 6.5, C.teal)], { sw: 2 }) +
    brillo(-46, -2, 5, 14, 18, 0.55) + brillo(-3, 18, 3, 2, 0, 0.7), rot);
}
export function paloma(x, y, s = 1, voltear = false, rama = false) {
  const cola = path('M-52 4 C-70 -6 -88 -14 -104 -12 C-100 -2 -104 8 -100 14 C-104 20 -100 30 -96 34 C-80 30 -64 24 -50 18 Z', 'x');
  const cuerpo = path('M-58 8 C-50 -20 -12 -28 18 -22 C30 -42 62 -44 76 -24 C84 -12 80 2 68 8 C56 30 18 42 -14 38 C-40 34 -60 24 -58 8 Z', 'x');
  const ala = path('M-26 0 C-18 -40 14 -72 54 -78 C48 -66 46 -58 52 -50 C40 -48 36 -40 40 -32 C28 -32 22 -24 24 -16 C10 -14 -6 -8 -26 0 Z', 'x');
  let b = '';
  if (rama) {
    b += pencilLines(['M86 -14 C98 -8 112 -2 128 0'], { sw: 3.4, color: C.leather, op: 1 }) +
      part([ell(102, -16, 11, 5, C.sage, -30), ell(116, -6, 11, 5, C.sage, 25), ell(122, 6, 10, 4.5, C.sage, -10)], { sw: 1.8 });
  }
  b += parteBlanca([cola, cuerpo], { outer: true }) +
    `<g opacity="0.45">${part([path('M-44 26 C-10 38 30 34 58 14 C42 32 10 42 -14 38 C-30 36 -42 32 -44 26 Z', C.cream)], { outline: false })}</g>` +
    pencilLines(['M-98 0 L-62 7', 'M-98 22 L-60 15'], { sw: 2, color: '#b9ab96', op: 0.85 }) +
    part([path('M76 -24 L97 -16 L76 -10 Z', C.mustard)], { sw: 2.2 }) +
    circ(60, -26, 4.6, C.ink) + circ(61.6, -27.6, 1.5, '#ffffff') +
    `<g opacity="0.55">${ell(62, -12, 7, 4.5, C.blush)}</g>` +
    parteBlanca([ala], { sw: 3 }) +
    pencilLines(['M-8 -10 C8 -30 26 -48 46 -62', 'M4 -8 C18 -22 30 -34 44 -44', 'M14 -12 C22 -18 30 -24 38 -28'], { sw: 2, color: '#b9ab96', op: 0.85 });
  return T(x, y, s, voltear ? `<g transform="scale(-1 1)">${b}</g>` : b);
}
export function espada(x, y, s = 1, rot = 0) {
  // mango en (0,0), hoja hacia arriba
  return T(x, y, s, part([path('M-15 -40 L-15 -262 L0 -296 L15 -262 L15 -40 Z', C.steelLight)], { sw: 3 }) +
    `<g opacity="0.6">${path('M-9 -52 L-9 -258 L-2 -280 L-2 -52 Z', '#ffffff')}</g>` +
    pencilLines(['M5 -62 L5 -250'], { sw: 2.6, color: C.steel, op: 0.9 }) +
    part([path('M-64 -50 C-52 -36 -22 -34 0 -40 C22 -34 52 -36 64 -50 C68 -36 62 -22 48 -20 L-48 -20 C-62 -22 -68 -36 -64 -50 Z', C.mustard)], { sw: 2.8 }) +
    part([circ(0, -32, 8, C.tomato)], { sw: 2 }) + brillo(-30, -36, 12, 3.5, 0, 0.5) +
    part([capsule(0, -18, 0, 34, 20, C.leatherDark)], { sw: 2.6 }) +
    pencilLines(['M-9 -8 L9 -2', 'M-9 6 L9 12', 'M-9 20 L9 26'], { sw: 2.4, color: C.mustard, op: 0.9 }) +
    part([circ(0, 48, 15, C.mustard)], { sw: 2.6 }) + brillo(-5, 43, 4, 3, 0, 0.6), rot);
}
export function escudo(x, y, s = 1, rot = 0) {
  const remaches = [[-74, -84], [74, -84], [-66, 10], [66, 10], [0, 96]];
  return T(x, y, s, part([path('M-88 -98 L88 -98 C90 10 62 74 0 112 C-62 74 -90 10 -88 -98 Z', C.mustard)], { sw: 3.4 }) +
    part([path('M-72 -82 L72 -82 C74 4 50 60 0 92 C-50 60 -74 4 -72 -82 Z', '#3d6890')], { sw: 2.6 }) +
    part([path('M-11 -68 H11 V-24 H48 V-2 H11 V72 H-11 V-2 H-48 V-24 H-11 Z', C.mustardLight)], { sw: 2.4 }) +
    part(remaches.map(([rx, ry]) => circ(rx, ry, 5.5, C.mustardLight)), { sw: 1.8 }) +
    brillo(-44, -46, 10, 28, 18, 0.35), rot);
}
export function cordero(x, y, s = 1) {
  const lana = [];
  for (let i = 0; i < 16; i++) {
    const a = (i / 16) * Math.PI * 2;
    lana.push(circ((Math.cos(a) * 96).toFixed(1), (Math.sin(a) * 54).toFixed(1), 26, 'x'));
  }
  lana.push(ell(0, 0, 98, 56, 'x'));
  const r = rng(9), rizos = [];
  for (let i = 0; i < 14; i++) {
    const rx = -70 + r() * 130, ry = -30 + r() * 60;
    rizos.push(`M${rx.toFixed(1)} ${ry.toFixed(1)} a9 9 0 1 1 13 5`);
  }
  return T(x, y, s,
    part([capsule(-56, 40, -58, 84, 22, C.leatherDark), capsule(-18, 46, -18, 88, 22, C.leatherDark), capsule(28, 46, 30, 86, 22, C.leatherDark), capsule(62, 40, 66, 80, 22, C.leatherDark)], { sw: 2.4 }) +
    parteBlanca(lana, { outer: true, op: 0.45 }) +
    pencilLines(rizos, { sw: 2.2, color: '#c9bba5', op: 0.9 }) +
    part([ell(76, -46, 22, 11, C.cream, -28), ell(140, -50, 22, 11, C.cream, 28)], { sw: 2.4 }) +
    `<g opacity="0.7">${ell(76, -46, 13, 5.5, C.blush, -28)}${ell(140, -50, 13, 5.5, C.blush, 28)}</g>` +
    part([ell(108, -16, 34, 40, C.cream)], { sw: 3 }) +
    parteBlanca([circ(108, -56, 18, 'x'), circ(92, -50, 13, 'x'), circ(124, -50, 13, 'x')], { outer: true }) +
    pencilLines(['M94 -16 Q100 -9 106 -16', 'M110 -16 Q116 -9 122 -16'], { sw: 3, color: C.ink, op: 1 }) +
    part([ell(108, 4, 7, 5, C.blush)], { sw: 1.8 }) + pencilLines(['M102 12 Q108 17 114 12'], { sw: 2.2, color: C.ink, op: 0.9 }) +
    `<g opacity="0.6">${ell(88, -2, 8, 5, C.blush)}${ell(128, -2, 8, 5, C.blush)}</g>`);
}
function aureola(x, y, r, { rayos = false } = {}) {
  let b = '';
  if (rayos) {
    const largos = [], cortos = [];
    for (let i = 0; i < 20; i++) {
      const a = (i / 20) * Math.PI * 2, R1 = r * 1.08, R2 = i % 2 ? r * 1.42 : r * 1.68;
      (i % 2 ? cortos : largos).push(capsule(x + Math.cos(a) * R1, y + Math.sin(a) * R1, x + Math.cos(a) * R2, y + Math.sin(a) * R2, i % 2 ? 16 : 20, i % 2 ? C.mustardLight : C.mustard));
    }
    b += part(largos, { sw: 2.4 }) + part(cortos, { sw: 2.2 });
  }
  b += part([circ(x, y, r, C.mustardLight)], { sw: 3 }) +
    `<g opacity="0.3">${part([circ(x, y, r * 0.8, C.mustard)], { outline: false })}</g>` +
    `<g opacity="0.45">${path(`M${x - r * 0.78} ${y - r * 0.2} A${r * 0.8} ${r * 0.8} 0 0 1 ${x - r * 0.1} ${y - r * 0.8} L${x - r * 0.12} ${y - r * 0.68} A${r * 0.68} ${r * 0.68} 0 0 0 ${x - r * 0.66} ${y - r * 0.16} Z`, '#ffffff')}</g>`;
  return resplandor(x, y, r) + sticker(b);
}
function nubecita(x, y, s = 1) {
  return T(x, y, s, parteBlanca([circ(-40, 6, 30, 'x'), circ(-6, -14, 38, 'x'), circ(34, 0, 32, 'x'), circ(60, 14, 22, 'x'), path('M-70 14 H80 V36 H-70 Z', 'x')], { outer: true }) +
    `<g opacity="0.4">${part([path('M-64 26 Q0 40 74 26 L74 34 L-64 34 Z', C.cream)], { outline: false })}</g>`);
}
function arcoiris(x, y, r) {
  const colores = [C.tomato, C.mustard, C.sage, '#bcd6e6'];
  const ancho = 30;
  const anillos = colores.map((c, i) => {
    const R = r - i * ancho, r2 = R - ancho;
    return path(`M${x - R} ${y} A${R} ${R} 0 0 1 ${x + R} ${y} L${x + r2} ${y} A${r2} ${r2} 0 0 0 ${x - r2} ${y} Z`, c);
  });
  const dentro = r - colores.length * ancho;
  return sticker(part(anillos, { sw: 2.6 }) +
    `<g opacity="0.35">${path(`M${x - r + 8} ${y} A${r - 8} ${r - 8} 0 0 1 ${x + r - 8} ${y} L${x + r - 14} ${y} A${r - 14} ${r - 14} 0 0 0 ${x - r + 14} ${y} Z`, '#ffffff')}</g>` +
    nubecita(x - (r + dentro) / 2, y, 1.1) + nubecita(x + (r + dentro) / 2, y, 1.1));
}

// ---------------- Cuerpo ----------------
function brazo(hombro, codo, muneca, { ancho = 62, mano = 28, sinMano = false } = {}) {
  const dx = muneca[0] - codo[0], dy = muneca[1] - codo[1], L = Math.hypot(dx, dy);
  const ux = dx / L, uy = dy / L, nx = -uy, ny = ux;
  const mx = muneca[0] + ux * 32, my = muneca[1] + uy * 32;
  const w2 = ancho * 0.62;
  const campana = path(`M${codo[0] + nx * ancho * 0.45} ${codo[1] + ny * ancho * 0.45} L${muneca[0] + nx * w2} ${muneca[1] + ny * w2} L${muneca[0] - nx * w2} ${muneca[1] - ny * w2} L${codo[0] - nx * ancho * 0.45} ${codo[1] - ny * ancho * 0.45} Z`, 'x');
  let manoSvg = '';
  if (!sinMano) {
    // Mano = solo la bolita (sin dedos), como los personajes del kit.
    manoSvg = part([circ(mx.toFixed(1), my.toFixed(1), mano, J.piel)]);
  }
  return sticker(manoSvg +
    parteBlanca([capsule(...hombro, ...codo, ancho, 'x'), capsule(...codo, ...muneca, ancho * 0.9, 'x'), campana], { outer: true }) +
    pencilLines([`M${codo[0] + nx * ancho * 0.3} ${codo[1] + ny * ancho * 0.3} Q${(codo[0] + muneca[0]) / 2} ${(codo[1] + muneca[1]) / 2} ${muneca[0] + nx * w2 * 0.6} ${muneca[1] + ny * w2 * 0.6}`], { sw: 2.2, color: '#b9ab96', op: 0.6 }));
}

function pies(cx) {
  return sticker(
    part([ell(cx - 54, 1004, 50, 14, C.leather), ell(cx + 54, 1004, 50, 14, C.leather)], { sw: 3 }) +
    part([ell(cx - 52, 986, 42, 22, J.piel), ell(cx + 52, 986, 42, 22, J.piel)], { sw: 3 }) +
    pencilLines([`M${cx - 88} 982 Q${cx - 54} 968 ${cx - 18} 982`, `M${cx + 18} 982 Q${cx + 54} 968 ${cx + 88} 982`, `M${cx - 52} 972 L${cx - 52} 998`, `M${cx + 52} 972 L${cx + 52} 998`], { sw: 7, color: C.leatherDark, op: 0.95 }));
}

function torso(cx, { armadura = false } = {}) {
  const t = `M${cx - 54} 398 C${cx - 104} 394 ${cx - 142} 408 ${cx - 150} 456 L${cx - 160} 950 Q${cx} 968 ${cx + 160} 950 L${cx + 150} 456 C${cx + 142} 408 ${cx + 104} 394 ${cx + 54} 398 Q${cx} 448 ${cx - 54} 398 Z`;
  let b = part([path(`M${cx - 48} 290 L${cx + 48} 290 L${cx + 50} 460 L${cx - 50} 460 Z`, J.piel)]) +
    parteBlanca([path(t, 'x')]) +
    pencilLines([`M${cx - 62} 408 Q${cx} 466 ${cx + 62} 408`], { sw: 2.6, color: C.pencil, op: 0.7 }) +
    pencilLines([`M${cx - 44} 450 L${cx - 54} 940`, `M${cx + 40} 640 L${cx + 48} 944`, `M${cx - 100} 640 L${cx - 112} 940`], { sw: 2.4, color: '#b9ab96', op: 0.65 });
  // banda roja: del hombro derecho (del espectador) a la cadera izquierda
  b += part([path(`M${cx + 44} 402 L${cx + 122} 410 L${cx - 152} 740 L${cx - 154} 650 Z`, J.banda)], { sw: 3 }) +
    pencilLines([`M${cx + 100} 410 L${cx - 152} 712`], { sw: 7, color: J.bandaRaya, op: 0.95 }) +
    part([path(`M${cx - 156} 690 L${cx - 118} 712 L${cx - 126} 870 Q${cx - 142} 880 ${cx - 160} 868 Z`, J.banda)], { sw: 3 }) +
    pencilLines([`M${cx - 137} 712 L${cx - 141} 866`], { sw: 5, color: J.bandaRaya, op: 0.9 });
  if (armadura) {
    const tiras = [];
    for (let i = 0; i < 6; i++) {
      const x0 = cx - 118 + i * 40;
      tiras.push(path(`M${x0} 682 L${x0 + 34} 682 L${x0 + 32} 758 Q${x0 + 17} 766 ${x0 + 2} 758 Z`, C.leather));
    }
    b += part(tiras, { sw: 2.4 }) +
      pencilLines(tiras.map((_, i) => `M${cx - 118 + i * 40 + 6} 746 L${cx - 118 + i * 40 + 28} 746`), { sw: 4, color: C.mustard, op: 0.95 }) +
      part([path(`M${cx - 132} 472 C${cx - 108} 442 ${cx - 70} 444 ${cx - 50} 450 Q${cx} 494 ${cx + 50} 450 C${cx + 70} 444 ${cx + 108} 442 ${cx + 132} 472 L${cx + 120} 664 C${cx + 70} 690 ${cx - 70} 690 ${cx - 120} 664 Z`, C.mustard)], { sw: 3.2 }) +
      pencilLines([`M${cx - 52} 456 Q${cx} 504 ${cx + 52} 456`], { sw: 12, color: C.mustardLight, op: 1 }) +
      pencilLines([`M${cx} 508 L${cx} 650`, `M${cx - 96} 530 Q${cx - 60} 590 ${cx - 70} 640`, `M${cx + 96} 530 Q${cx + 60} 590 ${cx + 70} 640`], { sw: 2.6, color: C.leather, op: 0.6 }) +
      brillo(cx - 70, 540, 18, 46, 12, 0.35) +
      part([capsule(cx - 124, 672, cx + 124, 672, 26, C.leatherDark)], { sw: 2.6 }) +
      part([path(`M${cx - 18} 658 H${cx + 18} V686 H${cx - 18} Z`, C.mustard)], { sw: 2.4 }) +
      part([path(`M${cx - 9} 520 H${cx + 9} V542 H${cx + 30} V558 H${cx + 9} V600 H${cx - 9} V558 H${cx - 30} V542 H${cx - 9} Z`, C.mustardLight)], { sw: 2.2 });
  }
  return sticker(b);
}
// Hombrera de dos placas con remaches (va encima del hombro, sobre la manga)
function hombrera(x, y, s = 1, rot = 0) {
  return sticker(T(x, y, s, part([path('M-62 46 C-60 18 60 18 62 46 C30 36 -30 36 -62 46 Z', C.mustardLight)], { sw: 2.6 }) +
    part([path('M-70 28 C-68 -42 68 -42 70 28 C36 14 -36 14 -70 28 Z', C.mustard)], { sw: 3 }) +
    part([circ(-46, 14, 5, C.mustardLight), circ(0, 4, 5, C.mustardLight), circ(46, 14, 5, C.mustardLight)], { sw: 1.8 }) +
    brillo(-26, -12, 16, 6, -12, 0.45), rot));
}
// Manos juntas para orar: dos bolitas unidas (sin dedos)
function manosOrando(x, y) {
  return sticker(part([circ(x - 17, y, 27, J.piel), circ(x + 17, y, 27, J.piel)], { outer: true }));
}

// ---------------- Poses ----------------
const CX = 400, HY = 215, HS = 1.22;
const H = (o) => sticker(T(CX, HY, HS, cabezaJesus(o)));
const HI = [CX - 136, 456], HD = [CX + 136, 456];   // hombros (izq./der. del espectador)

const POSES = {
  // Usuario nuevo: con un corderito en brazos
  nuevo: () => pies(CX) + torso(CX) + H({ ojos: 'felices', boca: 'abierta' }) +
    brazo(HI, [CX - 150, 620], [CX - 70, 690], { sinMano: true }) + brazo(HD, [CX + 156, 610], [CX + 90, 676], { sinMano: true }) +
    sticker(`<g transform="translate(${CX} 606) scale(-1 1)">${cordero(0, 0, 1)}</g>`) +
    sticker(part([circ(CX - 52, 700, 28, J.piel), circ(CX + 106, 680, 28, J.piel)])) +
    estrellita(CX - 236, 250, 16, -12) + estrellita(CX + 226, 190, 12, 14),
  // Alegre bienvenida: brazos abiertos
  bienvenida: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'abierta' }) +
    brazo(HI, [CX - 206, 560], [CX - 274, 512]) + brazo(HD, [CX + 206, 560], [CX + 274, 512]) +
    estrellita(CX - 250, 300, 16, -10) + estrellita(CX + 260, 280, 14, 12) + estrellita(CX + 200, 150, 10, -6),
  // Esperando: ora con los ojos cerrados, una paloma cerca
  esperando: () => pies(CX) + torso(CX) + H({ ojos: 'cerrados', boca: 'sonrisa' }) +
    brazo(HI, [CX - 128, 640], [CX - 34, 584], { sinMano: true }) + brazo(HD, [CX + 128, 640], [CX + 34, 584], { sinMano: true }) +
    manosOrando(CX, 560) + sticker(paloma(CX + 250, 320, 1.3, true, true)) + estrellita(CX - 226, 220, 13, -10),
  // Ánimo: sostiene un corazón que brilla
  animo: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'sonrisa' }) +
    resplandor(CX, 596, 80) + corazonKit(CX, 596, 190, -4) +
    brazo(HI, [CX - 142, 660], [CX - 82, 650]) + brazo(HD, [CX + 142, 660], [CX + 82, 650]) +
    corazonKit(CX - 232, 236, 70, -14) + corazonKit(CX + 240, 316, 58, 12) + corazonKit(CX + 200, 120, 46, -6),
  // Racha perdida: compasivo, con una lágrima y los brazos abiertos hacia abajo
  perdida: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'suave', triste: true, lagrima: true }) +
    brazo(HI, [CX - 182, 600], [CX - 250, 640]) + brazo(HD, [CX + 182, 600], [CX + 250, 640]),
  // Victoria del día: mano en alto (solo la bolita), mano en el corazón y corona
  victoria: () => sticker(corona(CX, 6, 0.95)) + pies(CX) + torso(CX) + H({ ojos: 'felices', boca: 'abierta' }) +
    brazo(HI, [CX - 214, 430], [CX - 224, 304]) + brazo(HD, [CX + 150, 620], [CX + 46, 560]) +
    estrellita(CX + 236, 236, 16, 12) + estrellita(CX - 300, 190, 12, -14) + estrellita(CX + 170, 56, 11, 8),
  // Primera semana: paloma con ramita en la mano, mano en el corazón y corona
  semana: () => sticker(corona(CX, 6, 0.95, 6)) + pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'sonrisa' }) +
    brazo(HI, [CX - 200, 590], [CX - 262, 520]) + brazo(HD, [CX + 150, 620], [CX + 46, 560]) +
    sticker(paloma(CX - 300, 430, 1.2, false, true)) + estrellita(CX + 236, 246, 14, 10) + estrellita(CX + 176, 84, 11, -8),
  // Un mes: hombrera dorada, mano en alto y la Biblia contra el pecho
  mes: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'abierta' }) +
    brazo(HI, [CX - 214, 430], [CX - 224, 304]) +
    brazo(HD, [CX + 170, 640], [CX + 104, 650], { sinMano: true }) + objetoKit('bible_closed', CX + 44, 610, 210, -8) +
    sticker(part([circ(CX + 128, 640, 28, J.piel)])) +
    estrellita(CX + 246, 300, 14, 10) + estrellita(CX - 300, 190, 12, -12) + estrellita(CX + 150, 56, 11, 6),
  // Centurión de la fe: armadura, espada en alto y escudo
  centurion: () => aureola(CX, HY - 24, 196, { rayos: true }) + pies(CX) + torso(CX, { armadura: true }) +
    H({ ojos: 'abiertos', boca: 'abierta' }) +
    sticker(espada(CX - 230, 300, 1.2, -6)) + brazo(HI, [CX - 216, 440], [CX - 228, 326]) + hombrera(HI[0] - 2, HI[1] + 4, 1.2, -14) +
    brazo(HD, [CX + 178, 620], [CX + 200, 600], { sinMano: true }) + sticker(escudo(CX + 214, 640, 0.95, 4)) + hombrera(HD[0] + 2, HD[1] + 4, 1.2, 14),
  // Un año glorioso: arcoíris, aureola con rayos, brazos abiertos y paloma
  anio: () => arcoiris(CX, 500, 352) + aureola(CX, HY - 24, 186, { rayos: true }) + pies(CX) + torso(CX) +
    H({ ojos: 'felices', boca: 'abierta' }) +
    brazo(HI, [CX - 210, 540], [CX - 276, 470]) + brazo(HD, [CX + 210, 540], [CX + 276, 470]) +
    sticker(paloma(CX + 312, 396, 1.15, true, true)) + estrellita(CX - 316, 296, 15, -12) + estrellita(CX - 250, 110, 12, 10) + estrellita(CX + 260, 96, 13, -8),
};

export const jesusSprites = Object.entries(POSES).map(([n, f]) => ({
  name: `jesus_${n}`,
  svg: svgDoc(800, 1200, `<g transform="translate(0 170)">${f()}</g>`, 41, { border: 10 }),
}));

// Retrato (como la referencia): busto en círculo mostaza
export const jesusRetrato = {
  name: 'jesus_retrato',
  svg: svgDoc(800, 800, `<circle cx="400" cy="400" r="370" fill="${C.mustard}"/>
    <defs><clipPath id="disco"><circle cx="400" cy="400" r="370"/></clipPath></defs>
    <g clip-path="url(#disco)"><g transform="translate(0 150)">${torso(CX)}${brazo(HI, [CX - 168, 640], [CX - 176, 760])}${brazo(HD, [CX + 168, 640], [CX + 176, 760])}${H({ ojos: 'abiertos', boca: 'sonrisa' })}</g></g>`, 41, { border: 10 }),
};
