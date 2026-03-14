# 📝 Guía Editorial para Contenido Personalizado

## Visión General

Todo el contenido en la app debe estar estructurado con **metadatos de taxonomía** que permiten al `PersonalizationEngine` recomendar el contenido correcto al usuario correcto en el momento correcto.

---

## 🎯 Los 6 Gigantes

| ID | Nombre | Emoji | Descripción |
|----|--------|-------|-------------|
| `digital` | Pornografía / Digital | 📱 | Adicción a pornografía, redes sociales, contenido digital |
| `sexual` | Conducta Sexual | 💔 | Comportamientos sexuales compulsivos, infidelidad |
| `health` | Salud / Alimentación | 🍔 | Trastornos alimenticios, sedentarismo, excesos |
| `substances` | Sustancias | 🍺 | Alcohol, tabaco, drogas |
| `mental` | Salud Mental | 🧠 | Ansiedad, depresión, pensamientos negativos |
| `emotions` | Control Emocional | 😤 | Ira, impulsividad, manejo de emociones |

### Regla de Asignación
- Cada contenido debe tener **1-3 gigantes** asociados
- El **primer gigante** en el array es el **primario** (más relevante)
- Evitar asignar más de 3 gigantes (pierde especificidad)

---

## 📊 Etapas del Usuario

| ID | Nombre | Cuándo Aplicar |
|----|--------|----------------|
| `crisis` | Crisis / Urgencia | Usuario en momento de tentación activa |
| `habit` | Formación de Hábito | Primeros 60 días, estableciendo rutinas |
| `maintenance` | Mantenimiento | Usuario estable, prevención de recaídas |
| `restoration` | Restauración | Después de una recaída, sanando |

### Cómo Elegir Etapa
- **Crisis**: Contenido corto, accionable, de emergencia
- **Hábito**: Contenido educativo, técnicas nuevas
- **Mantenimiento**: Contenido de refuerzo, recordatorios
- **Restauración**: Contenido de gracia, perdón, esperanza

---

## 🛠️ Técnicas Permitidas

Solo usar técnicas validadas psicológicamente:

| ID | Nombre | Descripción |
|----|--------|-------------|
| `craving_surfing` | Surfear el Antojo | Observar el antojo sin actuar |
| `urge_delay` | Retraso de Impulso | Esperar 10 minutos antes de actuar |
| `CBT_reframe` | Reestructuración Cognitiva | Cambiar pensamientos automáticos |
| `mindfulness` | Atención Plena | Estar presente sin juicio |
| `grounding` | Anclaje Sensorial | Técnica 5-4-3-2-1 para ansiedad |
| `accountability` | Rendición de Cuentas | Involucrar a otros en el proceso |
| `replacement_behavior` | Conducta de Reemplazo | Sustituir comportamiento negativo |
| `trigger_avoidance` | Evitación de Triggers | Identificar y evitar situaciones |
| `breathing` | Respiración | Técnicas de respiración calmante |
| `gratitude` | Gratitud | Enfocarse en lo positivo |
| `prayer` | Oración | Conexión espiritual |
| `scripture_meditation` | Meditación Bíblica | Reflexión profunda en versículos |

### ⚠️ Técnicas NO Permitidas
- Terapia de aversión
- Castigo o vergüenza
- Supresión de pensamientos
- "Solo di no" sin herramientas

---

## 🎭 Triggers (Detonantes)

| ID | Descripción |
|----|-------------|
| `boredom` | Aburrimiento |
| `stress` | Estrés |
| `loneliness` | Soledad |
| `tiredness` | Cansancio físico |
| `anger` | Enojo |
| `anxiety` | Ansiedad |
| `rejection` | Rechazo |
| `celebration` | Celebración (trigger positivo) |
| `temptation` | Tentación directa |
| `visual_trigger` | Estímulo visual |

---

## ✅ Outcomes (Resultados Esperados)

| ID | Descripción |
|----|-------------|
| `peace` | Paz interior |
| `clarity` | Claridad mental |
| `strength` | Fortaleza |
| `hope` | Esperanza |
| `self_control` | Dominio propio |
| `connection` | Conexión con Dios/otros |
| `forgiveness` | Perdón |
| `joy` | Gozo |
| `freedom` | Libertad |
| `wisdom` | Sabiduría |

---

## 📄 Templates por Tipo de Contenido

### 📖 Versículo (VerseItem)

```json
{
  "id": "v001",
  "type": "verse",
  "title": "Título descriptivo (3-7 palabras)",
  "subtitle": "Tema o aplicación breve",
  "verse": "Texto completo del versículo",
  "reference": "Libro Capítulo:Versículo (RVR1960 o NVI)",
  "metadata": {
    "giants": ["giant_primario", "giant_secundario"],
    "stage": "crisis|habit|maintenance|restoration",
    "intensityFit": [1, 2, 3],
    "techniques": ["technique_id"],
    "triggers": ["trigger_id"],
    "outcomes": ["outcome_id"],
    "source": "bible",
    "reviewLevel": "approved"
  }
}
```

**Ejemplo:**
```json
{
  "id": "v001",
  "type": "verse",
  "title": "Promesa de Escape",
  "subtitle": "Dios siempre provee una salida",
  "verse": "No os ha sobrevenido ninguna tentación que no sea humana; pero fiel es Dios, que no os dejará ser tentados más de lo que podéis resistir, sino que dará también juntamente con la tentación la salida, para que podáis soportar.",
  "reference": "1 Corintios 10:13 (RVR1960)",
  "metadata": {
    "giants": ["sexual", "substances", "digital"],
    "stage": "crisis",
    "intensityFit": [3, 4, 5],
    "techniques": ["urge_delay"],
    "triggers": ["temptation"],
    "outcomes": ["hope", "strength"],
    "source": "bible",
    "reviewLevel": "approved"
  }
}
```

---

### 🙏 Oración (PrayerItem)

```json
{
  "id": "p001",
  "type": "prayer",
  "title": "Título de la oración",
  "subtitle": "Momento/situación ideal",
  "content": "Texto completo de la oración...",
  "durationMinutes": 2,
  "metadata": {
    "giants": ["giant_id"],
    "stage": "stage_id",
    "techniques": ["prayer"],
    "triggers": ["trigger_id"],
    "outcomes": ["outcome_id"],
    "source": "curated",
    "reviewLevel": "approved"
  }
}
```

**Reglas:**
- Duración típica: 1-3 minutos
- Usar segunda persona (Tú/Señor)
- Incluir reconocimiento de la lucha
- Terminar con declaración de fe

---

### ✍️ Prompt de Diario (JournalPromptItem)

```json
{
  "id": "j001",
  "type": "journal_prompt",
  "title": "Título del prompt",
  "subtitle": "Área de reflexión",
  "prompt": "Pregunta principal...",
  "followUp": "Pregunta de seguimiento opcional",
  "metadata": {
    "giants": ["giant_id"],
    "stage": "habit",
    "techniques": ["CBT_reframe", "mindfulness"],
    "triggers": [],
    "outcomes": ["clarity", "self_control"],
    "source": "curated",
    "reviewLevel": "approved"
  }
}
```

**Reglas:**
- Preguntas abiertas, no cerradas (sí/no)
- Evitar juicio en el tono
- `followUp` debe profundizar, no repetir

---

### 💪 Ejercicio (ExerciseItem)

```json
{
  "id": "e001",
  "type": "exercise",
  "title": "Nombre del ejercicio",
  "subtitle": "Beneficio principal",
  "description": "Descripción breve",
  "steps": [
    "Paso 1...",
    "Paso 2...",
    "Paso 3..."
  ],
  "durationMinutes": 5,
  "metadata": {
    "giants": ["mental", "emotions"],
    "stage": "crisis",
    "techniques": ["breathing", "grounding"],
    "triggers": ["anxiety", "stress"],
    "outcomes": ["peace", "clarity"],
    "source": "curated",
    "reviewLevel": "approved"
  }
}
```

**Reglas:**
- Máximo 7 pasos
- Cada paso debe ser accionable
- Incluir duración realista

---

## 🔒 Niveles de Revisión

| Nivel | Significado | Bonus Score |
|-------|-------------|-------------|
| `approved` | Revisado por equipo pastoral/clínico | +20 |
| `reviewed` | Revisado por editor | +10 |
| `draft` | Borrador sin revisar | 0 |

---

## ⚠️ Disclaimer de Seguridad

Todo contenido debe incluir (implícita o explícitamente):

> "Este contenido es de apoyo espiritual y no reemplaza atención profesional de salud mental. Si experimentas crisis severa, busca ayuda profesional."

### Contenido que NO debe crearse:
- ❌ Promesas de curación garantizada
- ❌ Culpabilización excesiva
- ❌ Minimización de adicciones serias
- ❌ Sugerencias de "solo confía más"
- ❌ Contenido que pueda ser trigger

---

## 📈 Cómo Funciona el Scoring

El `PersonalizationEngine` calcula un puntaje para cada contenido:

```
Base Score = 0

+ 50 pts  → Cada gigante del usuario que coincide
+ 100 pts → Si es el gigante PRIMARIO del usuario
+ 30 pts  → Si la etapa coincide con la frecuencia del usuario
+ 20 pts  → Si reviewLevel = "approved"
+ 10 pts  → Si reviewLevel = "reviewed"

- 30 pts  → Si el contenido ya fue mostrado hoy
- 50 pts  → Si el contenido fue mostrado ayer
```

### Ejemplo de Cálculo
Usuario con gigante primario `digital` (frecuencia: diaria):

```
Versículo: 1 Cor 10:13
- giants: [sexual, substances, digital]
- stage: crisis

Scoring:
+ 50  (coincide 'digital')
+ 0   (no es primario en el versículo)
+ 30  (crisis = alta frecuencia)
+ 20  (approved)
= 100 puntos
```

---

## 🚀 Checklist para Nuevo Contenido

- [ ] ID único siguiendo formato (`v###`, `p###`, `j###`, `e###`)
- [ ] 1-3 gigantes asignados
- [ ] Etapa correcta según momento de uso
- [ ] Al menos 1 técnica de la lista permitida
- [ ] Triggers relevantes (si aplica)
- [ ] Outcomes esperados
- [ ] Revisión editorial completada
- [ ] JSON válido (usar linter)

---

## 📁 Ubicación de Archivos

```
assets/content/
├── verses.json          # Versículos bíblicos
├── prayers.json         # Oraciones guiadas
├── journal_prompts.json # Prompts para diario
└── exercises.json       # Ejercicios prácticos
```

Después de agregar contenido, ejecutar:
```bash
flutter pub get
flutter run
```

---

*Última actualización: Enero 2025*
*Mantenido por: Equipo Faith Victory*
