/// Escena de la racha en el tema «Papel recortado»: el fondo del hito de la
/// racha con el sprite de Jesús encima, enmarcada como foto de papel.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/jesus_widget_service.dart';
import '../vec/vec_tema.dart';

class EscenaRachaPapel extends StatelessWidget {
  const EscenaRachaPapel({
    super.key,
    required this.streakDays,
    required this.completedToday,
    required this.isNewUser,
    this.ancho = 128,
    this.alto = 188,
    this.giro = -2,
  });

  final int streakDays;

  /// Igual que en el tema normal: solo cuenta si el día fue de victoria.
  final bool completedToday;
  final bool isNewUser;
  final double ancho, alto, giro;

  @override
  Widget build(BuildContext context) {
    final service = JesusWidgetService.I;
    final sprite = service.getSprite(
      streakDays: streakDays,
      completedToday: completedToday,
      isNewUser: isNewUser,
      papel: true,
    );
    final fondo = service.getBackground(streakDays: streakDays, papel: true);
    final marco = ancho * 0.04;
    return Transform.rotate(
      angle: giro * math.pi / 180,
      child: Container(
        width: ancho,
        height: alto,
        padding: EdgeInsets.all(marco.clamp(5, 9)),
        decoration: BoxDecoration(
          color: VecColores.papel,
          borderRadius: BorderRadius.circular(VecRadios.m),
          boxShadow: VecSombras.papel,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(VecRadios.s),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                fondo,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.medium,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(4, alto * 0.05, 4, 2),
                child: Image.asset(
                  sprite,
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomCenter,
                  semanticLabel: 'Ilustración de Jesús',
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
