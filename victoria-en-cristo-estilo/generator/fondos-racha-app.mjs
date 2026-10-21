// Fondos de racha en el estilo de las escenas del kit (parque, playa):
// cielo con degradado suave, capas de papel con bruma y sombra, contorno a lápiz
// y la textura de papel del kit encima.
import fs from 'node:fs';
import { part, circ, ell, path, capsule, pencilLines, tornStrip, svgDoc, rng, C } from './papel-recortado.mjs';
import { objetoKit } from './jesus-app.mjs';

const S = 1024;
const AZUL = '#3d6890', AZUL_CLARO = '#4f7fa8', CELESTE = '#bcd6e6', NOCHE = '#2f4a68', TERRACOTA = '#c8553d', CREMA_OSC = '#efe6d6', ROJO_OSC = '#b5392e';

const TEXTURAS = process.env.VEC_TEXTURAS || new URL('../../assets/vec/texturas/', import.meta.url).pathname;
const texturaB64 = () => fs.readFileSync(`${TEXTURAS}papel_tile_512.png`).toString('base64');

let gid = 0;
function defs(extra = '') {
  return `<defs>
  <filter id="capa" x="-5%" y="-10%" width="110%" height="120%">
    <feGaussianBlur in="SourceAlpha" stdDeviation="5"/><feOffset dy="-5" result="o"/>
    <feFlood flood-color="rgb(74,48,22)" flood-opacity="0.22"/><feComposite in2="o" operator="in"/>
    <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="bruma" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="18"/></filter>
  <pattern id="tex" width="512" height="512" patternUnits="userSpaceOnUse"><image href="data:image/png;base64,${texturaB64()}" width="512" height="512"/></pattern>
  ${extra}</defs>`;
}
const textura = (op = 0.55) => `<rect x="0" y="0" width="${S}" height="${S}" fill="url(#tex)" style="mix-blend-mode:multiply" opacity="${op}"/>`;

// Cielo: degradado vertical suave entre colores del kit + un velo de acuarela
function cielo(colores) {
  const id = `g${gid++}`;
  const stops = colores.map(([o, c]) => `<stop offset="${o}" stop-color="${c}"/>`).join('');
  return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="0" y2="1">${stops}</linearGradient></defs>
    <rect x="-40" y="-40" width="${S + 80}" height="${S + 80}" fill="url(#${id})"/>
    <g opacity="0.18">${part([path(`M-60 -60 H${S + 60} V${S + 60} H-60 Z`, colores[Math.floor(colores.length / 2)][1])], { outline: false })}</g>`;
}
// Resplandor suave (para soles, lunas, antorchas)
function brilloSuave(x, y, r, color, op = 0.55) {
  return `<g filter="url(#bruma)" opacity="${op}">${circ(x, y, r, color)}</g>`;
}
// Capa de papel: relleno liso + acuarela tenue + contorno de lápiz + sombra de capa
function capa(d, color, { op = 0.45, linea = true, sombra = true, sw = 3.2 } = {}) {
  const forma = path(d, color);
  const b = `${forma}<g filter="url(#wc)" opacity="${op}">${forma}</g>` +
    (linea ? `<g filter="url(#pen)" opacity="0.85"><path d="${d}" fill="none" stroke="${C.pencil}" stroke-width="${sw}" stroke-linejoin="round"/></g>` : '');
  return sombra ? `<g filter="url(#capa)">${b}</g>` : b;
}
const colina = (baseY, color, o = {}) => capa(tornStrip(S, S, baseY, { amp: 36, waves: 2, jag: 3, ...o }).d, color, o);
// Bruma: banda horizontal clara que separa los planos (perspectiva atmosférica)
function bruma(y, alto, color, op = 0.5) {
  return `<g filter="url(#bruma)" opacity="${op}"><rect x="-60" y="${y}" width="${S + 120}" height="${alto}" fill="${color}"/></g>`;
}
function nube(x, y, s = 1, color = C.paper, sombraColor = C.cream) {
  const c = [circ(x - 70 * s, y, 42 * s, color), circ(x - 18 * s, y - 32 * s, 56 * s, color), circ(x + 46 * s, y - 14 * s, 48 * s, color),
    circ(x + 92 * s, y + 6 * s, 32 * s, color), path(`M${x - 110 * s} ${y + 8 * s} H${x + 122 * s} V${y + 38 * s} H${x - 110 * s} Z`, color)];
  const contorno = c.map((f) => f.replace(/fill="[^"]*"/, '').replace(/\/>$/, ` fill="none" stroke="${C.pencil}" stroke-width="${6.4}" stroke-linejoin="round"/>`)).join('');
  return `<g filter="url(#capa)"><g filter="url(#pen)" opacity="0.85">${contorno}</g>${c.join('')}<g filter="url(#wc)" opacity="0.35">${c.join('')}</g>` +
    `<g opacity="0.55">${path(`M${x - 108 * s} ${y + 22 * s} Q${x} ${y + 4 * s} ${x + 120 * s} ${y + 22 * s} L${x + 120 * s} ${y + 38 * s} L${x - 108 * s} ${y + 38 * s} Z`, sombraColor)}</g>` +
    `<g opacity="0.6">${ell(x - 30 * s, y - 52 * s, 22 * s, 10 * s, '#ffffff', -10)}</g></g>`;
}
function sol(x, y, r, color = C.mustard, { rayos = 12, brillo = C.mustardLight } = {}) {
  const ds = [];
  for (let i = 0; i < rayos; i++) {
    const a = (i / rayos) * Math.PI * 2;
    ds.push(`M${x + Math.cos(a) * r * 1.25} ${y + Math.sin(a) * r * 1.25} L${x + Math.cos(a) * r * 1.6} ${y + Math.sin(a) * r * 1.6}`);
  }
  return brilloSuave(x, y, r * 2.2, brillo, 0.6) + (rayos ? pencilLines(ds, { sw: 9, color, op: 0.9 }) : '') +
    capa(`M${x - r} ${y} A${r} ${r} 0 1 1 ${x + r} ${y} A${r} ${r} 0 1 1 ${x - r} ${y} Z`, color, { sombra: false });
}
function arbol(x, y, s = 1, copa = C.sage, tronco = C.leather, luz = true) {
  const t = capa(capsule(x, y, x, y - 170 * s, 30 * s, tronco).match(/d="([^"]*)"/)[1], tronco, { sombra: false });
  const bolas = [[0, -230, 80], [-56, -180, 62], [58, -186, 64], [-18, -300, 58], [34, -268, 52]];
  const formas = bolas.map(([dx, dy, r]) => circ(x + dx * s, y + dy * s, r * s, copa));
  const contorno = formas.map((f) => f.replace(/fill="[^"]*"/, '').replace(/\/>$/, ` fill="none" stroke="${C.pencil}" stroke-width="6.4"/>`)).join('');
  return t + `<g filter="url(#capa)"><g filter="url(#pen)" opacity="0.85">${contorno}</g>${formas.join('')}<g filter="url(#wc)" opacity="0.4">${formas.join('')}</g>` +
    (luz ? `<g opacity="0.16">${circ(x - 24 * s, y - 256 * s, 30 * s, '#ffffff')}${circ(x - 62 * s, y - 196 * s, 18 * s, '#ffffff')}</g>` : '') + '</g>';
}
function pino(x, y, s, color) {
  const d = `M${x} ${y - 200 * s} L${x + 46 * s} ${y - 120 * s} L${x + 28 * s} ${y - 120 * s} L${x + 66 * s} ${y - 50 * s} L${x + 40 * s} ${y - 50 * s} L${x + 80 * s} ${y} L${x - 80 * s} ${y} L${x - 40 * s} ${y - 50 * s} L${x - 66 * s} ${y - 50 * s} L${x - 28 * s} ${y - 120 * s} L${x - 46 * s} ${y - 120 * s} Z`;
  return capa(d, color, { sombra: false, sw: 2.6 });
}
function pajaros(lista, color = C.pencil) {
  return pencilLines(lista.map(([x, y, k = 1]) => `M${x - 16 * k} ${y - 6 * k} Q${x - 8 * k} ${y - 12 * k} ${x} ${y} Q${x + 8 * k} ${y - 12 * k} ${x + 16 * k} ${y - 6 * k}`), { sw: 3.4, color, op: 0.85 });
}
function pasto(seed, y0, y1, n, color) {
  const r = rng(seed), ds = [];
  for (let i = 0; i < n; i++) {
    const x = r() * S, y = y0 + r() * (y1 - y0);
    ds.push(`M${x - 8} ${y} L${x - 12} ${y - 16}`, `M${x} ${y} L${x} ${y - 20}`, `M${x + 8} ${y} L${x + 12} ${y - 15}`);
  }
  return pencilLines(ds, { sw: 3, color, op: 0.75 });
}
function flores(seed, y0, y1, n, colores) {
  const r = rng(seed); let b = '';
  for (let i = 0; i < n; i++) {
    const x = 20 + r() * (S - 40), y = y0 + r() * (y1 - y0), c = colores[i % colores.length], k = 0.8 + r() * 0.5;
    b += part([circ(x - 8 * k, y, 8 * k, c), circ(x + 8 * k, y, 8 * k, c), circ(x, y - 8 * k, 8 * k, c), circ(x, y + 8 * k, 8 * k, c)], { outer: true, sw: 2 }) + circ(x, y, 4.5 * k, C.mustard);
  }
  return b;
}
function estrellas(seed, n, y0, y1, { kit = 0.35 } = {}) {
  const r = rng(seed); let b = '';
  for (let i = 0; i < n; i++) {
    const x = 30 + r() * (S - 60), y = y0 + r() * (y1 - y0), k = r();
    if (k < kit) b += objetoKit('star', x, y, 34 + r() * 30, -20 + r() * 40);
    else b += `<g opacity="${0.6 + r() * 0.4}">${circ(x, y, 2.5 + r() * 3, C.mustardLight)}</g>`;
  }
  return b;
}
function luna(cx, cy, r, dx, dy, r2, color) {
  const d = Math.hypot(dx, dy), a = (r * r - r2 * r2 + d * d) / (2 * d), h = Math.sqrt(r * r - a * a);
  const ux = dx / d, uy = dy / d, px = cx + ux * a, py = cy + uy * a;
  const p1 = [px - uy * h, py + ux * h], p2 = [px + uy * h, py - ux * h];
  return brilloSuave(cx, cy, r * 2.1, CELESTE, 0.28) +
    capa(`M${p1[0]} ${p1[1]} A${r} ${r} 0 1 1 ${p2[0]} ${p2[1]} A${r2} ${r2} 0 0 0 ${p1[0]} ${p1[1]} Z`, color, { sombra: false }) +
    `<g opacity="0.45">${ell(cx - r * 0.55, cy - r * 0.1, r * 0.1, r * 0.3, '#ffffff', 15)}</g>`;
}
function haces(cx, cy, angulos, color, op = 0.22, largo = 1400, ancho = 4) {
  return `<g opacity="${op}">${angulos.map((a) => {
    const r1 = ((a - ancho) * Math.PI) / 180, r2 = ((a + ancho) * Math.PI) / 180;
    return path(`M${cx} ${cy} L${cx + Math.cos(r1) * largo} ${cy + Math.sin(r1) * largo} L${cx + Math.cos(r2) * largo} ${cy + Math.sin(r2) * largo} Z`, color);
  }).join('')}</g>`;
}
function rayosCuna(cx, cy, n, color, op = 0.35, R = 1600, fase = 0) {
  const t = [];
  for (let i = 0; i < n; i++) {
    const a1 = fase + (i / n) * Math.PI * 2, a2 = fase + ((i + 0.5) / n) * Math.PI * 2;
    t.push(path(`M${cx} ${cy} L${cx + Math.cos(a1) * R} ${cy + Math.sin(a1) * R} L${cx + Math.cos(a2) * R} ${cy + Math.sin(a2) * R} Z`, color));
  }
  return `<g opacity="${op}">${t.join('')}</g>`;
}
function camino(xc, yTop, anchoTop, anchoBase, color) {
  const a = anchoTop / 2, b = anchoBase / 2;
  const d = `M${xc - a} ${yTop} C${xc - a - 20} ${yTop + 90} ${xc - b * 0.55} ${yTop + 240} ${xc - b} ${S + 40} L${xc + b} ${S + 40} C${xc + b * 0.55} ${yTop + 240} ${xc + a + 20} ${yTop + 90} ${xc + a} ${yTop} Z`;
  return capa(d, color, { sombra: false });
}
function antorcha(x, y) {
  return brilloSuave(x, y - 90, 150, C.mustardLight, 0.5) +
    capa(`M${x - 20} ${y - 40} L${x + 20} ${y - 40} L${x + 12} ${y + 120} L${x - 12} ${y + 120} Z`, C.leather, { sombra: false }) +
    capa(`M${x - 30} ${y - 54} L${x + 30} ${y - 54} L${x + 22} ${y - 30} L${x - 22} ${y - 30} Z`, C.leatherDark, { sombra: false }) +
    objetoKit('flame', x, y - 104, 74);
}
function bandera(x, y, color) {
  return capa(`M${x - 50} ${y} L${x + 50} ${y} L${x + 50} ${y + 170} L${x} ${y + 140} L${x - 50} ${y + 170} Z`, color) +
    capa(`M${x - 8} ${y + 30} H${x + 8} V${y + 54} H${x + 28} V${y + 68} H${x + 8} V${y + 110} H${x - 8} V${y + 68} H${x - 28} V${y + 54} H${x - 8} Z`, C.mustard, { sombra: false, sw: 2 }) +
    pencilLines([`M${x - 60} ${y} L${x + 60} ${y}`], { sw: 7, color: C.leatherDark, op: 1 });
}

const FONDOS = {
  // 0 días: amanece sobre un camino que empieza — «todo camino comienza con un primer paso»
  listo: () => cielo([[0, CREMA_OSC], [0.55, C.cream], [1, C.blush]]) +
    sol(780, 470, 70, C.mustard, { rayos: 12 }) +
    nube(220, 230, 0.9) + nube(800, 170, 0.7) + pajaros([[380, 300], [420, 276, 0.8], [600, 330, 0.7]]) +
    colina(560, C.sage, { seed: 3, amp: 22, waves: 1, op: 0.3 }) + bruma(520, 90, C.cream, 0.6) +
    colina(640, C.kraft, { seed: 5, amp: 22 }) +
    camino(512, 640, 36, 620, C.cream) +
    capa(capsule(150, 780, 150, 620, 18, C.leather).match(/d="([^"]*)"/)[1], C.leather, { sombra: false }) +
    capa('M96 640 L250 640 L276 666 L250 692 L96 692 Z', C.kraft) +
    pasto(3, 760, 1000, 22, C.olive) + flores(6, 820, 1000, 8, [C.paper, C.blush]),
  // 1+: pradera al amanecer
  pradera: () => cielo([[0, CELESTE], [0.62, '#e9eef0'], [1, C.mustardLight]]) +
    sol(300, 560, 90, C.mustard, { rayos: 14 }) +
    nube(780, 200, 0.9) + nube(160, 150, 0.7) + pajaros([[640, 300], [690, 330, 0.8], [600, 350, 0.7]]) +
    colina(560, C.sage, { seed: 11, amp: 26, op: 0.3 }) + bruma(520, 100, '#ffffff', 0.45) +
    arbol(120, 720, 0.9, C.sage) + arbol(930, 700, 1, C.teal) +
    colina(690, C.sage, { seed: 13 }) + colina(820, C.olive, { seed: 17, amp: 28 }) +
    pasto(4, 860, 1010, 26, '#5d6a2c') + flores(6, 840, 1010, 18, [C.paper, C.blush, C.mustardLight]),
  // 3+: cielo de la fe — haces de luz y un piso de nubes
  cielo: () => cielo([[0, AZUL_CLARO], [0.7, CELESTE], [1, '#e9eef0']]) +
    haces(512, -120, [62, 74, 86, 98, 110, 122], '#ffffff', 0.18) +
    sol(512, 130, 80, C.mustardLight, { rayos: 16 }) +
    nube(150, 170, 1.1) + nube(880, 140, 1) + pajaros([[300, 360], [340, 330, 0.8], [720, 380, 0.9]], C.paper) +
    nube(80, 560, 1, C.paper, CELESTE) + nube(960, 600, 1.1, C.paper, CELESTE) +
    nube(180, 900, 1.8, C.paper, CELESTE) + nube(820, 920, 1.9, C.paper, CELESTE) + nube(500, 980, 1.6, C.paper, CELESTE),
  // 7+: atardecer glorioso
  atardecer: () => cielo([[0, C.mustard], [0.45, C.mustardLight], [0.75, C.blush], [1, TERRACOTA]]) +
    rayosCuna(512, 720, 20, '#ffffff', 0.14) + sol(512, 690, 150, C.tomato, { rayos: 0, brillo: C.mustardLight }) +
    nube(180, 220, 0.9, C.blush, TERRACOTA) + nube(840, 160, 0.8, C.blush, TERRACOTA) + nube(820, 420, 0.55, C.blush, TERRACOTA) +
    pajaros([[260, 380], [300, 350, 0.8], [700, 300, 0.9]]) +
    colina(700, TERRACOTA, { seed: 31, amp: 24, op: 0.35 }) + bruma(660, 70, C.mustardLight, 0.4) +
    arbol(110, 860, 0.85, C.leatherDark, C.leatherDark, false) + arbol(940, 840, 0.75, C.leatherDark, C.leatherDark, false) +
    colina(800, C.kraft, { seed: 37, amp: 30 }) + colina(910, C.leather, { seed: 41, amp: 20 }),
  // 14+: noche estrellada
  noche: () => cielo([[0, C.navy], [0.6, NOCHE], [1, AZUL]]) + estrellas(41, 46, 30, 620) +
    luna(800, 200, 96, 44, -34, 84, C.mustardLight) +
    colina(640, AZUL, { seed: 43, amp: 30, op: 0.35 }) + bruma(610, 70, AZUL_CLARO, 0.3) +
    pino(110, 820, 1.1, NOCHE) + pino(210, 840, 0.8, NOCHE) + pino(900, 820, 1.2, NOCHE) +
    colina(790, C.navy, { seed: 47, amp: 26 }) +
    [[180, 700], [320, 760], [700, 720], [860, 690], [560, 800]].map(([x, y]) => `<g opacity="0.25">${circ(x, y, 16, C.mustardLight)}</g><g opacity="0.45">${circ(x, y, 9, C.mustardLight)}</g>${circ(x, y, 4, C.mustardLight)}`).join(''),
  // 30+: batalla espiritual — la luz rompe entre nubes de tormenta
  batalla: () => cielo([[0, ROJO_OSC], [0.5, TERRACOTA], [1, C.mustard]]) +
    haces(700, -80, [100, 112, 124, 136], C.mustardLight, 0.3, 1500, 3) +
    nube(160, 180, 1.2, C.tomato, ROJO_OSC) + nube(860, 140, 1.1, C.tomato, ROJO_OSC) + nube(520, 330, 0.9, TERRACOTA, ROJO_OSC) +
    colina(720, ROJO_OSC, { seed: 51, amp: 40, waves: 3, op: 0.35 }) + bruma(690, 60, C.mustard, 0.35) +
    capa('M-40 1064 L-40 820 L80 760 L180 800 L260 740 L360 820 L420 1064 Z', C.leather) +
    capa('M640 1064 L700 800 L800 740 L880 790 L960 730 L1064 780 L1064 1064 Z', C.leather) +
    colina(900, C.leatherDark, { seed: 57, amp: 24 }),
  // 100+: armadura dorada — resplandor de gloria sobre un mar de nubes
  armadura: () => cielo([[0, C.mustard], [0.55, C.mustardLight], [1, C.cream]]) +
    rayosCuna(512, 380, 28, '#ffffff', 0.22) + brilloSuave(512, 380, 300, '#ffffff', 0.55) +
    estrellas(53, 16, 40, 600, { kit: 0.6 }) +
    nube(140, 820, 1.6, C.paper, C.mustardLight) + nube(860, 800, 1.7, C.paper, C.mustardLight) + nube(520, 960, 2, C.paper, C.mustardLight),
  // 365+: guardia eterna — muralla de noche con antorchas y estandartes
  guardia: () => {
    let muro = 'M-40 1064 L-40 560';
    for (let x = -40; x < S + 40; x += 128) muro += ` L${x} 520 L${x + 64} 520 L${x + 64} 560 L${x + 128} 560`;
    muro += ` L${S + 40} 1064 Z`;
    const piedras = [];
    for (let y = 620; y < S; y += 72) for (let x = (y / 72) % 2 ? -30 : 30; x < S; x += 124) piedras.push(`M${x} ${y} H${x + 104}`, `M${x + 104} ${y} V${y + 62}`);
    return cielo([[0, C.navy], [1, NOCHE]]) + estrellas(61, 30, 30, 460) +
      luna(512, 170, 80, 38, -30, 70, C.mustardLight) +
      capa(muro, NOCHE) + pencilLines(piedras, { sw: 3, color: C.navy, op: 0.5 }) +
      bandera(250, 600, TERRACOTA) + bandera(774, 600, TERRACOTA) +
      antorcha(90, 700) + antorcha(934, 700);
  },
};

export const fondosRacha = Object.entries(FONDOS).map(([n, f], i) => {
  gid = 0;
  return { name: `racha_${n}`, svg: svgDoc(S, S, defs() + f() + textura(), 70 + i * 3, { border: 8 }) };
});
