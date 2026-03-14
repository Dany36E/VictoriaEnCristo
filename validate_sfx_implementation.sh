#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════
# SCRIPT DE VALIDACIÓN - SFX TAB CHANGE + FEEDBACK INTEGRAL
# ═══════════════════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════════════════════"
echo "VALIDANDO IMPLEMENTACIÓN DE SFX TAB CHANGE + FEEDBACK INTEGRAL"
echo "═══════════════════════════════════════════════════════════════════════════"
echo ""

# Colores
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Contadores
PASS=0
FAIL=0
WARN=0

# Función de verificación
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✓${NC} Archivo existe: $1"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} Archivo NO encontrado: $1"
        ((FAIL++))
        return 1
    fi
}

check_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Contenido verificado en $1: $2"
        ((PASS++))
        return 0
    else
        echo -e "${RED}✗${NC} Contenido NO encontrado en $1: $2"
        ((FAIL++))
        return 1
    fi
}

check_warning() {
    if [ -f "$1" ]; then
        echo -e "${YELLOW}⚠${NC} ADVERTENCIA: $2"
        ((WARN++))
    fi
}

echo "1. VERIFICANDO ARCHIVOS CORE"
echo "─────────────────────────────────────────────────────────────────────────"
check_file "lib/services/feedback_engine.dart"
check_content "lib/services/feedback_engine.dart" "tab_slide.mp3"
check_content "lib/services/feedback_engine.dart" "_eventVolumes"
echo ""

echo "2. VERIFICANDO MÓDULO: PLANES"
echo "─────────────────────────────────────────────────────────────────────────"
check_file "lib/screens/plan_hub_screen.dart"
check_content "lib/screens/plan_hub_screen.dart" "FeedbackEngine"
check_content "lib/screens/plan_hub_screen.dart" "FeedbackEngine.I.confirm()"
check_file "lib/screens/plan_detail_screen.dart"
check_content "lib/screens/plan_detail_screen.dart" "FeedbackEngine"
echo ""

echo "3. VERIFICANDO MÓDULO: ORACIONES"
echo "─────────────────────────────────────────────────────────────────────────"
check_file "lib/screens/prayers_screen.dart"
check_content "lib/screens/prayers_screen.dart" "FeedbackEngine"
check_content "lib/screens/prayers_screen.dart" "FeedbackEngine.I.tap()"
echo ""

echo "4. VERIFICANDO MÓDULO: MI PROGRESO"
echo "─────────────────────────────────────────────────────────────────────────"
check_file "lib/screens/progress_screen.dart"
check_content "lib/screens/progress_screen.dart" "FeedbackEngine"
check_content "lib/screens/progress_screen.dart" "FeedbackEngine.I.confirm()"
echo ""

echo "5. VERIFICANDO MÓDULO: MI DIARIO"
echo "─────────────────────────────────────────────────────────────────────────"
check_file "lib/screens/journal_screen.dart"
check_content "lib/screens/journal_screen.dart" "FeedbackEngine"
check_content "lib/screens/journal_screen.dart" "FeedbackEngine.I.confirm()"
check_content "lib/screens/journal_screen.dart" "FeedbackEngine.I.tap()"
echo ""

echo "6. VERIFICANDO ASSETS DE AUDIO"
echo "─────────────────────────────────────────────────────────────────────────"
check_file "assets/sounds/sfx/tap.mp3"
check_file "assets/sounds/sfx/select.mp3"
check_file "assets/sounds/sfx/confirm.mp3"
check_file "assets/sounds/sfx/paper.mp3"

if [ ! -f "assets/sounds/sfx/tab_slide.mp3" ]; then
    echo -e "${YELLOW}⚠${NC} Archivo tab_slide.mp3 NO existe (REQUERIDO)"
    echo -e "${YELLOW}  ${NC} Ver: assets/sounds/sfx/TAB_SLIDE_PLACEHOLDER.txt"
    ((WARN++))
else
    echo -e "${GREEN}✓${NC} Archivo tab_slide.mp3 existe"
    ((PASS++))
fi
echo ""

echo "7. VERIFICANDO DOCUMENTACIÓN"
echo "─────────────────────────────────────────────────────────────────────────"
check_file "IMPLEMENTACION_SFX_TAB_CHANGE.md"
check_file "assets/sounds/sfx/TAB_SLIDE_PLACEHOLDER.txt"
echo ""

echo "═══════════════════════════════════════════════════════════════════════════"
echo "RESUMEN DE VALIDACIÓN"
echo "═══════════════════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Pasadas:${NC} $PASS"
echo -e "${RED}✗ Fallidas:${NC} $FAIL"
echo -e "${YELLOW}⚠ Advertencias:${NC} $WARN"
echo ""

if [ $FAIL -eq 0 ] && [ $WARN -eq 0 ]; then
    echo -e "${GREEN}🎉 VALIDACIÓN COMPLETA - TODO OK${NC}"
    exit 0
elif [ $FAIL -eq 0 ]; then
    echo -e "${YELLOW}⚠️  VALIDACIÓN OK CON ADVERTENCIAS${NC}"
    echo -e "${YELLOW}   Crear archivo tab_slide.mp3 antes de probar${NC}"
    exit 0
else
    echo -e "${RED}❌ VALIDACIÓN FALLIDA${NC}"
    exit 1
fi
