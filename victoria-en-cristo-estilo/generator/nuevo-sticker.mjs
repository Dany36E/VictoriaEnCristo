// Ejemplo: dibuja stickers nuevos con el mismo estilo usando papel-recortado.mjs (Node 18+).
// Uso:  node nuevo-sticker.mjs   -> crea corazon.svg y cruz.svg (ábrelos en el navegador o pásalos por laboratorio-stickers.html para el PNG)
import fs from 'node:fs';
import { svgDoc, part, path, ell, circ, pencilLines, C } from './papel-recortado.mjs';

const sticker = (b) => `<g filter="url(#sticker)">${b}</g>`;   // borde blanco + sombra

// 1) Corazón: part() = relleno de acuarela + contorno de lápiz
const corazon = sticker(
  part([path('M180 300 Q40 200 34 118 Q30 44 102 34 Q156 30 180 84 Q204 30 258 34 Q330 44 326 118 Q320 200 180 300 Z', C.tomato)]) +
  `<g opacity="0.55">${ell(118, 98, 34, 22, '#f6a598', -30)}</g>`          // brillo suave
);
fs.writeFileSync('corazon.svg', svgDoc(360, 330, corazon, 92, { border: 7 }));

// 2) Cruz dorada con rayitas de lápiz
const cruz = sticker(
  part([path('M70 10 H100 V60 H150 V90 H100 V190 H70 V90 H20 V60 H70 Z', C.mustard)], { sw: 3 }) +
  pencilLines(['M80 20 L80 180'], { color: '#c99a2e', sw: 3, op: 0.6 })
);
fs.writeFileSync('cruz.svg', svgDoc(170, 200, cruz, 31, { border: 6 }));
console.log('listo: corazon.svg, cruz.svg');
