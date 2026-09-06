# Material de envío a Google Play — Android

Versión preparada: **1.0.27 (37)**

Paquete: **com.victoriaencristo.app**
Categoría recomendada: **Estilo de vida**

## Ficha de Play Store

### Descripción breve

Crece en fe, vence tentaciones y encuentra apoyo cristiano cada día.

### Descripción completa

Victoria en Cristo es un espacio cristiano para fortalecer tu vida espiritual y avanzar con intención frente a hábitos y tentaciones.

Lee la Biblia sin conexión, sigue planes devocionales, registra tus días de victoria, configura recordatorios de oración y encuentra ayuda inmediata cuando más la necesitas.

También puedes caminar acompañado mediante el Compañero de Batalla y participar de forma anónima en un muro moderado. El contenido público se revisa antes de aparecer; puedes reportar publicaciones y bloquear a cualquier autor que no quieras volver a ver.

En Android, el Escudo de Pureza es una herramienta opcional que usa una VPN local para filtrar dominios de contenido adulto. Sólo procesa consultas DNS, mantiene una notificación visible mientras funciona y cifra las consultas permitidas mediante DNS-over-HTTPS. No inspeccionamos páginas ni vendemos tu actividad.

La app no sustituye atención médica, psicológica ni servicios de emergencia.

## Declaración de VpnService

- **¿VPN como función principal?** No.
- **Función permitida:** seguridad del dispositivo / firewall de filtrado DNS.
- **Finalidad:** bloquear dominios de contenido adulto como herramienta opcional de recuperación y autocontrol.
- **Activación:** únicamente por acción del usuario, después de un aviso destacado y consentimiento explícito.
- **Tráfico procesado:** consultas DNS. No se enruta el resto del tráfico web por servidores de Victoria en Cristo.
- **Transmisión:** las consultas permitidas viajan cifradas por HTTPS al filtro familiar de CleanBrowsing.
- **Datos almacenados por Victoria en Cristo:** ninguno de los dominios consultados; sólo contadores locales de bloqueos.
- **Monetización o publicidad:** no se redirige ni manipula tráfico con fines comerciales y no se usa identificador publicitario.
- **Notificación:** permanente y visible mientras la protección está activa.
- **Video para revisión:** grabar en menos de 90 segundos: abrir Protección → tocar Activar → leer/aceptar el aviso → aceptar el permiso VPN de Android → mostrar la notificación persistente → abrir un dominio de prueba bloqueado → volver a Protección y mostrar el contador.

## Declaración de servicio en primer plano especial

El servicio mantiene activo un filtro DNS local que el usuario inicia explícitamente. Debe continuar cuando la app no está visible para proteger los navegadores. El estado siempre es perceptible mediante una notificación persistente y el usuario puede detenerlo desde la pantalla Protección.

## Justificación de alarma exacta

Las Alarmas Sagradas son recordatorios configurados por el usuario para oración y devocionales a una hora exacta. La puntualidad es la función principal de este módulo. La app solicita acceso sólo al activar alarmas estrictas y ofrece abrir los ajustes del sistema si el permiso no está disponible.

## Resumen para Data Safety

| Categoría | Uso | Tratamiento |
|---|---|---|
| Email, nombre, foto y UID | Cuenta, perfil y sincronización | Recopilado; cifrado en tránsito; eliminable |
| Progreso y configuración | Funcionalidad y sincronización | Recopilado; cifrado en tránsito; eliminable |
| Mensajes con compañeros | Función social privada | Recopilado; cifrado en tránsito; eliminable |
| Publicaciones del Muro | Comunidad anónima y moderación | Recopilado; sin UID visible; el contenido público puede conservarse anónimo |
| Identificadores de dispositivo | Token FCM | Recopilado para notificaciones; eliminable |
| Diagnóstico y actividad | Crashlytics y Analytics | Recopilado para estabilidad y métricas; sin AD_ID |
| Consultas DNS del Escudo | Filtrado familiar opcional | No recibidas ni almacenadas por Victoria en Cristo; enviadas cifradas a CleanBrowsing |

## URLs públicas

- Política de privacidad: https://dany36e.github.io/VictoriaEnCristo/privacy_policy.html
- Eliminación de cuenta: https://dany36e.github.io/VictoriaEnCristo/data_deletion.html

## Pendiente dentro de Play Console

- Proporcionar un correo público real de soporte.
- Aceptar Play App Signing y añadir a Firebase sus huellas SHA-1 y SHA-256.
- Completar Data Safety, clasificación de contenido y declaraciones de permisos.
- Subir el video del VpnService y capturas de la ficha.
- Ejecutar prueba interna y reporte previo al lanzamiento.
- Si la cuenta personal fue creada después del 13 de noviembre de 2023, completar prueba cerrada con 12 testers durante 14 días continuos.
