# Material de envío a App Store — iPhone y iPad

Versión preparada: **1.0.27 (37)**

Bundle ID existente en Firebase: **com.victoriaecristo.app**

## Estado técnico

- Compilación universal para iPhone y iPad desde iOS/iPadOS 13.
- Xcode 26 y SDK de iOS 26 exigidos por el workflow.
- Inicio con Apple integrado con nonce SHA-256 y oculto hasta que el proveedor esté configurado.
- Capacidades enlazadas: Sign in with Apple y Push Notifications.
- Modo de fondo `remote-notification` declarado para FCM.
- `PrivacyInfo.xcprivacy` incluido en el bundle y tracking declarado como desactivado.
- Eliminación de cuenta disponible dentro de Perfil.
- Política, términos y eliminación de datos publicados mediante HTTPS.
- Pruebas automáticas en simuladores iPhone e iPad.
- Los widgets se ocultan en iOS porque la extensión WidgetKit todavía no forma parte del producto firmado.

## Configuración única en Apple Developer y Firebase

1. Inscribirse en Apple Developer Program.
2. Registrar el App ID explícito `com.victoriaecristo.app`.
3. Habilitar **Sign in with Apple** como App ID principal y **Push Notifications**.
4. Crear una clave APNs y subirla en Firebase Console → Project settings → Cloud Messaging.
5. Activar el proveedor Apple en Firebase Authentication usando Team ID, Key ID y la clave privada de Apple.
6. Crear un certificado Apple Distribution y un perfil **App Store Connect** que incluya ambas capacidades.
7. Crear la app en App Store Connect con el mismo Bundle ID.

## Workflow firmado

El flujo manual `.github/workflows/ios-app-store.yml` genera un IPA firmado y, opcionalmente, lo sube a TestFlight. Configurar estos secretos en el environment de GitHub `app-store`:

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_PROVISIONING_PROFILE_BASE64`
- `APPLE_TEAM_ID`
- `APPLE_KEY_ID`, `APPLE_ISSUER_ID` y `APPLE_API_PRIVATE_KEY` para TestFlight
- `FIREBASE_OPTIONS_DART`, `API_CONFIG_DART` y `ASSETS_CONFIG_JSON`

## App Privacy sugerida

| Tipo | Vinculado | Tracking | Finalidad |
|---|---:|---:|---|
| Nombre y correo | Sí | No | Cuenta y funcionalidad |
| User ID | Sí | No | Cuenta, seguridad y sincronización |
| Device ID/token push | Sí | No | Notificaciones |
| Contenido del usuario | Sí | No | Diario, progreso, mensajes y comunidad |
| Interacción con el producto | No | No | Analytics |
| Datos de fallos | No | No | Estabilidad |

La ficha de privacidad debe incluir también las prácticas efectivas de Firebase y de cualquier servicio habilitado en producción.

## Revisión de contenido

- Declarar contenido generado por usuarios por el Muro y los mensajes.
- Explicar que existe premoderación, reportes, bloqueo personal y suspensión administrativa.
- Responder el cuestionario de edad actualizado de Apple; por las referencias a adicciones, tentaciones, filtrado adulto y UGC, revisar cuidadosamente si corresponde **16+**.
- Proporcionar una cuenta demo plenamente funcional y explicar en Review Notes las alarmas, el Escudo exclusivo de Android y la eliminación de cuenta.

## URLs

- Política: https://dany36e.github.io/VictoriaEnCristo/privacy_policy.html
- Términos: https://dany36e.github.io/VictoriaEnCristo/terms.html
- Eliminación: https://dany36e.github.io/VictoriaEnCristo/data_deletion.html

## Pendientes humanos antes de revisión

- Correo público real de soporte.
- Membresía Apple Developer y aceptación de contratos.
- Credenciales/certificados anteriores.
- Capturas de iPhone 6.9 pulgadas y iPad 13 pulgadas.
- Cuenta demo y notas para App Review.
- Prueba real en al menos un iPad mediante TestFlight antes de enviar a revisión.
