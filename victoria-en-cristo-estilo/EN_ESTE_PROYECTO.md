# El kit dentro de Victoria en Cristo

Este kit ya está integrado en la app como el tema **«Papel recortado»** (Configuración → Apariencia).
Para no duplicar archivos pesados, aquí solo quedan la guía, el prompt, la vista previa, la versión web y el generador.

| En el kit original | Dónde vive en este proyecto |
|---|---|
| `assets/personajes`, `objetos`, `fondos`, `texturas`, `iconos` | `assets/vec/…` (declarados en `pubspec.yaml`) |
| `fonts/*.ttf` (+ licencias OFL) | `assets/vec/fuentes/` |
| `flutter/lib/vec/*.dart` | `lib/vec/` (con extensiones: `IconoVec`, `CirculoIcono`, `HojaRayada`, `AvatarVec`, `TituloVec`, `Letrero`, `EtiquetaSeccion`, `BordeConSombraVec`, `TransicionPapel`) |

Cómo se aplica en la app:

- `AppThemeData.paper` / `BibleReaderThemeData.paper` usan `VecColores`.
- `AppTheme.paperTheme` parte de `vecTema()` y lo extiende a todos los componentes de Material.
- `AppFonts` cambia Manrope/Cinzel/Lora/Crimson Pro por Lilita One y Patrick Hand cuando el tema activo es papel.
- Las pantallas con diseño propio revisan `AppThemeData.of(context).isPaper` y usan los widgets de `lib/vec`.

Para pantallas nuevas, usa el «prompt corto» de `PROMPT.md`.

## Personajes propios de la app

Dibujados con el mismo generador (`generator/jesus-app.mjs`, `fondos-racha-app.mjs`, `personajes-app.mjs` + `avatares-app.mjs`; se renderizan con `renderizar-app.mjs`):

- **Jesús** (pelo ondulado con raya al centro, barba, túnica blanca con banda roja) en los mismos estados que los sprites del tema normal: `jesus_nuevo` (con un corderito), `jesus_esperando`, `jesus_animo`, `jesus_perdida`, `jesus_victoria`, `jesus_semana`, `jesus_mes`, `jesus_centurion`, `jesus_anio`.
- **8 escenas de racha** (`assets/vec/fondos/racha_*.webp`): listo (0), pradera (1+), cielo (3+), atardecer (7+), noche (14+), batalla (30+), armadura (100+), guardia (365+).
- `JesusWidgetService.getSprite/getBackground(papel: true)` eligen el dibujo y la escena; los usan la tarjeta «días de victoria», la celebración y el widget de inicio de Android cuando el tema activo es papel.
- **20 avatares de perfil** (`avatar_h01`…`avatar_h10`, `avatar_m01`…`avatar_m10`). El usuario los elige en Mi Perfil; la elección se guarda en `profile_avatar_id` (`AvatarPerfilService`) y se sincroniza con la nube.

Reglas de dibujo que seguimos en estos personajes:

- Las manos son solo una bolita del color de la piel: nunca dedos (ni para señalar ni para orar).
- Las proporciones de la cabeza de Jesús salen de la ilustración de referencia (pelo en cúpula, raya al centro, barba que deja ver la boca).
- Corazón, Biblia, estrellas y flama son los objetos del kit (`assets/vec/objetos`); los fondos llevan encima la textura `papel_tile_512.png`.

Todo está en WebP para que la app pese menos.
