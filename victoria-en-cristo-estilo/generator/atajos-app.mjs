// Íconos de los atajos de la app (Inicio, widget y accesos del ícono en
// Android): uno por cada pantalla que se puede poner de atajo. Los que ya
// existen en el kit (Biblia, corazón, calendario…) se usan tal cual; el resto
// se dibuja aquí con las mismas partes de papel. Sin dedos: ningún dibujo
// lleva manos.
// Uso: se exportan con renderizar-app.mjs como atajo_<id>.png.
import fs from 'node:fs';
import { part, circ, ell, path, capsule, pencilLines, svgDoc, C } from './papel-recortado.mjs';

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

// ── Ayudas ────────────────────────────────────────────────────────────────
// Rectángulo redondeado como path relleno
const rr = (x, y, w, h, r, fill) =>
  path(`M${x + r} ${y} L${x + w - r} ${y} Q${x + w} ${y} ${x + w} ${y + r} L${x + w} ${y + h - r} Q${x + w} ${y + h} ${x + w - r} ${y + h} L${x + r} ${y + h} Q${x} ${y + h} ${x} ${y + h - r} L${x} ${y + r} Q${x} ${y} ${x + r} ${y} Z`, fill);
// Estrella de n puntas
function estrellaPath(cx, cy, R, r, n = 5, giro = -90) {
  const pts = [];
  for (let i = 0; i < n * 2; i++) {
    const a = ((giro + (i * 180) / n) * Math.PI) / 180;
    const k = i % 2 ? r : R;
    pts.push(`${(cx + k * Math.cos(a)).toFixed(1)} ${(cy + k * Math.sin(a)).toFixed(1)}`);
  }
  return `M${pts.join(' L')} Z`;
}
// Corazón centrado en (0,0), unos 80 px de ancho
const CORAZON = 'M0 34 Q-44 4 -44 -16 Q-44 -42 -21 -42 Q-6 -42 0 -26 Q6 -42 21 -42 Q44 -42 44 -16 Q44 4 0 34 Z';
// Renglón gris de texto impreso
const renglon = (x0, y, x1, grosor = 8) => capsule(x0, y, x1, y, grosor, '#bdb3a6');
// Trazo grueso sin contorno (signos, rutas punteadas)
const trazo = (d, color, ancho, extra = '') =>
  `<g filter="url(#wc)"><path d="${d}" fill="none" stroke="${color}" stroke-width="${ancho}" stroke-linecap="round" stroke-linejoin="round" ${extra}/></g>`;
const sector = (r1, r2, a1, a2) => {
  const p = (r, a) => `${(r * Math.cos((a * Math.PI) / 180)).toFixed(1)} ${(r * Math.sin((a * Math.PI) / 180)).toFixed(1)}`;
  return `M${p(r2, a1)} A${r2} ${r2} 0 0 1 ${p(r2, a2)} L${p(r1, a2)} A${r1} ${r1} 0 0 0 ${p(r1, a1)} Z`;
};

// ── Biblia y estudio ──────────────────────────────────────────────────────
const biblia = objetoKit('bible_closed', 180, 182, 318, -6);
const estudio = objetoKit('bible_open', 158, 222, 296, -4) + lupa(212, 136, 0.9, -8);
const apuntes = sticker(libreta(160, 182, 1, -7) + lapiz(250, 214, 1, -58));

// Hoja con renglones y listón rojo de separador
const guardados = T(180, 184, 1, sticker(
  part([rr(-96, -124, 192, 248, 10, C.paper)], { sw: 3 }) +
  [-80, -50, -20, 10, 40, 70].map((y, i) => renglon(-70, y, i % 3 === 2 ? 0 : 40)).join('') +
  part([path('M28 -134 L78 -134 L78 92 L53 70 L28 92 Z', C.tomato)], { sw: 3 }) +
  part([path(estrellaPath(53, -60, 17, 7), C.mustardLight)], { sw: 2 }) +
  brillo(40, -10, 4, 50, 0, 0.35),
), -6);

// Pergamino enrollado con tierras, ruta punteada y una X
const mapas = T(180, 182, 1, sticker(
  part([path('M-104 -84 Q-52 -98 0 -84 Q52 -70 104 -84 L104 88 Q52 74 0 88 Q-52 102 -104 88 Z', '#ead7b0')], { sw: 3 }) +
  `<g opacity="0.75">${part([path('M-84 -54 Q-46 -76 -14 -50 Q8 -26 -24 -4 Q-62 18 -84 -10 Z', C.sage), path('M14 26 Q54 -2 86 24 Q98 62 58 68 Q20 70 14 26 Z', C.sage)], { sw: 2.2 })}</g>` +
  trazo('M-64 46 Q-26 66 4 30 Q34 -4 62 -34', C.tomato, 6, 'stroke-dasharray="11 10"') +
  pencilLines(['M58 -48 L80 -26', 'M80 -48 L58 -26'], { sw: 6, color: C.tomato, op: 0.95 }) +
  part([capsule(-108, -96, -108, 100, 30, '#d8be8c'), capsule(108, -96, 108, 100, 30, '#d8be8c')], { sw: 3 }),
), -5);

// ── Vida espiritual ───────────────────────────────────────────────────────
// Mapa doblado en tres con ruta y un alfiler de corazón
const mapaOracion = T(180, 196, 1, sticker(
  part([
    path('M-122 -64 L-40 -84 L-40 102 L-122 82 Z', C.paper),
    path('M-40 -84 L40 -64 L40 122 L-40 102 Z', '#ece0c8'),
    path('M40 -64 L122 -84 L122 102 L40 122 Z', C.paper),
  ], { sw: 3 }) +
  trazo('M-98 70 Q-70 20 -40 34 Q-6 50 14 10 Q34 -24 70 -10 Q96 0 100 -40', C.navy, 5, 'stroke-dasharray="10 9"') +
  part([capsule(70, -10, 70, -60, 7, C.steel)], { sw: 2 }) +
  T(70, -84, 0.62, part([path(CORAZON, C.tomato)], { sw: 4.5 }) + brillo(-16, -20, 8, 5, -30, 0.6)),
), -4);

const versiculos = objetoKit('bubble', 180, 176, 300) + T(180, 160, 1,
  part([circ(-34, -6, 20, C.tomato), path('M-22 4 Q-16 34 -44 52 Q-30 30 -36 12 Z', C.tomato),
    circ(26, -6, 20, C.tomato), path('M38 4 Q44 34 16 52 Q30 30 24 12 Z', C.tomato)], { sw: 2.6 }));

// Frasco de vidrio con tapa y papelitos doblados dentro
function frasco() {
  const nota = (x, y, rot, color) => T(x, y, 1, part([rr(-24, -17, 48, 34, 4, color)], { sw: 2.4 }) +
    pencilLines(['M-24 -17 L0 4 L24 -17'], { sw: 2, op: 0.5 }), rot);
  return T(180, 186, 1, sticker(
    part([path('M-76 -66 Q-96 -56 -96 -24 L-96 98 Q-96 126 -68 126 L68 126 Q96 126 96 98 L96 -24 Q96 -56 76 -66 Z', '#dcefec')], { sw: 3 }) +
    nota(-44, 96, -12, C.blush) + nota(18, 98, 8, C.mustardLight) + nota(52, 62, -18, C.sage) +
    nota(-30, 56, 14, C.paper) + nota(12, 28, -6, C.tealLight) +
    T(-46, 16, 0.42, part([path(CORAZON, C.tomato)], { sw: 5 })) +
    brillo(-70, 10, 8, 50, 0, 0.7) + brillo(70, 40, 5, 30, 0, 0.4) +
    part([rr(-72, -92, 144, 30, 8, '#cfe6e2')], { sw: 2.6 }) +
    part([rr(-84, -128, 168, 40, 10, C.mustard)], { sw: 3 }) +
    pencilLines(['M-80 -104 L80 -104', 'M-80 -96 L80 -96'], { sw: 2.4, color: C.leather, op: 0.7 }),
  ), 4);
}

// Vela del kit en su portavelas, con la flama del kit y resplandor
const devocional = [[1.5, 0.14], [1.18, 0.22]].map(([k, op]) => `<g opacity="${op}">${circ(180, 100, 56 * k, C.mustardLight)}</g>`).join('') +
  sticker(part([ell(180, 292, 96, 24, C.mustard)], { sw: 3 }) + part([ell(180, 284, 58, 12, C.mustardLight)], { sw: 2.4 })) +
  objetoKit('candle', 180, 196, 88) + objetoKit('flame', 180, 74, 66);

const oraciones = objetoKit('heart_clean', 180, 186, 280, -4);
const progreso = objetoKit('calendar', 180, 184, 262, 4);

// Estrella dorada con brillo
const favoritos = T(180, 186, 1, sticker(
  part([path(estrellaPath(0, 0, 132, 58), C.mustard)], { sw: 3.4 }) +
  part([path(estrellaPath(0, 0, 70, 30), C.mustardLight)], { outline: false }) +
  brillo(-40, -44, 18, 9, -30, 0.7),
), -8);

// ── Escuela del Reino y juegos ────────────────────────────────────────────
// Libro con un birrete encima
const escuela = T(180, 190, 1, sticker(
  part([rr(-118, 54, 236, 58, 8, C.teal)], { sw: 3 }) +
  part([rr(-106, 62, 212, 16, 4, C.paper)], { sw: 2 }) +
  pencilLines(['M-100 70 L100 70'], { sw: 1.6, op: 0.5 }) +
  part([path('M-70 -6 L70 -6 L70 40 Q0 64 -70 40 Z', '#24345a')], { sw: 3 }) +
  part([path('M0 -76 L134 -26 L0 24 L-134 -26 Z', C.navy)], { sw: 3.2 }) +
  brillo(-40, -34, 34, 6, -20, 0.25) +
  trazo('M0 -26 Q64 -18 98 6', C.mustard, 7) +
  part([capsule(98, 6, 102, 62, 16, C.mustard)], { sw: 2.4 }) +
  part([circ(0, -26, 11, C.mustard)], { sw: 2.2 }),
), -4);

// Dado rojo y peón azul
function juegos() {
  const pip = (x, y) => circ(x, y, 12, C.paper);
  return sticker(
    T(144, 196, 1, part([rr(-78, -78, 156, 156, 26, C.tomato)], { sw: 3.4 }) +
      part([pip(-40, -40), pip(40, -40), pip(0, 0), pip(-40, 40), pip(40, 40)], { sw: 2 }) +
      brillo(-44, -60, 26, 6, 0, 0.35), -12) +
    T(266, 196, 1, part([path('M-36 74 Q-40 42 -18 20 Q-30 6 -26 -10 L26 -10 Q30 6 18 20 Q40 42 36 74 Z', C.ultra), circ(0, -36, 28, C.ultra), ell(0, 78, 54, 16, C.ultra)], { sw: 3 }) +
      brillo(-10, -46, 8, 5, -30, 0.6)),
  );
}

// Bandera a cuadros ondeando en su asta
function carrera() {
  const filas = 4, cols = 6, x0 = -78, x1 = 118, y0 = -98, alto = 120;
  const pt = (u, v) => {
    const x = x0 + (x1 - x0) * u;
    const ola = 12 * Math.sin(u * Math.PI * 1.6);
    return [x, y0 + ola + alto * v + 10 * u];
  };
  const cuadros = [];
  for (let i = 0; i < cols; i++) for (let j = 0; j < filas; j++) {
    const [a, b, c, d] = [pt(i / cols, j / filas), pt((i + 1) / cols, j / filas), pt((i + 1) / cols, (j + 1) / filas), pt(i / cols, (j + 1) / filas)];
    cuadros.push(path(`M${a.join(' ')} L${b.join(' ')} L${c.join(' ')} L${d.join(' ')} Z`, (i + j) % 2 ? C.paper : C.ink));
  }
  return T(170, 184, 1, sticker(
    part([capsule(-90, -116, -90, 126, 18, C.leather)], { sw: 3 }) +
    part([circ(-90, -122, 14, C.mustard)], { sw: 2.4 }) +
    part(cuadros, { sw: 2 }),
  ), -6);
}

// Rayo dorado con chispas
const duelo = T(180, 182, 1, sticker(
  part([path('M34 -132 L-74 22 L-8 22 L-44 132 L84 -32 L16 -32 L58 -132 Z', C.mustard)], { sw: 3.4 }) +
  part([path('M30 -112 L-42 8 L4 8', C.mustardLight)], { outline: false }) +
  part([path(estrellaPath(-82, -78, 24, 8, 4, 0), C.mustardLight), path(estrellaPath(96, 74, 20, 7, 4, 0), C.mustardLight)], { sw: 2.2 }),
), 4);

// Carta con un signo de interrogación (y otra detrás)
const quienSoy = sticker(
  T(150, 190, 1, part([rr(-84, -112, 168, 224, 16, C.tealLight)], { sw: 3 }), -12) +
  T(204, 180, 1,
    part([rr(-88, -118, 176, 236, 16, C.paper)], { sw: 3.2 }) +
    pencilLines(['M-72 -102 L72 -102 L72 102 L-72 102 Z'], { sw: 3, color: C.tomato, op: 0.6 }) +
    trazo('M-34 -40 Q-34 -84 2 -84 Q40 -84 40 -48 Q40 -22 12 -8 Q2 -2 2 22', C.ultra, 24) +
    part([circ(2, 62, 15, C.ultra)], { sw: 2.4 }), 8),
);

// Portapapeles con casillas palomeadas
function preguntas() {
  const fila = (y, marca) => part([rr(-64, y - 18, 36, 36, 6, C.paper)], { sw: 2.6 }) + renglon(-12, y, 58, 9) +
    (marca ? pencilLines([`M-58 ${y} L-48 ${y + 11} L-26 ${y - 16}`], { sw: 6, color: C.teal, op: 0.95 }) : '');
  return T(180, 190, 1, sticker(
    part([rr(-100, -120, 200, 250, 16, C.leather)], { sw: 3.2 }) +
    part([rr(-82, -96, 164, 212, 8, C.paper)], { sw: 2.6 }) +
    fila(-44, true) + fila(14, true) + fila(72, false) +
    part([rr(-44, -138, 88, 42, 12, C.steel)], { sw: 2.8 }) +
    part([circ(0, -124, 7, C.steelLight)], { sw: 2 }),
  ), 5);
}

// Libros parados en orden sobre una repisa
function ordenBiblia() {
  const libro = (x, w, h, color, banda) => part([rr(x, 96 - h, w, h, 6, color)], { sw: 3 }) +
    part([capsule(x + 8, 96 - h + 26, x + w - 8, 96 - h + 26, 7, banda), capsule(x + 8, 74, x + w - 8, 74, 7, banda)], { sw: 1.8 });
  return T(180, 172, 1, sticker(
    libro(-112, 46, 176, C.tomato, C.mustardLight) +
    libro(-60, 52, 156, C.teal, C.mustardLight) +
    libro(-2, 44, 190, C.mustard, C.paper) +
    libro(48, 40, 146, C.ultra, C.mustardLight) +
    part([rr(-132, 96, 264, 26, 6, C.kraft)], { sw: 3 }),
  ), -3);
}

// ── Comunidad y ayuda ─────────────────────────────────────────────────────
const ESCUDO = 'M0 -92 Q48 -70 82 -78 Q90 22 0 102 Q-90 22 -82 -78 Q-48 -70 0 -92 Z';
const companero = sticker(
  T(132, 192, 0.94, part([path(ESCUDO, C.teal)], { sw: 3.4 }) +
    part([capsule(0, -50, 0, 52, 18, C.paper), capsule(-34, -14, 34, -14, 18, C.paper)], { sw: 2.2 }), -10) +
  T(232, 178, 0.94, part([path(ESCUDO, C.tomato)], { sw: 3.4 }) +
    T(0, -4, 0.7, part([path(CORAZON, C.paper)], { sw: 3.6 })), 10),
);

// Tablero de corcho con notas clavadas
function muro() {
  const nota = (x, y, rot, color, alfiler) => T(x, y, 1,
    part([rr(-42, -36, 84, 72, 4, color)], { sw: 2.4 }) + renglon(-28, -6, 26, 6) + renglon(-28, 12, 12, 6) +
    part([circ(0, -30, 9, alfiler)], { sw: 2 }), rot);
  return T(180, 182, 1, sticker(
    part([rr(-132, -110, 264, 220, 16, C.leather)], { sw: 3.2 }) +
    part([rr(-114, -92, 228, 184, 8, '#c99a64')], { sw: 2.4 }) +
    `<g opacity="0.35">${[[-90, -60], [-40, 70], [60, -70], [90, 60], [10, -10], [-70, 20], [40, 30]].map(([x, y]) => circ(x, y, 4, C.leatherDark)).join('')}</g>` +
    nota(-56, -30, -8, C.paper, C.tomato) + nota(48, -36, 7, C.mustardLight, C.ultra) + nota(-4, 44, -3, C.blush, C.teal),
  ), 3);
}

// Salvavidas rojo y blanco
const sos = T(180, 182, 1, sticker(
  part([`<path d="M-118 0 A118 118 0 1 0 118 0 A118 118 0 1 0 -118 0 Z M-56 0 A56 56 0 1 1 56 0 A56 56 0 1 1 -56 0 Z" fill="${C.tomato}" fill-rule="evenodd"/>`], { sw: 3.4 }) +
  part([0, 90, 180, 270].map((a) => path(sector(56, 118, a + 24, a + 66), C.paper)), { sw: 2.4 }) +
  pencilLines([-60, 30, 120, 210].map((a) => {
    const r = 128, p = (d) => `${(r * Math.cos(((a + d) * Math.PI) / 180)).toFixed(1)} ${(r * Math.sin(((a + d) * Math.PI) / 180)).toFixed(1)}`;
    return `M${p(-14)} Q${(1.08 * r * Math.cos((a * Math.PI) / 180)).toFixed(1)} ${(1.08 * r * Math.sin((a * Math.PI) / 180)).toFixed(1)} ${p(14)}`;
  }), { sw: 5, color: C.kraft, op: 0.9 }) +
  brillo(-66, -70, 22, 8, -40, 0.4),
), -6);

// Campana dorada con badajo y ondas de sonido
const campanas = T(180, 176, 1,
  pencilLines(['M-118 -40 Q-136 0 -118 40', 'M-142 -58 Q-166 0 -142 58', 'M118 -40 Q136 0 118 40', 'M142 -58 Q166 0 142 58'], { sw: 5, color: C.mustard, op: 0.8 }) +
  sticker(
    part([circ(0, -112, 16, C.mustard)], { sw: 2.6 }) +
    part([circ(0, 104, 20, C.leatherDark)], { sw: 2.4 }) +
    part([path('M0 -100 Q-24 -100 -28 -86 Q-72 -78 -78 -14 Q-82 44 -108 74 L108 74 Q82 44 78 -14 Q72 -78 28 -86 Q24 -100 0 -100 Z', C.mustard)], { sw: 3.4 }) +
    part([rr(-114, 66, 228, 24, 12, C.mustardLight)], { sw: 2.8 }) +
    brillo(-40, -30, 10, 44, 10, 0.45),
  ));

const DIBUJOS = {
  biblia, estudio, apuntes, guardados, mapas,
  mapa_oracion: mapaOracion, versiculos, frasco: frasco(), devocional, oraciones, progreso, favoritos,
  escuela, juegos: juegos(), carrera: carrera(), duelo, quien_soy: quienSoy, preguntas: preguntas(), orden_biblia: ordenBiblia(),
  companero, muro: muro(), sos, campanas,
};

export const atajosItems = Object.entries(DIBUJOS).map(([id, cuerpo], i) => ({
  name: `atajo_${id}`,
  svg: svgDoc(LADO, LADO, cuerpo, 61 + i, { border: 7 }),
}));
