# Kit de estilo «papel recortado» — Victoria en Cristo

Todo lo necesario para que una app (Flutter o web) se vea como los videos de Timoteo y Victoria:
papel crema con textura, recortes con borde blanco, contorno de lápiz, cinta adhesiva, chips de colores y movimientos con rebote.

**Empieza aquí:** abre `PROMPT.md` y copia el prompt en Copilot / Claude Code / Cursor con esta carpeta dentro de tu proyecto.
Para ver cómo se ve, abre `web/demo.html` en Chrome o mira `vista-previa.png`.

## Contenido

| Carpeta / archivo | Qué es |
|---|---|
| `PROMPT.md` | El texto que le tienes que decir a la IA (versión larga y corta) |
| `vista-previa.png` | Cómo debe verse (pantalla de ejemplo) |
| `web/vec-estilo.css` | Tokens (colores, letras, sombras, radios) y componentes `.vec-*` listos |
| `web/vec-tokens.json` | Los mismos tokens en JSON (para Figma Tokens, Tailwind u otra plataforma) |
| `web/filtros.svg` | Filtros SVG: `wc` (acuarela), `pen` (lápiz), `sticker` (borde blanco + sombra), `wob` (tembladito) |
| `web/demo.html` | Pantalla de demostración con todos los componentes |
| `flutter/` | Tema y widgets para Flutter + scripts para copiar los assets (ver `flutter/LEEME_FLUTTER.md`) |
| `fonts/` | Lilita One, Patrick Hand y Caveat Brush (`.woff2` para web, `.ttf` para apps) con su licencia OFL |
| `assets/personajes/` | Timoteo y Victoria en 8 poses cada uno + avatares redondos |
| `assets/objetos/` | Biblia, corazones, sobre, carta, calendario, luna, reloj de arena, cruz, etc. y 4 escenas (panadería, auto de noche, sillón, playa) |
| `assets/fondos/` | Parque, cafetería y papel (1080×1920) |
| `assets/texturas/papel_tile_512.png` | Textura de papel que se repite sin costuras |
| `assets/iconos/` | 26 íconos SVG del estilo (cruz, biblia, corazón, orar, iglesia, mensaje, casa…) con `currentColor` |
| `generator/` | Para crear ilustraciones nuevas en el mismo estilo (ver abajo) |

## Reglas del estilo (resumen)

1. **Fondo de papel** siempre (textura repetida), nunca plano ni blanco puro.
2. **Paleta corta:** papel `#fbf7ee`, crema `#f3ecdf`, tinta `#2b2622`, terracota `#c8553d` (principal), azul `#3d6890`, mostaza `#e0a73a`, verde `#2f7f7a`, noche `#2f4a68`, gris `#8a7a64`.
3. **Tres letras:** Lilita One (títulos, botones), Patrick Hand (texto, versículos), Caveat Brush (notas a mano).
4. **Todo es un recorte:** tarjetas un poco chuecas (±1°), sombra sólida hacia abajo + sombra cálida, cinta en la esquina.
5. **Chips y botones en píldora** de un color de la paleta con texto crema; los botones se hunden al tocarlos.
6. **Ilustraciones tipo sticker:** acuarela + contorno de lápiz + borde blanco + sombra.
7. **Movimiento con rebote** (~0.4 s), nunca lineal.
8. **Palabra clave en terracota** dentro de títulos y subtítulos.

## Crear ilustraciones nuevas

- **Sin programar:** abre `generator/laboratorio-stickers.html` en Chrome, pega figuras SVG (por ejemplo, exportadas de Figma o Inkscape con colores de la paleta) y descarga el PNG ya con acuarela, lápiz y borde.
- **Con código (Node 18+):** `generator/papel-recortado.mjs` es la misma librería con la que se dibujaron los videos. Corre `node generator/nuevo-sticker.mjs` para ver un ejemplo (crea un corazón y una cruz en SVG).
- **Textura:** `generator/textura-papel.svg` genera la textura; cambia el color del primer `rect` para hacer otra.

## Licencias

- Fuentes: SIL Open Font License 1.1 (ver `fonts/*-LICENSE.txt`). Se pueden usar en apps, también comerciales.
- Personajes, objetos y fondos: hechos para Victoria en Cristo; úsalos en tus propios proyectos.
