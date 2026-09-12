# Sistema de diseño web — Victoria en Cristo

## Propósito

La web presenta y enseña. La portada explica el sentido de la app mediante una
Biblia que se abre con el desplazamiento; `ayuda.html` documenta sus funciones
sin registrar búsquedas, elecciones ni datos personales.

## Lenguaje visual

- Azul medianoche `#061A3D`, azul profundo `#020A19` y azul camino `#0D2F5A`.
- Oro de dirección `#F2C94C`, papel `#F6F1E7` y coral de seguridad `#F06543`.
- Crimson Pro para voz editorial y Manrope para navegación e instrucciones.
- Páginas, folios, márgenes, marcadores y reglas sustituyen las tarjetas de
  producto genéricas.
- El texto se alinea a la izquierda y los titulares nunca usan un interlineado
  menor de `0.99`.

## Movimiento

La escena 3D del hero es el único movimiento narrativo no solicitado. JavaScript
convierte el recorrido del hero a un progreso de 0 a 1 y alimenta rotaciones y
traslaciones CSS. No secuestra la rueda ni incorpora scroll virtual.

Los eventos locales disponibles son:

- `victoria:book-open-start`
- `victoria:book-open-complete`
- `victoria:pathway-select`
- `victoria:tutorial-open`

No se conectan a analítica. `prefers-reduced-motion` y la ausencia de JavaScript
muestran directamente una Biblia abierta con todo el contenido disponible.

## Privacidad y rendimiento

- Sin cookies, formularios, analítica, iframes, fuentes o scripts remotos.
- CSP limitada a recursos propios; `form-action` permanece bloqueado.
- Fuentes latinas en WOFF2 y emblema WebP transparente.
- `will-change` sólo se activa mientras la escena está dentro del viewport.
- Presupuesto inicial de recursos críticos inferior a 500 KB.

## Verificación

`node scripts/capture_website_qa.mjs` captura el timeline en 0, 25, 50, 75 y
100 %, además de estados finales entre 320 y 1920 px, sin modificar la
preferencia de movimiento del sistema.
