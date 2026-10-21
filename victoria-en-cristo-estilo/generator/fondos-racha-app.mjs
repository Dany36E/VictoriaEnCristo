// Fondos de racha en estilo «escena» del kit (acuarela + lápiz + capas de papel rasgado).
import { part, circ, ell, path, pencilLines, tornStrip, svgDoc, rng, C } from './papel-recortado.mjs';

const S = 1024;
const AZUL_CLARO = '#4f7fa8', CELESTE = '#bcd6e6', NOCHE = '#2f4a68', TERRACOTA = '#c8553d', CREMA_OSC = '#efe6d6', ROJO_OSC = '#b5392e';

const capaDefs = `<defs><filter id="capa" x="-5%" y="-10%" width="110%" height="120%">
  <feGaussianBlur in="SourceAlpha" stdDeviation="5"/><feOffset dy="-6" result="o"/>
  <feFlood flood-color="rgb(74,48,22)" flood-opacity="0.28"/><feComposite in2="o" operator="in"/>
  <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>`;

const cielo = (color) => part([path(`M-60 -60 H${S + 60} V${S + 60} H-60 Z`, color)], { outline: false });
const colina = (baseY, color, o = {}) => `<g filter="url(#capa)">${part([path(tornStrip(S, S, baseY, { amp: 40, waves: 2, jag: 4, ...o }).d, color)])}</g>`;
function nube(x, y, s = 1, color = C.paper) {
  const c = [circ(x - 70 * s, y, 44 * s, color), circ(x - 14 * s, y - 30 * s, 58 * s, color), circ(x + 52 * s, y - 8 * s, 48 * s, color), circ(x + 96 * s, y + 10 * s, 34 * s, color),
    path(`M${x - 112 * s} ${y + 10 * s} H${x + 128 * s} V${y + 40 * s} H${x - 112 * s} Z`, color)];
  return `<g filter="url(#capa)">${part(c, { outer: true })}</g>`;
}
function sol(x, y, r, { rayos = 12, color = C.mustard, largo = 1.6 } = {}) {
  const ds = [];
  for (let i = 0; i < rayos; i++) {
    const a = (i / rayos) * Math.PI * 2;
    ds.push(`M${x + Math.cos(a) * r * 1.2} ${y + Math.sin(a) * r * 1.2} L${x + Math.cos(a) * r * largo} ${y + Math.sin(a) * r * largo}`);
  }
  return pencilLines(ds, { sw: 9, color, op: 0.95 }) + part([circ(x, y, r, color)]);
}
function estrella(x, y, r, color = C.mustard) {
  const k = r * 0.32;
  return part([path(`M${x} ${y - r} Q${x + k} ${y - k} ${x + r} ${y} Q${x + k} ${y + k} ${x} ${y + r} Q${x - k} ${y + k} ${x - r} ${y} Q${x - k} ${y - k} ${x} ${y - r} Z`, color)], { sw: 2.4 });
}
function estrella5(x, y, r, color = C.mustard) {
  const p = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + (i * Math.PI) / 5, rr = i % 2 ? r * 0.45 : r;
    p.push(`${(x + Math.cos(a) * rr).toFixed(1)} ${(y + Math.sin(a) * rr).toFixed(1)}`);
  }
  return part([path(`M${p.join(' L')} Z`, color)], { sw: 2.6 });
}
// Luna creciente: círculo (cx,cy,r) menos el círculo (cx+dx, cy+dy, r2)
function luna(cx, cy, r, dx, dy, r2, color) {
  const d = Math.hypot(dx, dy), a = (r * r - r2 * r2 + d * d) / (2 * d), h = Math.sqrt(r * r - a * a);
  const ux = dx / d, uy = dy / d;
  const px = cx + ux * a, py = cy + uy * a;
  const p1 = [px - uy * h, py + ux * h], p2 = [px + uy * h, py - ux * h];
  return part([path(`M${p1[0]} ${p1[1]} A${r} ${r} 0 1 1 ${p2[0]} ${p2[1]} A${r2} ${r2} 0 0 0 ${p1[0]} ${p1[1]} Z`, color)]);
}
function rayosCuna(cx, cy, n, colorA, colorB, R = 1500, fase = 0) {
  const t = [];
  for (let i = 0; i < n; i++) {
    const a1 = fase + (i / n) * Math.PI * 2, a2 = fase + ((i + 0.5) / n) * Math.PI * 2;
    t.push(path(`M${cx} ${cy} L${cx + Math.cos(a1) * R} ${cy + Math.sin(a1) * R} L${cx + Math.cos(a2) * R} ${cy + Math.sin(a2) * R} Z`, colorB));
  }
  return cielo(colorA) + part(t, { outline: false });
}
function flores(seed, y0, y1, n, colores) {
  const r = rng(seed); let b = '';
  for (let i = 0; i < n; i++) {
    const x = 30 + r() * (S - 60), y = y0 + r() * (y1 - y0), c = colores[i % colores.length];
    b += part([circ(x - 7, y, 7, c), circ(x + 7, y, 7, c), circ(x, y - 7, 7, c), circ(x, y + 7, 7, c)], { outer: true, sw: 2 }) + circ(x, y, 4, C.mustard);
  }
  return b;
}

const FONDOS = {
  // 0 días: cielo crema y colinas de cartón, listo para empezar
  listo: () => cielo(C.cream) + `<g opacity="0.55">${sol(512, 470, 90, { color: C.mustardLight, rayos: 14 })}</g>` +
    nube(200, 260, 1.1) + nube(820, 200, 0.9) + colina(620, CREMA_OSC, { seed: 3 }) + colina(740, C.kraft, { seed: 5, amp: 30 }) + colina(880, C.leather, { seed: 7, amp: 24 }),
  // 1+: pradera al amanecer
  pradera: () => cielo(CELESTE) + colina(560, C.blush, { seed: 11, amp: 18, waves: 1 }) + sol(512, 600, 110, { color: C.mustardLight }) +
    nube(220, 230, 1) + nube(830, 300, 0.8) + colina(660, C.sage, { seed: 13 }) + colina(800, C.olive, { seed: 17, amp: 30 }) +
    flores(4, 830, 1000, 16, [C.paper, C.blush, C.mustardLight]),
  // 3+: cielo de la fe
  cielo: () => cielo(AZUL_CLARO) + colina(520, CELESTE, { seed: 21, amp: 24, waves: 1 }) + sol(512, 820, 150, { color: C.mustard, rayos: 16, largo: 1.9 }) +
    nube(150, 160, 1.3) + nube(880, 130, 1.2) + nube(90, 560, 1) + nube(950, 600, 1.1) + nube(260, 940, 1.6) + nube(780, 960, 1.7),
  // 7+: atardecer glorioso
  atardecer: () => rayosCuna(512, 760, 18, C.mustardLight, C.mustard) + sol(512, 760, 150, { color: TERRACOTA, rayos: 0 }) +
    nube(200, 220, 1, C.blush) + nube(840, 160, 0.9, C.blush) + nube(780, 420, 0.7, C.blush) +
    colina(760, TERRACOTA, { seed: 31 }) + colina(880, C.kraft, { seed: 37, amp: 30 }),
  // 14+: noche estrellada
  noche: () => {
    const r = rng(41); let est = '';
    for (let i = 0; i < 22; i++) {
      const x = 40 + r() * (S - 80), y = 40 + r() * 600, k = 10 + r() * 18;
      est += i % 3 ? estrella(x, y, k) : estrella5(x, y, k * 1.2);
    }
    return cielo(NOCHE) + est +
      luna(790, 220, 104, 48, -36, 92, C.mustardLight) +
      colina(720, '#3d6890', { seed: 43 }) + colina(860, C.navy, { seed: 47, amp: 30 });
  },
  // 30+: batalla espiritual
  batalla: () => {
    let b = cielo(TERRACOTA);
    const franjas = [[-200, ROJO_OSC], [120, C.tomato], [520, ROJO_OSC], [860, C.tomato]];
    for (const [o, c] of franjas) b += `<g filter="url(#capa)">${part([path(`M${o} ${S + 100} L${o + 900} -100 L${o + 1120} -100 L${o + 220} ${S + 100} Z`, c)])}</g>`;
    b += pencilLines(['M80 900 L760 60', 'M260 1000 L960 140', 'M-40 640 L520 -40'], { sw: 12, color: C.mustard, op: 0.9 });
    b += pencilLines(['M150 300 c40 -60 120 -20 90 40 c-20 40 -80 30 -70 -10', 'M820 760 c40 -60 120 -20 90 40 c-20 40 -80 30 -70 -10', 'M560 520 c30 -46 90 -16 68 30 c-16 30 -60 22 -52 -8'], { sw: 8, color: C.mustardLight, op: 0.9 });
    return b;
  },
  // 100+: armadura dorada
  armadura: () => {
    const r = rng(53); let chispas = '';
    for (let i = 0; i < 14; i++) chispas += estrella(60 + r() * 900, 60 + r() * 900, 10 + r() * 16, C.paper);
    return rayosCuna(512, 512, 24, C.mustard, C.mustardLight) +
      `<g filter="url(#capa)">${part([circ(512, 512, 210, C.paper)])}</g>` + part([circ(512, 512, 160, C.mustardLight)], { sw: 2.6 }) +
      part([path('M490 380 H534 V470 H612 V514 H534 V660 H490 V514 H412 V470 H490 Z', C.mustard)]) + chispas;
  },
  // 365+: guardia eterna
  guardia: () => {
    const r = rng(61); let est = '';
    for (let i = 0; i < 12; i++) est += estrella(40 + r() * (S - 80), 30 + r() * 300, 8 + r() * 12);
    let muro = `M-40 ${S + 40} L-40 600`;
    for (let x = -40; x < S + 40; x += 128) muro += ` L${x} 560 L${x + 64} 560 L${x + 64} 600 L${x + 128} 600`;
    muro += ` L${S + 40} ${S + 40} Z`;
    const piedras = [];
    for (let y = 660; y < S; y += 70) for (let x = (y / 70) % 2 ? -30 : 30; x < S; x += 120) piedras.push(`M${x} ${y} H${x + 100}`, `M${x + 100} ${y} V${y + 60}`);
    let chispas = '';
    for (let i = 0; i < 16; i++) chispas += circ(400 + r() * 224, 280 + r() * 280, 3 + r() * 4, C.mustardLight);
    return cielo(C.navy) + est +
      `<g opacity="0.16">${part([circ(512, 520, 330, C.mustardLight)], { outline: false })}</g><g opacity="0.22">${part([circ(512, 520, 230, C.mustardLight)], { outline: false })}</g><g opacity="0.3">${part([circ(512, 520, 140, C.mustardLight)], { outline: false })}</g>` +
      `<g filter="url(#capa)">${part([path(muro, NOCHE)])}</g>` + pencilLines(piedras, { sw: 3, color: C.navy, op: 0.55 }) +
      part([path('M480 640 L544 640 L530 900 L494 900 Z', C.leather)]) +
      part([path('M512 400 C590 470 580 560 512 610 C444 560 434 470 512 400 Z', C.mustard)]) +
      part([path('M512 470 C552 510 548 560 512 590 C476 560 472 510 512 470 Z', C.tomato)], { sw: 2.6 }) + chispas;
  },
};

export const fondosRacha = Object.entries(FONDOS).map(([n, f], i) => ({
  name: `racha_${n}`,
  svg: svgDoc(S, S, capaDefs + f(), 70 + i * 3, { border: 8 }),
}));
