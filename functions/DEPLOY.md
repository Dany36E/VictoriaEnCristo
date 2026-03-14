# 🚀 Deployment: Cloud Functions para Victoria en Cristo

## Prerrequisitos

1. **Firebase CLI instalado**:
   ```bash
   npm install -g firebase-tools
   ```

2. **Login en Firebase**:
   ```bash
   firebase login
   ```

3. **Proyecto Firebase configurado** con plan Blaze (pay-as-you-go)
   - Cloud Functions requiere plan Blaze para usar Admin SDK

---

## Pasos de Despliegue

### 1. Instalar dependencias

```bash
cd functions
npm install
```

### 2. Compilar TypeScript

```bash
npm run build
```

### 3. Probar localmente (opcional)

```bash
firebase emulators:start --only functions
```

### 4. Desplegar a producción

```bash
firebase deploy --only functions
```

---

## Funciones Desplegadas

### `deleteUserData` (Callable)

**Propósito**: Elimina completamente la cuenta del usuario y todos sus datos.

**Subcollections que elimina**:
- `/users/{uid}/victoryDays`
- `/users/{uid}/journalEntries`
- `/users/{uid}/plansProgress`
- `/users/{uid}/widgetConfig`

**Acciones**:
1. Valida que el usuario esté autenticado
2. Elimina todas las subcollections usando BulkWriter
3. Elimina el documento principal `/users/{uid}`
4. Elimina el usuario de Firebase Auth

**Retorna**:
```json
{
  "success": true,
  "message": "Cuenta y datos eliminados correctamente",
  "deletedSubcollections": {
    "victoryDays": 50,
    "journalEntries": 10,
    "plansProgress": 5,
    "widgetConfig": 1,
    "userDocument": 1,
    "authUser": 1
  }
}
```

---

## Verificar Despliegue

1. **En Firebase Console**: Functions → Ver `deleteUserData`
2. **En la app Flutter**: Probar "Eliminar cuenta" en pantalla de Perfil

---

## Troubleshooting

### Error: "functions: failed to deploy"
- Verifica que tienes plan Blaze activo
- Verifica permisos de IAM

### Error: "unauthenticated"
- El usuario debe estar logueado antes de llamar la función
- Verificar que el token no haya expirado

### Error: "requires-recent-login"
- El cliente debe re-autenticar antes de llamar
- Ya está manejado en `auth_service.dart`
