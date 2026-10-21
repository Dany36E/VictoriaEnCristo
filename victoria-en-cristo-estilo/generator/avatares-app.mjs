// Catálogo de avatares de perfil (10 hombre + 10 mujer).
import { avatar, PIEL, PELO } from './personajes-app.mjs';
import { C } from './papel-recortado.mjs';

const F = { celeste: '#bcd6e6', mostaza: C.mustardLight, salvia: C.sage, rubor: C.blush, agua: C.tealLight };
const R = { azul: '#3d6890', azulClaro: '#4f7fa8', terracota: '#c8553d', mostaza: C.mustard, verde: C.teal, noche: '#2f4a68', olivo: C.olive, tomate: C.tomato, salvia: C.sage, kraft: C.kraft };

export const AVATARES = [
  // ---- hombres ----
  { id: 'h01', piel: PIEL.morena, pelo: PELO.negro, peinado: 'corto', ojos: 'felices', prenda: 'camisa', ropa: R.azulClaro, fondo: F.celeste },
  { id: 'h02', piel: PIEL.clara, pelo: PELO.castano, peinado: 'lado', barba: 'corta', ojos: 'abiertos', prenda: 'sueter', ropa: R.verde, fondo: F.mostaza },
  { id: 'h03', piel: PIEL.oscura, pelo: PELO.negro, peinado: 'rizado', ojos: 'felices', prenda: 'playera', ropa: R.mostaza, fondo: F.salvia },
  { id: 'h04', piel: PIEL.canela, pelo: PELO.negro, peinado: 'rapado', barba: 'completa', ojos: 'felices', prenda: 'sudadera', ropa: R.terracota, fondo: F.celeste },
  { id: 'h05', piel: PIEL.media, pelo: PELO.canas, peinado: 'calvo', barba: 'completa', lentes: 'redondos', ojos: 'felices', prenda: 'sueter', ropa: R.noche, fondo: F.rubor },
  { id: 'h06', piel: PIEL.clara, pelo: PELO.rubio, peinado: 'corto', lentes: 'cuadrados', ojos: 'abiertos', prenda: 'camisa', ropa: R.salvia, fondo: F.agua },
  { id: 'h07', piel: PIEL.oscura, pelo: PELO.negro, peinado: 'afro', barba: 'candado', ojos: 'felices', prenda: 'camisa', ropa: R.terracota, fondo: F.agua },
  { id: 'h08', piel: PIEL.morena, pelo: PELO.negro, peinado: 'lado', barba: 'bigote', ojos: 'abiertos', prenda: 'playera', ropa: R.noche, fondo: F.mostaza },
  { id: 'h09', piel: PIEL.clara, pelo: PELO.cobrizo, peinado: 'rizado', barba: 'corta', ojos: 'felices', prenda: 'overol', ropa: R.mostaza, interior: R.azul, fondo: F.celeste },
  { id: 'h10', piel: PIEL.media, pelo: PELO.castano, peinado: 'corto', barba: 'candado', lentes: 'redondos', ojos: 'felices', prenda: 'sudadera', ropa: R.verde, fondo: F.rubor },
  // ---- mujeres ----
  { id: 'm01', piel: PIEL.media, pelo: PELO.castano, peinado: 'largo', aretes: true, ojos: 'felices', prenda: 'blusa', ropa: R.terracota, cruz: true, fondo: F.mostaza },
  { id: 'm02', piel: PIEL.clara, pelo: PELO.castano, peinado: 'cola', aretes: true, ojos: 'abiertos', prenda: 'playera', ropa: R.azulClaro, fondo: F.rubor },
  { id: 'm03', piel: PIEL.morena, pelo: PELO.negro, peinado: 'chongo', aretes: true, ojos: 'felices', prenda: 'sueter', ropa: R.mostaza, fondo: F.celeste },
  { id: 'm04', piel: PIEL.clara, pelo: PELO.negro, peinado: 'bob', lentes: 'redondos', ojos: 'felices', prenda: 'blusa', ropa: R.verde, fondo: F.mostaza },
  { id: 'm05', piel: PIEL.clara, pelo: PELO.cobrizo, peinado: 'ondulado', ojos: 'felices', prenda: 'sueter', ropa: R.noche, fondo: F.rubor },
  { id: 'm06', piel: PIEL.oscura, pelo: PELO.negro, peinado: 'trenzas', ojos: 'felices', prenda: 'overol', ropa: R.mostaza, interior: R.azul, fondo: F.salvia },
  { id: 'm07', piel: PIEL.canela, pelo: PELO.negro, peinado: 'puff', aretes: true, ojos: 'felices', prenda: 'blusa', ropa: R.tomate, fondo: F.celeste },
  { id: 'm08', piel: PIEL.clara, pelo: PELO.canas, peinado: 'chongo', lentes: 'cuadrados', ojos: 'felices', prenda: 'blusa', ropa: R.salvia, cruz: true, fondo: F.mostaza },
  { id: 'm09', piel: PIEL.clara, pelo: PELO.rubio, peinado: 'largo', aretes: true, ojos: 'abiertos', prenda: 'camisa', ropa: R.azulClaro, fondo: F.salvia },
  { id: 'm10', piel: PIEL.canela, pelo: PELO.negro, peinado: 'ondulado', aretes: true, ojos: 'felices', prenda: 'sudadera', ropa: R.mostaza, fondo: F.agua },
];

export const avatarItems = AVATARES.map((a, i) => ({ name: `avatar_${a.id}`, svg: avatar(a, 100 + i * 3) }));
