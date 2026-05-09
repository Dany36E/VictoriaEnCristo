# Google OAuth en Windows

La app Windows usa un flujo OAuth Desktop con PKCE. Para que el botón **Continuar con Google** funcione en computadora, la build debe incluir un OAuth Client de tipo **Aplicación de escritorio**.

## Crear credenciales

1. Abre Google Cloud Console: https://console.cloud.google.com/apis/credentials?project=victoria-en-cristo
2. Crea credenciales: **ID de cliente de OAuth**.
3. Tipo de aplicación: **Aplicación de escritorio**.
4. Nombre sugerido: `Victoria en Cristo Windows`.
5. Copia estos dos valores:
   - Client ID
   - Client secret

## Guardar valores sólo en esta computadora

Crea un archivo local, no versionado, en la raíz del proyecto:

```powershell
notepad .env.desktop
```

Contenido:

```env
GOOGLE_DESKTOP_CLIENT_ID=TU_CLIENT_ID.apps.googleusercontent.com
GOOGLE_DESKTOP_CLIENT_SECRET=TU_CLIENT_SECRET
```

`.env.desktop` está cubierto por `.gitignore` mediante `.env.*`, así que no se sube a GitHub.

## Compilar Windows

```powershell
.\scripts\build_windows_release.ps1 -Zip
```

El script lee `.env.desktop` automáticamente y compila con:

```powershell
--dart-define=GOOGLE_DESKTOP_CLIENT_ID=...
--dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=...
```

Si no existe `.env.desktop`, la app compila igual, pero Google mostrará el error de falta de configuración en Windows. Mientras tanto puedes usar **Continuar sin cuenta** para crear un usuario anónimo local/Firebase y guardar estudios en esta computadora.
