# Usar el estilo en Flutter

1. Crea tu app (si no la tienes): `flutter create mi_app`
2. Copia el kit a tu proyecto:
   - Windows (PowerShell, desde esta carpeta `flutter`): `.\copiar_assets.ps1 -Proyecto "C:\ruta\a\mi_app"`
   - macOS/Linux: `sh copiar_assets.sh /ruta/a/mi_app`
   Esto copia `assets/vec/...` (personajes, objetos, fondos, texturas, íconos y fuentes) y `lib/vec/*.dart`.
3. Pega el contenido de `pubspec_fragmento.yaml` en tu `pubspec.yaml` (sección `flutter:`) y corre `flutter pub get`.
4. Prueba la pantalla de ejemplo: `flutter run -t lib/main_demo.dart`
5. En tu app: `MaterialApp(theme: vecTema(), ...)` y usa los widgets de `lib/vec/vec_widgets.dart`.

## Qué trae `lib/vec`
| Archivo | Contenido |
|---|---|
| `vec_tema.dart` | `VecColores`, `VecFuentes`, `VecSombras`, `VecRadios`, `VecMovimiento` y `vecTema()` |
| `vec_widgets.dart` | `FondoPapel`, `TarjetaPapel` (con cinta), `TarjetaVersiculo`, `ChipVec`, `BotonVec` (se hunde al tocarlo), `Subtitulo`, `Globo`, `Sticker`, `PopIn` (aparece con rebote) |

## Notas
- Los PNG de `personajes/` y `objetos/` ya traen su borde blanco y su sombra: úsalos tal cual con `Image.asset` o `Sticker(...)`.
- Para los íconos SVG instala `flutter_svg` (`flutter pub add flutter_svg`) y pásalos a `ChipVec(iconoWidget: SvgPicture.asset(...))`. Están dibujados con `currentColor`, así que toman el color que les pongas.
- Las fuentes incluidas son el subconjunto latino (acentos, ñ, ¿ ¡). Si necesitas otros idiomas, descarga la familia completa de Google Fonts.
- Este código está escrito para Flutter 3.22 o más nuevo (usa `WidgetStateProperty` y records de Dart 3). No lo compilé aquí: si tu versión marca algo, pégale el error a Copilot/Claude junto con `PROMPT.md`.
