# Sacred Alarm Android QA

Version objetivo: `1.0.9+11`

## Precondiciones

- Instalar la build Android `1.0.9+11`.
- Aceptar permiso de notificaciones.
- En Android 12+ permitir `alarmas exactas` si el sistema lo solicita.
- Abrir `Ajustes > Campanas Sagradas`.

## Smoke Test

1. Activar `Campanas Sagradas`.
2. Crear una `campana unica` a 2 o 3 minutos en el futuro.
3. Salir de la app y bloquear el telefono.
4. Verificar que la campana suena a la hora esperada.
5. Tocar la notificacion.
6. Verificar que abre la pantalla `Campana Sagrada`.
7. Completar los checks y apagar la campana desde la app.

Resultado esperado:

- La campana suena.
- La notificacion abre la pantalla correcta.
- La campana se apaga solo al completar la pantalla.

## Reinicio Del Telefono

1. Dejar una `campana unica` programada para unos minutos despues.
2. Reiniciar el telefono antes de que llegue la hora.
3. No abrir la app.
4. Esperar la hora programada.

Resultado esperado:

- La campana sigue sonando despues del reinicio.

## Cambio De Hora / Zona Horaria

1. Programar una campana unica futura.
2. Cambiar la hora manual del sistema o la zona horaria.
3. Verificar que la campana sigue existiendo en la lista de proximas campanas.
4. Esperar el disparo.

Resultado esperado:

- La app reprograma la campana y no la pierde.

## Actualizacion De La App

1. Instalar una version anterior que tenga campanas futuras programadas.
2. Actualizar encima con la build `1.0.9+11`.
3. No borrar datos.
4. Esperar el siguiente disparo.

Resultado esperado:

- Las campanas futuras siguen sonando despues de la actualizacion.

## Cancelacion / Reconfiguracion

1. Programar varias campanas futuras.
2. Desactivar `Campanas Sagradas` o eliminar las campanas unicas.
3. Reiniciar el telefono.

Resultado esperado:

- Las campanas canceladas no reaparecen tras el reinicio.

## Comando De Test Local

Para la prueba de widget de esta pantalla en Windows, usar:

```powershell
flutter test --no-test-assets test\screens\sacred_alarm_active_screen_test.dart
```

Esto evita un crash del tool de Flutter en Windows al copiar `NativeAssetsManifest.json`.
