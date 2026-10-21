// Jesús «papel recortado» v2 (según la referencia: pelo ondulado con raya al
// centro, cejas gruesas, barba con la boca descubierta, cuello, túnica blanca
// con escote redondo y banda roja sobre el hombro). Sprites por estado de racha.
import { part, circ, ell, path, capsule, pencilLines, svgDoc, C } from './papel-recortado.mjs';

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
  const lado = (k) => `C${20 * k} -170 ${70 * k} -170 ${100 * k} -146 C${130 * k} -122 ${146 * k} -86 ${146 * k} -44 ` +
    `C${158 * k} -20 ${150 * k} 4 ${146 * k} 16 C${160 * k} 36 ${158 * k} 60 ${150 * k} 74 ` +
    `C${166 * k} 94 ${164 * k} 120 ${150 * k} 132 C${144 * k} 146 ${126 * k} 148 ${116 * k} 140 ` +
    `C${108 * k} 152 ${92 * k} 154 ${84 * k} 144 L${80 * k} 60`;
  const atras = part([path(`M0 -158 ${lado(1)} L0 60 Z`, h), path(`M0 -158 ${lado(-1)} L0 60 Z`, h)], { outer: true }) +
    pencilLines(['M-128 -50 C-140 -10 -124 20 -136 56 C-146 86 -130 110 -140 128', 'M128 -50 C140 -10 124 20 136 56 C146 86 130 110 140 128',
      'M-112 40 C-120 70 -104 96 -112 132', 'M112 40 C120 70 104 96 112 132'], { sw: 2.4, color: C.hair, op: 0.5 });

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

  const barba = part([path('M-99 -6 C-104 74 -62 152 0 154 C62 152 104 74 99 -6 L90 -6 C88 24 72 46 48 58 L-48 58 C-72 46 -88 24 -90 -6 Z', h)]) +
    pencilLines(['M-74 60 C-70 96 -52 122 -30 136', 'M74 60 C70 96 52 122 30 136', 'M0 118 L0 140'], { sw: 2.2, color: C.hair, op: 0.45 });
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
  // solo la línea del nacimiento del pelo y algunas hebras
  // mechones sobre la frente: sin contorno exterior (si no parece capucha);
  // solo la línea del nacimiento del pelo, el rizo junto a la oreja y hebras
  const mechon = (k) => `M0 -156 C${-40 * k} -160 ${-92 * k} -140 ${-116 * k} -96 C${-130 * k} -66 ${-128 * k} -20 ${-124 * k} 10 ` +
    `C${-122 * k} 26 ${-110 * k} 32 ${-100 * k} 22 C${-100 * k} -12 ${-92 * k} -50 ${-72 * k} -78 C${-52 * k} -102 ${-24 * k} -108 ${-1 * k} -106 Z`;
  const frente = part([path(mechon(1), h), path(mechon(-1), h)], { outline: false }) +
    pencilLines(['M-124 10 C-122 26 -110 32 -100 22 C-100 -12 -92 -50 -72 -78 C-52 -102 -24 -108 0 -106 C24 -108 52 -102 72 -78 C92 -50 100 -12 100 22 C110 32 122 26 124 10', 'M0 -152 L0 -110'], { sw: 3.4, color: C.pencil, op: 0.92 }) +
    pencilLines(['M-10 -148 C-54 -140 -94 -104 -110 -40 C-114 -20 -112 -4 -118 8', 'M10 -148 C54 -140 94 -104 110 -40 C114 -20 112 -4 118 8',
      'M-30 -154 C-72 -146 -108 -112 -126 -56', 'M30 -154 C72 -146 108 -112 126 -56'], { sw: 2.4, color: C.hair, op: 0.5 });

  return atras + cara + rubor + cejas + ojos + nariz + lagrima + barba + zonaBoca + bigote + boca + frente;
}

// ---------------- Accesorios ----------------
export function estrellita(x, y, r = 14, color = C.mustard) {
  r *= 1.5;
  const k = r * 0.32;
  return part([path(`M${x} ${y - r} Q${x + k} ${y - k} ${x + r} ${y} Q${x + k} ${y + k} ${x} ${y + r} Q${x - k} ${y + k} ${x - r} ${y} Q${x - k} ${y - k} ${x} ${y - r} Z`, color)], { sw: 2.2 });
}
export function corazonP(x, y, s = 1, color = C.tomato) {
  const d = 'M180 300 Q40 200 34 118 Q30 44 102 34 Q156 30 180 84 Q204 30 258 34 Q330 44 326 118 Q320 200 180 300 Z';
  return T(x, y, s, `<g transform="translate(-180 -165)">${part([path(d, color)], { sw: 7 })}<g opacity="0.5">${ell(110, 98, 34, 22, '#f6a598', -30)}</g></g>`);
}
export function corona(x, y, s = 1) {
  return T(x, y, s, part([path('M-56 22 L-62 -30 L-30 -2 L0 -46 L30 -2 L62 -30 L56 22 Z', C.mustard)], { sw: 3 }) +
    part([path('M-58 10 L58 10 L56 26 L-56 26 Z', C.mustardLight)], { sw: 2.6 }) +
    circ(-62, -34, 7, C.mustardLight) + circ(0, -50, 8, C.mustardLight) + circ(62, -34, 7, C.mustardLight) +
    part([circ(0, 18, 6, C.tomato), circ(-32, 18, 5, C.teal), circ(32, 18, 5, C.teal)], { sw: 1.8 }));
}
export function paloma(x, y, s = 1, voltear = false) {
  const b = parteBlanca([
    path('M-62 6 L-96 -10 L-90 14 L-60 18 Z', 'x'),
    ell(-6, 8, 50, 28, 'x'),
    circ(38, -16, 20, 'x'),
  ], { outer: true }) + part([path('M54 -18 L74 -12 L54 -6 Z', C.mustard)], { sw: 2 }) + circ(42, -20, 3.6, C.ink) +
    parteBlanca([path('M-30 0 C-10 -40 30 -50 40 -40 C26 -20 6 4 -30 10 Z', 'x')], { sw: 3 }) +
    pencilLines(['M-10 -16 C4 -26 18 -32 26 -34', 'M-18 -6 C-2 -16 12 -22 22 -26'], { sw: 2, color: '#b9ab96', op: 0.8 });
  return T(x, y, s, voltear ? `<g transform="scale(-1 1)">${b}</g>` : b);
}
export function biblia(x, y, s = 1, rot = 0) {
  return T(x, y, s, part([path('M-46 -60 L46 -60 L46 60 L-46 60 Z', C.leatherDark)], { sw: 3 }) +
    part([path('M46 -54 L54 -50 L54 62 L46 60 Z', C.cream)], { sw: 2.4 }) +
    part([path('M-6 -40 H6 V-20 H24 V-8 H6 V34 H-6 V-8 H-24 V-20 H-6 Z', C.mustard)], { sw: 2 }), rot);
}
export function espada(x, y, s = 1, rot = 0) {
  // mango en (0,0), hoja hacia arriba
  return T(x, y, s, part([path('M-14 -40 L-14 -250 L0 -282 L14 -250 L14 -40 Z', C.steelLight)], { sw: 3 }) +
    pencilLines(['M0 -46 L0 -256'], { sw: 2.4, color: C.steel, op: 0.9 }) +
    part([capsule(-50, -40, 50, -40, 18, C.mustard)], { sw: 2.6 }) +
    part([capsule(0, -32, 0, 30, 18, C.leather)], { sw: 2.6 }) + part([circ(0, 40, 13, C.mustard)], { sw: 2.4 }), rot);
}
export function escudo(x, y, s = 1) {
  return T(x, y, s, part([circ(0, 0, 92, C.mustard)], { sw: 3.4 }) + part([circ(0, 0, 70, C.mustardLight)], { sw: 2.6 }) +
    part([path('M-10 -48 H10 V-12 H44 V8 H10 V52 H-10 V8 H-44 V-12 H-10 Z', C.tomato)], { sw: 2.4 }) +
    circ(-72, -40, 5, C.leather) + circ(72, -40, 5, C.leather) + circ(-72, 40, 5, C.leather) + circ(72, 40, 5, C.leather));
}
export function cordero(x, y, s = 1) {
  const lana = [];
  for (let i = 0; i < 12; i++) {
    const a = (i / 12) * Math.PI * 2;
    lana.push(circ((Math.cos(a) * 92).toFixed(1), (Math.sin(a) * 52).toFixed(1), 34, 'x'));
  }
  lana.push(ell(0, 0, 96, 58, 'x'));
  return T(x, y, s, parteBlanca(lana, { outer: true }) +
    part([ell(84, -40, 16, 26, C.kraft, 30), ell(140, -42, 16, 26, C.kraft, -30)], { sw: 2.6 }) +
    part([ell(112, -18, 36, 40, C.cream)], { sw: 3 }) +
    parteBlanca([circ(112, -56, 20, 'x'), circ(96, -50, 14, 'x'), circ(128, -50, 14, 'x')], { outer: true }) +
    pencilLines(['M98 -16 Q104 -10 110 -16', 'M114 -16 Q120 -10 126 -16'], { sw: 3, color: C.ink, op: 1 }) +
    part([ell(112, 2, 7, 5, C.blush)], { sw: 1.8 }) +
    `<g opacity="0.6">${ell(92, -2, 8, 5, C.blush)}${ell(132, -2, 8, 5, C.blush)}</g>`);
}
function aureola(x, y, r, { rayos = false } = {}) {
  let b = '';
  if (rayos) {
    const tiras = [];
    for (let i = 0; i < 16; i++) {
      const a = (i / 16) * Math.PI * 2, a2 = a + 0.09;
      const R = r * 1.65;
      tiras.push(path(`M${x + Math.cos(a - 0.09) * r * 0.9} ${y + Math.sin(a - 0.09) * r * 0.9} L${x + Math.cos(a) * R} ${y + Math.sin(a) * R} L${x + Math.cos(a2 + 0.09) * r * 0.9} ${y + Math.sin(a2 + 0.09) * r * 0.9} Z`, i % 2 ? C.mustardLight : C.mustard));
    }
    b += part(tiras, { sw: 2.4 });
  }
  b += part([circ(x, y, r, C.mustardLight)], { sw: 3 }) + `<g opacity="0.35">${part([circ(x, y, r * 0.8, C.mustard)], { outline: false })}</g>`;
  return sticker(b);
}
function arcoiris(x, y, r) {
  const colores = [C.tomato, C.mustard, C.sage, '#bcd6e6'];
  const anillos = colores.map((c, i) => {
    const R = r - i * 26, r2 = R - 26;
    return path(`M${x - R} ${y} A${R} ${R} 0 0 1 ${x + R} ${y} L${x + r2} ${y} A${r2} ${r2} 0 0 0 ${x - r2} ${y} Z`, c);
  });
  return sticker(part(anillos, { sw: 2.6 }));
}

// ---------------- Cuerpo ----------------
function brazo(hombro, codo, muneca, { ancho = 62, mano = 28, apunta = false, sinMano = false } = {}) {
  const dx = muneca[0] - codo[0], dy = muneca[1] - codo[1], L = Math.hypot(dx, dy);
  const ux = dx / L, uy = dy / L, nx = -uy, ny = ux;
  const mx = muneca[0] + ux * 32, my = muneca[1] + uy * 32;
  const w2 = ancho * 0.62;
  const campana = path(`M${codo[0] + nx * ancho * 0.45} ${codo[1] + ny * ancho * 0.45} L${muneca[0] + nx * w2} ${muneca[1] + ny * w2} L${muneca[0] - nx * w2} ${muneca[1] - ny * w2} L${codo[0] - nx * ancho * 0.45} ${codo[1] - ny * ancho * 0.45} Z`, 'x');
  let manoSvg = '';
  if (!sinMano) {
    manoSvg = apunta
      ? part([capsule(mx, my, mx + ux * 8, my - 52, 17, J.piel), circ(mx.toFixed(1), my.toFixed(1), mano, J.piel)], { outer: true })
      : part([circ(mx.toFixed(1), my.toFixed(1), mano, J.piel)]);
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
    b += part([path(`M${cx - 134} 470 C${cx - 108} 440 ${cx - 70} 444 ${cx - 50} 448 Q${cx} 492 ${cx + 50} 448 C${cx + 70} 444 ${cx + 108} 440 ${cx + 134} 470 L${cx + 120} 660 C${cx + 70} 690 ${cx - 70} 690 ${cx - 120} 660 Z`, C.mustard)], { sw: 3.2 }) +
      part([path(`M${cx - 116} 676 L${cx - 112} 740 L${cx - 76} 744 L${cx - 72} 690 Z`, C.mustard), path(`M${cx - 60} 692 L${cx - 58} 756 L${cx - 20} 758 L${cx - 20} 696 Z`, C.mustard), path(`M${cx + 20} 696 L${cx + 20} 758 L${cx + 58} 756 L${cx + 60} 692 Z`, C.mustard), path(`M${cx + 72} 690 L${cx + 76} 744 L${cx + 112} 740 L${cx + 116} 676 Z`, C.mustard)], { sw: 2.6 }) +
      pencilLines([`M${cx} 492 L${cx} 676`, `M${cx - 110} 580 Q${cx} 610 ${cx + 110} 580`], { sw: 2.6, color: C.leather, op: 0.7 }) +
      part([path(`M${cx - 9} 506 H${cx + 9} V530 H${cx + 30} V546 H${cx + 9} V584 H${cx - 9} V546 H${cx - 30} V530 H${cx - 9} Z`, C.mustardLight)], { sw: 2.2 });
  }
  return sticker(b);
}
function hombrera(x, y, s = 1) {
  return sticker(T(x, y, s, part([path('M-62 20 C-60 -40 60 -40 62 20 C30 8 -30 8 -62 20 Z', C.mustard)], { sw: 3 }) +
    pencilLines(['M-46 0 C-20 -14 20 -14 46 0'], { sw: 2.4, color: C.leather, op: 0.7 })));
}
function manosOrando(x, y) {
  return sticker(part([ell(x - 14, y, 20, 40, J.piel, 8), ell(x + 14, y, 20, 40, J.piel, -8)]) +
    pencilLines([`M${x} ${y - 34} L${x} ${y + 34}`], { sw: 2.6, color: C.pencil, op: 0.8 }));
}

// ---------------- Poses ----------------
const CX = 400, HY = 215, HS = 1.22;
const H = (o) => sticker(T(CX, HY, HS, cabezaJesus(o)));
const HI = [CX - 136, 456], HD = [CX + 136, 456];   // hombros (izq./der. del espectador)

const POSES = {
  // Usuario nuevo: con un corderito en brazos
  nuevo: () => pies(CX) + torso(CX) + H({ ojos: 'felices', boca: 'abierta' }) +
    brazo(HI, [CX - 150, 620], [CX - 70, 690], { sinMano: true }) + brazo(HD, [CX + 156, 610], [CX + 90, 676], { sinMano: true }) +
    sticker(`<g transform="translate(${CX} 610) scale(-1 1)">${cordero(0, 0, 1)}</g>`) +
    sticker(part([circ(CX - 52, 700, 28, J.piel), circ(CX + 106, 680, 28, J.piel)])) +
    estrellita(CX - 230, 250, 16) + estrellita(CX + 220, 200, 12),
  // Alegre bienvenida: brazos abiertos
  bienvenida: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'abierta' }) +
    brazo(HI, [CX - 206, 560], [CX - 274, 512]) + brazo(HD, [CX + 206, 560], [CX + 274, 512]) +
    estrellita(CX - 250, 300, 16) + estrellita(CX + 260, 280, 14) + estrellita(CX + 200, 160, 10),
  // Esperando: ora con los ojos cerrados, una paloma cerca
  esperando: () => pies(CX) + torso(CX) + H({ ojos: 'cerrados', boca: 'sonrisa' }) +
    brazo(HI, [CX - 128, 640], [CX - 30, 580], { sinMano: true }) + brazo(HD, [CX + 128, 640], [CX + 30, 580], { sinMano: true }) +
    manosOrando(CX, 540) + sticker(paloma(CX + 250, 320, 1.35, true)) + estrellita(CX - 220, 220, 12),
  // Ánimo: sostiene un corazón
  animo: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'sonrisa' }) +
    sticker(`<g opacity="0.55">${part([circ(CX, 590, 108, C.mustardLight)], { outline: false })}</g>`) +
    sticker(corazonP(CX, 590, 0.5)) +
    brazo(HI, [CX - 140, 650], [CX - 70, 640]) + brazo(HD, [CX + 140, 650], [CX + 70, 640]) +
    sticker(corazonP(CX - 226, 230, 0.2)) + sticker(corazonP(CX + 236, 310, 0.17)) + sticker(corazonP(CX + 200, 110, 0.14)),
  // Racha perdida: compasivo, con una lágrima y los brazos abiertos hacia abajo
  perdida: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'suave', triste: true, lagrima: true }) +
    brazo(HI, [CX - 182, 600], [CX - 250, 640]) + brazo(HD, [CX + 182, 600], [CX + 250, 640]),
  // Victoria del día: señala al cielo, mano en el corazón, corona
  victoria: () => sticker(corona(CX, 0, 0.9)) + pies(CX) + torso(CX) + H({ ojos: 'felices', boca: 'abierta' }) +
    brazo(HI, [CX - 214, 430], [CX - 222, 300], { apunta: true }) + brazo(HD, [CX + 150, 620], [CX + 46, 560]) +
    estrellita(CX + 230, 230, 16) + estrellita(CX - 120, 60, 12) + estrellita(CX + 140, 40, 10),
  // Primera semana: paloma en la mano, mano en el corazón, corona
  semana: () => sticker(corona(CX, 0, 0.9)) + pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'sonrisa' }) +
    brazo(HI, [CX - 200, 590], [CX - 262, 520]) + brazo(HD, [CX + 150, 620], [CX + 46, 560]) +
    sticker(paloma(CX - 312, 430, 1.25)) + estrellita(CX + 230, 240, 14) + estrellita(CX + 170, 90, 10),
  // Un mes: hombrera dorada, señala al cielo y sostiene la Biblia
  mes: () => pies(CX) + torso(CX) + H({ ojos: 'abiertos', boca: 'abierta' }) +
    brazo(HI, [CX - 214, 430], [CX - 222, 300], { apunta: true }) +
    sticker(biblia(CX + 222, 560, 1.3, 8)) + brazo(HD, [CX + 176, 640], [CX + 196, 610]) + hombrera(HD[0] + 4, HD[1] - 10, 1.3) +
    estrellita(CX + 240, 300, 14) + estrellita(CX - 140, 120, 12) + estrellita(CX + 120, 60, 10),
  // Centurión de la fe: armadura, espada en alto y escudo
  centurion: () => aureola(CX, HY - 20, 210, { rayos: true }) + pies(CX) + torso(CX, { armadura: true }) +
    H({ ojos: 'abiertos', boca: 'abierta' }) +
    sticker(espada(CX - 229, 292, 1.25, -6)) + brazo(HI, [CX - 216, 440], [CX - 226, 318]) + hombrera(HI[0] - 4, HI[1] - 10, 1.3) +
    brazo(HD, [CX + 178, 620], [CX + 200, 600], { sinMano: true }) + sticker(escudo(CX + 220, 640, 0.95)) + hombrera(HD[0] + 4, HD[1] - 10, 1.3),
  // Un año glorioso: aureola con rayos, arcoíris, brazos abiertos y paloma
  anio: () => arcoiris(CX, 470, 420) + aureola(CX, HY - 20, 200, { rayos: true }) + pies(CX) + torso(CX) +
    H({ ojos: 'felices', boca: 'abierta' }) +
    brazo(HI, [CX - 210, 540], [CX - 276, 470]) + brazo(HD, [CX + 210, 540], [CX + 276, 470]) +
    sticker(paloma(CX + 316, 400, 1.2, true)) + estrellita(CX - 300, 300, 16) + estrellita(CX - 230, 120, 12) + estrellita(CX + 250, 90, 14),
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
