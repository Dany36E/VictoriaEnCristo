---
layout: default
title: Eliminar cuenta y datos
---

# Eliminar tu cuenta y datos — Victoria en Cristo

Cumple el requisito de Play Store: "Account Data Deletion".

## Opción 1 — Desde la app (recomendado)

1. Inicia sesión en Victoria en Cristo.
2. Ve a **Configuración → Cuenta → Eliminar cuenta**.
3. Confirma la acción. Se ejecutará una Cloud Function (`deleteUserData`) que:
   - Borra recursivamente tu documento `/users/{uid}` y TODAS sus subcolecciones (días de victoria, notas, planes, mensajes, tokens FCM, etc.).
   - Borra tu cuenta de Firebase Authentication.
4. La operación es irreversible.

## Opción 2 — Solicitud externa

Si no puedes acceder a la app:

1. Envía un email a **soporte@victoriaencristo.app** desde la dirección con la que te registraste, con asunto **"Eliminación de cuenta"**.
2. Incluye:
   - Email de la cuenta.
   - Nombre que aparece en tu perfil.
3. Procesaremos la solicitud en máximo **30 días** y te enviaremos confirmación.

## Qué datos se eliminan

- Perfil de usuario (nombre, email, foto, configuración).
- Progreso (días de victoria, racha, planes activos).
- Notas, versículos guardados, oraciones, alarmas.
- Tokens FCM y registros de mensajes con compañeros.
- Publicaciones del Muro de Batalla quedan anónimas (nunca contuvieron tu UID, solo un hash que ya no será recomputable).

## Qué se retiene

Por requisitos legales y de operación, retenemos hasta **90 días** después de la eliminación:
- Logs agregados de Cloud Functions (sin datos personales).
- Reportes de Crashlytics (anónimos).

Después de ese plazo, los datos quedan totalmente purgados.
