# Instalar Victoria en Cristo en un iPad desde Windows

La compilación descargable de GitHub produce un IPA **sin firma**. Para instalarlo
en un iPad hay que firmarlo con un Apple ID en el momento de la instalación.

## Opción disponible sin Mac ni cuenta Apple Developer

1. En Windows, instala iTunes e iCloud desde el sitio de Apple (no desde Microsoft
   Store). Reinicia Windows si los instaladores lo solicitan.
2. Descarga e instala Sideloadly desde su sitio oficial.
3. Conecta el iPad por USB, desbloquéalo y pulsa **Confiar** cuando lo solicite.
4. Abre Sideloadly y arrastra el archivo
   `VictoriaEnCristo-iOS-unsigned-v1.0.26+36.ipa`.
5. Selecciona el iPad, escribe el Apple ID que se usará para firmar y pulsa
   **Start**. Apple puede pedir una contraseña específica para apps o el código de
   doble factor.
6. En el iPad, autoriza el perfil en **Ajustes > General > VPN y gestión de
   dispositivos**. En versiones recientes de iPadOS también puede ser necesario
   activar **Modo de desarrollador** en **Ajustes > Privacidad y seguridad** y
   reiniciar el iPad.

Con un Apple ID gratuito, Apple limita esta instalación a aproximadamente siete
días. Antes de que venza hay que conectar el iPad y volver a firmar/actualizar la
app con Sideloadly. Esto no elimina los datos si se usa el mismo Apple ID y el
mismo identificador de la app.

## Opción permanente y recomendada para varias personas

Una membresía de Apple Developer permite distribuir la app por TestFlight. Para
esa ruta se necesitan los certificados de distribución, un perfil de App Store y
registrar el identificador iOS de la aplicación. El IPA sin firma no se sube
directamente a TestFlight: debe archivarse y firmarse con esas credenciales.

## Notas

- El proyecto admite iPhone y iPad con iOS/iPadOS 13 o posterior.
- El IPA sin firma se genera en GitHub Actions y se conserva como artefacto por
  30 días.
- No compartas con otras personas la contraseña del Apple ID ni las contraseñas
  específicas para apps.
