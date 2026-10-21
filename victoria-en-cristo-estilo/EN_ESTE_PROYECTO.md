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
