# Audio bíblico narrado (Bible Brain) — Configuración

La app lee la Biblia en voz alta de dos formas:

1. **Audio narrado** (voz humana) desde **Bible Brain**, la API de *Faith Comes
   By Hearing* (FCBH), también llamada *Digital Bible Platform v4* (DBP v4).
2. **Voz sintética** (TTS del dispositivo) cuando no hay clave, no hay
   internet, la plataforma no reproduce audio o **la versión que se está
   leyendo no tiene audio narrado configurado**.

Nunca se reproduce el audio de otra versión: si lees RVR1960 y solo hubiera
audio de la NVI, se usa la voz sintética.

---

## 1. Conseguir la clave gratuita

1. Entra a <https://www.biblebrain.com/> y busca la sección para
   desarrolladores (**API** → *Request an API key* / *Sign up*).
2. Completa el formulario: nombre, correo, organización o ministerio
   («Victoria en Cristo»), descripción del uso (app móvil cristiana gratuita
   que reproduce la Biblia en audio en español) y plataformas (Android/iOS).
3. Acepta los términos de uso de Bible Brain / FCBH y confirma tu correo.
4. La clave llega por correo o aparece en tu panel. Es una cadena larga; trátala
   como una contraseña.

Comprueba que funciona (reemplaza `TU_CLAVE`):

```
GET https://4.dbt.io/api/bibles?language_code=spa&v=4&key=TU_CLAVE
```

Si responde JSON con una lista de Biblias, la clave sirve.

---

## 2. Encontrar los fileset IDs de cada versión

### 2.1 Listar las Biblias en español

```
GET https://4.dbt.io/api/bibles?language_code=spa&v=4&key=TU_CLAVE
```

(Si hay varias páginas, agrega `&page=2`, `&page=3`…)

En cada resultado mira `abbr` / `name` / `vname` para reconocer la versión
(Reina-Valera 1960, NVI, LBLA, NTV, TLA) y anota su `abbr` (el *bible_id*,
p. ej. `SPNRVR`).

### 2.2 Ver los filesets de esa Biblia

```
GET https://4.dbt.io/api/bibles/{bible_id}?v=4&key=TU_CLAVE
```

En `data.filesets["dbp-prod"]` aparecen todos los filesets. Interesan los de
audio:

| `type`        | Qué es                                   |
|---------------|------------------------------------------|
| `audio_drama` | Audio dramatizado (varias voces, música) |
| `audio`       | Solo narración                           |

y su `size`: `OT` (Antiguo Testamento), `NT` (Nuevo Testamento) o `C`
(completa). Formato habitual del ID (10 caracteres):

```
SPN RVR N 2 DA
│   │   │ │ └─ DA = audio digital (mp3)
│   │   │ └─── 2 = dramatizado, 1 = no dramatizado
│   │   └───── O = Antiguo Testamento, N = Nuevo Testamento
│   └───────── versión
└───────────── idioma
```

Ignora los que terminan en `16`/`opus16` (otro formato) y los de `text`/`video`.

### 2.3 Probar un capítulo

```
GET https://4.dbt.io/api/bibles/filesets/{fileset_id}/JHN/3?v=4&key=TU_CLAVE
```

Debe devolver `data[0].path` con una URL de mp3. Los timestamps por versículo
(para resaltar el versículo que suena) se piden así:

```
GET https://4.dbt.io/api/timestamps/{fileset_id}/JHN/3?v=4&key=TU_CLAVE
```

No todos los filesets tienen timestamps; sin ellos el audio suena igual, pero
no se resalta el versículo.

### 2.4 Pasar los IDs al código

Todo el mapeo versión → filesets está en **un solo lugar**:
`kBibleAudioFilesets` en `lib/services/bible/bible_audio_service.dart`.
Cada versión tiene una lista para AT (`ot`) y otra para NT (`nt`), en orden de
preferencia (primero dramatizado, luego solo narración). La app prueba esa
lista en orden y recuerda durante la sesión cuál funcionó y cuáles fallaron.

> ⚠️ **Todos los IDs que hay hoy en el código son TENTATIVOS** y deben
> verificarse con los pasos de arriba antes de publicar:
>
> | Versión  | AT (tentativo)              | NT (tentativo)              |
> |----------|-----------------------------|-----------------------------|
> | RVR1960  | `SPNRVRO2DA`, `SPNRVRO1DA`  | `SPNRVRN2DA`, `SPNRVRN1DA`  |
> | NVI      | `SPNNVIO2DA`, `SPNNVIO1DA`  | `SPNNVIN2DA`, `SPNNVIN1DA`  |
> | LBLA     | `SPNBDAO2DA`, `SPNBDAO1DA`  | `SPNBDAN2DA`, `SPNBDAN1DA`  |
> | TLA      | `SPNTLAO2DA`, `SPNTLAO1DA`  | `SPNTLAN2DA`, `SPNTLAN1DA`  |
> | NIV (EN) | `ENGNIVO2DA`, `ENGNIVO1DA`  | `ENGNIVN2DA`, `ENGNIVN1DA`  |
>
> NTV, NLT y NKJV no tienen filesets configurados (usan voz sintética).
> Si una versión no aparece en Bible Brain, o su audio no tiene licencia para
> nosotros, **bórrala del mapa**: así nunca se intenta.

Los tests (`test/bible_audio_state_test.dart`) comprueban el formato de los
IDs, que cada versión solo use filesets de su propia Biblia y que AT/NT estén
en su lista correcta.

---

## 3. Dónde poner la clave

En `lib/config/api_config.dart` (este archivo está en `.gitignore`):

```dart
static const String bibleBrainKey = 'TU_CLAVE';
```

- **Nunca** subas la clave al repositorio, ni la pegues en issues, PRs,
  capturas o chats.
- Si la clave se filtra, pide una nueva en Bible Brain y deja de usar la
  anterior.
- Con la clave vacía (`''`) la app funciona igual, solo con voz sintética.

---

## 4. Licencias del audio (confirmar ANTES de publicar)

Tener la clave de la API **no** significa tener permiso para usar todas las
grabaciones en la app. Antes de activar el audio narrado en producción:

1. **Lee los términos de Bible Brain / FCBH** (en el sitio y en el correo de la
   clave): uso permitido, atribución obligatoria, prohibición de descargar o
   guardar el audio de forma permanente, límites de uso, etc.
2. **El texto y la grabación de cada versión tienen dueño propio.** Por
   ejemplo, la Reina-Valera 1960 y su audio son © Sociedades Bíblicas Unidas;
   la NVI © Biblica; la LBLA © The Lockman Foundation; la TLA © Sociedades
   Bíblicas Unidas. FCBH distribuye, pero el permiso de **streaming y
   redistribución dentro de una app** depende del titular de cada versión.
3. **Pide confirmación por escrito** (correo de FCBH o del titular) de que la
   app «Victoria en Cristo» puede reproducir por streaming el audio de cada
   versión que vayas a activar. Guarda esos correos.
4. **Uso comercial** (suscripción, anuncios, compras dentro de la app): hay que
   contactar a FCBH antes (partnerships@fcbh.org) y, si corresponde, al
   titular de la versión. Los permisos gratuitos suelen ser solo para uso no
   comercial / ministerial.
5. Muestra la **atribución** que pidan (p. ej. «Audio: Faith Comes By
   Hearing — Reina-Valera 1960 © Sociedades Bíblicas Unidas») en la pantalla de
   ajustes o créditos.

Hasta tener esa confirmación, deja `bibleBrainKey` vacía en las compilaciones
de producción: la app usará la voz sintética.

---

## 5. Cómo se comporta la app

- Las URLs de audio expiran: se guardan solo en memoria durante la sesión.
- Un fileset que la API rechaza (4xx o sin datos) no se vuelve a probar en la
  sesión; un error de red o timeout sí se reintenta la próxima vez.
- Velocidad (0,75x–2x), avance automático al siguiente capítulo, temporizador
  de sueño y voz sintética se configuran en la barra del reproductor y en
  Ajustes de la Biblia → Audio.
