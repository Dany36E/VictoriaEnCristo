# Qué decirle a la IA (Copilot, Claude Code, Cursor, v0, Lovable…)

Abre tu proyecto, pon esta carpeta del kit dentro (o adjúntala) y pega **el prompt largo** la primera vez.
Después, para cada pantalla nueva, basta con el **prompt corto**.

---

## Prompt largo (cópialo completo)

```
Quiero que TODA la interfaz de esta app use el estilo visual «papel recortado» de Victoria en Cristo.
La carpeta victoria-en-cristo-estilo/ tiene todo lo necesario: tokens, fuentes, texturas, personajes, íconos y código de ejemplo.
Lee primero victoria-en-cristo-estilo/LEEME.md y usa SIEMPRE esos recursos; no inventes colores, fuentes ni sombras nuevos.

Cómo se ve el estilo:
- Parece hecho con recortes de papel pegados sobre una hoja: fondo crema con textura de papel
  (assets/texturas/papel_tile_512.png repetido), nunca fondos planos ni blanco puro.
- Paleta (usa solo estos): papel #fbf7ee, crema #f3ecdf, tinta #2b2622 (texto, nunca negro puro),
  terracota #c8553d (color principal y palabras clave), azul #3d6890 / #4f7fa8, mostaza #e0a73a,
  verde #2f7f7a (confirmar), noche #2f4a68, gris #8a7a64 (texto secundario).
- Letras: Lilita One para títulos, botones, chips y etiquetas; Patrick Hand para texto y versículos;
  Caveat Brush solo para notas o cartas escritas a mano. Nunca fuentes del sistema.
- Tarjetas: papel #fbf7ee, esquinas de 14 px, giradas -1° a 1°, con sombra sólida hacia abajo
  (0 9px 0 rgba(43,38,34,.18)) más una sombra suave cálida (0 16px 26px rgba(74,48,22,.22)),
  y una cinta adhesiva a rayas mostaza (#e0a73a/#efc56a, rayas de 10 px a 45°) pegada en una esquina, girada ±24°.
- Chips y botones: píldoras de color sólido de la paleta, texto crema en Lilita One, ícono a la izquierda,
  sombra sólida 0 8px 0 rgba(43,38,34,.28). Los botones se hunden 5 px al tocarlos (la sombra baja a 3 px).
- Ilustraciones e íconos: estilo sticker (relleno tipo acuarela, contorno de lápiz irregular color #3a332c,
  borde blanco de 6–10 px y sombra suave). Usa los PNG de assets/personajes y assets/objetos tal cual
  (ya traen borde y sombra) y los SVG de assets/iconos (usan currentColor).
- Personajes: Timoteo (azul) y Victoria (terracota) pueden aparecer como guías en pantallas vacías,
  bienvenidas y mensajes de éxito.
- Movimiento: los elementos entran con un "pop" (escala 0.5→1 con rebote, curva cubic-bezier(.34,1.56,.64,1),
  ~420 ms) y un leve giro. Nada de transiciones lineales planas ni de más de 0.5 s. Respeta "reducir movimiento".
- Versículos: referencia en terracota (Lilita One), versión en gris pequeña (RVR1960, NTV, TLA) y el texto en Patrick Hand.

Prohibido: degradados brillantes, glassmorphism, neumorfismo, sombras grises frías o difusas sin la sombra sólida,
íconos de línea delgada estilo iOS, esquinas perfectamente rectas en tarjetas, blanco #fff y negro #000,
emojis como íconos.

Si la app es Flutter: usa victoria-en-cristo-estilo/flutter/lib/vec (vecTema(), FondoPapel, TarjetaPapel,
TarjetaVersiculo, ChipVec, BotonVec, Subtitulo, Globo, Sticker, PopIn) y sigue flutter/LEEME_FLUTTER.md.
Si es web: usa victoria-en-cristo-estilo/web/vec-estilo.css (clases .vec-*) y web/filtros.svg.
Antes de crear un componente nuevo, revisa si ya existe en esos archivos y extiéndelo en lugar de duplicarlo.
Cuando termines una pantalla, compárala con victoria-en-cristo-estilo/vista-previa.png y corrige lo que no se parezca.
```

---

## Prompt corto (para cada pantalla nueva)

```
Haz la pantalla de [describe la pantalla] con el estilo «papel recortado» de victoria-en-cristo-estilo/
(tokens y widgets de flutter/lib/vec, o web/vec-estilo.css). Fondo de papel, tarjetas con cinta, chips en píldora,
letras Lilita One / Patrick Hand y entrada con pop. Nada de colores o fuentes fuera del kit.
```

---

## Si algo sale "muy digital"

Dile exactamente qué corregir, por ejemplo:

- «Ese fondo está plano: usa FondoPapel / la clase .vec-fondo.»
- «La tarjeta no tiene la sombra sólida de abajo ni la cinta: usa TarjetaPapel.»
- «Ese ícono es de línea delgada: usa un SVG de assets/iconos o un Icon relleno dentro de un círculo de color.»
- «Ese texto está en la fuente del sistema: títulos en Lilita One, texto en Patrick Hand.»
