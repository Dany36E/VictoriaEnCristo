@echo off
echo ═══════════════════════════════════════════════════════════════════════════
echo EJECUTANDO APP EN ANDROID
echo ═══════════════════════════════════════════════════════════════════════════
echo.

cd /d c:\Proyectos\Flutter\app_quitar

echo Verificando dispositivos Android conectados...
flutter devices

echo.
echo Ejecutando app en Android...
flutter run

pause
