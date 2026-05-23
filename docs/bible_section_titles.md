# Bible Section Titles

La app usa subtítulos de navegación propios para ayudar en el lector y en el modo estudio.

## Qué son

- No copian encabezados editoriales de versiones protegidas.
- Son títulos descriptivos creados para orientar la lectura.
- Se renderizan antes del versículo indicado por la clave `bookNumber:chapter:startVerse`.

## Assets

- Base compartida: `assets/bible/section_titles.json`
- Mapas por versión: `assets/bible/section_title_overrides.json`

## Versiones cubiertas

- `RVR1960`
- `NVI`
- `NTV`
- `TLA`

## Generación

```powershell
python tool\bible\generate_versioned_section_titles.py
```

## Validación

```powershell
python tool\bible\validate_section_titles.py
```

La validación revisa:

- que cada clave apunte a un capítulo y versículo existente en el XML real;
- que los títulos no estén vacíos ni tengan problemas básicos de formato;
- que la cobertura por versión sea consistente con los archivos de la app.

## Nota sobre TLA

`TLA.xml` tiene 2 posiciones donde la estructura del XML no coincide con la base común:

- `3:23:33`
- `23:38:1`

Por eso el generador las omite solo para `TLA`.
