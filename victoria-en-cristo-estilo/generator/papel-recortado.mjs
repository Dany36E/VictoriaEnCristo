// Utilidades compartidas: azar con semilla, filtros SVG de acuarela/lápiz/sticker y bordes rasgados.

export function rng(seed) {
  let a = seed >>> 0;
  return function () {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export const C = {
  tomato: '#d9483b', mustard: '#e0a73a', teal: '#2f7f7a', ultra: '#2f4fa8', olive: '#7c8a3c',
  sage: '#9dbb8e', blush: '#f1a9a0', cream: '#f3ecdf', paper: '#fbf7ee', kraft: '#b98f5e',
  ink: '#2b2622', pencil: '#3a332c', navy: '#1b2a4a',
  skin: '#f4cfb2', hair: '#3a2a24', tealDark: '#256a66', tealLight: '#5aa69e',
  leather: '#8a5a36', leatherDark: '#6a4128', steel: '#c4c9d0', steelLight: '#e3e6ea',
  tights: '#34405c', mustardLight: '#efc56a',
};

// Filtros: wc = relleno acuarela; pen = línea de lápiz; sticker = borde blanco + sombra.
export function filterDefs(seed = 1, { border = 10, shadow = true } = {}) {
  const s = (n) => seed * 7 + n;
  return `
  <filter id="wc" x="-8%" y="-8%" width="116%" height="116%" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="0.022" numOctaves="3" seed="${s(1)}" result="warp"/>
    <feDisplacementMap in="SourceGraphic" in2="warp" scale="5" xChannelSelector="R" yChannelSelector="G" result="shape"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="4" seed="${s(2)}" result="pig"/>
    <feColorMatrix in="pig" type="matrix" values="0.32 0 0 0 0.8  0.32 0 0 0 0.8  0.32 0 0 0 0.8  0 0 0 0 1" result="pigGray"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="${s(3)}" result="grain"/>
    <feColorMatrix in="grain" type="matrix" values="0.12 0 0 0 0.93  0.12 0 0 0 0.93  0.12 0 0 0 0.93  0 0 0 0 1" result="grainGray"/>
    <feComposite in="shape" in2="pigGray" operator="arithmetic" k1="1.04" result="tex1"/>
    <feComposite in="tex1" in2="grainGray" operator="arithmetic" k1="1.0" result="tex2"/>
    <feMorphology in="shape" operator="erode" radius="3" result="er"/>
    <feComposite in="shape" in2="er" operator="out" result="ring"/>
    <feGaussianBlur in="ring" stdDeviation="1.6" result="ringB"/>
    <feFlood flood-color="#2b2622" flood-opacity="0.22"/>
    <feComposite in2="ringB" operator="in" result="edgeDark"/>
    <feComposite in="edgeDark" in2="shape" operator="in" result="edgeIn"/>
    <feMerge><feMergeNode in="tex2"/><feMergeNode in="edgeIn"/></feMerge>
  </filter>
  <filter id="pen" x="-8%" y="-8%" width="116%" height="116%" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="0.05" numOctaves="2" seed="${s(4)}" result="w"/>
    <feDisplacementMap in="SourceGraphic" in2="w" scale="3.5" xChannelSelector="R" yChannelSelector="G" result="d"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="${s(5)}" result="g"/>
    <feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1.4 0.25" result="ga"/>
    <feComposite in="d" in2="ga" operator="in"/>
  </filter>
  <filter id="torn" x="-2%" y="-10%" width="104%" height="120%">
    <feTurbulence type="fractalNoise" baseFrequency="0.09" numOctaves="3" seed="${s(7)}" result="w"/>
    <feDisplacementMap in="SourceGraphic" in2="w" scale="9" xChannelSelector="R" yChannelSelector="G"/>
  </filter>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
    <feGaussianBlur stdDeviation="6"/>
  </filter>
  <filter id="sticker" x="-12%" y="-12%" width="124%" height="128%" color-interpolation-filters="sRGB">
    <feMorphology in="SourceAlpha" operator="dilate" radius="${border}" result="dil"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.04" numOctaves="2" seed="${s(6)}" result="tn"/>
    <feDisplacementMap in="dil" in2="tn" scale="4" xChannelSelector="R" yChannelSelector="G" result="dilW"/>
    <feGaussianBlur in="dilW" stdDeviation="0.6" result="dilS"/>
    <feFlood flood-color="#fbf7ee"/>
    <feComposite in2="dilS" operator="in" result="white"/>
    ${shadow ? `
    <feOffset in="dilS" dy="9" result="o1"/><feGaussianBlur in="o1" stdDeviation="3.5" result="b1"/>
    <feFlood flood-color="rgb(74,48,22)" flood-opacity="0.30"/><feComposite in2="b1" operator="in" result="sh1"/>
    <feOffset in="dilS" dy="2" result="o2"/><feGaussianBlur in="o2" stdDeviation="0.8" result="b2"/>
    <feFlood flood-color="#000" flood-opacity="0.20"/><feComposite in2="b2" operator="in" result="sh2"/>` : ''}
    <feMerge>${shadow ? '<feMergeNode in="sh1"/><feMergeNode in="sh2"/>' : ''}<feMergeNode in="white"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>`;
}

// Una "parte": relleno acuarela + contorno de lápiz encima.
// outer=true: solo se ve el contorno exterior del grupo (útil para pelo, nubes, humo).
export function part(shapes, { outline = true, sw = 3.4, oc = C.pencil, outer = false } = {}) {
  if (STYLE.mode === 'wc') { sw *= 0.9; oc = '#33251d'; }
  const fills = shapes.join('');
  const strokeOf = (w) => shapes.map((s) => s
    .replace(/fill="[^"]*"/g, '')
    .replace(/\/>$/, ` fill="none" stroke="${oc}" stroke-width="${w}" stroke-linejoin="round" stroke-linecap="round"/>`)).join('');
  if (outer && outline) {
    return `<g filter="url(#pen)" opacity="0.92">${strokeOf(sw * 2)}</g><g filter="url(#wc)">${fills}</g>`;
  }
  if (STYLE.mode === 'wc' && outline) return `<g filter="url(#wc)">${fills}</g><g filter="url(#pen2)" opacity="0.4">${strokeOf(sw * 0.7)}</g><g filter="url(#pen)" opacity="0.92">${strokeOf(sw)}</g>`;
  return `<g filter="url(#wc)">${fills}</g>${outline ? `<g filter="url(#pen)" opacity="0.92">${strokeOf(sw)}</g>` : ''}`;
}

export const circ = (cx, cy, r, fill) => `<circle cx="${cx}" cy="${cy}" r="${r}" fill="${fill}"/>`;
export const ell = (cx, cy, rx, ry, fill, rot = 0) => `<ellipse cx="${cx}" cy="${cy}" rx="${rx}" ry="${ry}" fill="${fill}" transform="rotate(${rot} ${cx} ${cy})"/>`;
export const path = (d, fill) => `<path d="${d}" fill="${fill}"/>`;

// Cápsula (brazo, pierna) como path relleno
export function capsule(x1, y1, x2, y2, w, fill) {
  const dx = x2 - x1, dy = y2 - y1, L = Math.hypot(dx, dy);
  const nx = (-dy / L) * (w / 2), ny = (dx / L) * (w / 2);
  const r = w / 2;
  const d = `M${x1 + nx} ${y1 + ny} L${x2 + nx} ${y2 + ny} A${r} ${r} 0 0 0 ${x2 - nx} ${y2 - ny} L${x1 - nx} ${y1 - ny} A${r} ${r} 0 0 0 ${x1 + nx} ${y1 + ny} Z`;
  return path(d, fill);
}

// Línea de lápiz suelta (sin relleno)
export function pencilLines(ds, { sw = 3.4, color = C.pencil, op = 0.9 } = {}) {
  if (STYLE.mode === 'wc' && color === C.pencil) color = '#33251d';
  return `<g filter="url(#pen)" opacity="${op}">${ds.map((d) => `<path d="${d}" fill="none" stroke="${color}" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round"/>`).join('')}</g>`;
}

// Borde superior rasgado: devuelve path de una franja desde una línea ondulada hasta abajo.
export function tornStrip(width, height, baseY, { seed = 1, amp = 40, waves = 3, jag = 5, phase = 0 } = {}) {
  const r = rng(seed);
  const pts = [];
  const step = 6;
  const ph = [r() * 6.28 + phase, r() * 6.28, r() * 6.28];
  for (let x = -20; x <= width + 20; x += step) {
    const t = x / width;
    const y = baseY
      - amp * Math.sin(t * Math.PI * waves + ph[0]) * 0.6
      - amp * 0.35 * Math.sin(t * Math.PI * waves * 2.3 + ph[1])
      - amp * 0.15 * Math.sin(t * Math.PI * waves * 5.1 + ph[2])
      + (r() - 0.5) * jag;
    pts.push([x, y]);
  }
  const top = pts.map(([x, y], i) => `${i ? 'L' : 'M'}${x.toFixed(1)} ${y.toFixed(1)}`).join(' ');
  return { d: `${top} L${width + 20} ${height + 20} L-20 ${height + 20} Z`, top: pts };
}

// Estilo: 'cut' = recorte de papel (la película); 'wc' = acuarela con tinta suelta (prueba de estilo)
export const STYLE = { mode: 'cut' };

// Acuarela: aguada transparente con orillas irregulares, pigmento acumulado en el borde, manchas y grano;
// el color corrido unos px respecto a la tinta. Tinta: línea temblorosa que a ratos se levanta.
export function filterDefsWC(seed = 1) {
  const s = (n) => seed * 7 + n;
  return `
  <filter id="wc" x="-12%" y="-12%" width="124%" height="124%" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="0.016" numOctaves="4" seed="${s(1)}" result="warp"/>
    <feDisplacementMap in="SourceGraphic" in2="warp" scale="13" xChannelSelector="R" yChannelSelector="G" result="shape0"/>
    <feOffset in="shape0" dx="3" dy="4" result="shape"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.011" numOctaves="3" seed="${s(2)}" result="blot"/>
    <feColorMatrix in="blot" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  1.0 0 0 0 0.5" result="blotA"/>
    <feColorMatrix in="blot" type="matrix" values="0.45 0 0 0 0.68  0.45 0 0 0 0.68  0.45 0 0 0 0.68  0 0 0 0 1" result="blotG"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.75" numOctaves="2" seed="${s(3)}" result="grain"/>
    <feColorMatrix in="grain" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0.9 0 0 0 0.5" result="grainA"/>
    <feComposite in="shape" in2="blotG" operator="arithmetic" k1="1.06" result="shapeV"/>
    <feComposite in="shapeV" in2="blotA" operator="in" result="s1"/>
    <feComposite in="s1" in2="grainA" operator="in" result="s2"/>
    <feMorphology in="shape" operator="erode" radius="5" result="er"/>
    <feComposite in="shape" in2="er" operator="out" result="ring"/>
    <feGaussianBlur in="ring" stdDeviation="2" result="ringB"/>
    <feComposite in="shape" in2="ringB" operator="in" result="ringC"/>
    <feColorMatrix in="ringC" type="matrix" values="0.5 0 0 0 0  0 0.5 0 0 0  0 0 0.5 0 0  0 0 0 0.75 0" result="ringDark"/>
    <feMerge><feMergeNode in="s2"/><feMergeNode in="ringDark"/></feMerge>
  </filter>
  <filter id="pen" x="-8%" y="-8%" width="116%" height="116%" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="2" seed="${s(4)}" result="w"/>
    <feDisplacementMap in="SourceGraphic" in2="w" scale="4.5" xChannelSelector="R" yChannelSelector="G" result="d"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.02" numOctaves="2" seed="${s(5)}" result="br"/>
    <feColorMatrix in="br" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  5 0 0 0 -1.35" result="brA"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" seed="${s(6)}" result="g"/>
    <feColorMatrix in="g" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1.6 0.1" result="ga"/>
    <feComposite in="d" in2="brA" operator="in" result="d2"/>
    <feComposite in="d2" in2="ga" operator="in"/>
  </filter>
  <filter id="pen2" x="-8%" y="-8%" width="116%" height="116%" color-interpolation-filters="sRGB">
    <feTurbulence type="fractalNoise" baseFrequency="0.03" numOctaves="2" seed="${s(8)}" result="w"/>
    <feDisplacementMap in="SourceGraphic" in2="w" scale="9" xChannelSelector="G" yChannelSelector="R" result="d"/>
    <feOffset in="d" dx="-2" dy="1.5" result="o"/>
    <feTurbulence type="fractalNoise" baseFrequency="0.025" numOctaves="2" seed="${s(9)}" result="br"/>
    <feColorMatrix in="br" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  6 0 0 0 -2.6" result="brA"/>
    <feComposite in="o" in2="brA" operator="in"/>
  </filter>
  <filter id="torn"><feMerge><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="soft" x="-20%" y="-20%" width="140%" height="140%"><feGaussianBlur stdDeviation="6"/></filter>
  <filter id="sticker" x="-6%" y="-6%" width="112%" height="112%" color-interpolation-filters="sRGB">
    <feComponentTransfer in="SourceAlpha" result="solid"><feFuncA type="discrete" tableValues="0 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1 1"/></feComponentTransfer>
    <feMorphology in="solid" operator="erode" radius="2" result="core"/>
    <feGaussianBlur in="core" stdDeviation="1.2" result="coreS"/>
    <feFlood flood-color="#fbf6ea"/><feComposite in2="coreS" operator="in" result="under"/>
    <feMerge><feMergeNode in="under"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>`;
}

export function svgDoc(w, h, body, seed = 1, opts = {}) {
  const defs = STYLE.mode === 'wc' ? filterDefsWC(seed) : filterDefs(seed, opts);
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"><defs>${defs}</defs>${body}</svg>`;
}
