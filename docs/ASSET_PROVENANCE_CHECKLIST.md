# Control de procedencia de activos

Este inventario no concede derechos. Cada grupo debe tener una fuente y licencia verificables antes de producción. Los comprobantes privados deben guardarse fuera de GitHub.

| Grupo | Cantidad actual | Estado de procedencia | Evidencia requerida |
|---|---:|---|---|
| Textos y datos bíblicos (`assets/bible`) | 265 | Bloqueado | Autorización de distribución completa por traducción y plataforma |
| Contenido local (`assets/content`) | 24 | Por documentar | Autor, fecha y cesión o licencia |
| Imágenes y portadas (`assets/images`) | 89 | Por documentar | Archivo fuente, autor, licencia y modificaciones permitidas |
| Audio, música y efectos (`assets/sounds`) | 14 | Por documentar | Licencia de sincronización/distribución y comprobante |
| Marca (`assets/branding`) | 2 | Por documentar | Autoría/cesión del logo y búsqueda marcaria |

Para marcar un grupo como aprobado, registrar en un archivo privado: nombre exacto, ruta en la app, titular, URL o contrato de origen, tipo de licencia, fecha de obtención, territorios, plataformas, atribución obligatoria, restricciones y ubicación del comprobante. Si un dato falta, el activo se considera no aprobado.

## Diccionario Strong en español (`assets/bible/lexicon/strong_*.json`)

- **Obra:** diccionarios griego y hebreo de James Strong (1890), dominio público. Traducción propia al español de Victoria en Cristo.
- **Hebreo:** texto fuente digital Open Scriptures Hebrew Bible/Strong's (CC BY-SA 4.0); la traducción se comparte bajo la misma licencia (CC BY-SA 4.0).
- **Griego:** texto fuente strongs-dictionary-xml (U. Sandborg-Petersen, CC0).
- **Atribución en la app:** «Diccionario de Strong (1890), dominio público. Traducción propia al español.» más la línea del idioma, en el panel morfológico y en la búsqueda avanzada. Detalle y regeneración: `docs/STRONG_LEXICON_SOURCE.md`.

## Diccionario Bíblico de Easton en español (`assets/bible/dictionary/easton.json`)

- **Obra:** M. G. Easton, *Easton's Bible Dictionary* (1897), dominio público (el autor murió en 1894). Traducción propia al español de Victoria en Cristo.
- **Texto fuente:** CCEL, ThML v2.0 (https://ccel.org/ccel/easton/ebd2.xml), metadatos `<DC.Rights>Public Domain</DC.Rights>`; SHA-256 del archivo usado `10e3f432e38ee8197c30a613576dc363af3f29fa4aa90ebd0782533df906e5f1`.
- **Contenido:** 3964 entradas `{id, term, term_en, definition, references, see, source}`. La definición conserva marcadores `[[GEN.2.7|Gn 2:7]]` (citas, abren el lector) y `[[VER:e0054|ABRAHAM]]` («Véase», abren la entrada). Generado con `contenido_es/ensamblar.py --obra easton --conservar-marcadores` y `contenido_es/correcciones_easton.py` (grafías de nombres propios según la RVR1960, títulos de obras citadas en su inglés original, enlaces «Véase» verificados).
- **Atribución en la app:** «Diccionario Bíblico de Easton (1897), dominio público. Traducción propia al español.» en la lista del diccionario, en el detalle de cada entrada y en la hoja rápida.
- **Hitchcock (`hitchcock.json`):** breve lista de nombres propios en español (*Hitchcock's Bible Names*, 1869, dominio público), sin cambios.
