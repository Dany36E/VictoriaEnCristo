# ⚠️ CONFIGURACIÓN REQUERIDA - Firebase Authentication

## 🔥 Problema Detectado

1. **Google Sign-In no funciona** → Requiere configuración en Firebase Console
2. **"Continuar sin cuenta" no muestra onboarding** → ✅ YA CORREGIDO

---

## ✅ Cambios Realizados

### 1. Autenticación Anónima Implementada

**Archivos Modificados:**
- `lib/services/auth_service.dart` → Agregado método `signInAnonymously()`
- `lib/screens/login_screen.dart` → Botón "Continuar sin cuenta" ahora usa autenticación anónima

**Flujo Actual:**
```
Usuario presiona "Continuar sin cuenta"
    ↓
signInAnonymously() en Firebase
    ↓
StreamBuilder detecta usuario autenticado
    ↓
Verifica isOnboardingCompleted
    ↓
Si false → Muestra OnboardingWelcomeScreen
Si true → Muestra HomeScreen
```

---

## 🛠️ PASOS PARA HABILITAR EN FIREBASE

### PASO 1: Habilitar Autenticación Anónima

1. Ve a **Firebase Console**: https://console.firebase.google.com
2. Selecciona tu proyecto: **victoria-en-cristo-app**
3. En el menú lateral → **Authentication** → **Sign-in method**
4. Busca **"Anonymous"** en la lista de proveedores
5. Haz clic en **"Anonymous"** → Toggle **Enable** → **Save**

### PASO 2: Habilitar Google Sign-In (Opcional pero recomendado)

1. En la misma sección **Sign-in method**
2. Busca **"Google"** en la lista
3. Haz clic en **"Google"** → Toggle **Enable**
4. Configura el **Support email** (tu email)
5. Haz clic en **Save**

**Para Android (adicional):**
- Descargar el nuevo `google-services.json` y reemplazar en:
  - `android/app/google-services.json`

**Para iOS (adicional):**
- Descargar el nuevo `GoogleService-Info.plist` y reemplazar en:
  - `ios/Runner/GoogleService-Info.plist`

---

## 📱 Probar los Cambios

### Después de habilitar en Firebase:

```powershell
# Detén la app si está corriendo
# Luego reinicia:
flutter run
```

### Flujo de Prueba:

1. **Presiona "Continuar sin cuenta"**
   - ✅ Debe iniciar sesión como usuario anónimo
   - ✅ Debe mostrar OnboardingWelcomeScreen (3 pantallas)

2. **Presiona "Iniciar con Google"**
   - ✅ Debe abrir selector de cuenta Google
   - ✅ Debe iniciar sesión correctamente
   - ✅ Si es primera vez → Muestra Onboarding

---

## 🔍 Debugging

Si el Google Sign-In sigue fallando:

```dart
// Verifica el error en la consola de debug
// El error debería mostrar si falta configuración de SHA-1 o cliente OAuth
```

Para agregar SHA-1 en Firebase (Android):

```powershell
cd android
.\gradlew signingReport
```

Copia los SHA-1 y SHA-256 que aparecen y agrégalos en:
**Firebase Console → Project Settings → Your apps → Android app → Add fingerprint**

---

## 📊 Estado Actual

- ✅ Onboarding UI completo (3 pantallas)
- ✅ OnboardingService con persistencia
- ✅ Integración con main.dart
- ✅ Autenticación anónima implementada
- ⚠️ **PENDIENTE: Habilitar en Firebase Console**

---

## 🎯 Siguiente Paso

**ACCIÓN REQUERIDA:** 
Ve a Firebase Console y habilita:
1. Anonymous Authentication
2. Google Sign-In (opcional)

Luego ejecuta `flutter run` para probar.
