// Avatares de perfil con el generador del kit (papel-recortado.mjs).
// Jesús está en jesus-app.mjs.
import { part, circ, ell, path, capsule, pencilLines, svgDoc, rng, C } from './papel-recortado.mjs';

const sticker = (b) => `<g filter="url(#sticker)">${b}</g>`;
const T = (x, y, s, b) => `<g transform="translate(${x} ${y}) scale(${s})">${b}</g>`;

// Tonos de piel (el kit trae C.skin; Timoteo y Victoria usan tonos más morenos).
export const PIEL = {
  clara: C.skin,          // #f4cfb2
  media: '#e8b892',       // Victoria
  morena: '#c68a5e',      // Timoteo
  canela: '#a86d47',
  oscura: '#7a4a30',
};
export const PELO = {
  negro: C.hair,          // #3a2a24
  castano: C.leatherDark, // #6a4128
  claro: C.leather,       // #8a5a36
  rubio: C.mustard,       // #e0a73a
  cobrizo: C.kraft,       // #b98f5e
  canas: C.steel,         // #c4c9d0
};
const BOCA = '#b8443a';
const CEJA = C.hair;

// ---------- Cabeza (coordenadas locales: centro de la cara en 0,0; cara 100x100) ----------
// o: { piel, pelo, peinado, barba, lentes, aretes, ojos: 'abiertos'|'felices'|'cerrados', boca: 'sonrisa'|'abierta' }
export function cabeza(o) {
  const p = o.piel, h = o.pelo;
  const ceja = o.pelo === PELO.canas ? '#8a8f96' : (o.pelo === PELO.rubio || o.pelo === PELO.cobrizo ? C.leather : CEJA);
  let atras = '', frente = '', orejas = true, extra = '';

  switch (o.peinado) {
    case 'corto':
      frente = part([path('M-104 -2 C-114 -96 -58 -132 2 -130 C72 -128 114 -92 104 -2 C98 -40 82 -60 54 -70 C22 -56 -30 -60 -62 -66 C-86 -54 -100 -34 -104 -2 Z', h)]);
      extra = pencilLines(['M-30 -112 Q10 -122 46 -104'], { sw: 2.4, color: '#7a5a48', op: 0.6 });
      break;
    case 'rapado':
      frente = part([path('M-100 -18 C-104 -98 -50 -118 0 -118 C50 -118 104 -98 100 -18 C92 -58 60 -80 0 -82 C-60 -80 -92 -58 -100 -18 Z', h)], { sw: 2.8 });
      break;
    case 'lado':
      frente = part([path('M-106 0 C-120 -104 -40 -146 22 -138 C94 -132 122 -82 106 0 C100 -46 84 -66 62 -74 C22 -52 -44 -80 -72 -60 C-94 -46 -102 -26 -106 0 Z', h)]);
      extra = pencilLines(['M-60 -110 Q0 -128 60 -100', 'M-20 -86 Q30 -96 70 -84'], { sw: 2.4, color: '#7a5a48', op: 0.55 });
      break;
    case 'rizado': {
      const rs = [];
      for (let i = 0; i <= 9; i++) {
        const a = Math.PI * (1.02 + i * 0.106);
        rs.push(circ((Math.cos(a) * 100).toFixed(1), (-14 + Math.sin(a) * 104).toFixed(1), i % 2 ? 30 : 34, h));
      }
      rs.push(ell(0, -84, 92, 36, h));
      frente = part(rs, { outer: true });
      break;
    }
    case 'afro': {
      const rs = [];
      for (let i = 0; i < 14; i++) {
        const a = Math.PI * (0.86 + i * 0.1);
        rs.push(circ((Math.cos(a) * 136).toFixed(1), (-26 + Math.sin(a) * 130).toFixed(1), 40, h));
      }
      rs.push(ell(0, -40, 136, 128, h));
      atras = part(rs, { outer: true });
      frente = part([path('M-100 -6 C-104 -70 -60 -98 0 -98 C60 -98 104 -70 100 -6 C90 -40 60 -60 0 -62 C-60 -60 -90 -40 -100 -6 Z', h)], { sw: 2.6 });
      break;
    }
    case 'calvo':
      frente = part([path('M-104 10 C-110 -20 -104 -40 -94 -50 C-90 -30 -88 -10 -88 10 Z', h), path('M104 10 C110 -20 104 -40 94 -50 C90 -30 88 -10 88 10 Z', h)], { sw: 2.4 });
      extra = pencilLines(['M-30 -84 Q-10 -90 6 -86'], { sw: 2.2, color: '#9a6a50', op: 0.5 });
      break;
    case 'jesus':
      orejas = false;
      atras = part([path('M-118 -20 C-126 -140 126 -140 118 -20 L126 150 C110 168 84 168 66 158 L-66 158 C-84 168 -110 168 -126 150 Z', h)]);
      frente = part([path('M-114 70 C-122 -60 -76 -128 0 -128 C76 -128 122 -60 114 70 C102 10 66 -80 4 -96 L-4 -96 C-66 -80 -102 10 -114 70 Z', h)]);
      extra = pencilLines(['M-8 -118 Q-60 -110 -96 -30', 'M8 -118 Q60 -110 96 -30', 'M-106 20 Q-110 70 -104 130', 'M106 20 Q110 70 104 130'], { sw: 2.2, color: '#9a6a50', op: 0.55 });
      break;
    case 'largo':
      orejas = false;
      atras = part([path('M-122 -20 C-128 -140 128 -140 122 -20 L134 236 C120 246 98 246 88 238 C78 180 66 124 62 90 L-62 90 C-66 124 -78 180 -88 238 C-98 246 -120 246 -134 236 Z', h)]);
      frente = part([path('M-114 50 C-124 -96 -40 -132 12 -128 C84 -124 122 -80 114 50 C104 0 92 -46 52 -80 C18 -40 -48 -40 -96 -16 C-104 4 -110 26 -114 50 Z', h)]);
      extra = pencilLines(['M-40 -110 Q30 -126 86 -84', 'M-112 80 Q-118 150 -110 224', 'M112 80 Q118 150 110 224'], { sw: 2.2, color: '#9a6a50', op: 0.5 });
      break;
    case 'ondulado': {
      orejas = false;
      const rs = [path('M-124 -20 C-130 -140 130 -140 124 -20 L130 210 C116 226 96 226 86 214 C78 170 66 124 62 90 L-62 90 C-66 124 -78 170 -86 214 C-96 226 -116 226 -130 210 Z', h)];
      for (let y = 20; y <= 220; y += 44) {
        rs.push(circ(-128 - (y % 88 ? 6 : 0), y, 28, h), circ(128 + (y % 88 ? 6 : 0), y, 28, h));
      }
      atras = part(rs, { outer: true });
      frente = part([path('M-114 44 C-122 -96 -40 -132 8 -128 C80 -124 122 -84 114 44 C104 -4 84 -56 40 -80 C10 -50 -50 -56 -96 -20 C-104 0 -110 20 -114 44 Z', h)]);
      extra = pencilLines(['M-118 70 Q-104 100 -122 130 Q-140 160 -120 190', 'M118 70 Q104 100 122 130 Q140 160 120 190'], { sw: 2.2, color: '#9a6a50', op: 0.5 });
      break;
    }
    case 'bob':
      orejas = false;
      atras = part([path('M-122 -20 C-128 -140 128 -140 122 -20 L128 92 C100 106 -100 106 -128 92 Z', h)]);
      frente = part([path('M-116 60 C-128 -150 128 -150 116 60 L100 60 L100 -36 C60 -26 -60 -26 -100 -36 L-100 60 Z', h)]);
      extra = pencilLines(['M-60 -52 L-58 -32', 'M-20 -56 L-20 -30', 'M20 -56 L20 -30', 'M60 -52 L58 -32'], { sw: 2, color: '#9a6a50', op: 0.45 });
      break;
    case 'cola':
      atras = part([path('M96 -40 C150 -60 176 10 160 90 C150 140 120 150 112 120 C130 70 128 10 96 -10 Z', h)]);
      frente = part([path('M-106 10 C-116 -100 -50 -132 4 -130 C66 -128 116 -96 106 10 C100 -44 80 -70 40 -80 C10 -64 -40 -66 -76 -56 C-96 -40 -104 -20 -106 10 Z', h)]);
      extra = pencilLines(['M-40 -114 Q20 -128 80 -96'], { sw: 2.2, color: '#9a6a50', op: 0.5 });
      break;
    case 'chongo':
      atras = part([circ(0, -136, 46, h)]);
      frente = part([path('M-106 10 C-116 -100 -50 -124 0 -124 C50 -124 116 -100 106 10 C100 -40 70 -74 0 -78 C-70 -74 -100 -40 -106 10 Z', h)]);
      extra = pencilLines(['M-60 -100 Q0 -90 60 -100', 'M-24 -160 Q0 -150 24 -160'], { sw: 2.2, color: o.pelo === PELO.canas ? '#8a8f96' : '#9a6a50', op: 0.5 });
      break;
    case 'trenzas': {
      orejas = false;
      atras = part([path('M-118 -20 C-126 -136 126 -136 118 -20 L112 60 L-112 60 Z', h)]);
      const tr = [];
      for (const s of [-1, 1]) for (let i = 0; i < 6; i++) tr.push(ell(s * (106 + i * 2), 64 + i * 34, 22, 20, h));
      frente = part([path('M-114 60 C-122 -96 -60 -128 0 -128 C60 -128 122 -96 114 60 C104 0 62 -84 4 -96 L-4 -96 C-62 -84 -104 0 -114 60 Z', h)]) + part(tr) +
        part([circ(-116, 270, 10, C.tomato), circ(116, 270, 10, C.tomato)], { sw: 2.4 });
      break;
    }
    case 'puff':
      atras = part([circ(-110, -96, 52, h), circ(110, -96, 52, h)], { outer: false });
      frente = part([path('M-104 0 C-110 -96 -50 -120 0 -120 C50 -120 110 -96 104 0 C96 -48 64 -74 0 -78 C-64 -74 -96 -48 -104 0 Z', h)], { sw: 2.6 });
      break;
  }

  // Cuello, orejas y cara
  const cuello = o.sinCuello ? '' : part([capsule(0, 70, 0, 170, 62, p)]);
  const caraFormas = [];
  if (orejas) caraFormas.push(ell(-100, 14, 17, 25, p), ell(100, 14, 17, 25, p));
  caraFormas.push(ell(0, 0, 100, 102, p));
  let cara = cuello + part(caraFormas);

  // Rasgos
  const ojoX = 42, ojoY = 12;
  let rasgos = `<g opacity="0.55">${ell(-68, 50, 18, 11, C.blush)}${ell(68, 50, 18, 11, C.blush)}</g>`;
  rasgos += pencilLines([`M${-ojoX - 17} -22 Q${-ojoX} -31 ${-ojoX + 17} -23`, `M${ojoX - 17} -23 Q${ojoX} -31 ${ojoX + 17} -22`], { sw: 4, color: ceja, op: 0.95 });
  if (o.ojos === 'felices') {
    rasgos += pencilLines([`M${-ojoX - 13} ${ojoY + 4} Q${-ojoX} ${ojoY - 10} ${-ojoX + 13} ${ojoY + 4}`, `M${ojoX - 13} ${ojoY + 4} Q${ojoX} ${ojoY - 10} ${ojoX + 13} ${ojoY + 4}`], { sw: 4.2, color: C.ink, op: 1 });
  } else if (o.ojos === 'cerrados') {
    rasgos += pencilLines([`M${-ojoX - 13} ${ojoY} Q${-ojoX} ${ojoY + 9} ${ojoX * 0 - ojoX + 13} ${ojoY}`, `M${ojoX - 13} ${ojoY} Q${ojoX} ${ojoY + 9} ${ojoX + 13} ${ojoY}`], { sw: 4, color: C.ink, op: 1 });
  } else {
    rasgos += circ(-ojoX, ojoY, 8, C.ink) + circ(ojoX, ojoY, 8, C.ink) + circ(-ojoX + 2.6, ojoY - 2.8, 2.6, '#ffffff') + circ(ojoX + 2.6, ojoY - 2.8, 2.6, '#ffffff');
  }
  rasgos += pencilLines(['M6 26 Q-10 42 4 48'], { sw: 3, color: '#8a5a40', op: 0.8 });

  // Barba / bigote (van antes de la boca para que la sonrisa se lea encima)
  let barba = '';
  const hb = h === PELO.canas ? C.steel : h;
  if (o.barba === 'completa' || o.barba === 'jesus') {
    barba = part([
      path('M-101 8 C-104 92 -56 142 0 142 C56 142 104 92 101 8 L86 8 C84 46 64 70 36 76 C22 66 -22 66 -36 76 C-64 70 -84 46 -86 8 Z', hb),
      path('M-40 66 C-26 52 -8 56 0 62 C8 56 26 52 40 66 C26 68 10 68 0 70 C-10 68 -26 68 -40 66 Z', hb),
    ], { sw: 3 });
  } else if (o.barba === 'bigote') {
    barba = part([path('M-44 66 C-30 50 -8 54 0 60 C8 54 30 50 44 66 C28 70 10 68 0 70 C-10 68 -28 70 -44 66 Z', hb)], { sw: 2.8 });
  } else if (o.barba === 'candado') {
    barba = part([
      path('M-40 66 C-26 52 -8 56 0 62 C8 56 26 52 40 66 C26 68 10 68 0 70 C-10 68 -26 68 -40 66 Z', hb),
      path('M-36 70 C-40 96 -24 122 0 124 C24 122 40 96 36 70 L26 74 C26 92 14 102 0 102 C-14 102 -26 92 -26 74 Z', hb),
    ], { sw: 2.8 });
  } else if (o.barba === 'corta') {
    const r = rng(7), pts = [];
    while (pts.length < 120) {
      const x = (r() * 2 - 1) * 98, y = 40 + r() * 62;
      const dentroCara = (x / 100) ** 2 + (y / 102) ** 2 < 0.92;
      const fueraBoca = !(Math.abs(x) < 40 && y > 60 && y < 90) && !(Math.abs(x) < 86 && y < 62);
      if (dentroCara && fueraBoca) pts.push(circ(x.toFixed(1), y.toFixed(1), 1.6, hb));
    }
    barba = `<g opacity="0.7">${pts.join('')}</g>`;
  }

  let boca;
  if (o.boca === 'abierta') {
    boca = part([path('M-24 78 Q0 104 24 78 Q0 84 -24 78 Z', '#8e2f28')], { sw: 2.6 }) + path('M-16 81 Q0 85 16 81 L14 86 Q0 89 -14 86 Z', '#fbf7ee');
  } else if (o.barba === 'completa' || o.barba === 'jesus' || o.barba === 'candado') {
    // sobre la barba la línea sola se pierde: labio relleno
    boca = part([path('M-20 77 Q0 96 20 77 Q0 85 -20 77 Z', C.tomato)], { sw: 2.4 });
  } else {
    boca = pencilLines(['M-18 78 Q0 92 18 78'], { sw: 4.2, color: BOCA, op: 1 });
  }

  let lentes = '';
  if (o.lentes === 'redondos') {
    lentes = pencilLines([`M${-ojoX + 26} ${ojoY} A26 26 0 1 0 ${-ojoX - 26} ${ojoY} A26 26 0 1 0 ${-ojoX + 26} ${ojoY}`, `M${ojoX + 26} ${ojoY} A26 26 0 1 0 ${ojoX - 26} ${ojoY} A26 26 0 1 0 ${ojoX + 26} ${ojoY}`, `M${-ojoX + 26} ${ojoY - 4} Q0 ${ojoY - 12} ${ojoX - 26} ${ojoY - 4}`], { sw: 4.2, color: C.ink, op: 0.95 });
  } else if (o.lentes === 'cuadrados') {
    lentes = pencilLines([`M${-ojoX - 28} ${ojoY - 20} H${-ojoX + 28} V${ojoY + 18} H${-ojoX - 28} Z`, `M${ojoX - 28} ${ojoY - 20} H${ojoX + 28} V${ojoY + 18} H${ojoX - 28} Z`, `M${-ojoX + 28} ${ojoY - 6} H${ojoX - 28}`], { sw: 4.2, color: C.navy, op: 0.95 });
  }
  const aretes = o.aretes ? circ(-101, 44, 7, C.mustard) + circ(101, 44, 7, C.mustard) : '';

  return { atras, cabeza: cara + rasgos + barba + boca + aretes + frente + extra + lentes };
}

// ---------- Busto para avatares (mismas coordenadas locales que la cabeza) ----------
// El cuello va dentro del busto y la ropa lo tapa con su escote, así la cabeza
// (con su borde de sticker) queda encima como en Timoteo.
export function busto(o) {
  const ropa = o.ropa;
  const hombro = (escote) => `M-190 330 C-190 196 -130 150 -58 140 ${escote} C130 150 190 196 190 330 Z`;
  const cuello = part([path('M-31 40 L31 40 L34 210 L-34 210 Z', o.piel)]);
  const camiseta = (color, dip = 176) => part([path(`M-66 140 Q0 ${dip} 66 140 L66 260 L-66 260 Z`, color)], { sw: 2.6 });
  switch (o.prenda) {
    case 'camisa':
      return cuello + camiseta(C.paper) + part([path(hombro('L0 200 L58 140'), ropa)]) +
        part([path('M-62 136 L-4 200 L-30 216 L-80 158 Z', ropa), path('M62 136 L4 200 L30 216 L80 158 Z', ropa)], { sw: 2.8 }) +
        circ(0, 240, 5, C.steelLight) + circ(0, 290, 5, C.steelLight);
    case 'playera':
      return cuello + part([path(hombro('Q0 196 58 140'), ropa)]) +
        pencilLines(['M-54 142 Q0 194 54 142'], { sw: 5, color: C.paper, op: 0.85 });
    case 'sudadera':
      return part([path('M-124 156 C-112 104 112 104 124 156 L92 186 L-92 186 Z', ropa)]) + cuello +
        part([path(hombro('Q0 190 58 140'), ropa)]) +
        pencilLines(['M-24 178 L-28 254', 'M24 178 L28 254'], { sw: 4, color: C.paper, op: 0.95 });
    case 'sueter':
      return cuello + camiseta(C.paper) + part([path(hombro('L0 216 L58 140'), ropa)]) +
        pencilLines(['M-52 146 L0 222 L52 146'], { sw: 6, color: C.cream, op: 0.8 });
    case 'blusa':
      return cuello + part([path(hombro('Q0 206 58 140'), ropa)]) +
        pencilLines(['M-54 144 Q0 204 54 144'], { sw: 4, color: C.cream, op: 0.85 }) +
        (o.cruz ? part([path('M-5 186 H5 V194 H14 V203 H5 V224 H-5 V203 H-14 V194 H-5 Z', C.mustard)], { sw: 1.8 }) : '');
    case 'overol':
      return cuello + part([path(hombro('Q0 190 58 140'), ropa)]) +
        part([path('M-112 330 L-98 214 L-76 214 L-72 252 L72 252 L76 214 L98 214 L112 330 Z', o.interior || C.ultra)], { sw: 3 }) +
        part([capsule(-87, 214, -70, 150, 18, o.interior || C.ultra), capsule(87, 214, 70, 150, 18, o.interior || C.ultra)], { sw: 2.6 }) +
        circ(-84, 226, 6, C.mustard) + circ(84, 226, 6, C.mustard);
  }
  return cuello + part([path(hombro('Q0 190 58 140'), ropa)]);
}

// Avatar redondo (512x512) como timoteo_avatar / victoria_avatar
export function avatar(o, seed) {
  const s = 1.08, cx = 256, cy = 250;
  const { atras, cabeza: cab } = cabeza({ ...o, sinCuello: true });
  const personaje = sticker(T(0, -22, 1, busto(o))) + sticker(atras + cab);
  const body = `
    <defs>
      <clipPath id="disco"><circle cx="256" cy="256" r="230"/></clipPath>
      <filter id="sombraAro" x="-10%" y="-10%" width="120%" height="125%">
        <feGaussianBlur in="SourceAlpha" stdDeviation="2.4"/><feOffset dy="3" result="b"/>
        <feFlood flood-color="rgb(74,48,22)" flood-opacity="0.28"/><feComposite in2="b" operator="in"/>
        <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
    </defs>
    <circle cx="256" cy="256" r="230" fill="${o.fondo}"/>
    <g clip-path="url(#disco)">${T(cx, cy, s, personaje)}</g>
    <path fill-rule="evenodd" filter="url(#sombraAro)" fill="${C.paper}" d="M256 4 A252 252 0 1 1 255.9 4 Z M256 28 A228 228 0 1 0 256.1 28 Z"/>`;
  return svgDoc(512, 512, body, seed, { border: 10 });
}
