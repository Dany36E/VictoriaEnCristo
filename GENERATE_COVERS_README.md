# 🎨 Generación Automática de Covers

## Opción 1: Usar DALL-E 3 (Automático - RECOMENDADO)

### Requisitos:
- Python 3.7+
- API Key de OpenAI ([Obtener aquí](https://platform.openai.com/api-keys))
- ~$5-10 USD de créditos OpenAI (cada imagen HD cuesta ~$0.12)

### Instalación:
```bash
pip install openai requests pillow
```

### Uso:
```bash
python generate_covers_dalle.py TU_API_KEY_AQUI
```

El script:
- ✅ Genera las 32 imágenes automáticamente
- ✅ Calidad profesional HD (1024x1792px)
- ✅ Las guarda directamente en `assets/images/plan_covers/`
- ✅ Formato optimizado para Flutter (.jpg)
- ✅ Reintentos automáticos en caso de error

**Costo estimado:** $3.84 USD (32 imágenes × $0.12)

---

## Opción 2: Usar ChatGPT Plus (Manual)

Si tienes ChatGPT Plus, puedes generar las imágenes gratis:

1. Abre el archivo `PLAN_COVERS_SPECS.md`
2. Copia el **"Prompt para AI"** de cada plan
3. Pégalo en ChatGPT con DALL-E 3
4. Descarga la imagen generada
5. Renombra como `<plan-id>.jpg`
6. Coloca en `assets/images/plan_covers/`

**Ventaja:** Gratis si ya tienes ChatGPT Plus
**Desventaja:** Manual (32 imágenes)

---

## Opción 3: Alternativas Gratuitas

### Leonardo.AI (Gratis)
- 150 créditos diarios gratis
- Cada imagen consume ~10 créditos
- Puedes generar 15 imágenes por día
- URL: https://leonardo.ai

### Ideogram (Gratis)
- Modelo gratuito de alta calidad
- Sin límites estrictos
- URL: https://ideogram.ai

### Proceso:
1. Usa los prompts de `PLAN_COVERS_SPECS.md`
2. Ajusta dimensiones a 600x900px
3. Descarga y renombra según `<plan-id>.jpg`

---

## Verificación Post-Generación

Después de generar las imágenes:

```bash
# Verificar que todas existan
ls assets/images/plan_covers/*.jpg | wc -l
# Debe mostrar: 32
```

En Flutter:
1. Hot reload: `r`
2. O hot restart: `R`
3. Las imágenes se cargarán automáticamente

---

## Para Agregar Nuevos Planes en el Futuro

1. Agrega el plan al JSON: `assets/content/plans.json`
2. Define coverImage: `"coverImage":"assets/images/plan_covers/nuevo-plan.jpg"`
3. Genera la imagen:
   - Opción A: Agrega al array `PLANS` en `generate_covers_dalle.py` y reejécuta
   - Opción B: Genera manualmente con ChatGPT usando el formato de especificaciones
4. Hot reload en Flutter

---

## Troubleshooting

### "ModuleNotFoundError: No module named 'openai'"
```bash
pip install openai requests
```

### "API key is invalid"
Verifica tu API key en: https://platform.openai.com/api-keys

### "Rate limit exceeded"
El script espera 3 segundos entre llamadas. Si falla, espera 1 minuto y reintenta.

### "Image not loading in Flutter"
1. Verifica que el archivo existe: `assets/images/plan_covers/<plan-id>.jpg`
2. Verifica que `pubspec.yaml` incluye:
   ```yaml
   assets:
     - assets/images/plan_covers/
   ```
3. Hot restart: `R`

---

## Calidad de Imágenes

Las imágenes generadas son:
- **Resolución:** 1024x1792px (formato vertical óptimo para covers)
- **Calidad:** HD professional
- **Estilo:** Consistente pero único por plan
- **Tamaño:** ~200-400KB por imagen
- **Formato:** JPEG optimizado para Flutter

---

## Contacto

Si encuentras problemas, revisa los logs del script o contacta al equipo de desarrollo.
