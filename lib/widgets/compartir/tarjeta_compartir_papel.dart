import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';

/// Quién presenta la tarjeta. Como en los videos: Victoria en terracota y
/// Timoteo en azul.
enum PersonajeCompartir {
  victoria('assets/vec/personajes/victoria_presenta.png', VecColores.terracota),
  timoteo('assets/vec/personajes/timoteo_presenta.png', VecColores.azul);

  const PersonajeCompartir(this.ruta, this.color);
  final String ruta;
  final Color color;
}

/// Imagen para compartir un versículo con el estilo «papel recortado»: hoja
/// con textura, tarjeta con cinta, letra de mano, la referencia del color del
/// personaje y el personaje que la presenta asomado en la esquina.
///
/// Se dibuja siempre a [ancho] lógico (360) para que la composición no cambie
/// con la pantalla; al capturarla con `pixelRatio: 3` sale de 1080 px. Donde
/// el lienzo es más grande (las plantillas de 1080) se envuelve en `FittedBox`.
class TarjetaCompartirPapel extends StatelessWidget {
  const TarjetaCompartirPapel({
    super.key,
    required this.texto,
    required this.referencia,
    this.version = '',
    this.etiqueta,
    this.pie,
    this.proporcion = 1,
    this.personaje = PersonajeCompartir.victoria,
    this.mostrarMarca = true,
    this.alineacion = TextAlign.center,
    this.tamanoTexto,
  });

  /// Ancho lógico fijo del dibujo.
  static const double ancho = 360;

  final String texto;
  final String referencia;
  final String version;

  /// Chip arriba de la tarjeta («Versículo», «Devocional»…).
  final String? etiqueta;

  /// Línea chica bajo la marca (p. ej. «La Chequera del Banco de la Fe»).
  final String? pie;

  /// Ancho entre alto: 1 (cuadrada), 0.8 (4:5) o 0.5625 (9:16).
  final double proporcion;
  final PersonajeCompartir personaje;
  final bool mostrarMarca;
  final TextAlign alineacion;

  /// Tamaño de la letra del versículo; si es null se elige por su largo.
  final double? tamanoTexto;

  double get _alto => ancho / proporcion;

  static double tamanoPorLargo(int largo) {
    if (largo < 80) return 25;
    if (largo < 150) return 22;
    if (largo < 250) return 19;
    if (largo < 380) return 17;
    return 15;
  }

  @override
  Widget build(BuildContext context) {
    final alto = _alto;
    final vertical = proporcion < 0.95;
    // El personaje crece con el lienzo, sin tapar la tarjeta.
    final altoPersonaje = vertical ? math.min(alto * 0.36, 230.0) : 128.0;
    final abajoTarjeta = mostrarMarca || pie != null ? 70.0 : 40.0;
    final arribaTarjeta = etiqueta != null ? 58.0 : 34.0;

    return MediaQuery(
      // La imagen no depende del tamaño de letra del teléfono.
      data: const MediaQueryData(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: DecoratedBox(
          decoration: FondoPapel.decoracion,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (etiqueta != null)
                Positioned(
                  top: 18,
                  left: 22,
                  child: _Etiqueta(texto: etiqueta!, color: personaje.color),
                ),
              Positioned(
                left: 22,
                right: 22,
                top: arribaTarjeta,
                bottom: abajoTarjeta + (vertical ? altoPersonaje * 0.45 : 0),
                child: Center(
                  child: TarjetaPapel(
                    giro: -1.2,
                    cintaDerecha: true,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                    child: _Contenido(
                      texto: texto,
                      referencia: referencia,
                      version: version,
                      color: personaje.color,
                      alineacion: alineacion,
                      // En historias (9:16) sobra alto: letra un poco más grande.
                      tamano:
                          (tamanoTexto ?? tamanoPorLargo(texto.length)) *
                          (proporcion < 0.7 ? 1.15 : 1),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: 10,
                bottom: -altoPersonaje * 0.08,
                height: altoPersonaje,
                child: Image.asset(
                  personaje.ruta,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
              ),
              if (mostrarMarca || pie != null)
                Positioned(
                  left: 24,
                  bottom: 18,
                  right: altoPersonaje * 0.55 + 16,
                  child: _Marca(pie: pie, conNombre: mostrarMarca),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Contenido extends StatelessWidget {
  const _Contenido({
    required this.texto,
    required this.referencia,
    required this.version,
    required this.color,
    required this.alineacion,
    required this.tamano,
  });

  final String texto, referencia, version;
  final Color color;
  final TextAlign alineacion;
  final double tamano;

  CrossAxisAlignment get _cruce => switch (alineacion) {
    TextAlign.left || TextAlign.start => CrossAxisAlignment.start,
    TextAlign.right || TextAlign.end => CrossAxisAlignment.end,
    _ => CrossAxisAlignment.center,
  };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restricciones) {
        // Ancho fijo para que el texto se acomode en renglones y, si aun así
        // no cabe, se achique todo junto en vez de cortarse.
        return FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: restricciones.maxWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: _cruce,
              children: [
                Text(
                  '“',
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 46,
                    height: 0.8,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
                Text(
                  texto,
                  textAlign: alineacion,
                  style: TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: tamano,
                    height: 1.28,
                    color: VecColores.tinta,
                  ),
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: referencia,
                        style: TextStyle(
                          fontFamily: VecFuentes.titulo,
                          fontSize: 20,
                          color: color,
                        ),
                      ),
                      if (version.isNotEmpty)
                        TextSpan(
                          text: '  $version',
                          style: const TextStyle(
                            fontFamily: VecFuentes.titulo,
                            fontSize: 13,
                            color: VecColores.gris,
                          ),
                        ),
                    ],
                  ),
                  textAlign: alineacion,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Píldora chica del color del personaje (versión compacta de ChipVec).
class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto, required this.color});
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -3 * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 6, 14, 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(VecRadios.pildora),
          boxShadow: VecSombras.chip,
        ),
        child: Text(
          texto,
          style: const TextStyle(
            fontFamily: VecFuentes.titulo,
            fontSize: 14,
            color: VecColores.papel,
          ),
        ),
      ),
    );
  }
}

class _Marca extends StatelessWidget {
  const _Marca({required this.pie, required this.conNombre});
  final String? pie;
  final bool conNombre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CirculoIcono(iconoVec: 'cruz', tamano: 28, giro: -6),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (conNombre)
                const Text(
                  'Victoria en Cristo',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: VecFuentes.titulo,
                    fontSize: 15,
                    color: VecColores.tinta,
                  ),
                ),
              if (pie != null)
                Text(
                  pie!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 13,
                    color: VecColores.gris,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
