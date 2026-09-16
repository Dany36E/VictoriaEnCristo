# Léxico Strong local: procedencia y regeneración

La app usa los diccionarios griego y hebreo de **Open Scriptures / Strong's
Dictionaries**:

- Repositorio: https://github.com/openscriptures/strongs
- Revisión usada: `0acd2f251c2d35ff8db2dece4e0593979d3ac223`
- Archivos de origen:
  - `greek/strongs-greek-dictionary.js`
  - `hebrew/strongs-hebrew-dictionary.js`
- Licencia declarada en esos archivos: **CC BY-SA**, derivados de las ediciones
  XML de dominio público de los diccionarios históricos de James Strong.

Los JSON en `assets/bible/lexicon/` son una transformación mecánica y compacta:
no se traducen ni se reescriben las definiciones. El índice de apariciones se
genera a partir de los interlineales locales. El arameo queda excluido de esta
etapa de forma intencional.

Para regenerar los cuatro activos, descarga los dos archivos anteriores y
ejecuta:

```text
dart run tool/generate_strong_assets.dart <greek-js> <hebrew-js>
```

El generador informa cuántas entradas, términos y vínculos se produjeron. No
debe publicarse una versión regenerada sin conservar esta atribución y revisar
si el origen o su licencia cambiaron.
