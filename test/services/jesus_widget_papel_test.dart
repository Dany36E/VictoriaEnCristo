import 'dart:io';

import 'package:app_quitar/services/jesus_widget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final service = JesusWidgetService.I;

  test('cada estado de racha tiene su dibujo de papel', () {
    final rutas = <String>{
      service.getSprite(streakDays: 0, completedToday: false, isNewUser: true),
      for (final dias in [0, 1, 5, 7, 30, 100, 365])
        for (final hecho in [false, true])
          service.getSprite(streakDays: dias, completedToday: hecho, isNewUser: false),
    };
    expect(rutas, hasLength(8));
    for (final ruta in rutas) {
      expect(ruta, startsWith('assets/vec/personajes/jesus_'));
      expect(File(ruta).existsSync(), isTrue, reason: ruta);
    }
  });

  test('cada hito de racha tiene su escena de papel', () {
    final rutas = <String>{
      for (final dias in [0, 1, 3, 7, 14, 30, 100, 365])
        service.getBackground(streakDays: dias),
    };
    expect(rutas, hasLength(8));
    for (final ruta in rutas) {
      expect(File(ruta).existsSync(), isTrue, reason: ruta);
    }
  });
}
