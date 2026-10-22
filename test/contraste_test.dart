import 'package:app_quitar/theme/contraste.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const blanco = Color(0xFFFFFFFF);
  const noche = Color(0xFF0A0A12);
  const dorado = Color(0xFFD4A853);

  test('contrasteWcag da 21 entre blanco y negro y 1 entre iguales', () {
    expect(contrasteWcag(Colors.black, blanco), closeTo(21, 0.01));
    expect(contrasteWcag(dorado, dorado), closeTo(1, 0.01));
  });

  test('legibleSobre no toca un color que ya se lee', () {
    expect(legibleSobre(dorado, noche), dorado);
  });

  test('legibleSobre oscurece sobre claro y aclara sobre oscuro', () {
    final sobreBlanco = legibleSobre(dorado, blanco);
    expect(contrasteWcag(sobreBlanco, blanco), greaterThanOrEqualTo(4.5));
    expect(sobreBlanco.computeLuminance(), lessThan(dorado.computeLuminance()));

    const grisOscuro = Color(0xFF333333);
    final sobreOscuro = legibleSobre(grisOscuro, noche);
    expect(contrasteWcag(sobreOscuro, noche), greaterThanOrEqualTo(4.5));
    expect(
      sobreOscuro.computeLuminance(),
      greaterThan(grisOscuro.computeLuminance()),
    );
  });

  test('legibleSobre conserva el tono', () {
    final ajustado = legibleSobre(dorado, blanco);
    expect(
      HSLColor.fromColor(ajustado).hue,
      closeTo(HSLColor.fromColor(dorado).hue, 2),
    );
  });

  test('legibleEnPastilla se lee sobre su propia pastilla', () {
    const azul = Color(0xFF42A5F5);
    final texto = legibleEnPastilla(azul, 0.15, blanco);
    final pastilla = Color.alphaBlend(azul.withValues(alpha: 0.15), blanco);
    expect(contrasteWcag(texto, pastilla), greaterThanOrEqualTo(4.5));
  });

  test('legibleSobre acepta el mínimo de texto grande', () {
    final grande = legibleSobre(dorado, blanco, minimo: 3);
    expect(contrasteWcag(grande, blanco), greaterThanOrEqualTo(3));
    expect(contrasteWcag(grande, blanco), lessThan(4.5));
  });
}
