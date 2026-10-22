# Victoria en Cristo - Flutter App

App cristiana para superar tentaciones y vicios. Flutter + Firebase.

## Stack

- **Flutter** SDK ^3.10.1
- **Firebase**: Auth, Firestore, Cloud Functions
- **Audio**: just_audio + audio_session
- **Animaciones**: flutter_animate, animations
- **Notificaciones**: flutter_local_notifications + timezone
- **Widgets nativos**: home_widget (Android/iOS)
- **TTS**: flutter_tts

## Comandos esenciales

```bash
# Correr app en dispositivo/emulador conectado
flutter run

# Correr app en dispositivo específico
flutter run -d <device_id>

# Listar dispositivos disponibles
flutter devices

# Unit/widget tests
flutter test

# Test específico
flutter test test/widget_test.dart

# Integration tests (requiere dispositivo/emulador)
flutter test integration_test/app_flow_test.dart -d <device_id>

# Build
flutter build apk --debug
flutter build apk --release

# Analizar código
flutter analyze

# Hot reload (dentro de flutter run): tecla 'r'
# Hot restart: tecla 'R'
```

## Estructura del proyecto

```
lib/          - Código fuente principal
test/         - Unit y widget tests
integration_test/ - Tests de integración (app_flow_test.dart)
assets/       - Sonidos, imágenes, contenido
functions/    - Cloud Functions (Node.js)
```

## Flujo de trabajo preferido

1. Antes de cambios: leer el archivo relevante en `lib/`
2. Hacer cambios mínimos y enfocados
3. Correr `flutter analyze` para verificar errores de tipo
4. Correr tests relevantes
5. No modificar `pubspec.yaml` sin confirmar con el usuario

## Convenciones

- Español para nombres de variables de negocio y comentarios
- Material Design 3 con tema oscuro premium
- Firebase como backend (no agregar otros backends)
- Audio gestionado por `AudioService` existente

## Revisión obligatoria antes de terminar

- Antes de dar por terminada cualquier tarea que cambie código o textos,
  invoca al subagente `revisor` (`.claude/agents/revisor.md`). Corrige todo lo
  que reporte como seguro y vuelve a invocarlo hasta que responda "Sin
  problemas encontrados". No te revises tú mismo en lugar del revisor.
- Cambios de UI, tema o colores: la pantalla tiene que estar en
  `test/visual/screens_theme_matrix_test.dart`, que la dibuja en todos los temas
  y revisa desbordes, fondos de botones y contraste WCAG. Mira las capturas
  de `build/qa/` antes de terminar. `test/visual/problemas_conocidos/` lista
  problemas que ya existían: corrígelos y regenera con
  `ACTUALIZAR_PROBLEMAS_CONOCIDOS=1 flutter test test/visual/`; nunca agregues
  problemas nuevos a esa lista.
- En la nube, `.claude/hooks/session-start.sh` instala Flutter 3.41.1 y crea
  los stubs de los archivos secretos; `.claude/hooks/stop-analyze.sh` corre
  `flutter analyze` al terminar si hubo cambios en Dart y obliga a corregir
  los errores.
