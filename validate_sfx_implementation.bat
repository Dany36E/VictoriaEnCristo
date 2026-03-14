@echo off
REM ═══════════════════════════════════════════════════════════════════════════
REM SCRIPT DE VALIDACIÓN - SFX TAB CHANGE + FEEDBACK INTEGRAL (Windows)
REM ═══════════════════════════════════════════════════════════════════════════

echo ═══════════════════════════════════════════════════════════════════════════
echo VALIDANDO IMPLEMENTACIÓN DE SFX TAB CHANGE + FEEDBACK INTEGRAL
echo ═══════════════════════════════════════════════════════════════════════════
echo.

set PASS=0
set FAIL=0
set WARN=0

echo 1. VERIFICANDO ARCHIVOS CORE
echo ─────────────────────────────────────────────────────────────────────────
call :check_file "lib\services\feedback_engine.dart"
call :check_content "lib\services\feedback_engine.dart" "tab_slide.mp3"
call :check_content "lib\services\feedback_engine.dart" "_eventVolumes"
echo.

echo 2. VERIFICANDO MÓDULO: PLANES
echo ─────────────────────────────────────────────────────────────────────────
call :check_file "lib\screens\plan_hub_screen.dart"
call :check_content "lib\screens\plan_hub_screen.dart" "FeedbackEngine"
call :check_file "lib\screens\plan_detail_screen.dart"
call :check_content "lib\screens\plan_detail_screen.dart" "FeedbackEngine"
echo.

echo 3. VERIFICANDO MÓDULO: ORACIONES
echo ─────────────────────────────────────────────────────────────────────────
call :check_file "lib\screens\prayers_screen.dart"
call :check_content "lib\screens\prayers_screen.dart" "FeedbackEngine"
echo.

echo 4. VERIFICANDO MÓDULO: MI PROGRESO
echo ─────────────────────────────────────────────────────────────────────────
call :check_file "lib\screens\progress_screen.dart"
call :check_content "lib\screens\progress_screen.dart" "FeedbackEngine"
echo.

echo 5. VERIFICANDO MÓDULO: MI DIARIO
echo ─────────────────────────────────────────────────────────────────────────
call :check_file "lib\screens\journal_screen.dart"
call :check_content "lib\screens\journal_screen.dart" "FeedbackEngine"
echo.

echo 6. VERIFICANDO ASSETS DE AUDIO
echo ─────────────────────────────────────────────────────────────────────────
call :check_file "assets\sounds\sfx\tap.mp3"
call :check_file "assets\sounds\sfx\select.mp3"
call :check_file "assets\sounds\sfx\confirm.mp3"
call :check_file "assets\sounds\sfx\paper.mp3"

if not exist "assets\sounds\sfx\tab_slide.mp3" (
    echo [93m⚠ Archivo tab_slide.mp3 NO existe (REQUERIDO)[0m
    echo    Ver: assets\sounds\sfx\TAB_SLIDE_PLACEHOLDER.txt
    set /a WARN+=1
) else (
    echo [92m✓ Archivo tab_slide.mp3 existe[0m
    set /a PASS+=1
)
echo.

echo 7. VERIFICANDO DOCUMENTACIÓN
echo ─────────────────────────────────────────────────────────────────────────
call :check_file "IMPLEMENTACION_SFX_TAB_CHANGE.md"
call :check_file "assets\sounds\sfx\TAB_SLIDE_PLACEHOLDER.txt"
echo.

echo ═══════════════════════════════════════════════════════════════════════════
echo RESUMEN DE VALIDACIÓN
echo ═══════════════════════════════════════════════════════════════════════════
echo [92m✓ Pasadas:[0m %PASS%
echo [91m✗ Fallidas:[0m %FAIL%
echo [93m⚠ Advertencias:[0m %WARN%
echo.

if %FAIL% EQU 0 (
    if %WARN% EQU 0 (
        echo [92m🎉 VALIDACIÓN COMPLETA - TODO OK[0m
        exit /b 0
    ) else (
        echo [93m⚠️  VALIDACIÓN OK CON ADVERTENCIAS[0m
        echo    Crear archivo tab_slide.mp3 antes de probar
        exit /b 0
    )
) else (
    echo [91m❌ VALIDACIÓN FALLIDA[0m
    exit /b 1
)

:check_file
if exist "%~1" (
    echo [92m✓ Archivo existe: %~1[0m
    set /a PASS+=1
) else (
    echo [91m✗ Archivo NO encontrado: %~1[0m
    set /a FAIL+=1
)
exit /b

:check_content
findstr /C:"%~2" "%~1" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [92m✓ Contenido verificado en %~1[0m
    set /a PASS+=1
) else (
    echo [91m✗ Contenido NO encontrado en %~1: %~2[0m
    set /a FAIL+=1
)
exit /b
