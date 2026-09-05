# Flujo seguro entre Codex, VS Code y GitHub

Este proyecto no necesita migrarse fuera de VS Code para usar Codex. VS Code y
Codex pueden trabajar sobre **la misma carpeta Git local**; GitHub funciona como
respaldo remoto y punto de sincronizacion.

## 1. Elegir una unica carpeta canonica

En Windows, usa como carpeta principal:

```text
C:\Proyectos\Flutter\app\_quitar
```

Antes de continuar, confirma que esa carpeta contiene `.git`, `pubspec.yaml`,
`lib`, `test`, `android`, `ios`, `web` y `windows`. No mantengas dos copias
editables del proyecto (por ejemplo, una extraida de un ZIP y otra clonada),
porque sus cambios pueden divergir.

## 2. Conectar la copia existente con GitHub

Primero crea en GitHub un repositorio privado vacio, sin README ni `.gitignore`.
Luego abre PowerShell en la carpeta del proyecto:

```powershell
cd C:\Proyectos\Flutter\app\_quitar
git status
git remote -v
```

Si `origin` no aparece, agrega la URL que GitHub muestra para el repositorio:

```powershell
git remote add origin https://github.com/TU_USUARIO/TU_REPOSITORIO.git
git push -u origin HEAD
```

Si `origin` existe pero apunta al lugar incorrecto:

```powershell
git remote set-url origin https://github.com/TU_USUARIO/TU_REPOSITORIO.git
git push -u origin HEAD
```

No pegues tokens, contrasenas ni llaves en archivos del proyecto o en mensajes
para el agente. Autentica GitHub mediante el navegador o GitHub CLI.

## 3. Abrir exactamente esa carpeta en Codex

Selecciona `C:\Proyectos\Flutter\app\_quitar` como workspace de Codex. Al iniciar
cada tarea, pide primero una comprobacion no destructiva:

```text
Antes de editar, confirma pwd, git status --short --branch y git remote -v.
No cambies archivos fuera de este repositorio. Crea una rama para la tarea,
ejecuta las pruebas relevantes y muestra el diff antes de confirmar cambios.
```

La ruta que muestra Codex puede ser distinta cuando trabaja en un entorno Linux
o remoto. Lo importante es verificar que el repositorio tenga el mismo remoto y
el commit esperado, no que la ruta textual sea identica a la de Windows.

## 4. Trabajar por ramas

Sincroniza la rama principal y crea una rama corta por cambio:

```powershell
git switch main
git pull --ff-only
git switch -c feat/nombre-del-cambio
```

Despues de editar con Codex o VS Code:

```powershell
git status
git diff
flutter analyze --no-pub
flutter test --no-pub
git add -A
git commit -m "feat: descripcion breve"
git push -u origin HEAD
```

Crea un pull request en GitHub, revisa el diff y fusiona solo cuando las pruebas
pasen. Para volver a empezar desde la version fusionada:

```powershell
git switch main
git pull --ff-only
```

## 5. Evitar conflictos entre VS Code y Codex

- No edites la misma rama desde dos equipos o sesiones al mismo tiempo.
- Antes de empezar, ejecuta `git status` y `git pull --ff-only`.
- Antes de cambiar de herramienta, guarda, confirma y sube el trabajo, o deja
  claro que hay cambios sin confirmar en la carpeta compartida.
- No ejecutes `git reset --hard`, `git clean -fd` ni force push sin revisar y
  respaldar primero los cambios locales.
- Haz commits pequenos: una funcionalidad o correccion coherente por commit.

## 6. Archivos locales y secretos

El `.gitignore` del proyecto excluye, entre otros, configuraciones locales y
secretos de Firebase, archivos `.env`, keystores, `assets/config.json`,
`android/local.properties`, dependencias de Node y carpetas de build. Antes del
primer push, revisa lo que Git realmente va a publicar:

```powershell
git status --short
git ls-files
git diff --cached
```

Si un secreto fue confirmado alguna vez, agregarlo despues a `.gitignore` no lo
elimina del historial. En ese caso, revoca o rota la credencial antes de limpiar
el historial.

## 7. Mapa rapido del repositorio

- `lib/`: aplicacion Flutter, organizada en pantallas, servicios, modelos,
  repositorios, navegacion, tema y widgets.
- `test/`: pruebas unitarias y de widgets.
- `assets/`: Biblias, contenido, imagenes, sonidos y recursos de widgets.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: integraciones por
  plataforma.
- `functions/`: Cloud Functions de Firebase en TypeScript.
- `docs/`: decisiones, configuracion y guias operativas.
- `scripts/` y `tool/`: automatizacion de builds, auditoria y utilidades.
- `faith-victory-app/`: proyecto Android complementario; confirma su proposito
  antes de modificarlo junto con la app Flutter principal.

## Lista de verificacion inicial

1. La carpeta local correcta contiene `.git` y `pubspec.yaml`.
2. `git status` no muestra cambios inesperados.
3. `git remote -v` muestra el repositorio GitHub correcto para fetch y push.
4. `git branch --show-current` muestra la rama esperada.
5. Los secretos siguen ignorados y no aparecen en `git ls-files`.
6. Flutter y Firebase estan configurados localmente sin subir credenciales.
7. Cada tarea se hace en una rama, se prueba y se revisa mediante pull request.
