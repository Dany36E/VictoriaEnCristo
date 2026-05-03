# Plan senior de mejora y QA

Fecha de auditoria: 2026-04-25  
Alcance: rendimiento, operacion, UX/UI, psicologia, estructura, pruebas y release.

## Estado verificado

- `flutter analyze --no-pub`: sin errores ni warnings; solo infos de doc comments con `<...>`.
- `flutter test --no-pub`: 98 tests aprobados.
- Assets: 406 archivos, aprox. 144 MB.
- Archivos Dart mas grandes detectados:
  - `lib/screens/home_screen.dart`: 1384 lineas.
  - `lib/screens/learning/game_race_screen.dart`: 1212 lineas.
  - `lib/screens/bible/bible_search_screen.dart`: 1193 lineas.
  - `lib/screens/bible/bible_map_screen.dart`: 1120 lineas.
  - `lib/screens/settings_screen.dart`: 1017 lineas.
- CI ya existe en `.github/workflows/ci.yml` con auditoria de assets, analyze, tests y build de Functions.
- No hay herramientas locales de compresion de imagen instaladas (`magick`, `cwebp`, `optipng`, `pngquant`).
- El workspace tenia cambios previos en multiples archivos de learning/audio/pubspec; los cambios de este plan evitan pisarlos.

## Principios de ejecucion

1. No tocar cambios previos no relacionados sin revisarlos y sin necesidad clara.
2. Priorizar mejoras con alto impacto y bajo riesgo antes de refactors amplios.
3. Cada mejora debe tener verificacion objetiva: analyzer, tests, build, medicion o checklist QA.
4. Los cambios de UX psicologicamente sensibles deben preferir lenguaje de gracia, agencia y pasos pequenos.
5. Los refactors grandes se hacen por feature flags o extracciones pequenas, nunca en un solo bloque masivo.

## Decision por recomendacion

| Area | Recomendacion | Decision | Estado | Verificacion |
| --- | --- | --- | --- | --- |
| Rendimiento | Reducir peso de assets | Necesario | En progreso | Medir MB antes/despues, optimizacion lossless, smoke visual de imagenes, `flutter test` |
| Rendimiento | Revisar carga del modulo biblico | Necesario | Fase 3 | DevTools memory profile, prueba multi-version, analyzer |
| Rendimiento | Medir startup por servicio | Necesario | Fase 2 | Logs por fase + primer frame percibido |
| Estructura | Dividir pantallas monoliticas | Necesario | Fase 3 | Refactor por pantalla con tests de render/overflow |
| Estructura | Centralizar navegacion ligera | Necesario | En progreso | Deep links, notificaciones, widget native routes |
| Operacion | Agregar CI | Necesario | Fase 1 | GitHub Actions: analyze, tests, Functions build |
| Operacion | Actualizar README | Necesario | Fase 1 | README refleja comandos, arquitectura y QA |
| Operacion | Usar mas `AppErrorHandler` | Necesario | En progreso | Errores visibles y Crashlytics non-fatal clasificado |
| Operacion | Fortalecer limites server-side | Necesario | En progreso | Emulator tests/QA manual de abuso |
| UX/UI | Reducir densidad del Home | Necesario | Fase 3 | Test visual 340/411px, UX review, no overflow |
| UX/UI | Settings mas escaneable | Necesario | Fase 3 | Tests de render por seccion, QA de toggles |
| UX/UI | Feedback consistente | Necesario | Fase 1 | Analyzer + QA toggles haptics/SFX |
| Psicologia | Expandir enfoque de gracia | Necesario | Fase 2 | Content review con checklist de tono |
| Psicologia | Revisar lenguaje de guerra/verguenza | Necesario | Fase 2 | Content audit, reemplazos graduales |
| Psicologia | Mejorar escalacion SOS | Necesario | Fase 2 | QA crisis flow, accesibilidad, partner path |
| Contenido | Mover contenido hardcodeado a JSON | Conveniente | Fase 4 | Tests de schema/longitud, migracion gradual |

## Fase 1: base de calidad inmediata

Objetivo: dejar el proyecto mejor protegido sin tocar comportamiento amplio.

### 1. CI minimo

Acciones:
- Crear `.github/workflows/ci.yml`.
- Ejecutar `flutter pub get`, `flutter analyze --no-pub`, `flutter test --no-pub`.
- Ejecutar `npm ci` y `npm run build` en `functions/`.

Criterios QA:
- El workflow no requiere emulador ni secretos.
- No ejecuta integration tests por defecto.
- Falla si TypeScript de Functions no compila.

### 2. README operativo

Acciones:
- Reemplazar README plantilla por documentacion real del proyecto.
- Incluir comandos, arquitectura, pruebas, Firebase, assets y convenciones.

Criterios QA:
- Un dev nuevo debe poder correr analyze/test/build sin buscar en otros archivos.
- Documenta que integration tests requieren dispositivo/emulador.

### 3. Feedback SOS consistente

Acciones:
- Reemplazar `HapticFeedback.heavyImpact()` directo del boton SOS por `FeedbackEngine.I.confirm()`.

Criterios QA:
- Respeta toggles de haptics/SFX.
- No cambia navegacion ni texto del boton.

## Fase 2: mejoras de producto y observabilidad

### 4. Preparar optimizacion de assets

Acciones implementadas/propuestas:
- Mantener medicion con `scripts/audit_assets.ps1` y CI.
- Preparar `scripts/optimize_headbanz_png.ps1` con dry-run por defecto, backup y solo optimizacion PNG lossless (`oxipng`/`optipng`).
- No usar compresion con perdida ni conversion de formato sin aprobacion explicita y comparacion visual.
- Revisar BGM duplicados y mover contenido avanzado no esencial a descarga opcional en una fase posterior.

Criterios QA:
- Snapshot visual de al menos 5 cartas antes/despues.
- Reduccion objetivo inicial: lo que permita lossless sin degradacion visible; cualquier compresion con perdida requiere aprobacion aparte.
- `flutter analyze` y test de render de `GameHeadbanzScreen`.

### 5. Instrumentar startup

Acciones propuestas:
- Agregar logs por subfase en `main.dart`: Firebase, Fase 1, scoring, bootstrap, post-frame services.
- Evitar enviar metricas sensibles; solo duraciones.

Criterios QA:
- Logs muestran cada bloque con ms.
- No cambia orden de inicializacion.

### 6. AppErrorHandler extendido

Acciones propuestas:
- Migrar errores repetidos de sync/audio/download a `AppErrorHandler`.
- Definir mensajes amables para usuario solo cuando la accion falla de forma visible.

Criterios QA:
- Crashlytics recibe non-fatal con `where`.
- No aparecen snackbars por fallos silenciosos de background.

### 7. SOS psicologicamente reforzado

Acciones propuestas:
- Agregar paso de regulacion corporal breve.
- Agregar accion rapida hacia companero si existe.
- Agregar mensaje de ayuda profesional en caso de riesgo grave, sin alarmismo.

Criterios QA:
- Flujo sigue siendo usable en menos de 60 segundos.
- Textos no culpan ni humillan.
- Accesible con lector de pantalla.

## Fase 3: refactors con bajo riesgo incremental

### 8. Home por secciones

Acciones propuestas:
- Extraer widgets de Home sin cambiar UX: header, streak, acciones, learning/community, badges.
- Reducir `home_screen.dart` por debajo de 700 lineas.

Criterios QA:
- Tests en anchos 340, 360, 411.
- No cambia estado de racha, check-in ni recaida.

### 9. Settings por secciones

Acciones propuestas:
- Extraer secciones Apariencia, Notificaciones, Audio, TTS, Privacidad/Datos.
- Mantener una sola pantalla inicialmente.

Criterios QA:
- Cada toggle conserva persistencia.
- BGM/SFX/Haptics respetan estado real.

### 10. Navegacion centralizada

Acciones propuestas:
- Crear helpers de navegacion sin migrar a `go_router`.
- Mover deep links de notificaciones/widgets a helpers compartidos.

Criterios QA:
- Widget nativo abre rutas existentes.
- Notificaciones abren devotional/journal/battle sin duplicar stack.

## Fase 4: hardening avanzado

### 11. Limites server-side de companero/muro

Acciones implementadas/propuestas:
- Llevar a Cloud Functions los writes criticos de Companero: enviar invitacion, aceptar invitacion, enviar mensaje, enviar SOS.
- Bloquear creates directos desde cliente en `battlePartners`, `partnerInvites` y `battleMessages`.
- Mantener pendiente tests de reglas/emulador o pruebas automatizadas de Functions.

Criterios QA:
- Cliente malicioso no puede saltarse limites.
- Mensajes de error son genericos y no filtran detalles internos.

### 12. Contenido editorial a JSON validado

Acciones propuestas:
- Migrar gradualmente `dummy_plans.dart`, `devotionals.dart`, `prayers.dart` a assets JSON.
- Agregar tests de schema, longitud minima y tono.

Criterios QA:
- No se pierde contenido.
- Fallback si un JSON esta corrupto.

## Checklist QA por release

- `flutter analyze --no-pub` sin errores ni warnings.
- `flutter test --no-pub` aprobado.
- `npm --prefix functions run build` aprobado.
- Smoke manual Android:
  - Login/onboarding.
  - Registrar victoria despues de 18:00.
  - Recaida y pantalla de gracia.
  - SOS completo y escalacion.
  - Biblia: abrir capitulo, busqueda, version paralela.
  - Learning: Maná, Juegos, Headbanz.
  - Settings: BGM/SFX/Haptics/notificaciones.
  - Compañero: invitacion, mensaje, SOS.
- Smoke visual responsive: 340px, 360px, 411px.
- Revisión de texto: no verguenza, no condena, CTA claros.
- Revisión de privacidad: widget discreto, compañero no expone diario/gigantes salvo opt-in.

## Definicion de terminado

Un cambio se considera terminado solo si:

1. Tiene criterio de aceptacion escrito.
2. Tiene verificacion automatica o checklist manual claro.
3. No modifica archivos no relacionados.
4. No incrementa deuda estructural sin documentarla.
5. Mantiene el tono pastoral y psicologicamente seguro de la app.