# 🧪 GUÍA DE TESTING - SFX TAB CHANGE + FEEDBACK INTEGRAL

## 📋 Pre-requisitos

1. ✅ Código implementado (completo)
2. ⚠️ Archivo `tab_slide.mp3` en `assets/sounds/sfx/`
3. ✅ App corriendo en emulador o dispositivo
4. ✅ Volumen del dispositivo activado
5. ✅ SFX habilitados en Configuración

---

## 🎯 TEST 1: Cambio de Tabs (CRÍTICO)

**Objetivo:** Verificar que el cambio de tabs suene sutil y NO como cámara

### Pasos:
1. Abrir app
2. Ir a **Versículos** (tap en card desde Home)
3. Cambiar entre tabs:
   - Tap en "**Tentación**"
   - Tap en "**Pureza**"
   - Tap en "**Fortaleza**"
   - Tap en "**Victoria**"
   - Tap en "**Espíritu**"

### Verificar:
- [x] Suena un sonido sutil tipo "page slide" o "whoosh suave"
- [x] NO suena como shutter de cámara
- [x] NO suena como "click" fuerte
- [x] Volumen es más bajo que otros botones
- [x] Haptic vibra levemente (lightImpact)
- [x] No hay delay perceptible
- [x] Rate limiting funciona (cambiar rápido no hace spam)

### ✅ Pasa si:
El sonido es sutil, espiritual, tipo "page turn" o "slide", sin sonar a cámara.

### ❌ Falla si:
Suena como cámara/shutter o es muy fuerte/arcade.

---

## 🎯 TEST 2: Módulo Planes

### 2.1 Plan Hub
1. Ir a **Home** → Tap "Biblioteca de Planes"
2. **Tap en Hero Card** (plan grande arriba)
   - ✓ Debe sonar `confirm()` (volumen medio-alto)
3. **Tap en Active Card** (si existe, card de "Continuar Plan")
   - ✓ Debe sonar `confirm()`
4. **Tap en Poster Card** (carruseles horizontales)
   - ✓ Debe sonar `tap()` (volumen medio)

### 2.2 Plan Detail
1. Dentro de un plan, **Tap en "Continuar Plan"** (botón principal)
   - ✓ Debe sonar `confirm()`
2. **Tap en un día** (Day 1, Day 2, etc.)
   - ✓ Debe sonar `select()` (volumen medio)

### ✅ Pasa si:
Todos los taps suenan apropiadamente. CTA principal más fuerte que cards.

---

## 🎯 TEST 3: Módulo Oraciones

1. Ir a **Oraciones**
2. **Tap en cualquier card de oración**
   - ✓ Debe sonar `tap()` (volumen medio)
3. Abrir detalle de oración
   - ✓ Navegación suena

### ✅ Pasa si:
Cards de oraciones suenan consistentemente.

---

## 🎯 TEST 4: Módulo Mi Progreso

1. Ir a **Mi Progreso**
2. **Tap en "Registrar Victoria"** (botón principal)
   - ✓ Debe sonar `confirm()` (volumen medio-alto)
   - ✓ Debe mostrar confetti + sonido
3. **Tap en botón de reset/restauración**
   - ✓ Debe sonar `select()` (volumen medio)

### ✅ Pasa si:
Registrar victoria suena más fuerte/prominente que reset.

---

## 🎯 TEST 5: Módulo Mi Diario

### 5.1 Nueva Entrada
1. Ir a **Mi Diario**
2. **Tap en FAB "Nueva Entrada"** (+)
   - ✓ Debe sonar `confirm()` (volumen medio-alto)
3. En el editor, **seleccionar un mood** (emoji 😊/😐/😢)
   - ✓ Cada tap debe sonar `select()`
4. Escribir algo y **tap "Guardar"**
   - ✓ Debe sonar `confirm()`

### 5.2 Ver Entrada
1. **Tap en una entrada existente**
   - ✓ Debe sonar `tap()` (volumen medio)

### ✅ Pasa si:
Nueva/guardar suenan más fuertes que selecciones y cards.

---

## 🎯 TEST 6: Jerarquía de Volumen

**Objetivo:** Verificar que hay diferencia perceptible entre eventos

### Secuencia de prueba:
1. Tap en una oración (tap) → volumen X
2. Cambiar tab en versículos (tabChange) → volumen más bajo que X
3. Tap "Guardar" en diario (confirm) → volumen más alto que X
4. Seleccionar mood (select) → volumen similar a X

### ✅ Pasa si:
`tabChange` < `tap/select` < `confirm`

### Orden esperado (de más alto a más bajo):
1. 🔊 **confirm** (0.45) - CTAs, acciones principales
2. 🔉 **tap/select** (0.40) - Navegación, selecciones
3. 🔉 **paper** (0.35) - Efectos especiales
4. 🔈 **tabChange** (0.30) - ⭐ Cambio de tabs (MÁS SUTIL)

---

## 🎯 TEST 7: Toggles y Configuración

### 7.1 SFX OFF
1. Ir a **Configuración**
2. Desactivar **SFX**
3. Realizar cualquier acción
   - ✓ NO debe sonar nada
   - ✓ Haptics pueden seguir activos (si están ON)

### 7.2 Haptics OFF
1. Desactivar **Haptics**
2. Realizar cualquier acción
   - ✓ Debe sonar SFX normalmente
   - ✓ NO debe vibrar

### 7.3 Ambos OFF
1. Desactivar **SFX** y **Haptics**
2. Realizar cualquier acción
   - ✓ Silencio total, sin feedback

### ✅ Pasa si:
Los toggles funcionan independientemente y como se espera.

---

## 🎯 TEST 8: Rate Limiting

**Objetivo:** Verificar que no hay spam de audio

### Pasos:
1. Cambiar tabs rápidamente (5 taps en 1 segundo)
   - ✓ No debe sonar todo encimado
   - ✓ Debe respetar límite de 100ms
2. Tap rápido en múltiples cards
   - ✓ Audio debe quedar limpio, sin layering

### ✅ Pasa si:
No hay audio encimado, spam controlado, experiencia limpia.

---

## 🎯 TEST 9: BGM Independiente

**Objetivo:** Verificar que BGM y SFX no interfieren

### Pasos:
1. Activar **BGM** (música de fondo) en Configuración
2. Realizar acciones con SFX
   - ✓ BGM continúa sonando sin interrupciones
   - ✓ SFX se mezclan bien con BGM
3. Desactivar **SFX**
   - ✓ BGM sigue sonando normalmente

### ✅ Pasa si:
BGM y SFX son completamente independientes.

---

## 🎯 TEST 10: Edge Cases

### 10.1 Sin Archivo de Audio
1. Renombrar temporalmente `tab_slide.mp3` a `tab_slide.mp3.bak`
2. Cambiar tabs
   - ✓ NO debe crashear la app
   - ✓ Debe fallar silenciosamente (log en debug)
   - ✓ Otros SFX siguen funcionando

### 10.2 Cambios Rápidos de Pantalla
1. Navegar rápidamente entre módulos mientras suena audio
   - ✓ No debe crashear
   - ✓ Audio debe limpiarse apropiadamente

### ✅ Pasa si:
La app es resiliente a errores y cambios de estado.

---

## 📊 Checklist de Aceptación Final

Marcar todos antes de aprobar:

### Funcionalidad Core
- [ ] Cambio de tabs Pureza/Tentación/Fortaleza suena sutil
- [ ] NO suena como cámara/foto/shutter
- [ ] Volumen de tabChange es más bajo que otros eventos

### Cobertura de Módulos
- [ ] Planes: Hero, Active, Poster cards suenan
- [ ] Planes: Continuar y seleccionar día suenan
- [ ] Oraciones: Cards suenan al tap
- [ ] Mi Progreso: Victoria y reset suenan
- [ ] Mi Diario: Nueva, guardar, moods, cards suenan

### Jerarquía y Calidad
- [ ] Jerarquía de volumen perceptible (confirm > tap/select > tabChange)
- [ ] No hay layering (solo 1 SFX por evento)
- [ ] Rate limiting funciona (no spam)
- [ ] Audio premium, sutil, espiritual (NO arcade)

### Configuración
- [ ] Toggle SFX ON/OFF funciona
- [ ] Toggle Haptics ON/OFF funciona
- [ ] BGM y SFX son independientes
- [ ] Configuración persiste al cerrar app

### Edge Cases
- [ ] App no crashea si falta archivo de audio
- [ ] Navegación rápida no causa problemas
- [ ] Hot reload mantiene configuración

---

## 🐛 Reporte de Bugs

Si encuentras algún problema, reportar con:

1. **Descripción:** ¿Qué está mal?
2. **Pasos para reproducir:** ¿Cómo pasó?
3. **Esperado vs Real:** ¿Qué debería pasar vs qué pasa?
4. **Device/OS:** ¿Android/iOS? ¿Versión?
5. **Logs:** ¿Hay errores en consola?

Buscar logs con: `[FEEDBACK]` o `[SFX]`

---

## ✅ Criterio de Éxito

**La implementación se considera exitosa cuando:**

1. ✅ Tabs suenan sutiles (NO cámara)
2. ✅ Todos los módulos tienen feedback
3. ✅ Jerarquía de volumen es clara
4. ✅ Experiencia es premium (Netflix/HBO style)
5. ✅ Toggles funcionan correctamente
6. ✅ No hay bugs críticos
7. ✅ Pasa todos los tests de esta guía

---

## 📝 Notas para QA

- **Testing óptimo:** Usar dispositivo físico (haptics mejor)
- **Volumen:** Probar con volumen al 50-70%
- **Ambiente:** Lugar silencioso para detectar sutilezas
- **Comparación:** Probar con apps tipo Netflix, Calm, Headspace
- **Logs:** Activar para ver mensajes de FeedbackEngine

**Comando para logs filtrados:**
```bash
flutter logs | grep FEEDBACK
```

---

**Duración estimada de testing completo:** ~15-20 minutos

**¡Happy Testing!** 🚀
