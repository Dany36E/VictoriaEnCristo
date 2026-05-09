# Política de Privacidad — Victoria en Cristo

**Última actualización:** mayo 2026

Esta aplicación móvil (en adelante, "la App") es operada por el equipo de Victoria en Cristo. Esta política describe qué datos recopilamos, cómo los usamos y cómo puedes ejercer tus derechos.

## 1. Datos que recopilamos

### 1.1. Cuenta y autenticación
- Email, nombre y foto de perfil (vía Firebase Authentication, opcional con Google Sign-In).
- ID único de usuario (UID).

### 1.2. Datos de uso de la app
- Días de victoria, frecuencia de oración, plan devocional activo, configuración personal (modo oscuro, sonidos, notificaciones).
- Notas bíblicas, versículos guardados, oraciones, alarmas sagradas configuradas.
- Mensajes intercambiados con tu Compañero de Batalla (cifrados en tránsito).
- Publicaciones anónimas en el "Muro de Batalla" (NO almacenamos tu UID en el post; usamos un hash con sal secreta para detectar abuso).

### 1.3. Datos técnicos
- Token de Firebase Cloud Messaging para enviar notificaciones push.
- Reportes de errores anónimos (Firebase Crashlytics) — sin contenido personal.
- Métricas agregadas de uso (Firebase Analytics) — sin identificadores publicitarios (AD_ID está deshabilitado).

## 2. Cómo usamos los datos

- Para autenticarte y proteger tu cuenta.
- Para sincronizar tu progreso entre dispositivos.
- Para enviarte notificaciones que tú activaste (alarmas sagradas, mensajes de tu compañero).
- Para mejorar la app (crash reports, métricas agregadas anónimas).
- Para moderar el Muro de Batalla y prevenir abuso.

**No vendemos ni compartimos tus datos con terceros con fines comerciales.**

## 3. Almacenamiento

- Los datos se almacenan en **Google Firebase / Cloud Firestore** (servidores en us-central1).
- Una caché local cifrada vive en tu dispositivo para uso offline.
- Las claves de API (Blue Letter Bible) opcionales se guardan en el almacenamiento seguro del sistema (Keychain/Keystore).

## 4. Compartir datos

Compartimos datos solo con los siguientes proveedores, sujetos a sus respectivas políticas:
- **Google Firebase** (Auth, Firestore, FCM, Crashlytics, Analytics) — Google LLC.
- **Blue Letter Bible API** (opcional, solo si activas integración Strong's) — solo el versículo consultado, sin datos personales.

## 5. Tus derechos

- **Acceso / portabilidad:** puedes solicitar una copia de tus datos escribiéndonos.
- **Eliminación:** ve a *Configuración > Cuenta > Eliminar cuenta* dentro de la app, o usa el formulario externo: ver `data_deletion.md`.
- **Rectificación:** edita tu nombre/foto desde la pantalla de perfil.
- **Oposición / limitación:** desactiva las notificaciones, analytics o crash reports en *Configuración*.

## 6. Niños

La app está pensada para mayores de 13 años. No recopilamos conscientemente datos de menores. Si crees que un menor ha creado una cuenta, escríbenos para eliminarla.

## 7. Cambios a esta política

Publicaremos cualquier cambio en esta página y, para cambios materiales, te notificaremos en la app.

## 8. Contacto

Para cualquier consulta sobre privacidad: **soporte@victoriaencristo.app** (reemplaza con email real antes de publicar).
