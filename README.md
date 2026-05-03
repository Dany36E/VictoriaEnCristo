# Victoria en Cristo

App Flutter cristiana para acompanamiento espiritual, lectura biblica, planes, diario, ejercicios de crisis, juegos biblicos, widgets nativos y comunidad moderada.

## Stack

- Flutter / Dart con Material Design 3.
- Firebase Auth, Firestore, Cloud Functions, Analytics, Crashlytics y FCM.
- Persistencia local con `shared_preferences` y cache offline de Firestore.
- Audio con `just_audio`, `audio_session` y TTS con `flutter_tts`.
- Widgets nativos con `home_widget`.
- Mapas biblicos con `flutter_map`.

## Modulos principales

- Home: racha, check-in, versiculo diario, SOS, planes, comunidad y aprendizaje.
- Victoria: registro por gigantes, umbral compuesto y flujo de gracia ante recaida.
- Biblia: lector, busqueda, notas, highlights, favoritos, comentarios, interlineal, mapas y timeline.
- Escuela del Reino: quizzes, recorridos, heroes, parabolas, libros, profecias y juegos.
- Diario y oraciones: reflexion, prompts, oraciones por categoria y seguimiento espiritual.
- Compañero de Batalla: invitaciones, mensajes, SOS de oracion y privacidad por defecto.
- Muro de Batalla: publicaciones anonimas moderadas por Cloud Functions.

## Comandos esenciales

```powershell
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter run -d <device_id>
flutter build apk --debug
flutter build apk --release
```

Windows desktop:

```powershell
./scripts/build_windows_release.ps1
./scripts/build_windows_release.ps1 -Zip
```

Cloud Functions:

```powershell
cd functions
npm ci
npm run build
npm run serve
```

Integration tests requieren dispositivo o emulador:

```powershell
flutter test integration_test/app_flow_test.dart -d <device_id>
```

## Arquitectura

- Servicios singleton con patron `.I` para estado local y operaciones de dominio.
- Repositories cloud-first para datos sincronizados por usuario.
- Sync adapters write-through para conectar acciones locales con Firestore.
- `DataBootstrapper` y `AccountSessionManager` coordinan login/logout, hidratacion cloud y limpieza segura.
- `LearningRegistry` centraliza la inicializacion de Escuela del Reino.
- `AppErrorHandler` centraliza reportes a Crashlytics y mensajes amables al usuario.
- `AppNavigation` centraliza rutas imperativas usadas por SOS, notificaciones y deep links.
- Compañero de Batalla usa Cloud Functions para invitaciones, aceptar, mensajes y SOS; las reglas bloquean creates directos en documentos sensibles.
- Desktop usa `PlatformCapabilities` para omitir plugins moviles no disponibles y mantener Windows como app maximizada/pantalla completa.

Referencia ampliada: [docs/senior_improvement_plan.md](docs/senior_improvement_plan.md).

## Flujo de calidad

Antes de subir cambios:

1. Ejecutar `flutter analyze --no-pub`.
2. Ejecutar `flutter test --no-pub`.
3. Si se tocaron Functions, ejecutar `npm --prefix functions run build`.
4. Si se tocaron assets, ejecutar `./scripts/audit_assets.ps1 -Top 30` y comparar tamano antes/despues.
5. Si se tocaron pantallas grandes, probar anchos 340, 360 y 411 px.
6. Si se tocaron flujos sensibles, revisar tono: gracia, agencia, pasos pequenos y cero verguenza.

CI ejecuta auditoria de assets, analyze, tests y build de Cloud Functions en `.github/workflows/ci.yml`.

## Assets e imagenes

- Medicion reproducible: `./scripts/audit_assets.ps1 -Top 30`.
- Headbanz PNG lossless: `./scripts/optimize_headbanz_png.ps1` revisa disponibilidad de `oxipng`/`optipng` y hace dry-run por defecto.
- Para aplicar: `./scripts/optimize_headbanz_png.ps1 -Apply`. El script crea backup en `.asset_backups/` antes de tocar imagenes.
- No usar conversion con perdida (`pngquant`, WebP, AVIF, resize) sin aprobacion explicita y QA visual lado a lado. La prioridad es que las cartas se vean igual.

## Convenciones

- Espanol para textos de producto y nombres de negocio.
- Mantener el tono pastoral, seguro y no condenatorio.
- No agregar backends fuera de Firebase sin decision explicita.
- No usar `HapticFeedback` o `AudioPlayer` directo desde pantallas: usar `FeedbackEngine` / `AudioEngine`.
- No hacer refactors masivos sin plan de QA y pruebas enfocadas.
- No escribir directamente invites/mensajes/SOS de Companero desde cliente; usar las callables `sendPartnerInvite`, `acceptPartnerInvite`, `sendBattleMessage`, `sendBattleSos`.

## Documentacion util

- [CLAUDE.md](CLAUDE.md): comandos y convenciones del proyecto.
- [TESTING_GUIDE.md](TESTING_GUIDE.md): checklist manual de feedback/audio.
- [docs/desktop_offline_install.md](docs/desktop_offline_install.md): build instalable de Windows, pantalla completa y modo offline.
- [docs/go_router_evaluation.md](docs/go_router_evaluation.md): decision sobre navegacion.
- [functions/DEPLOY.md](functions/DEPLOY.md): despliegue de Functions.
- [CONFIGURACION_FIREBASE_AUTH.md](CONFIGURACION_FIREBASE_AUTH.md): configuracion de Auth.
