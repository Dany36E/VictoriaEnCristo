# Diccionario Strong en español: procedencia y regeneración

`assets/bible/lexicon/strong_greek.json` y `strong_hebrew.json` contienen una
**traducción propia al español** de los diccionarios de James Strong (1890,
dominio público), con el mismo esquema compacto que usaba la app
(`{meta, entries{G1:{w,x,p,o,d,u}}}`):

- `w` lema y `x` transliteración: copiados byte a byte de la edición digital
  (la interlineal y `original_*.json` dependen de ellos).
- `p` pronunciación; `o` etimología, `d` definición y `u` equivalentes de la
  KJV: traducidos al español. Las palabras griegas y hebreas citadas dentro del
  texto se restauran exactamente desde el original al ensamblar.

## Fuentes

| Idioma | Texto inglés traducido | Licencia del archivo digital |
|---|---|---|
| Griego | `strongsgreek.xml` de https://github.com/morphgnt/strongs-dictionary-xml (U. Sandborg-Petersen) | CC0 |
| Hebreo | `hebrew/strongs-hebrew-dictionary.js` de https://github.com/openscriptures/strongs (revisión `0acd2f251c2d35ff8db2dece4e0593979d3ac223`) | CC BY-SA 4.0 |

Lemas y transliteraciones de ambos idiomas: Open Scriptures (misma revisión).

Atribución que muestra la app (panel morfológico y búsqueda avanzada):

> Diccionario de Strong (1890), dominio público. Traducción propia al español.
> Hebreo: Texto fuente digital: Open Scriptures Hebrew Bible/Strong's (CC BY-SA 4.0);
> esta traducción se comparte bajo la misma licencia.
> Griego: Texto fuente: strongs-dictionary-xml (CC0).

## Regeneración

El proceso de traducción vive fuera del repositorio, en `contenido_es/`
(`GUIA_TRADUCCION.md`, `FUENTES.md`, `validar.py`, `ensamblar.py`,
`correcciones_strong.py`):

```text
python -I validar.py --manifiesto --obra strong_griego
python -I validar.py --manifiesto --obra strong_hebreo
python -I ensamblar.py --obra strong_griego
python -I ensamblar.py --obra strong_hebreo
python -I correcciones_strong.py --destino <repo>
```

`correcciones_strong.py` aplica las correcciones revisadas a mano contra el
texto de Strong y la RVR1960 (nombres propios con la grafía de la RVR1960,
«demonio» en H7700, «Menfis», «retama», «alianza», «Verbo» en G3056, etc.) y
limpia restos de la fuente digital (notas «lemma/xlit … corregido a …»,
letras sueltas).

El antiguo generador `tool/generate_strong_assets.dart` produce la versión
**inglesa**; no debe usarse para sobrescribir estos archivos.
