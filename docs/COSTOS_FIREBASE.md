# Costos de Firebase y cómo protegerte

Guía para mantener Victoria en Cristo dentro de **~100 pesos al mes** (unos
5 dólares, según el tipo de cambio) con más de 100 personas usándola diario,
y con frenos por si algo se sale de control.

> Precios y cuotas revisados en octubre de 2026. Google los cambia de vez en
> cuando: antes del lanzamiento revisa la página oficial de
> [precios de Firebase](https://firebase.google.com/pricing).

## 1. Cómo cobra Firebase en el plan Blaze

Blaze es «pago por uso», **pero conserva las mismas cuotas gratis del plan
Spark**. Solo pagas lo que pase de esas cuotas, y cada cuota se reinicia sola
(por día o por mes). Si tu uso queda debajo, la factura es de $0.

| Servicio | Gratis | Se reinicia |
|---|---|---|
| Firestore: lecturas | 50,000 documentos | cada día |
| Firestore: escrituras | 20,000 documentos | cada día |
| Firestore: borrados | 20,000 documentos | cada día |
| Firestore: almacenamiento | 1 GiB | — |
| Cloud Functions | 2 millones de llamadas, 400,000 GB-s y 200,000 GHz-s | cada mes |
| Cloud Scheduler (tareas programadas) | 3 tareas | cada mes |
| Storage (bucket `*.firebasestorage.app` en us-central1, us-east1 o us-west1) | 5 GB guardados, 100 GB de descarga, 5,000 subidas y 50,000 descargas | cada mes |
| Storage (bucket antiguo `*.appspot.com`) | 5 GB guardados, 1 GB de descarga, 20,000 subidas y 50,000 descargas | cada día |
| Authentication (correo, Google, Apple) | ilimitado para este uso | — |
| Cloud Messaging (notificaciones), Analytics, Crashlytics | sin costo | — |
| App Check con Play Integrity | 10,000 verificaciones | cada día |

Lo que se cobra al pasar la cuota son centavos de dólar: por ejemplo, las
lecturas extra de Firestore cuestan unos pocos centavos por cada 100,000.
El riesgo real no es el uso normal, sino un error (un ciclo que lee sin
parar) o alguien que abuse de la app con un script. Para eso son los
protectores de abajo.

Fuentes: [precios de Firestore](https://firebase.google.com/docs/firestore/pricing),
[planes de Firebase](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans),
[cambios de Storage](https://firebase.google.com/docs/storage/faqs-storage-changes-announced-sept-2024),
[precios de Cloud Functions](https://cloud.google.com/functions/pricing-1stgen),
[Cloud Scheduler](https://cloud.google.com/scheduler/pricing),
[cuotas de Play Integrity](https://developer.android.com/google/play/integrity/setup).

## 2. Cuánto gasta la app

### Por persona al día (aproximado)

| Qué hace | Lecturas | Escrituras |
|---|---|---|
| Abrir la app (perfil, racha de 90 días, insignias, favoritos, diario) | 5 a 250 la primera vez del día; casi nada si la vuelve a abrir antes de 30 min | — |
| Entrar a la Biblia (subrayados, notas, guardados, oraciones; con límite) | 10 a 700 la primera vez del día | — |
| Marcar la victoria del día, subrayar, escribir notas o apuntes | — | 5 a 40 |
| Muro (20 publicaciones por página) | 20 por página | solo al publicar |
| Fotos y dibujos de Apuntes | se descargan una vez y quedan en el teléfono | ~0.3 a 1.5 MB por foto |

Una persona **típica** gasta unas **150 lecturas y 20 escrituras** al día; una
muy **intensa** (cientos de subrayados y notas, entra varias veces), unas
**600 lecturas y 60 escrituras**.

### Escenarios al mes (Firestore, región us-central1)

Precio al pasar la cuota: 0.03 USD por cada 100,000 lecturas y 0.09 USD
por cada 100,000 escrituras ([fuente](https://cloud.google.com/firestore/pricing);
si tu base está en una región múltiple como `nam5`, es más o menos el doble).

| Personas al día | Uso típico | Todas muy intensas |
|---|---|---|
| 100 | 15,000 lecturas/día → **$0** | 60,000 lecturas/día → ~0.10–0.20 USD |
| 300 | 45,000 lecturas/día → **$0** | 180,000 lecturas/día → ~1–2.5 USD |
| 1,000 | 150,000 lecturas/día → ~1–2 USD | 600,000 lecturas/día → ~6–12 USD |

Lo demás, con este tamaño, queda dentro de lo gratis:

- **Cloud Functions:** unos miles de llamadas al mes (Muro, compañero,
  salas, borrar cuenta, y la tarea de cada 5 minutos de las salas, ~8,600
  al mes) contra 2 millones gratis.
- **Storage:** 300 personas con 10 fotos cada una son ~2.5 GB, debajo de
  los 5 GB gratis. Las descargas se guardan en el teléfono.
- **Authentication, notificaciones, Analytics, Crashlytics:** sin costo.

**Conclusión:** con 100 a 300 personas diarias la factura esperada es de
**$0 con uso normal** y, en el peor caso (todas usándola muchísimo), de unos
**50 pesos al mes**; tus 100 pesos alcanzan con margen. Lo que
puede disparar la factura no es el uso normal, sino un error o un abuso,
y para eso son los protectores.

## 3. Protectores que ya están en el código

**Cloud Functions**
- Cada función tiene **tope de instancias** (`functions/src/limites.ts`): 10
  a la vez en general, 1 en las tareas programadas y 3 en «borrar cuenta».
  Una ola de llamadas ya no puede levantar cientos de servidores.
- Todas corren en `us-central1`, la región con cuotas gratis.
- Límites por persona en el servidor (un cliente modificado no los puede
  saltar):
  - Muro: 3 publicaciones por hora y 5 al día, 10 comentarios por hora y 30
    al día, 20 reportes al día; textos de máximo 500 y 300 caracteres.
  - Compañero de batalla: máximo 5 compañeros, 3 mensajes y 1 SOS al día.
  - Salas de estudio: 10 salas al día por persona.
  - Candado del guardián: 5 intentos de PIN y 5 solicitudes al día.
- Solo hay 3 tareas programadas (las 3 que Google regala). Agregar una
  cuarta costaría unos 0.10 USD al mes.
- Al cerrar una sala de estudio vacía o vieja se borran también sus
  subrayados y respuestas (antes quedaban huérfanos ocupando espacio).
- Interruptor para exigir App Check en las funciones (ver 4.3).

**Firestore**
- Reglas «negar todo» por defecto: cada persona solo lee y escribe sus
  propios datos; lo compartido (Muro, salas) pasa por funciones.
- Las listas grandes se leen con límite (Muro de 20 en 20, apuntes hasta
  300, subrayados hasta 150…) y con caché en el teléfono (50 MB), así que
  abrir de nuevo una pantalla casi no cuesta.
- Los módulos se conectan solo cuando la persona entra a ellos (la Biblia,
  Apuntes o el compañero de batalla no abren conexiones al iniciar sesión).
- No se repiten lecturas ni escrituras:
  - El registro de ejercicios solo descarga lo nuevo y solo sube lo que
    falta. Antes, **cada arranque leía 200 documentos y reescribía 50**;
    con 100 personas eso solo se comía casi toda la cuota diaria.
  - Marcar la victoria del día escribe una vez (antes, una por gigante).
  - Apuntes y Modo Estudio no vuelven a guardar si cierras sin editar
    (antes, cada cierre era una escritura y además subía el apunte al primer
    lugar de «Más recientes»).
  - Las salas de estudio solo suben tus respuestas si cambiaron (antes, cada
    3 minutos aunque no cambiaran, más una lectura por compañero).
  - Las preferencias no se escriben si la nube ya tiene lo mismo, y las
    subidas que llegan juntas al pasar la app a segundo plano se combinan
    en una sola.
  - El tamaño de letra se guarda al soltar el deslizador, no en cada paso.
  - El progreso para tus compañeros de batalla se agrupa 30 segundos.
- Se corrigieron dos lecturas y escrituras que las reglas rechazaban en
  cada intento: el reflejo de tu racha en la ficha de cada compañero (que
  además hacía fallar tu propio progreso público) y la versión mínima de la
  app (`app_config`).

**Storage**
- Solo se aceptan las fotos y dibujos de Apuntes, con el nombre que crea la
  app, su tipo exacto y un tamaño máximo (3 MB las fotos, 5 MB los
  dibujos). Nadie puede usar el bucket como disco duro.
- Las fotos se reducen a 2048 px al 82 % antes de subirse, y lo que ya se
  descargó se guarda en el teléfono: verlas otra vez no vuelve a descargar.


## 4. Lo que debes configurar tú en la consola

Estos frenos no se pueden poner desde el código: se activan en la consola de
Firebase o de Google Cloud con tu cuenta.

### 4.1 Alertas de presupuesto (hazlo ya)

Una alerta **no detiene el gasto**: solo te manda un correo. Aun así es lo
primero, porque te enteras el mismo día.

1. Entra a [console.firebase.google.com](https://console.firebase.google.com),
   abre el proyecto y ve a ⚙️ → **Uso y facturación** → **Detalles y
   configuración** (o directo en Google Cloud: **Facturación** →
   **Presupuestos y alertas**).
2. **Crear presupuesto** para este proyecto:
   - Hoy (pruebas): monto de **5 USD** o **100 MXN** (la moneda la pone tu
     cuenta de facturación).
   - Alertas al **25 %, 50 %, 90 % y 100 %** del gasto real, y al **100 %
     del gasto previsto** (te avisa antes de que pase).
3. Agrega tu correo y el de alguien de confianza como destinatarios.

Fuente: [alertas de presupuesto de Firebase](https://firebase.google.com/docs/projects/billing/budget-alerts),
[presupuestos de Cloud Billing](https://docs.cloud.google.com/billing/docs/how-to/budgets).

### 4.2 Tope de gasto para Cloud Functions (spend cap)

Firebase ya permite un **tope que sí pausa el servicio**, pero solo para
algunos productos; de los que usa la app, aplica a **Cloud Functions**.
Si las funciones llegan al monto del mes, Google las pausa hasta el mes
siguiente (el Muro, el compañero de batalla, las salas de estudio y borrar
cuenta dejan de funcionar, pero no se cobra más).

1. Firebase → ⚙️ → **Uso y facturación** → **Presupuestos y alertas**.
2. Crea un presupuesto de **un solo proyecto y un solo servicio: Cloud
   Functions**, mensual, y marca la opción de **pausar el servicio** al
   llegar al 100 %.
3. Con lo que gasta la app hoy, un tope de **2 USD** para funciones basta y
   deja margen.

Fuente: [spend caps en Firebase](https://firebase.google.com/docs/projects/billing/spend-caps).

### 4.3 App Check en modo «obligatorio» (antes de publicar)

App Check comprueba que quien llama a Firestore, Storage o las funciones es
**tu app original instalada desde la tienda**, no un script. Es el protector
más fuerte contra abuso. La app ya lo activa (Play Integrity en Android,
DeviceCheck en iPhone), pero en la consola está en **modo monitor**: mide,
no bloquea.

1. Firebase → **App Check** → pestaña **APIs**.
2. Revisa unas semanas que casi todo el tráfico salga como «verificado».
3. Pulsa **Aplicar** (enforce) en **Cloud Firestore** y **Cloud Storage**.
4. Las **Cloud Functions** no se encienden desde la consola sino en el
   código; ya está listo un interruptor. Crea el archivo `functions/.env`
   (no se sube a GitHub) con la línea `EXIGIR_APP_CHECK=true` y vuelve a
   desplegar con `firebase deploy --only functions`.
5. Para seguir probando con versiones de desarrollo, registra el *debug
   token* que imprime la app en la consola de App Check.

Play Integrity regala 10,000 verificaciones al día; con 300 personas se usan
unas cuantas centenas. Si un día creciera mucho, se pide más cuota en Play
Console.

### 4.4 Limpieza de imágenes de las funciones

Cada vez que se despliegan las funciones, Google guarda una imagen en
Artifact Registry. Si se acumulan pasan de lo gratis y cobran centavos cada
mes. Una vez, con la CLI de Firebase:

```bash
firebase functions:artifacts:setpolicy
```

Eso deja una regla que borra las imágenes viejas automáticamente (la CLI
también lo ofrece al desplegar).

### 4.5 Interruptor de emergencia (opcional, con cuidado)

Google documenta una función que **quita la facturación del proyecto** cuando
el presupuesto llega al 100 %. Es el único freno total, pero es drástico:
apaga **todo** (incluso lo gratis), la app deja de sincronizar y volver a
encenderlo es manual; Google advierte que algunos recursos podrían no
recuperarse. Además, las notificaciones de presupuesto llegan con retraso
(cada ~20 minutos), así que no garantiza no pasarse unos centavos.

Recomendación: **no** lo actives al principio. Con las alertas, el tope de
Functions, App Check obligatorio y los protectores del código, el riesgo ya
es muy bajo. Si algún día quieres el interruptor, la guía oficial es
[desactivar la facturación con notificaciones](https://docs.cloud.google.com/billing/docs/how-to/disable-billing-with-notifications)
y [Evita facturas sorpresa](https://firebase.google.com/docs/projects/billing/avoid-surprise-bills).

### 4.6 Revisión semanal (5 minutos)

- Firebase → **Uso y facturación**: gasto del mes y proyección.
- Firestore → **Uso**: lecturas por día. Si pasan de ~40,000 seguido, algo
  cambió (o la app creció): avísame y lo revisamos.
- Storage → **Uso**: GB guardados y descargados.

## 5. Plan hasta el lanzamiento (diciembre de 2026)

| Cuándo | Qué hacer |
|---|---|
| Ya | Alerta de presupuesto de 5 USD (4.1) y limpieza de imágenes (4.4). |
| Al desplegar este cambio | `firebase deploy --only functions,firestore:rules,storage` para subir los topes de instancias y las reglas nuevas. |
| Noviembre | Tope de gasto de Cloud Functions (4.2). Registrar los *debug tokens* de App Check y revisar en la consola que el tráfico salga verificado. |
| Antes de publicar | App Check obligatorio en la consola y `EXIGIR_APP_CHECK=true` en las funciones (4.3). Subir la alerta a 100 MXN / 5–6 USD. |
| Primer mes publicado | Revisión semanal (4.6). Si las lecturas pasan de ~40,000 diarias seguido, revisar qué pantalla las genera. |

## 6. Probar las reglas

Las reglas de Firestore y Storage tienen pruebas en el emulador oficial
(`tools/pruebas-reglas`). Necesitan Java 11 o más:

```bash
cd tools/pruebas-reglas
npm install
npm test
```

