# Evaluación: migración a `go_router`

Revisado el `2026-04-18` como parte del refactor del audit. Este documento
resume la recomendación **NO** migrar ahora mismo.

## Contexto del proyecto

- **Framework**: Flutter con `MaterialApp` clásico (rutas `home` + `routes`
  + `onGenerateRoute`).
- **Volumen**: ~40+ llamadas a `Navigator.push` / `Navigator.pop` /
  `MaterialPageRoute` distribuidas en ~20 archivos de `lib/screens/` y
  `lib/widgets/`.
- **Rutas nombradas definidas**: apenas 2 (`/widget-settings`, `/emergency`).
  Todo el resto es navegación imperativa con `MaterialPageRoute`.
- **Deep-linking actual**:
  - Widget nativo Android usa `MethodChannel('victoria/navigation')`
    (`_checkInitialRoute` en `main.dart`).
  - Notificaciones usan `NotificationService.lastTapPayload` +
    `_consumeNotificationPayload` (nuevo, Task 5).
- **Estado**: sin BottomNavigationBar persistente con navegación anidada;
  las pantallas son pila lineal. Sin tabs que necesiten rutas paralelas.

## Pros de migrar a `go_router`

1. **URLs declarativas y deep-links unificados** — Las notificaciones y
   widgets nativos podrían despachar strings `/devotional`, `/journal/:id`,
   `/plan/:id/session/:n` directamente.
2. **Web/back button correctos** — Si en el futuro se compila para Web,
   `go_router` soporta URL sync nativo.
3. **StatefulShellRoute** — Útil si se añade BottomNavigationBar con tabs
   que preservan estado.
4. **Type-safe routes** — Con `go_router_builder` se generan rutas
   tipadas.
5. **Patrón moderno** — Recomendado por el equipo de Flutter para apps
   nuevas.

## Contras / costos en este proyecto

1. **Refactor grande y arriesgado** — Cambiar ~40+ sitios de navegación
   imperativa a `context.push('/x')` + registro de cada pantalla en el
   `GoRouter`. Riesgo de regresiones en flujos críticos (onboarding,
   emergencia, Bible reader con navegación anidada por libro/capítulo).
2. **Sin pay-off real hoy** — La app **no es web**, no tiene tabs
   persistentes, y el deep-linking ya funciona con el mecanismo actual
   (ValueNotifier + MethodChannel). El valor incremental de `go_router`
   es marginal.
3. **Curva de aprendizaje** — Redirecciones, guards, sub-routers y
   ShellRoute requieren entender el nuevo paradigma. Onboarding de nuevos
   desarrolladores sería más abrupto.
4. **Interacción con `showModalBottomSheet` / `showDialog`** — Estos usan
   `Navigator.of(context)` directamente; con `go_router` hay que decidir
   si son rutas o no. Muchas pantallas de la app los usan intensamente.
5. **Animaciones custom entre pantallas** — Algunas transiciones usan
   `PageRouteBuilder`/custom curves. Con `go_router` hay que configurar
   `pageBuilder` + `CustomTransitionPage` en cada ruta.
6. **Bible reader** — La navegación entre libro→capítulo→versículo
   actualmente usa `MaterialPageRoute`. Portarla a rutas dinámicas
   paramétricas funciona, pero agrega estado que ya está manejado en
   memoria por `BibleReaderState`.
7. **Integration tests** — Los tests en `integration_test/` usan
   `find.text`/`tap` agnósticos a router, pero algunos tests navegan por
   `pageView` y pueden romperse con semántica distinta de stack.

## Alternativa incremental (recomendada)

En lugar de una migración completa, aplicar mejoras puntuales al sistema
actual:

1. **Centralizar rutas** — Crear `lib/navigation/routes.dart` con
   constantes `AppRoutes.devotional`, `AppRoutes.journal`, etc., y helpers
   `navigateToDevotional(context)` que encapsulan `Navigator.push(...)`.
   Beneficio ~80% del de `go_router` con 5% del costo.
2. **Router para deep-links** — Extender `_consumeNotificationPayload`
   para parsear payloads con `Uri.parse('app://route/:id')` y despachar
   al helper correspondiente. Misma API que `go_router` pero ligera.
3. **Analytics de navegación** — Ya hay `FirebaseAnalyticsObserver`. No
   requiere cambio.

## Decisión

- **No migrar a `go_router`** en este ciclo.
- **Reevaluar** si: (a) se agrega target Web, (b) se introduce
  BottomNavigationBar persistente, (c) se planifican deep-links complejos
  con parámetros (no presentes hoy).
- **Acción inmediata**: aplicar la alternativa incremental en un sprint
  separado (centralizar constantes y helpers).

## Presupuesto estimado (si algún día se migra)

- ~2 días de trabajo de un dev senior para rediseñar el árbol de rutas.
- ~3 días para portar sitios de navegación (con tests).
- ~2 días para QA de flujos críticos (emergencia, onboarding, Bible,
  Battle Partner, notificaciones, widget).
- Total: ~1 semana + riesgo de regresiones.
