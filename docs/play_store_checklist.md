# Play Store Readiness Checklist

Lista de tareas para subir Victoria en Cristo a Google Play Store con todos los compliance.

## ✅ Hecho en código (rama `hardening-2026-05`)

- [x] `applicationId` definitivo: `com.victoriaencristo.app`.
- [x] `firebase_options.dart` Android usa appId nuevo (`5b81abbc45942c48d9df8b`).
- [x] `android:allowBackup="false"` + `dataExtractionRules` excluyendo todo.
- [x] `usesCleartextTraffic="false"`.
- [x] AD_ID + AdServices removidos vía `tools:node="remove"`.
- [x] Build release falla si no hay `key.properties` (no firma con debug por accidente).
- [x] R8 + ProGuard activos en release.
- [x] Firestore cache limitado a 50MB (no ilimitado).
- [x] Firebase App Check inicializado (Play Integrity Android, DeviceCheck iOS) en modo monitor.
- [x] Reglas Firestore: `isAdmin` vía custom claims con fallback, deny en colecciones de rate limit.
- [x] Cloud Function `deleteUserData` usa `recursiveDelete` (borra TODAS las subcolecciones).
- [x] Cloud Function `cleanStaleFcmTokens` scheduled (purga tokens >90 días).
- [x] Cloud Function `setAdminClaim` para custom claims.
- [x] Rate limits: wall (3/h, 5/día), studyRoom (10/día).
- [x] Windows Google OAuth con PKCE S256.
- [x] Política de contraseñas en signup (8+ chars, alfanumérico).
- [x] BLB API key migrada con flag idempotente.

## 🔧 Pendiente — Acciones manuales en Google / Firebase Console

### A. Firebase Console
- [ ] **App Check**: registrar provider Play Integrity (Android) y DeviceCheck/AppAttest (iOS). Subir SHA-256 keystore release.
- [ ] **App Check Enforcement**: tras 1-2 semanas en monitor sin falsos positivos, activar enforcement en Firestore, Functions y Storage.
- [ ] **Functions secrets**: verificar `WALL_ABUSE_SALT` (≥16 chars).
- [ ] **Authentication**: configurar action URL personalizada para email verification.
- [x] **Desplegado 2026-05-08**: Functions (19 actualizadas + `setAdminClaim` + `cleanStaleFcmTokens`) y Firestore rules.
  ```bash
  cd functions && npm run build && firebase deploy --only functions
  firebase deploy --only firestore:rules
  ```

### B. Google Cloud Console
- [ ] **APIs & Services → Credentials → restringir API keys**:
  - API key Android (la que aparece en `google-services.json` → `client[0].api_key.current_key`) → restringir a Android package `com.victoriaencristo.app` + SHA-1 release.
  - Crear API key separada para iOS bundle.
- [ ] **OAuth consent screen**: completar con privacy_policy URL pública.
- [ ] **OAuth Client IDs**: crear Desktop client para Windows OAuth si se distribuirá.

### C. Bootstrapping de admins
- [ ] Ejecutar manualmente (UNA vez):
  ```bash
  cd functions
  node -e "require('firebase-admin').initializeApp(); require('firebase-admin').auth().setCustomUserClaims('UID_DEL_ADMIN', {admin:true}).then(()=>console.log('OK'))"
  ```
- [ ] El admin podrá luego usar `setAdminClaim` callable para granjear/revocar otros.

### D. Hosting de docs
- [ ] Hospedar `docs/privacy_policy.md` y `docs/data_deletion.md` en URL pública (sugerencia: Firebase Hosting o GitHub Pages).
- [ ] URLs requeridas en Play Console:
  - Política de privacidad.
  - URL de eliminación de cuenta.

## 🛒 Play Console — formulario de envío

### Permisos sensibles a justificar
- `SCHEDULE_EXACT_ALARM`: alarmas sagradas a hora exacta para devociones (uso esencial — feature core).
- `FOREGROUND_SERVICE_MEDIA_PLAYBACK`: reproducción de audios de oración con `SacredAlarmForegroundService`.
- `RECEIVE_BOOT_COMPLETED`: re-programar alarmas tras reinicio del dispositivo.
- `POST_NOTIFICATIONS`: notificaciones de alarmas y compañero de batalla.

### Data Safety form
- **Datos personales**: email, nombre, foto, UID. **Recolectados** y **almacenados encriptados en tránsito** (TLS).
- **Mensajes**: contenido de Battle Partner. **Recolectados** (encriptados en tránsito).
- **App activity**: progreso, configuración. **Recolectados**.
- **Diagnóstico**: crash reports + métricas anónimas.
- **Identificador publicitario**: NO recolectado (AD_ID removido).
- Política de eliminación: link a `data_deletion.md` hospedado.

### Content rating (UGC)
- Marcar **"Sí, los usuarios pueden interactuar/intercambiar contenido"** por:
  - Muro de Batalla (publicaciones moderadas).
  - Battle Partner messages.
- Sistema de moderación: pre-aprobación + reportes + ban por hash.

### Categoría
- **Lifestyle** o **Health & Fitness** (la app es de bienestar emocional/espiritual; NO es Medical).

## 🏗️ Builds para subir

```bash
flutter build appbundle --release   # SUBIR A PLAY (no APK)
# Validar:
bundletool validate --bundle=build/app/outputs/bundle/release/app-release.aab
# Validar Google Sign-In en APK local:
powershell -ExecutionPolicy Bypass -File scripts/verify_android_google_signin.ps1
```

Antes de compartir un link de verificadores / testing por Play Console:
- Play Console -> App integrity -> App signing key certificate: copiar SHA-1 y SHA-256.
- Firebase Console -> Project settings -> Android app `com.victoriaencristo.app` -> Add fingerprint.
- Descargar el `google-services.json` actualizado, reemplazar `android/app/google-services.json`, reconstruir y subir de nuevo si Firebase agrego nuevos OAuth clients.

## 🔐 Post-lanzamiento

- [ ] Activar **Play App Signing** (Google gestiona la upload key) y registrar su SHA-1/SHA-256 en Firebase Auth.
- [ ] Activar **Play Integrity API** y vincular con App Check.
- [ ] Configurar alertas en Firebase Console (errores Functions, picos Firestore).
- [ ] Habilitar **Cloud Logging** para inspección post-incident.
