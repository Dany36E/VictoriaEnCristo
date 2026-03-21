# Bible Brain Audio API — Setup

## Obtener API Key

1. **Registrar cuenta:**  
   Ir a [https://biblebrain.com/api](https://biblebrain.com/api)  
   → "Sign Up for API Key"  
   → Completar el formulario (nombre, ministerio, uso)  
   → Verificar email

2. **Obtener la API key** en el dashboard de Bible Brain

3. **Verificar que RVR1960 tiene audio disponible:**
   ```
   GET https://4.dbt.io/api/bibles?language_code=SPA&media=audio_drama&key=TU_KEY&v=4
   ```

4. **Agregar en** `lib/config/api_config.dart`:
   ```dart
   static const String bibleBrainKey = 'TU_KEY_AQUI';
   ```

## Filesets de Audio en Español

| Fileset ID  | Descripción                  |
|-------------|------------------------------|
| SPNRVRN2DA  | RVR1960 NT dramatizado       |
| SPNRVRN1DA  | RVR1960 AT dramatizado       |
| SPNNVIN2DA  | NVI NT dramatizado           |

## API Endpoints Usados

- **Audio del capítulo:**  
  `GET https://4.dbt.io/api/bibles/filesets/{fileset_id}/{book_code}/{chapter}?key={KEY}&v=4`

- **Timestamps de versículos:**  
  `GET https://4.dbt.io/api/timestamps/{fileset_id}/{book_code}/{chapter}?key={KEY}&v=4`

## Notas

- Gratis para apps no comerciales y ministerios
- Para apps comerciales contactar: partnerships@fcbh.org
- Las URLs de audio expiran, se cachean solo en memoria por sesión
- Sin API key o sin internet, el sistema hace fallback automático a TTS
