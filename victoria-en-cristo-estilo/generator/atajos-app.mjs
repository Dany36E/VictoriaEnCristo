// Íconos de los atajos de la app (Inicio y widget de Android): Biblia, Estudio
// bíblico y Apuntes. La Biblia es el objeto del kit; la lupa y la libreta se
// dibujan aquí con las mismas partes de papel.
// Uso: se exportan con renderizar-app.mjs como atajo_*.png.
import fs from 'node:fs';
import { part, circ, path, capsule, pencilLines, svgDoc, C } from './papel-recortado.mjs';

const OBJETOS = process.env.VEC_OBJETOS || new URL('../../assets/vec/objetos/', import.meta.url).pathname;

function objetoKit(nombre, x, y, ancho, rot = 0) {
  const buf = fs.readFileSync(`${OBJETOS}${nombre}.png`);
  const w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);
  const alto = (ancho * h) / w;
  return `<g transform="translate(${x} ${y}) rotate(${rot})"><image href="data:image/png;base64,${buf.toString('base64')}" x="${-ancho / 2}" y="${-alto / 2}" width="${ancho}" height="${alto}"/></g>`;
}
const T = (x, y, s, b, rot = 0) => `<g transform="translate(${x} ${y}) rotate(${rot}) scale(${s})">${b}</g>`;
const sticker = (b) => `<g filter="url(#sticker)">${b}</g>`;
const brillo = (x, y, rx, ry, rot = 0, op = 0.55) =>
  `<g opacity="${op}"><ellipse cx="${x}" cy="${y}" rx="${rx}" ry="${ry}" fill="#ffffff" transform="rotate(${rot} ${x} ${y})"/></g>`;

const LADO = 360;

// Lupa: aro azul marino, cristal claro con renglones aumentados y mango de madera.
function lupa(x, y, s = 1, rot = 0) {
  const renglones = [[-30, -18, 26], [-34, 4, 30], [-28, 26, 18]]
    .map(([x0, y0, l]) => capsule(x0, y0, x0 + l * 2, y0, 7, '#a59c90')).join('');
  return T(x, y, s, sticker(
    part([capsule(48, 48, 112, 112, 30, C.leather)], { sw: 3 }) +
    part([capsule(44, 44, 62, 62, 34, C.steel)], { sw: 2.6 }) +
    part([circ(0, 0, 70, C.navy)], { sw: 3.2 }) +
    part([circ(0, 0, 54, '#e4f0ee')], { sw: 2.4 }) +
    `<g opacity="0.85">${renglones}</g>` +
    brillo(-24, -30, 16, 8, -40, 0.75) +
    pencilLines(['M90 90 L104 104'], { sw: 2.4, op: 0.5 }),
  ), rot);
}

// Libreta de espiral con renglones, margen rojo y notas a lápiz.
function libreta(x, y, s = 1, rot = 0) {
  const renglones = [-40, -12, 16, 44, 72].map((ry) => `M-74 ${ry} L86 ${ry}`);
  const espiral = [-66, -42, -18, 6, 30, 54, 78].map((ex) =>
    part([capsule(ex, -116, ex, -88, 11, C.steel)], { sw: 2.2 })).join('');
  return T(x, y, s,
    part([path('M-96 -98 Q-98 -104 -90 -104 L104 -104 Q110 -104 110 -96 L110 120 Q110 128 102 128 L-90 128 Q-98 128 -96 120 Z', C.teal)], { sw: 3.2 }) +
    part([path('M-90 -96 L100 -96 L100 116 L-90 116 Z', C.paper)], { sw: 2.6 }) +
    pencilLines(renglones, { sw: 2.4, color: '#8fb0d6', op: 0.8 }) +
    pencilLines(['M-56 -88 L-56 112'], { sw: 2.4, color: C.tomato, op: 0.65 }) +
    pencilLines([
      'M-44 -46 C-30 -56 -18 -38 -4 -48 C8 -56 18 -40 32 -48 C42 -54 50 -44 60 -48',
      'M-44 -18 C-32 -26 -20 -10 -6 -20 C6 -28 16 -14 28 -20',
      'M-44 10 C-30 2 -18 18 -4 8 C6 2 14 14 24 8',
    ], { sw: 3, color: C.navy, op: 0.75 }) +
    espiral,
    rot);
}

// Lápiz amarillo con borrador rosa y punta de grafito (cuerpo horizontal antes de rotar).
function lapiz(x, y, s = 1, rot = 0) {
  return T(x, y, s,
    part([path('M-92 -15 L-128 0 L-92 15 Z', '#e8c39a')], { sw: 2.6 }) +
    part([path('M-116 -5 L-128 0 L-116 5 Z', C.ink)], { sw: 2 }) +
    part([path('M-92 -15 L58 -15 L58 15 L-92 15 Z', C.mustard)], { sw: 3 }) +
    pencilLines(['M-88 -5 L54 -5', 'M-88 6 L54 6'], { sw: 2, color: '#c48a22', op: 0.7 }) +
    part([path('M58 -16 L80 -16 L80 16 L58 16 Z', C.steel)], { sw: 2.6 }) +
    part([path('M80 -15 L96 -15 Q106 -15 106 0 Q106 15 96 15 L80 15 Z', C.blush)], { sw: 2.6 }) +
    brillo(-20, -9, 50, 3, 0, 0.5),
    rot);
}

const biblia = objetoKit('bible_closed', 180, 182, 318, -6);
const estudio = objetoKit('bible_open', 158, 222, 296, -4) + lupa(212, 136, 0.9, -8);
const apuntes = sticker(libreta(160, 182, 1, -7) + lapiz(250, 214, 1, -58));

export const atajosItems = [
  { name: 'atajo_biblia', svg: svgDoc(LADO, LADO, biblia, 61, { border: 7 }) },
  { name: 'atajo_estudio', svg: svgDoc(LADO, LADO, estudio, 62, { border: 7 }) },
  { name: 'atajo_apuntes', svg: svgDoc(LADO, LADO, apuntes, 63, { border: 7 }) },
];
