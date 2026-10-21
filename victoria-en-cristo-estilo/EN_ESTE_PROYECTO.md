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

Dibujados con el mismo generador (`generator/personajes-app.mjs`, `avatares-app.mjs`; se renderizan con `renderizar-app.mjs`):

- **Jesús** (túnica blanca con banda roja y aureola) en 4 poses: `jesus_saludo`, `jesus_presenta`, `jesus_brazos`, `jesus_corazon`. Lo usa la tarjeta «días de victoria» del Inicio en el tema papel.
- **20 avatares de perfil** (`avatar_h01`…`avatar_h10`, `avatar_m01`…`avatar_m10`). El usuario los elige en Mi Perfil; la elección se guarda en `profile_avatar_id` (`AvatarPerfilService`) y se sincroniza con la nube.

Están en `assets/vec/personajes/` como WebP (los avatares a 384 px) para que la app pese menos.
