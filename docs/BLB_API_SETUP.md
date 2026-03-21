# Blue Letter Bible - Configuración de API

## ¿Qué es?

La integración con **Blue Letter Bible (BLB)** permite acceder a herramientas
de estudio profundo directamente desde la app:

- **Strong's Numbers**: Identifica las palabras originales (griego/hebreo) detrás de cada versículo.
- **Lexicón**: Definiciones completas de cada palabra original.
- **Referencias cruzadas**: Otros pasajes bíblicos relacionados.

## Obtener tu API Key

1. Visita [Blue Letter Bible API](https://www.blueletterbible.org/webtools/api.cfm).
2. Completa el formulario de solicitud con:
   - **Application Name**: Victoria en Cristo
   - **Description**: Aplicación cristiana móvil para estudio bíblico
   - **Platform**: Mobile (Flutter)
3. Acepta los términos de uso.
4. Recibirás tu API key por correo electrónico (puede tardar 1-3 días hábiles).

## Configurar en la App

1. Abre **Biblia → Ajustes** (ícono de engranaje).
2. Busca la sección **"Herramientas de Estudio"**.
3. Pega tu API key en el campo correspondiente.
4. Pulsa **"Guardar y verificar"**.
5. Si aparece ✓ en verde, la key es válida y ya puedes usar las herramientas.

## Límites del Plan Gratuito

| Límite         | Valor          |
|----------------|----------------|
| Peticiones/día | ~500           |
| Rate limit     | Sin burst alto |
| Versiones      | KJV (principal)|

> La app cachea automáticamente los resultados de lexicón (permanente) y
> referencias cruzadas (30 días) para minimizar el consumo de peticiones.

## Cómo funciona internamente

- La API de BLB solo soporta versiones en inglés (KJV).
- La app consulta BLB usando la referencia equivalente en KJV
  (mismo libro:capítulo:versículo).
- El texto en español se obtiene del XML local (RVR1960/NVI).
- Los datos de Strong's y lexicón se muestran junto al texto español.

## Solución de Problemas

| Problema                      | Solución                                      |
|-------------------------------|-----------------------------------------------|
| "API key no válida"           | Verifica que copiaste la key completa         |
| "Límite diario alcanzado"    | Espera hasta medianoche (se reinicia el contador) |
| No aparecen datos de Strong's | Algunos versículos cortos pueden no tener datos |
| Error de conexión             | Verifica tu conexión a internet               |
