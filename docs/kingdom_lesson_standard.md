# Escuela del Reino: Estándar de Lección Bíblica

## Propósito
Este documento define cuándo una lección de `Escuela del Reino` puede
considerarse bíblicamente estructurada, pedagógicamente clara y lista para
revisión teológica.

La prioridad es profundidad y fidelidad bíblica, no cantidad de lecciones.

## Plantilla mínima
Toda lección bíblica de ruta principal debe incluir:

- `title`
- `objective`
- `unitId`
- `moduleKey`
- `competencyIds`
- `lessonGoal`
- `practiceMode`
- `baseTextRefs`
- `keyVerseRef`
- `contextNote`
- `doctrinePoint`
- `doctrinalCategory`
- `applicationPrompt`
- `questions`
- `quizItems`
- `commonErrors`
- `masteryCriteria`
- `theologyReviewStatus`

## Campos obligatorios
- `objective`: qué debe aprender el usuario al terminar.
- `baseTextRefs`: referencias base en RVR1960.
- `keyVerseRef`: versículo clave de retención.
- `contextNote`: contexto histórico, literario o teológico breve.
- `doctrinePoint`: verdad doctrinal central de la lección.
- `doctrinalCategory`: categoría doctrinal o formativa.
- `applicationPrompt`: respuesta práctica concreta.
- `competencyIds`: habilidades bíblicas que entrena.
- `questions`: preguntas de comprensión.
- `quizItems`: evaluación breve.
- `commonErrors`: errores de interpretación o aplicación a evitar.
- `masteryCriteria`: cómo saber si hubo dominio.
- `theologyReviewStatus`: `draft`, `needsReview`, `reviewed` o `approved`.

## Campos opcionales
- `christConnection`: cómo la lección apunta a Cristo cuando aplique.
- `reviewAfterLessonIds`: lecciones previas que conviene mezclar en repaso.
- `reviewedBy`
- `reviewedAt`
- `reviewNotes`

Nota:
`reviewedBy`, `reviewedAt` y `reviewNotes` se vuelven obligatorios cuando el
estado pasa a `reviewed` o `approved`.

## Estructura pedagógica recomendada
La experiencia de una lección debe seguir esta secuencia:

1. `Objetivo`
2. `Texto base RVR1960`
3. `Versículo clave`
4. `Contexto`
5. `Verdad central`
6. `Conexión con Cristo` cuando aplique
7. `Preguntas de comprensión`
8. `Mini quiz`
9. `Aplicación`
10. `Errores comunes`
11. `Criterio de dominio`
12. `Estado de revisión teológica`

## Ejemplo resumido
```json
{
  "id": "gospel_christ",
  "title": "Cristo en el centro del evangelio",
  "objective": "Comprender que Jesús murió por nuestros pecados y resucitó conforme a las Escrituras.",
  "moduleKey": "kingdom_lesson",
  "practiceMode": "learn",
  "competencyIds": ["gospel_core", "reading_observation"],
  "baseTextRefs": ["1 Corintios 15:3-4", "Romanos 5:8"],
  "keyVerseRef": "1 Corintios 15:3-4",
  "contextNote": "Pablo resume el evangelio recibido y entregado a la iglesia de Corinto como verdad central de la fe cristiana.",
  "doctrinePoint": "El evangelio bíblico se centra en la muerte y resurrección de Cristo por nuestros pecados.",
  "doctrinalCategory": "Evangelio y salvación",
  "christConnection": "Jesús es el cumplimiento de la promesa redentora de Dios.",
  "applicationPrompt": "Explica con tus palabras por qué la resurrección de Cristo cambia tu esperanza hoy.",
  "commonErrors": [
    "Reducir el evangelio a consejos morales.",
    "Hablar de Jesús sin mencionar su muerte y resurrección."
  ],
  "masteryCriteria": "Puede resumir el evangelio bíblico en una explicación breve y fiel al texto.",
  "questions": [
    {
      "id": "q1",
      "prompt": "¿Qué elementos del evangelio aparecen en 1 Corintios 15:3-4?",
      "expectedIdea": "La muerte de Cristo por nuestros pecados, su sepultura y su resurrección."
    }
  ],
  "quizItems": [
    {
      "id": "quiz1",
      "type": "multipleChoice",
      "prompt": "¿Qué hace central al evangelio según Pablo?",
      "options": [
        "La superación personal",
        "La muerte y resurrección de Cristo",
        "La tradición religiosa",
        "La experiencia emocional"
      ],
      "correctIndex": 1,
      "explanation": "Pablo presenta el evangelio como la obra histórica de Cristo por nuestros pecados.",
      "ref": "1 Corintios 15:3-4"
    }
  ],
  "theologyReviewStatus": "reviewed",
  "reviewedBy": "Equipo curricular",
  "reviewedAt": "2026-05-24",
  "reviewNotes": "Lista para revisión pastoral final."
}
```

## Checklist de calidad
### Bíblico
- Usa referencias RVR1960.
- No depende de versículos aislados fuera de contexto.
- Distingue texto, doctrina y aplicación.

### Doctrinal
- Tiene una verdad central clara.
- Identifica errores comunes.
- Tiene categoría doctrinal definida.
- No adelanta temas avanzados sin fundamento previo.

### Pedagógico
- Enseña una idea principal por lección.
- Las preguntas miden comprensión, no solo memoria.
- El quiz confirma el objetivo real.
- La aplicación es concreta y alcanzable.

### UX
- El usuario entiende la lección sin saturación visual.
- El siguiente paso está claro al terminar.
- El feedback del quiz corrige con claridad y amabilidad.

### Técnico
- La lección pasa `validationIssues(requireStructuredContent: true)`.
- Si está en `reviewed` o `approved`, también pasa
  `validationIssues(requireStructuredContent: true, requireReviewTrail: true)`.

## Criterios para aprobar una lección
Una lección puede marcarse `approved` solo si:

- Tiene contenido bíblico estructurado completo.
- Tiene trazabilidad de revisión.
- Sus preguntas y quiz sí miden el objetivo central.
- Su aplicación no reemplaza la interpretación.
- Un revisor humano confirma fidelidad doctrinal.

## Criterios para rechazar o devolver a borrador
- Falta texto base o versículo clave.
- El quiz es trivia o no mide la verdad principal.
- La aplicación es vaga o sentimental sin anclaje bíblico.
- La doctrina está adelantada respecto al nivel.
- No hay revisión teológica documentada.
