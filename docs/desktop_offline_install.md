# Escritorio y modo offline

Victoria en Cristo puede prepararse como app de escritorio instalable usando Flutter Desktop. El objetivo recomendado es Windows primero, porque este repo ya incluye `windows/` y Firebase tiene opciones para Windows y macOS.

## Estado por plataforma

- Windows: soportado. La ventana abre maximizada, el titulo es `Victoria en Cristo` y F11 / Alt+Enter alternan pantalla completa. Escape sale de pantalla completa.
- macOS: Firebase tiene opciones declaradas, pero falta hacer QA de firma/permisos en una Mac.
- Linux: requiere regenerar `firebase_options.dart` con FlutterFire CLI para Linux antes de compilar.

## Build Windows

Requisito local: instalar Visual Studio o Visual Studio Build Tools con el workload `Desktop development with C++` y sus componentes por defecto. `flutter doctor -v` debe mostrar `Visual Studio - develop Windows apps` en verde.

```powershell
flutter pub get
./scripts/build_windows_release.ps1
```

Para generar un ZIP portable:

```powershell
./scripts/build_windows_release.ps1 -Zip
```

La carpeta resultante queda en `build/windows/x64/runner/Release`. Para distribuirla, conserva el `.exe`, la carpeta `data/` y los DLL juntos.

## Offline

Funciona sin internet después de que la app ya fue abierta y el usuario inició sesión al menos una vez en ese equipo.

Disponible offline:

- Biblia incluida en assets XML.
- Comentarios, mapas/recursos incluidos como assets locales.
- Fuentes locales bundled; no se descargan fuentes en runtime.
- Diario con cache local.
- Resaltados, notas por versículo, notas por capítulo, colecciones de versículos, versículos guardados, oraciones por versículo y preferencias de lector con cache local explícita.
- Firestore mantiene cola local de writes y sincroniza al reconectar.

Requiere internet:

- Primer login o cambio de cuenta.
- Sincronización entre dispositivos.
- Muro, Compañero de Batalla, Cloud Functions y notificaciones push.
- APIs externas o recursos remotos que no estén en assets.

## Adaptaciones desktop

- Widgets nativos de pantalla de inicio se mantienen solo en Android/iOS; en escritorio no se invoca `home_widget`.
- FCM se omite en Windows/Linux para evitar plugins moviles no disponibles.
- La pantalla de widgets muestra un estado de escritorio en computadora.
- La app conserva el comportamiento movil en Android/iOS.

## QA recomendado

1. `flutter analyze --no-pub`.
2. `flutter test --no-pub`.
3. `flutter build windows --release`.
4. Abrir `build/windows/x64/runner/Release/app_quitar.exe`.
5. Probar F11, Alt+Enter y Escape.
6. Iniciar sesion con internet, abrir Biblia, crear nota/resaltado/diario, cerrar app.
7. Cortar internet, reabrir app y confirmar que la nota/resaltado/diario siguen visibles.
8. Reconectar internet y confirmar que sincroniza sin duplicados.