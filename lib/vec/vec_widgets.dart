// Victoria en Cristo — piezas de interfaz en estilo «papel recortado».
// FondoPapel · TarjetaPapel (con cinta) · TarjetaVersiculo · ChipVec · BotonVec · Subtitulo · Globo · Sticker · PopIn
// Extensiones para la app: IconoVec · CirculoIcono · HojaRayada · AvatarVec · BordeConSombraVec · TransicionPapel

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'vec_tema.dart';

const _rutaTextura = 'assets/vec/texturas/papel_tile_512.png';

/// Fondo de papel crema con textura que se repite (no uses fondos planos).
class FondoPapel extends StatelessWidget {
  const FondoPapel({super.key, required this.child});
  final Widget child;

  /// La misma decoración, para usarla donde no se puede envolver con el widget.
  /// La textura va a media opacidad sobre el crema: entera es más oscura que
  /// el crema del kit y le quita contraste al texto. En los papeles oscuros la
  /// textura encima aclararía el fondo: se tiñe del mismo fondo (modulate),
  /// que la oscurece un poco y deja ver el grano.
  static BoxDecoration get decoracion => VecColores.oscuro ? _decoracionOscura : _decoracionClara;

  static final _decoracionClara = BoxDecoration(
    color: VecPaleta.claro.crema,
    image: const DecorationImage(
      image: AssetImage(_rutaTextura),
      repeat: ImageRepeat.repeat,
      scale: 2,
      opacity: 0.5,
    ),
  );

  static BoxDecoration get _decoracionOscura => BoxDecoration(
        color: VecColores.crema,
        image: DecorationImage(
          image: const AssetImage(_rutaTextura),
          repeat: ImageRepeat.repeat,
          scale: 2,
          opacity: 0.6,
          colorFilter: ColorFilter.mode(VecColores.crema, BlendMode.modulate),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: decoracion, child: child);
  }
}

/// Cinta adhesiva (washi tape) a rayas mostaza.
class Cinta extends StatelessWidget {
  const Cinta({super.key, this.ancho = 96, this.alto = 30});
  final double ancho, alto;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.86,
      child: Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: const Alignment(-0.6, 0.2),
            colors: [VecColores.mostaza, VecColores.mostaza, VecColores.mostazaClaro, VecColores.mostazaClaro],
            stops: const [0, 0.5, 0.5, 1],
            tileMode: TileMode.repeated,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta de papel crema, un poquito chueca, con sombra de papel grueso y cinta en la esquina.
class TarjetaPapel extends StatelessWidget {
  const TarjetaPapel({
    super.key,
    required this.child,
    this.giro = -1.0,
    this.cintaDerecha = false,
    this.brilla = false,
    this.fondo,
    this.padding = const EdgeInsets.fromLTRB(24, 22, 24, 20),
  });
  final Widget child;
  final double giro; // grados
  final bool cintaDerecha, brilla;
  final Color? fondo; // papel si no se da
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: giro * math.pi / 180,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: double.infinity,
            padding: padding,
            decoration: BoxDecoration(
              color: fondo ?? VecColores.papel,
              borderRadius: BorderRadius.circular(VecRadios.m),
              boxShadow: brilla ? [...VecSombras.brillo, ...VecSombras.papel] : VecSombras.papel,
            ),
            child: child,
          ),
          Positioned(
            left: cintaDerecha ? null : -22.0,
            right: cintaDerecha ? -16.0 : null,
            top: -12,
            child: Transform.rotate(angle: (cintaDerecha ? 24.0 : -24.0) * math.pi / 180, child: const Cinta()),
          ),
        ],
      ),
    );
  }
}

/// Versículo: referencia en terracota, versión en gris y el texto con letra de mano.
class TarjetaVersiculo extends StatelessWidget {
  const TarjetaVersiculo({super.key, required this.referencia, required this.texto, this.version = 'RVR1960', this.brilla = false});
  final String referencia, texto, version;
  final bool brilla;

  @override
  Widget build(BuildContext context) {
    return TarjetaPapel(
      brilla: brilla,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: referencia, style: TextStyle(fontFamily: VecFuentes.titulo, fontSize: 26, color: VecColores.terracota)),
            TextSpan(text: '  $version', style: TextStyle(fontFamily: VecFuentes.titulo, fontSize: 14, color: VecColores.gris)),
          ])),
          const SizedBox(height: 8),
          Text(texto, style: TextStyle(fontFamily: VecFuentes.texto, fontSize: 20, height: 1.3, color: VecColores.tinta)),
        ],
      ),
    );
  }
}

/// Píldora de color con ícono y texto crema.
class ChipVec extends StatelessWidget {
  const ChipVec({super.key, required this.texto, this.icono, this.iconoWidget, this.color, this.giro = -1.5});
  final String texto;
  final IconData? icono;
  final Widget? iconoWidget; // p. ej. IconoVec('cruz'): sin color propio toma el del texto
  final Color? color; // terracota si no se da
  final double giro;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? VecColores.terracota;
    final colorTexto = textoSobre(color);
    return Transform.rotate(
      angle: giro * math.pi / 180,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 9, 20, 8),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(VecRadios.pildora), boxShadow: VecSombras.chip),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (iconoWidget != null) ...[
            SizedBox(
              width: 24,
              height: 24,
              child: IconTheme.merge(data: IconThemeData(color: colorTexto), child: iconoWidget!),
            ),
            const SizedBox(width: 8),
          ]
          else if (icono != null) ...[Icon(icono, color: colorTexto, size: 22), const SizedBox(width: 8)],
          Text(texto, style: TextStyle(fontFamily: VecFuentes.titulo, fontSize: 18, color: colorTexto)),
        ]),
      ),
    );
  }
}

/// Botón que se hunde al tocarlo (la sombra sólida se achica).
class BotonVec extends StatefulWidget {
  const BotonVec({
    super.key,
    required this.texto,
    required this.onPressed,
    this.icono,
    this.iconoWidget,
    this.color,
    this.colorTexto,
    this.cargando = false,
    this.expandido = false,
  });
  final String texto;
  final VoidCallback? onPressed;
  final IconData? icono;
  final Widget? iconoWidget; // p. ej. IconoVec('mensaje')
  final Color? color; // terracota si no se da
  final Color? colorTexto; // el que más se lea sobre [color] si no se da
  final bool cargando; // muestra un indicador y bloquea el toque
  final bool expandido; // ocupa todo el ancho disponible

  @override
  State<BotonVec> createState() => _BotonVecState();
}

class _BotonVecState extends State<BotonVec> {
  bool _abajo = false;

  bool get _activo => widget.onPressed != null && !widget.cargando;

  @override
  Widget build(BuildContext context) {
    // Deshabilitado: casilla apagada del papel con texto gris.
    final color = widget.color ?? VecColores.terracota;
    final fondo = widget.onPressed == null ? VecColores.cremaOscuro : color;
    final tinta = widget.onPressed == null ? VecColores.gris : widget.colorTexto ?? textoSobre(color);
    final abajo = _abajo && _activo;
    return Semantics(
      button: true,
      enabled: _activo,
      label: widget.texto,
      // La acción va en este nodo: excludeSemantics borra la del GestureDetector.
      onTap: _activo ? widget.onPressed : null,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: _activo ? (_) => setState(() => _abajo = true) : null,
        onTapUp: _activo ? (_) => setState(() => _abajo = false) : null,
        onTapCancel: _activo ? () => setState(() => _abajo = false) : null,
        onTap: _activo ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          transform: Matrix4.translationValues(0.0, abajo ? 5.0 : 0.0, 0.0),
          padding: const EdgeInsets.fromLTRB(26, 14, 26, 12),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: BorderRadius.circular(VecRadios.pildora),
            boxShadow: abajo ? VecSombras.presionado : VecSombras.chip,
          ),
          child: Row(
            mainAxisSize: widget.expandido ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.cargando) ...[
                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 3, color: tinta)),
                const SizedBox(width: 10),
              ] else if (widget.iconoWidget != null) ...[
                IconTheme(data: IconThemeData(color: tinta, size: 24), child: widget.iconoWidget!),
                const SizedBox(width: 10),
              ] else if (widget.icono != null) ...[
                Icon(widget.icono, color: tinta, size: 24),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(
                  widget.texto,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: VecFuentes.titulo, fontSize: 20, color: tinta),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Subtítulo como en los videos: etiqueta de quién habla + texto en papel con una franja de color.
class Subtitulo extends StatelessWidget {
  const Subtitulo({super.key, required this.quien, required this.texto, this.color, this.clave});
  final String quien, texto;
  final Color? color; // terracota = Victoria (si no se da), azul = Timoteo
  final String? clave; // palabra que se pinta de terracota

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? VecColores.terracota;
    final estilo = TextStyle(fontFamily: VecFuentes.titulo, fontSize: 24, color: VecColores.tinta, height: 1.3);
    final partes = (clave == null || !texto.contains(clave!)) ? [texto] : texto.split(clave!);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12, 3, 12, 1),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Text(quien, style: TextStyle(fontFamily: VecFuentes.titulo, fontSize: 15, color: textoSobre(color))),
      ),
      const SizedBox(height: 4),
      DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [BoxShadow(color: Color(0x402B2622), offset: Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ColoredBox(
            color: VecColores.papel,
            child: IntrinsicHeight(
              child: Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 6, color: color),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
                    child: Text.rich(TextSpan(style: estilo, children: [
                      for (var i = 0; i < partes.length; i++) ...[
                        TextSpan(text: partes[i]),
                        if (i < partes.length - 1) TextSpan(text: clave, style: TextStyle(color: VecColores.terracota)),
                      ],
                    ])),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Globo de diálogo con contorno de tinta.
class Globo extends StatelessWidget {
  const Globo({super.key, required this.texto});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
        decoration: BoxDecoration(
          color: VecColores.papel,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: VecColores.tinta, width: 4),
        ),
        child: Text(texto, style: TextStyle(fontFamily: VecFuentes.titulo, fontSize: 20, color: VecColores.tinta)),
      ),
      Positioned(left: 30, bottom: -16, child: CustomPaint(size: const Size(24, 18), painter: _Piquito())),
    ]);
  }
}

class _Piquito extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width * 0.3, s.height)
      ..close();
    c.drawPath(p, Paint()..color = VecColores.tinta);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Imagen de los assets (ya traen su borde blanco y sombra), con giro opcional.
class Sticker extends StatelessWidget {
  const Sticker(this.ruta, {super.key, this.alto, this.giro = 0});
  final String ruta;
  final double? alto;
  final double giro;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(angle: giro * math.pi / 180, child: Image.asset(ruta, height: alto, filterQuality: FilterQuality.medium));
  }
}

/// Aparece con un "pop": crece con rebote y endereza el giro (como en los videos).
class PopIn extends StatefulWidget {
  const PopIn({super.key, required this.child, this.retraso = Duration.zero, this.giroFinal = 0});
  final Widget child;
  final Duration retraso;
  final double giroFinal; // grados

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: VecMovimiento.duracion);
  late final Animation<double> _t = CurvedAnimation(parent: _c, curve: VecMovimiento.rebote);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.retraso, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "reducir movimiento": aparece directo, sin rebote ni giro.
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) _c.value = 1;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final v = _t.value;
        return Opacity(
          opacity: _c.value,
          child: Transform.rotate(
            angle: (widget.giroFinal - 6 * (1 - v)) * math.pi / 180,
            child: Transform.scale(scale: 0.5 + 0.5 * v, child: child),
          ),
        );
      },
    );
  }
}


// ───────────────────────────────────────────────────────────────────────────
// Extensiones del kit para Victoria en Cristo (mismos tokens de vec_tema.dart)
// ───────────────────────────────────────────────────────────────────────────

/// Ícono SVG del kit (assets/vec/iconos/<nombre>.svg). Usa currentColor, así
/// que toma el color que le pases (o el del IconTheme).
class IconoVec extends StatelessWidget {
  const IconoVec(this.nombre, {super.key, this.color, this.tamano});
  final String nombre; // cruz, biblia, corazon, orar, escudo, mensaje...
  final Color? color;
  final double? tamano;

  @override
  Widget build(BuildContext context) {
    final tema = IconTheme.of(context);
    final t = tamano ?? tema.size ?? 24;
    return SvgPicture.asset(
      'assets/vec/iconos/$nombre.svg',
      width: t,
      height: t,
      // currentColor del SVG; los trazos con color fijo (p. ej. la palomita
      // verde) se respetan.
      theme: SvgTheme(currentColor: color ?? tema.color ?? VecColores.tinta),
    );
  }
}

/// Ícono relleno dentro de un círculo de color (para íconos de Material que no
/// existen en el kit: nunca íconos de línea delgada sueltos).
class CirculoIcono extends StatelessWidget {
  const CirculoIcono({super.key, this.icono, this.iconoVec, this.color, this.colorIcono, this.tamano = 46, this.giro = 0, this.sombra = true});
  final IconData? icono;
  final String? iconoVec; // nombre de un SVG del kit
  final Color? color; // terracota si no se da
  final Color? colorIcono; // el que más se lea sobre [color] si no se da
  final double tamano, giro;
  final bool sombra; // como .vec-tab .ico: la casilla apagada no lleva sombra

  @override
  Widget build(BuildContext context) {
    final t = tamano * 0.56;
    final color = this.color ?? VecColores.terracota;
    final colorIcono = this.colorIcono ?? textoSobre(color);
    return Transform.rotate(
      angle: giro * math.pi / 180,
      child: Container(
        width: tamano,
        height: tamano,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: sombra ? const [BoxShadow(color: Color(0x402B2622), offset: Offset(0, 5))] : null,
        ),
        child: iconoVec != null ? IconoVec(iconoVec!, color: colorIcono, tamano: t) : Icon(icono, color: colorIcono, size: t),
      ),
    );
  }
}

/// Título del estilo (.vec-titulo): Lilita One en tinta con la palabra clave
/// en terracota.
class TituloVec extends StatelessWidget {
  const TituloVec(this.texto, {super.key, this.clave, this.tamano = 30, this.color, this.alineacion = TextAlign.start});
  final String texto;
  final String? clave; // palabra que se pinta de terracota
  final double tamano;
  final Color? color; // tinta si no se da
  final TextAlign alineacion;

  @override
  Widget build(BuildContext context) {
    final estilo = TextStyle(fontFamily: VecFuentes.titulo, fontSize: tamano, color: color ?? VecColores.tinta, height: 1.05);
    final partes = (clave == null || !texto.contains(clave!)) ? [texto] : texto.split(clave!);
    return Text.rich(
      TextSpan(style: estilo, children: [
        for (var i = 0; i < partes.length; i++) ...[
          TextSpan(text: partes[i]),
          if (i < partes.length - 1) TextSpan(text: clave, style: TextStyle(color: VecColores.terracota)),
        ],
      ]),
      textAlign: alineacion,
    );
  }
}

/// Letrero grande con contorno de tinta (.vec-letrero), para portadas. Es como
/// un sticker impreso: lleva los colores del papel claro en todos los temas.
class Letrero extends StatelessWidget {
  const Letrero(this.texto, {super.key, this.clave, this.tamano = 44, this.giro = -2});
  final String texto;
  final String? clave; // se pinta en amarillo de letrero
  final double tamano, giro;

  static const _amarillo = Color(0xFFF6C34A); // .vec-letrero .clave

  @override
  Widget build(BuildContext context) {
    final partes = (clave == null || !texto.contains(clave!)) ? [texto] : texto.split(clave!);
    TextSpan spans(TextStyle base, {Color? colorClave}) => TextSpan(style: base, children: [
          for (var i = 0; i < partes.length; i++) ...[
            TextSpan(text: partes[i]),
            if (i < partes.length - 1) TextSpan(text: clave, style: colorClave == null ? null : TextStyle(color: colorClave)),
          ],
        ]);
    final base = TextStyle(fontFamily: VecFuentes.titulo, fontSize: tamano, height: 1.05);
    final contorno = base.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeJoin = StrokeJoin.round
        ..color = VecPaleta.claro.tinta,
      shadows: const [Shadow(color: Color(0x592B2622), offset: Offset(0, 6))],
    );
    return Transform.rotate(
      angle: giro * math.pi / 180,
      child: Stack(alignment: Alignment.center, children: [
        Text.rich(spans(contorno), textAlign: TextAlign.center),
        Text.rich(spans(base.copyWith(color: VecPaleta.claro.papel), colorClave: _amarillo), textAlign: TextAlign.center),
      ]),
    );
  }
}

/// Encabezado de sección (h2.seccion del demo): Lilita One gris, en mayúsculas.
class EtiquetaSeccion extends StatelessWidget {
  const EtiquetaSeccion(this.texto, {super.key});
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(
      texto.toUpperCase(),
      style: TextStyle(fontFamily: VecFuentes.titulo, fontSize: 17, color: VecColores.gris, letterSpacing: 0.5),
    );
  }
}

/// Hoja rayada para cartas y notas a mano (.vec-hoja): Caveat Brush en azul noche.
class HojaRayada extends StatelessWidget {
  const HojaRayada({super.key, required this.child, this.giro = 1.0, this.cintaDerecha = true});
  final Widget child;
  final double giro;
  final bool cintaDerecha;

  static TextStyle get estilo => TextStyle(fontFamily: VecFuentes.mano, fontSize: 24, height: 40 / 24, color: VecColores.noche);

  @override
  Widget build(BuildContext context) {
    return TarjetaPapel(
      giro: giro,
      cintaDerecha: cintaDerecha,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 10),
      child: CustomPaint(
        painter: _Renglones(),
        child: DefaultTextStyle.merge(style: estilo, child: child),
      ),
    );
  }
}

class _Renglones extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = const Color(0xFFD7E3EE) // raya de --vec-hoja
      ..strokeWidth = 2;
    for (var y = 39.0; y < s.height; y += 40) {
      c.drawLine(Offset(-24, y), Offset(s.width + 24, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Avatar redondo de los personajes (.vec-avatar).
class AvatarVec extends StatelessWidget {
  const AvatarVec({super.key, this.ruta = 'assets/vec/personajes/victoria_avatar.png', this.tamano = 64});
  final String ruta;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x402B2622), offset: Offset(0, 5))],
      ),
      child: ClipOval(child: Image.asset(ruta, fit: BoxFit.cover, filterQuality: FilterQuality.medium)),
    );
  }
}

/// Forma de Material (botones, tarjetas, chips, diálogos) que pinta las
/// sombras del kit (VecSombras) solo POR FUERA de la figura: el color lo pinta
/// el propio Material y la sombra sólida no lo oscurece.
class BordeConSombraVec extends OutlinedBorder {
  BordeConSombraVec({required this.forma, List<BoxShadow>? sombras})
      : sombras = sombras ?? VecSombras.papel,
        super(side: forma.side);
  final OutlinedBorder forma;
  final List<BoxShadow> sombras;

  /// Píldora con la sombra sólida de chips/botones.
  static BordeConSombraVec pildora({bool presionado = false}) =>
      BordeConSombraVec(forma: const StadiumBorder(), sombras: presionado ? VecSombras.presionado : VecSombras.chip);

  /// Tarjeta de papel: esquinas de 14 px, sombra sólida + cálida.
  static BordeConSombraVec tarjeta({double radio = VecRadios.m}) =>
      BordeConSombraVec(forma: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radio)));

  @override
  EdgeInsetsGeometry get dimensions => forma.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) => forma.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => forma.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final figura = getOuterPath(rect, textDirection: textDirection);
    canvas.save();
    canvas.clipPath(Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(200))
      ..addPath(figura, Offset.zero));
    for (final s in sombras) {
      canvas.drawPath(figura.shift(s.offset), s.toPaint());
    }
    canvas.restore();
    forma.paint(canvas, rect, textDirection: textDirection);
  }

  @override
  OutlinedBorder copyWith({BorderSide? side}) => BordeConSombraVec(forma: forma.copyWith(side: side), sombras: sombras);

  @override
  ShapeBorder scale(double t) => BordeConSombraVec(forma: forma.scale(t) as OutlinedBorder, sombras: BoxShadow.lerpList(null, sombras, t)!);

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is BordeConSombraVec) {
      final f = ShapeBorder.lerp(a.forma, forma, t);
      if (f is OutlinedBorder) return BordeConSombraVec(forma: f, sombras: BoxShadow.lerpList(a.sombras, sombras, t)!);
    }
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is BordeConSombraVec) {
      final f = ShapeBorder.lerp(forma, b.forma, t);
      if (f is OutlinedBorder) return BordeConSombraVec(forma: f, sombras: BoxShadow.lerpList(sombras, b.sombras, t)!);
    }
    return super.lerpTo(b, t);
  }

  @override
  bool operator ==(Object other) => other is BordeConSombraVec && other.forma == forma && listEquals(other.sombras, sombras);

  @override
  int get hashCode => Object.hash(forma, Object.hashAll(sombras));
}

/// Transición de página que pone el papel con textura (FondoPapel) detrás de
/// cada pantalla, para que ninguna quede con fondo plano.
class TransicionPapel extends PageTransitionsBuilder {
  const TransicionPapel(this.base);
  final PageTransitionsBuilder base;

  @override
  DelegatedTransitionBuilder? get delegatedTransition => base.delegatedTransition;

  @override
  Duration get transitionDuration => base.transitionDuration;

  @override
  Duration get reverseTransitionDuration => base.reverseTransitionDuration;

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return base.buildTransitions(route, context, animation, secondaryAnimation, FondoPapel(child: child));
  }
}
