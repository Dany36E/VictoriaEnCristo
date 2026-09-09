# Entrega pendiente para producción

Estado técnico de referencia: versión `1.0.29+39`, 8 de septiembre de 2026.

Este documento separa las tareas que requieren decisiones, datos o cuentas del titular. No sustituye asesoría jurídica ni las declaraciones finales de Google Play o App Store Connect.

## 1. Completar identidad y contacto legal

1. Definir el nombre completo o razón social de quien opera la app.
2. Definir un domicilio verificable para el aviso de privacidad. Consultar con un abogado si puede publicarse un domicilio profesional o de servicio en vez del personal.
3. Activar `soporte@victoriaencristo.app` y comprobar recepción y respuesta, o elegir otro correo operativo.
4. Sustituir los avisos de bloqueo en `privacy_policy.html`, `terms.html` y `data_deletion.html` con esos datos reales.
5. Desplegar otra vez Firebase Hosting y abrir cada página desde una ventana privada.

## 2. Documentar licencias de contenido

1. Pedir autorización escrita para distribuir el texto bíblico completo y sin conexión de NVI, LBLA, NTV, TLA y RVR1960.
2. Confirmar que la autorización incluya Android, iOS y Windows, territorios de publicación, idiomas, actualizaciones y uso comercial o gratuito según corresponda.
3. Guardar contrato, correo o certificado original fuera del repositorio y registrar su fecha, titular y alcance en el inventario interno.
4. Para cualquier traducción sin autorización suficiente, retirar sus archivos y referencias antes de publicar.
5. Repetir el proceso con imágenes, fondos, cartas, portadas, música y efectos. No basta con haber encontrado un archivo en Internet.

## 3. Probar la eliminación real de una cuenta

1. Crear una cuenta desechable en la versión de producción.
2. Generar datos de prueba en las funciones que use la cuenta: perfil, publicaciones, comentarios, reportes, progreso y consentimientos.
3. Ejecutar **Eliminar cuenta** desde la app.
4. Verificar en Firebase Authentication que el usuario ya no exista.
5. Buscar el UID y sus identificadores seudónimos en Firestore y Storage; el resultado esperado es cero datos vinculables salvo registros cuya conservación esté documentada y justificada.
6. Guardar fecha, versión, UID de prueba, capturas y resultado. No publicar el UID ni los datos de prueba en GitHub.

## 4. Google Play Console

1. Crear la versión de producción y cargar el AAB firmado de `1.0.29+39`.
2. Completar **Seguridad de los datos** usando `google_play_submission.md`; declarar cuenta, contenido del usuario, identificadores, actividad, diagnósticos y datos sensibles voluntarios según el comportamiento final.
3. Declarar la eliminación de cuenta y colocar `https://victoria-en-cristo.web.app/data_deletion.html`.
4. Completar acceso a la app, anuncios, público objetivo, clasificación de contenido y aplicaciones de salud si la consola las solicita.
5. Usar una cuenta de revisión separada si alguna pantalla no es accesible sin inicio de sesión.
6. Ejecutar primero una prueba interna, instalar desde Play y probar registro, acceso, notificaciones, enlaces legales, muro, audio y eliminación.
7. Corregir todos los avisos del informe previo al lanzamiento antes de promover a producción.

## 5. App Store Connect e instalación en iPad

1. Inscribirse en Apple Developer Program y disponer de un Mac o de un servicio de compilación macOS confiable.
2. Crear el identificador de la app y configurar certificados y perfil de distribución.
3. Compilar y firmar el archivo iOS; el IPA generado en Windows por CI es sólo para inspección y no se instala en un iPad normal.
4. Subir la compilación a App Store Connect y completar App Privacy conforme a `app_store_submission.md`.
5. Agregar datos de revisión, clasificación por edades y notas sobre contenido sensible, moderación y eliminación.
6. Invitar el Apple ID de la persona mediante TestFlight y probar en el iPad antes de enviar a revisión pública.

## 6. Decisiones de producto y revisión final

1. Elegir y documentar el público objetivo. Por el contenido sobre sexualidad, adicciones y salud emocional, no marcar la app como dirigida a niños sin una evaluación especializada.
2. Hacer una búsqueda profesional de antecedentes de **Victoria en Cristo** en IMPI/MARCia y en las tiendas.
3. Revisar el aviso de privacidad con un profesional que conozca la LFPDPPP y los países donde se distribuirá.
4. Ejecutar una revisión final de accesibilidad en dispositivos reales: lector de pantalla, tamaño de texto, contraste, orientación, foco de teclado y botones.
5. Congelar el binario aprobado, sus declaraciones de privacidad, licencias y evidencias con el mismo número de versión.
