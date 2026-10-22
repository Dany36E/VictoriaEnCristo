import 'dart:io';

import 'package:app_quitar/services/avatar_perfil_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hay 10 avatares de hombre y 10 de mujer, con su dibujo', () {
    expect(AvatarPerfilService.hombres, hasLength(10));
    expect(AvatarPerfilService.mujeres, hasLength(10));
    expect(AvatarPerfilService.mujeres.every((a) => a.esMujer), isTrue);
    for (final a in [
      ...AvatarPerfilService.hombres,
      ...AvatarPerfilService.mujeres,
    ]) {
      expect(File(a.ruta).existsSync(), isTrue, reason: a.ruta);
    }
  });

  test('cargar ignora ids desconocidos', () async {
    SharedPreferences.setMockInitialValues({
      AvatarPerfilService.clave: 'x99',
    });
    await AvatarPerfilService.I.cargar();
    expect(AvatarPerfilService.I.avatarId.value, isNull);
  });

  test('elegir guarda y quitar borra la preferencia', () async {
    SharedPreferences.setMockInitialValues({});
    await AvatarPerfilService.I.elegir('m03');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AvatarPerfilService.clave), 'm03');
    expect(AvatarPerfilService.I.avatarId.value, 'm03');

    await AvatarPerfilService.I.cargar();
    expect(AvatarPerfilService.I.avatarId.value, 'm03');

    await AvatarPerfilService.I.elegir(null);
    expect(prefs.getString(AvatarPerfilService.clave), isNull);
    expect(AvatarPerfilService.I.avatarId.value, isNull);
  });
}
