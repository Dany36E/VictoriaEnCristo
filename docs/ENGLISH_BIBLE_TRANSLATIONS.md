# Traducciones bíblicas en inglés

La aplicación reconoce tres traducciones en inglés y las muestra en una
sección separada de las traducciones en español:

- `NIV_EN`: New International Version (NIV)
- `NLT`: New Living Translation (NLT)
- `NKJV`: New King James Version (NKJV)

Estas traducciones no se incluyen en el paquete de la aplicación porque su
texto está protegido por derechos de autor. Los archivos obtenidos de fuentes
de terceros no deben copiarse a `assets/` ni publicarse en el repositorio sin
una licencia o autorización verificable para distribución dentro de la app.

## Activación después de obtener permiso

1. Obtén autorización del titular de cada traducción para el uso previsto.
2. Aloja cada XML autorizado en una ubicación HTTPS controlada y privada.
3. En Firestore, crea o actualiza `config/bibleDownloads` con un mapa `urls`:

```text
urls:
  NIV_EN: https://servidor.example/NIV.xml
  NLT: https://servidor.example/NLT.xml
  NKJV: https://servidor.example/NKJV.xml
```

4. Conserva el formato XML que ya acepta el lector (`biblebook`, `chapter` y
   `verse`). Si el XML omite nombres de libros, la app aplica los nombres
   canónicos en inglés.
5. Prueba la descarga, búsqueda, comparación y lectura en voz alta antes de
   publicar. La voz se selecciona con preferencia por `en-US` y respaldo en
   `en-GB`.

No se deben guardar tokens, claves privadas ni URLs firmadas permanentes en el
repositorio. Si el proveedor exige autenticación, usa un backend autorizado que
entregue el contenido de acuerdo con sus términos.
