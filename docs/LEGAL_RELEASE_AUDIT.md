# Auditoría legal y de privacidad para producción

Fecha técnica: 2026-09-07. Este documento registra comprobaciones de producto; no sustituye la opinión de un abogado que conozca el responsable, el público y los países de distribución.

## Implementado

- Aviso de privacidad integral, términos, cookies/tecnologías similares, pagos/reembolsos, eliminación de datos y avisos de terceros.
- Analytics y Crashlytics desactivados por defecto en Android, iOS y Flutter; controles independientes y revocables en la app.
- Reproductor de YouTube bloqueado hasta una acción afirmativa; alternativa para abrirlo externamente.
- Consentimiento separado y no premarcado para términos y tratamiento de datos sensibles; versión y fecha registradas localmente y en el documento privado del usuario.
- Eliminación en servidor ampliada a publicaciones, comentarios y reportes vinculados al hash seudónimo del Muro.
- Eliminadas las afirmaciones absolutas “100% anónima” y “privacidad garantizada”. No se encontraron reseñas o testimonios comerciales falsos en la interfaz.
- Formularios de acceso con acciones de teclado, autofill, etiquetas visibles y controles estándar accesibles.
- Etiquetas semánticas o exclusión correcta de imágenes decorativas en las superficies principales.
- Contraste de texto secundario corregido en los temas que no alcanzaban 4.5:1 sobre sus tarjetas.
- No se requieren cookies para las páginas legales actuales: son estáticas, sin scripts, analítica, anuncios ni embeds.

## Bloqueos antes de producción

1. **Identidad legal:** proporcionar nombre o razón social, domicilio verificable y correo operativo para privacidad/ARCO y soporte. `soporte@victoriaencristo.app` no debe anunciarse hasta funcionar.
2. **Copyright bíblico:** archivar licencias de distribución digital completa para NVI, LBLA, NTV, TLA y RVR1960. La atribución dentro del XML no basta.
3. **Otros activos:** documentar procedencia y licencia de cartas Headbanz, fondos para compartir, portadas, audios y bases de comentarios. Retirar cualquier archivo sin evidencia.
4. **Tiendas:** hacer que Data Safety de Google Play y App Privacy de Apple coincidan exactamente con el binario final y todos sus SDK.
5. **Prueba de eliminación:** las reglas de Firestore y la nueva función `deleteUserData` quedaron desplegadas el 7 de septiembre de 2026. Falta ejecutar una baja real con una cuenta desechable y verificar que no queden documentos vinculables en las colecciones superiores.
6. **Público objetivo:** confirmar si la distribución será 13+, 17+ o sólo adultos y completar cuestionarios de contenido de ambas tiendas de forma coherente.
7. **Revisión jurídica:** validar el aviso bajo la LFPDPPP vigente y las jurisdicciones adicionales donde se distribuya. Si se dirige a la UE, EE. UU. u otros países, aplicar sus reglas específicas.
8. **Nombre y marca:** realizar una búsqueda profesional de antecedentes en IMPI/MARCia y en las tiendas antes de solicitar registro o afirmar exclusividad. “Victoria en Cristo” aparece en denominaciones de distintas asociaciones religiosas mexicanas; eso no prueba por sí solo un conflicto marcario, pero sí crea riesgo de confusión que debe revisarse.

## Declaraciones de tienda que requieren atención

- Datos de cuenta, contenido del usuario, identificadores, actividad de la app y diagnósticos.
- Datos sensibles voluntarios relacionados con religión, vida sexual, salud emocional o adicciones.
- Firebase Auth/Firestore/Functions/FCM; Analytics y Crashlytics como opcionales.
- YouTube, CleanBrowsing, Esri y APIs bíblicas activadas por función.
- Cifrado en tránsito, eliminación de cuenta y ausencia de publicidad/venta de datos.

## Evidencia recomendada

- Capturas del consentimiento sin casillas premarcadas y del Centro de privacidad.
- Exportación de Data Safety y App Privacy versionada junto con cada release.
- Comprobantes de licencias y atribuciones con fecha y alcance.
- Prueba de eliminación: UID de ensayo, fecha, resultado de la función y consultas que confirmen cero documentos vinculables.
