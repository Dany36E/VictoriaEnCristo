# Auditoría de seguridad web — Victoria en Cristo

Fecha de revisión: 13 de septiembre de 2026

## Alcance

Esta revisión cubre la web pública alojada en Firebase Hosting, su configuración de encabezados, el código HTML/CSS/JavaScript servido al navegador, los paquetes de Cloud Functions y una inspección estática de reglas de Firestore y Storage. No equivale a una garantía de invulnerabilidad ni sustituye monitoreo continuo, pruebas de las reglas contra emuladores o una auditoría externa.

## Controles comprobados

- La web pública es estática y no contiene formularios, iframes, videos incrustados, analítica, píxeles, cookies propias, `localStorage`, `sessionStorage` ni solicitudes de red desde JavaScript.
- Scripts, estilos, imágenes y fuentes son locales. Sólo `site.js` ejecuta JavaScript y no usa `eval`, `innerHTML`, `document.write` ni otros sumideros DOM de alto riesgo.
- La política CSP parte de `default-src 'none'`, permite únicamente scripts, estilos, imágenes y fuentes propios, bloquea conexiones, objetos, workers, formularios y carga dentro de marcos, y fuerza la actualización de recursos inseguros.
- Se envían `nosniff`, política de referente `no-referrer`, aislamiento de ventana con COOP, denegación de marcos, bloqueo de políticas Flash heredadas y una Permissions Policy restrictiva.
- Firebase Hosting sirve HTTPS. En los subdominios predeterminados `web.app`, Firebase controla el encabezado HSTS; si se conecta un dominio propio debe verificarse HSTS de nuevo antes del lanzamiento.
- El directorio público excluye Markdown, archivos TTF de trabajo, JSON, metadatos ocultos y documentación interna.
- Las reglas de Firestore comienzan con denegación total; los datos privados bajo `users/{uid}` exigen autenticación y propiedad. Las escrituras sensibles del Muro, compañeros, moderación, candado y salas pasan por Cloud Functions.
- Storage limita los archivos privados al propietario, a imagen o audio y a menos de 5 MB. Los demás caminos se deniegan por defecto.
- Los paquetes de Cloud Functions se actualizaron a Firebase Admin 14 y Firebase Functions 7 manteniendo explícitamente la API v1 desplegada. `npm audit` no reporta vulnerabilidades conocidas y TypeScript compila correctamente.
- Una búsqueda de firmas comunes de secretos en archivos rastreados no encontró credenciales reales; la única coincidencia es la clave ficticia del archivo de ejemplo de Firebase.

## Automatización preventiva

Ejecutar antes de publicar:

```powershell
./scripts/audit_web_security.ps1
cd functions
npm ci
npm audit --audit-level=low
npm run build
```

El flujo de integración continua repite la auditoría del sitio, la instalación reproducible, `npm audit` y la compilación de Functions.

## Riesgos residuales que requieren operación

1. **Firebase App Check:** no debe activarse en modo obligatorio hasta registrar Android, Apple y Windows y comprobar que la versión instalada envía tokens válidos; activarlo antes rompería Muro, compañeros, salas y eliminación de cuenta. Prepararlo y observar métricas en modo no obligatorio es el siguiente control recomendado.
2. **Pruebas de reglas:** añadir pruebas automatizadas con Firebase Emulator Suite para intentos permitidos y denegados de Firestore/Storage, especialmente resaltados y respuestas de salas.
3. **Monitoreo:** revisar Cloud Functions, Authentication, Firestore, Storage, cuotas y facturación; configurar alertas de gasto y de errores. Los límites de la aplicación reducen abuso, pero no sustituyen alertas operativas.
4. **Cuenta y dominio:** habilitar autenticación multifactor para las cuentas con acceso a Firebase/GitHub y, cuando exista dominio propio, verificar DNS, HSTS, correo de soporte y registros de correo.
5. **Respuesta a incidentes:** conservar propietarios de proyecto mínimos, rotar cualquier secreto que llegue a un registro o repositorio y documentar quién puede retirar una publicación o revocar una sesión.

## Límite de la afirmación

La superficie web queda deliberadamente pequeña y endurecida, pero ningún sitio puede prometer protección absoluta. La seguridad de producción depende también de permisos de las cuentas, configuración viva de Firebase, versiones desplegadas, monitoreo y respuesta rápida a nuevas vulnerabilidades.
