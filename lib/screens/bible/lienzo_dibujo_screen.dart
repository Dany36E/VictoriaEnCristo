import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bible/dibujo_nota.dart';
import '../../theme/app_theme_data.dart';
import '../../utils/tinta.dart';
import '../../vec/vec_tema.dart';
import '../../widgets/bible/sermon/lienzo/bandeja_herramientas.dart';
import '../../widgets/bible/sermon/lienzo/edicion_trazos.dart';
import '../../widgets/bible/sermon/lienzo/pintura_dibujo.dart';

/// Lienzo de Apuntes para dibujar o escribir a mano, y para marcar fotos.
///
/// - Un dedo o el lápiz dibujan; dos dedos mueven la hoja y hacen zoom.
/// - Si se detecta un lápiz (Apple Pencil, S Pen…), el dedo solo mueve la
///   hoja, como «Dibujar solo con el Apple Pencil».
/// - Mantener quieto el final de un trazo lo convierte en línea recta.
class LienzoDibujoScreen extends StatefulWidget {
  const LienzoDibujoScreen({
    super.key,
    this.inicial,
    this.foto,
    this.titulo = 'Dibujo',
  });

  final DatosDibujo? inicial;

  /// Foto de fondo: el lienzo toma su proporción y se dibuja encima.
  final ui.Image? foto;
  final String titulo;

  static Future<DatosDibujo?> abrir(
    BuildContext context, {
    DatosDibujo? inicial,
    ui.Image? foto,
    String titulo = 'Dibujo',
  }) {
    return Navigator.push<DatosDibujo>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            LienzoDibujoScreen(inicial: inicial, foto: foto, titulo: titulo),
      ),
    );
  }

  @override
  State<LienzoDibujoScreen> createState() => _LienzoDibujoScreenState();
}

const List<Color> _tintas = [
  VecColores.tinta,
  VecColores.terracota,
  VecColores.azul,
  VecColores.verde,
  VecColores.mostaza,
  Color(0xFF7E57C2),
  Color(0xFFE5739A),
  Color(0xFFFFFFFF),
];

const List<Color> _resaltadores = [
  Color(0xFFFFE066),
  Color(0xFF9BE58A),
  Color(0xFF8FD3FF),
  Color(0xFFFF9EC7),
  Color(0xFFFFB86B),
];

const Map<HerramientaLienzo, List<double>> _grosores = {
  HerramientaLienzo.pluma: [3, 5, 8, 12],
  HerramientaLienzo.lapiz: [2, 4, 6, 9],
  HerramientaLienzo.marcador: [8, 14, 22, 32],
  HerramientaLienzo.resaltador: [18, 28, 40, 56],
  HerramientaLienzo.borrador: [14, 28, 48],
};

enum _ModoBorrador { completo, parcial }

class _LienzoDibujoScreenState extends State<LienzoDibujoScreen> {
  late List<Trazo> _trazos = widget.inicial?.trazos ?? const [];
  late double _alto =
      widget.foto != null
          ? DatosDibujo.ancho * widget.foto!.height / widget.foto!.width
          : widget.inicial?.alto ?? DatosDibujo.altoInicial;
  late FondoLienzo _fondo = widget.inicial?.fondo ?? FondoLienzo.liso;
  final List<DatosDibujo> _deshacer = [];
  final List<DatosDibujo> _rehacer = [];
  bool _cambio = false;

  HerramientaLienzo _herramienta = HerramientaLienzo.pluma;
  final Map<HerramientaLienzo, Color> _color = {
    HerramientaLienzo.pluma: VecColores.tinta,
    HerramientaLienzo.lapiz: VecColores.lapiz,
    HerramientaLienzo.marcador: VecColores.terracota,
    HerramientaLienzo.resaltador: _resaltadores.first,
  };
  final Map<HerramientaLienzo, double> _grosor = {
    for (final e in _grosores.entries) e.key: e.value[1],
  };
  _ModoBorrador _modoBorrador = _ModoBorrador.completo;

  // Vista
  Size _vista = Size.zero;
  double _zoom = 1;
  Offset _pan = Offset.zero;
  bool _panListo = false;

  // Punteros
  final Map<int, Offset> _toques = {};
  int? _punteroAccion;
  bool _accionConDedo = false;
  DateTime _inicioAccion = DateTime.now();
  bool _hayLapiz = false;
  bool _soloLapiz = false;
  bool _soloLapizElegido = false;
  double _zoomPellizco = 1;
  double _distanciaPellizco = 0;
  Offset _focoPellizco = Offset.zero;
  Offset? _inicioArrastre;
  Offset _panArrastre = Offset.zero;

  // Trazo en curso
  List<PuntoTinta>? _activo;
  bool _presionReal = false;
  HerramientaLienzo? _herramientaActiva;
  Timer? _temporizadorRecta;
  Offset _ultimaPosicion = Offset.zero;
  PuntoTinta? _inicioRecta;

  // Borrador y lazo
  Offset? _cursorBorrador;
  bool _borroAlgo = false;
  List<Offset>? _lazo;
  Set<int> _seleccion = const {};
  bool _moviendo = false;
  Offset _origenMovimiento = Offset.zero;
  List<Trazo> _antesDeMover = const [];

  ui.Picture? _grabado;
  List<Trazo>? _grabadoDe;

  bool get _conFoto => widget.foto != null;

  @override
  void dispose() {
    _temporizadorRecta?.cancel();
    _grabado?.dispose();
    super.dispose();
  }

  DatosDibujo _datos() =>
      DatosDibujo(alto: _alto, fondo: _fondo, trazos: _trazos);

  void _guardarDeshacer() {
    _deshacer.add(_datos());
    if (_deshacer.length > 60) _deshacer.removeAt(0);
    _rehacer.clear();
    _cambio = true;
  }

  void _restaurar(DatosDibujo d) {
    _trazos = d.trazos;
    _alto = d.alto;
    _fondo = d.fondo;
    _seleccion = const {};
  }

  void _deshacerUno() {
    if (_deshacer.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _rehacer.add(_datos());
      _restaurar(_deshacer.removeLast());
    });
  }

  void _rehacerUno() {
    if (_rehacer.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _deshacer.add(_datos());
      _restaurar(_rehacer.removeLast());
    });
  }

  // ── Vista y coordenadas ────────────────────────────────────────────────

  double get _escalaBase =>
      math.max(0.1, (_vista.width - 24) / DatosDibujo.ancho);
  double get _escala => _escalaBase * _zoom;

  Offset _aLienzo(Offset pantalla) => (pantalla - _pan) / _escala;

  Offset _limitarPan(Offset pan) {
    final anchoHoja = DatosDibujo.ancho * _escala;
    final altoHoja = _alto * _escala;
    final x = anchoHoja + 24 <= _vista.width
        ? (_vista.width - anchoHoja) / 2
        : pan.dx.clamp(_vista.width - anchoHoja - 12, 12.0);
    const arriba = 12.0;
    const abajo = 170.0; // la bandeja tapa la parte de abajo
    final minimo = math.min(arriba, _vista.height - altoHoja - abajo);
    return Offset(x.toDouble(), pan.dy.clamp(minimo, arriba).toDouble());
  }

  // ── Punteros ───────────────────────────────────────────────────────────

  bool _esLapiz(PointerEvent e) =>
      e.kind == PointerDeviceKind.stylus ||
      e.kind == PointerDeviceKind.invertedStylus;

  double _presion(PointerEvent e) {
    if (e.pressureMax <= e.pressureMin) return 0.5;
    return ((e.pressure - e.pressureMin) / (e.pressureMax - e.pressureMin))
        .clamp(0.05, 1.0);
  }

  void _alBajar(PointerDownEvent e) {
    if (_esLapiz(e)) {
      if (!_hayLapiz) {
        _hayLapiz = true;
        if (!_soloLapizElegido) setState(() => _soloLapiz = true);
      }
      if (_punteroAccion != null) return;
      _empezarAccion(
        e,
        borrador: e.kind == PointerDeviceKind.invertedStylus,
      );
      return;
    }
    if (e.kind == PointerDeviceKind.mouse && e.buttons != kPrimaryButton) {
      return;
    }
    _toques[e.pointer] = e.localPosition;
    if (_toques.length == 2) {
      // Segundo dedo: si el trazo apenas empezaba, era el inicio de un gesto.
      if (_punteroAccion != null && _accionConDedo) _cancelarSiEsCorta();
      _empezarPellizco();
      return;
    }
    if (_toques.length != 1) return;
    if (_soloLapiz && e.kind != PointerDeviceKind.mouse) {
      _inicioArrastre = e.localPosition;
      _panArrastre = _pan;
    } else if (_punteroAccion == null) {
      _accionConDedo = true;
      _empezarAccion(e);
    }
  }

  void _alMover(PointerMoveEvent e) {
    if (e.pointer == _punteroAccion) {
      _moverAccion(e);
      return;
    }
    if (!_toques.containsKey(e.pointer)) return;
    _toques[e.pointer] = e.localPosition;
    if (_toques.length >= 2) {
      _actualizarPellizco();
    } else if (_inicioArrastre != null) {
      setState(() {
        _pan = _limitarPan(_panArrastre + e.localPosition - _inicioArrastre!);
      });
    }
  }

  void _alSubir(PointerEvent e) {
    if (e.pointer == _punteroAccion) _terminarAccion();
    _toques.remove(e.pointer);
    if (_toques.length < 2) _distanciaPellizco = 0;
    if (_toques.isEmpty) _inicioArrastre = null;
    if (_toques.length == 1 && (_soloLapiz || _distanciaPellizco == 0)) {
      // Queda un dedo tras el zoom: sigue moviendo la hoja.
      _inicioArrastre = _toques.values.first;
      _panArrastre = _pan;
    }
  }

  void _alRueda(PointerSignalEvent e) {
    if (e is PointerScrollEvent) {
      setState(() => _pan = _limitarPan(_pan - e.scrollDelta));
    }
  }

  void _empezarPellizco() {
    final p = _toques.values.toList();
    _distanciaPellizco = math.max(1, (p[0] - p[1]).distance);
    _zoomPellizco = _zoom;
    _focoPellizco = _aLienzo((p[0] + p[1]) / 2);
    _inicioArrastre = null;
  }

  void _actualizarPellizco() {
    final p = _toques.values.take(2).toList();
    if (_distanciaPellizco == 0) _empezarPellizco();
    final centro = (p[0] + p[1]) / 2;
    final zoom = (_zoomPellizco * (p[0] - p[1]).distance / _distanciaPellizco)
        .clamp(0.6, 4.0);
    setState(() {
      _zoom = zoom;
      _pan = _limitarPan(centro - _focoPellizco * _escala);
    });
  }

  // ── Acciones ───────────────────────────────────────────────────────────

  void _empezarAccion(PointerDownEvent e, {bool borrador = false}) {
    _punteroAccion = e.pointer;
    _inicioAccion = DateTime.now();
    final c = _aLienzo(e.localPosition);
    final herramienta = borrador ? HerramientaLienzo.borrador : _herramienta;
    _herramientaActiva = herramienta;
    _ultimaPosicion = e.localPosition;
    switch (herramienta) {
      case HerramientaLienzo.borrador:
        _guardarDeshacer();
        _borroAlgo = false;
        _borrarEn(c);
      case HerramientaLienzo.lazo:
        final caja = limitesDe(_trazos, _seleccion);
        if (caja != null && caja.inflate(12).contains(c)) {
          _guardarDeshacer();
          _moviendo = true;
          _origenMovimiento = c;
          _antesDeMover = _trazos;
        } else {
          setState(() {
            _seleccion = const {};
            _lazo = [c];
          });
        }
      default:
        _presionReal = _esLapiz(e) && e.pressureMax > e.pressureMin;
        _inicioRecta = null;
        setState(() => _activo = [PuntoTinta(c.dx, c.dy, _presion(e))]);
        _reiniciarRecta();
    }
  }

  void _moverAccion(PointerMoveEvent e) {
    final c = _aLienzo(e.localPosition);
    switch (_herramientaActiva) {
      case HerramientaLienzo.borrador:
        final previo = _cursorBorrador ?? c;
        final radio = _grosor[HerramientaLienzo.borrador]!;
        final pasos = math.max(1, ((c - previo).distance / (radio / 2)).ceil());
        for (var i = 1; i <= pasos; i++) {
          _borrarEn(Offset.lerp(previo, c, i / pasos)!);
        }
      case HerramientaLienzo.lazo:
        if (_moviendo) {
          final d = c - _origenMovimiento;
          setState(() {
            _trazos = [
              for (var i = 0; i < _antesDeMover.length; i++)
                _seleccion.contains(i)
                    ? _antesDeMover[i].mover(d)
                    : _antesDeMover[i],
            ];
          });
        } else if (_lazo != null) {
          setState(() => _lazo = [..._lazo!, c]);
        }
      default:
        final activo = _activo;
        if (activo == null) return;
        if (_inicioRecta != null) {
          setState(() {
            _activo = lineaRecta(_inicioRecta!, PuntoTinta(c.dx, c.dy));
          });
          return;
        }
        final ultimo = activo.last;
        if ((c - ultimo.offset).distance * _escala < 0.8) return;
        setState(() => _activo = [...activo, PuntoTinta(c.dx, c.dy, _presion(e))]);
        if ((e.localPosition - _ultimaPosicion).distance > 3) {
          _ultimaPosicion = e.localPosition;
          _reiniciarRecta();
        }
    }
  }

  void _reiniciarRecta() {
    _temporizadorRecta?.cancel();
    _temporizadorRecta = Timer(const Duration(milliseconds: 600), () {
      final activo = _activo;
      if (!mounted || activo == null || activo.length < 3) return;
      if ((activo.last.offset - activo.first.offset).distance < 40) return;
      HapticFeedback.selectionClick();
      setState(() {
        _inicioRecta = activo.first;
        _activo = lineaRecta(activo.first, activo.last);
      });
    });
  }

  void _cancelarSiEsCorta() {
    final reciente =
        DateTime.now().difference(_inicioAccion) <
        const Duration(milliseconds: 250);
    if (_activo != null && reciente) {
      _temporizadorRecta?.cancel();
      setState(() => _activo = null);
      _punteroAccion = null;
    } else {
      _terminarAccion();
    }
  }

  void _terminarAccion() {
    _temporizadorRecta?.cancel();
    final herramienta = _herramientaActiva;
    _punteroAccion = null;
    _accionConDedo = false;
    _herramientaActiva = null;
    switch (herramienta) {
      case HerramientaLienzo.borrador:
        if (!_borroAlgo && _deshacer.isNotEmpty) _deshacer.removeLast();
        setState(() => _cursorBorrador = null);
      case HerramientaLienzo.lazo:
        if (_moviendo) {
          setState(() => _moviendo = false);
        } else if (_lazo != null) {
          setState(() {
            _seleccion = seleccionarConLazo(_trazos, _lazo!);
            _lazo = null;
          });
          if (_seleccion.isNotEmpty) HapticFeedback.selectionClick();
        }
      case null:
        break;
      default:
        final activo = _activo;
        if (activo == null) return;
        _guardarDeshacer();
        setState(() {
          _trazos = [
            ..._trazos,
            Trazo(
              herramienta: _tipoDeTinta(herramienta),
              color: _color[herramienta]!.toARGB32(),
              grosor: _grosor[herramienta]!,
              puntos: activo,
              presionReal: _presionReal && _inicioRecta == null,
            ),
          ];
          _activo = null;
          _inicioRecta = null;
        });
    }
  }

  void _borrarEn(Offset c) {
    final radio = _grosor[HerramientaLienzo.borrador]! / 2;
    final siguiente = _modoBorrador == _ModoBorrador.completo
        ? borrarTrazosCompletos(_trazos, c, radio)
        : borrarParcial(_trazos, c, radio);
    setState(() {
      _cursorBorrador = c;
      if (!identical(siguiente, _trazos)) {
        _trazos = siguiente;
        _borroAlgo = true;
      }
    });
  }

  HerramientaTrazo _tipoDeTinta(HerramientaLienzo h) => switch (h) {
    HerramientaLienzo.lapiz => HerramientaTrazo.lapiz,
    HerramientaLienzo.marcador => HerramientaTrazo.marcador,
    HerramientaLienzo.resaltador => HerramientaTrazo.resaltador,
    _ => HerramientaTrazo.pluma,
  };

  // ── Selección ──────────────────────────────────────────────────────────

  void _borrarSeleccion() {
    _guardarDeshacer();
    setState(() {
      _trazos = [
        for (var i = 0; i < _trazos.length; i++)
          if (!_seleccion.contains(i)) _trazos[i],
      ];
      _seleccion = const {};
    });
  }

  void _duplicarSeleccion() {
    _guardarDeshacer();
    final copias = [for (final i in _seleccion) _trazos[i].mover(const Offset(30, 30))];
    setState(() {
      final inicio = _trazos.length;
      _trazos = [..._trazos, ...copias];
      _seleccion = {for (var i = 0; i < copias.length; i++) inicio + i};
    });
  }

  void _colorearSeleccion(Color color) {
    _guardarDeshacer();
    setState(() {
      _trazos = [
        for (var i = 0; i < _trazos.length; i++)
          _seleccion.contains(i)
              ? _trazos[i].copiar(color: color.toARGB32())
              : _trazos[i],
      ];
    });
  }

  // ── Menú y salida ──────────────────────────────────────────────────────

  void _elegirFondo(FondoLienzo fondo) {
    if (fondo == _fondo) return;
    _guardarDeshacer();
    setState(() => _fondo = fondo);
  }

  void _masEspacio() {
    _guardarDeshacer();
    setState(() => _alto += DatosDibujo.espacioExtra);
  }

  Future<void> _borrarTodo() async {
    if (_trazos.isEmpty) return;
    final ok = await _confirmar(
      '¿Borrar todo el dibujo?',
      'Puedes recuperarlo con Deshacer mientras sigas aquí.',
      'Borrar todo',
    );
    if (ok != true) return;
    _guardarDeshacer();
    setState(() {
      _trazos = const [];
      _seleccion = const {};
    });
  }

  Future<bool?> _confirmar(String titulo, String texto, String accion) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(accion),
          ),
        ],
      ),
    );
  }

  void _listo() {
    final datos = _datos();
    Navigator.pop(
      context,
      datos.vacio && widget.inicial == null && !_conFoto ? null : datos,
    );
  }

  Future<void> _salir() async {
    if (!_cambio) {
      Navigator.pop(context);
      return;
    }
    final ok = await _confirmar(
      '¿Descartar los cambios?',
      'Lo que dibujaste en esta sesión no se guardará.',
      'Descartar',
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  // ── Interfaz ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final mesa = t.isPaper
        ? const Color(0xFFE6DAC4)
        : t.isDark
        ? const Color(0xFF16161C)
        : const Color(0xFFE4E4E8);
    final superficie = t.isPaper ? VecColores.papel : t.surface;
    final texto = t.isPaper ? VecColores.tinta : t.textPrimary;
    if (!identical(_grabadoDe, _trazos)) {
      _grabado?.dispose();
      _grabado = grabarTrazos(_trazos);
      _grabadoDe = _trazos;
    }
    return PopScope(
      canPop: !_cambio,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _salir();
      },
      child: Scaffold(
        backgroundColor: mesa,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _barraSuperior(superficie, texto, t),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _lienzo()),
                    if (_seleccion.isNotEmpty && !_moviendo)
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Center(child: _menuSeleccion(superficie, texto)),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _panelInferior(superficie, texto, t),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _barraSuperior(Color superficie, Color texto, AppThemeData t) {
    final acento = t.isPaper ? VecColores.terracota : t.accent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: superficie,
        border: Border(
          bottom: BorderSide(color: texto.withValues(alpha: 0.08)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Cerrar',
              icon: Icon(Icons.close_rounded, color: texto),
              onPressed: _salir,
            ),
            Expanded(
              child: Text(
                widget.titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: t.isPaper ? VecFuentes.titulo : null,
                  fontSize: t.isPaper ? 20 : 17,
                  fontWeight: t.isPaper ? FontWeight.w400 : FontWeight.w700,
                  color: texto,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Deshacer',
              icon: const Icon(Icons.undo_rounded),
              color: texto,
              onPressed: _deshacer.isEmpty ? null : _deshacerUno,
            ),
            IconButton(
              tooltip: 'Rehacer',
              icon: const Icon(Icons.redo_rounded),
              color: texto,
              onPressed: _rehacer.isEmpty ? null : _rehacerUno,
            ),
            _menuOpciones(texto),
            const SizedBox(width: 4),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: acento,
                foregroundColor: t.isPaper ? VecColores.papel : t.scaffoldBg,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _listo,
              child: const Text('Listo'),
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuOpciones(Color texto) {
    return PopupMenuButton<String>(
      tooltip: 'Más opciones',
      icon: Icon(Icons.more_horiz_rounded, color: texto),
      onSelected: (v) {
        switch (v) {
          case 'lapiz':
            setState(() {
              _soloLapiz = !_soloLapiz;
              _soloLapizElegido = true;
            });
          case 'espacio':
            _masEspacio();
          case 'borrar':
            _borrarTodo();
          default:
            _elegirFondo(FondoLienzo.values.byName(v));
        }
      },
      itemBuilder: (_) => [
        if (!_conFoto) ...[
          for (final f in FondoLienzo.values)
            CheckedPopupMenuItem(
              value: f.name,
              checked: f == _fondo,
              child: Text(switch (f) {
                FondoLienzo.liso => 'Hoja lisa',
                FondoLienzo.rayado => 'Hoja rayada',
                FondoLienzo.cuadricula => 'Cuadrícula',
                FondoLienzo.puntos => 'Puntos',
              }),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'espacio',
            child: ListTile(
              leading: Icon(Icons.vertical_align_bottom_rounded),
              title: Text('Más espacio'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
        CheckedPopupMenuItem(
          value: 'lapiz',
          checked: _soloLapiz,
          child: const Text('Dibujar solo con lápiz'),
        ),
        const PopupMenuItem(
          value: 'borrar',
          child: ListTile(
            leading: Icon(Icons.delete_outline_rounded),
            title: Text('Borrar todo'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }

  Widget _lienzo() {
    return LayoutBuilder(
      builder: (context, c) {
        final nueva = Size(c.maxWidth, c.maxHeight);
        if (nueva != _vista) {
          _vista = nueva;
          if (!_panListo) {
            _panListo = true;
            _pan = const Offset(12, 12);
          }
          _pan = _limitarPan(_pan);
        }
        return Semantics(
          label:
              'Hoja de dibujo. Dibuja con un dedo o con el lápiz; con dos '
              'dedos mueves la hoja y haces zoom.',
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _alBajar,
            onPointerMove: _alMover,
            onPointerUp: _alSubir,
            onPointerCancel: _alSubir,
            onPointerSignal: _alRueda,
            child: CustomPaint(
              size: Size.infinite,
              painter: _PintorLienzo(
                pan: _pan,
                escala: _escala,
                alto: _alto,
                fondo: _fondo,
                foto: widget.foto,
                grabado: _grabado,
                activo: _activo == null
                    ? null
                    : Trazo(
                        herramienta: _tipoDeTinta(_herramientaActiva!),
                        color: _color[_herramientaActiva]!.toARGB32(),
                        grosor: _grosor[_herramientaActiva]!,
                        puntos: _activo!,
                        presionReal: _presionReal && _inicioRecta == null,
                      ),
                lazo: _lazo,
                seleccion: limitesDe(_trazos, _seleccion),
                cursorBorrador: _cursorBorrador,
                radioBorrador: _grosor[HerramientaLienzo.borrador]! / 2,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _menuSeleccion(Color superficie, Color texto) {
    return Material(
      color: superficie,
      borderRadius: BorderRadius.circular(24),
      shadowColor: const Color(0x552B2622),
      elevation: 3,
      surfaceTintColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton.icon(
              onPressed: _duplicarSeleccion,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Duplicar'),
            ),
            TextButton.icon(
              onPressed: _borrarSeleccion,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Borrar'),
            ),
            PopupMenuButton<Color>(
              tooltip: 'Cambiar color',
              icon: const Icon(Icons.palette_outlined, size: 20),
              onSelected: _colorearSeleccion,
              itemBuilder: (_) => [
                for (final c in _tintas)
                  PopupMenuItem(
                    value: c,
                    child: Row(
                      children: [
                        _Muestra(color: c, elegido: false),
                        const SizedBox(width: 10),
                        Text(_nombreColor(c)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _panelInferior(Color superficie, Color texto, AppThemeData t) {
    final h = _herramienta;
    final opciones = <Widget>[];
    final grosores = _grosores[h];
    if (grosores != null) {
      for (final g in grosores) {
        opciones.add(
          _Grosor(
            grosor: g,
            maximo: grosores.last,
            elegido: _grosor[h] == g,
            color: h == HerramientaLienzo.borrador ? texto : _color[h]!,
            onTap: () => setState(() => _grosor[h] = g),
          ),
        );
      }
    }
    if (h == HerramientaLienzo.borrador) {
      opciones.add(const SizedBox(width: 8));
      opciones.add(
        SegmentedButton<_ModoBorrador>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(
              value: _ModoBorrador.completo,
              label: Text('Trazo'),
              tooltip: 'Borra trazos completos',
            ),
            ButtonSegment(
              value: _ModoBorrador.parcial,
              label: Text('Parte'),
              tooltip: 'Borra solo lo que tocas',
            ),
          ],
          selected: {_modoBorrador},
          onSelectionChanged: (s) => setState(() => _modoBorrador = s.first),
        ),
      );
    } else if (h == HerramientaLienzo.lazo) {
      opciones.add(
        Flexible(
          child: Text(
            _seleccion.isEmpty
                ? 'Rodea lo que quieras mover, copiar o borrar.'
                : 'Arrastra la selección para moverla.',
            style: TextStyle(color: texto, fontSize: 14),
          ),
        ),
      );
    } else {
      opciones.add(const SizedBox(width: 6));
      final paleta = h == HerramientaLienzo.resaltador ? _resaltadores : _tintas;
      for (final c in paleta) {
        opciones.add(
          Semantics(
            button: true,
            selected: _color[h] == c,
            label: 'Color ${_nombreColor(c)}',
            child: GestureDetector(
              onTap: () => setState(() => _color[h] = c),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: _Muestra(color: c, elegido: _color[h] == c),
              ),
            ),
          ),
        );
      }
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: superficie,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(color: Color(0x262B2622), blurRadius: 14, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 40,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: opciones),
                ),
              ),
              BandejaHerramientas(
                activa: _herramienta,
                colorDe: (h) => _color[h] ?? texto,
                onElegir: (h) => setState(() {
                  _herramienta = h;
                  if (h != HerramientaLienzo.lazo) _seleccion = const {};
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _nombreColor(Color c) {
    const nombres = {
      0xFF2B2622: 'tinta',
      0xFFC8553D: 'terracota',
      0xFF3D6890: 'azul',
      0xFF2F7F7A: 'verde',
      0xFFE0A73A: 'mostaza',
      0xFF7E57C2: 'morado',
      0xFFE5739A: 'rosa',
      0xFFFFFFFF: 'blanco',
      0xFFFFE066: 'amarillo',
      0xFF9BE58A: 'verde claro',
      0xFF8FD3FF: 'celeste',
      0xFFFF9EC7: 'rosa claro',
      0xFFFFB86B: 'naranja',
    };
    return nombres[c.toARGB32()] ?? 'personalizado';
  }
}

class _Muestra extends StatelessWidget {
  const _Muestra({required this.color, required this.elegido});

  final Color color;
  final bool elegido;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: elegido ? VecColores.tinta : const Color(0x332B2622),
          width: elegido ? 3 : 1.2,
        ),
        boxShadow: elegido
            ? const [BoxShadow(color: Color(0x33000000), blurRadius: 4)]
            : null,
      ),
    );
  }
}

class _Grosor extends StatelessWidget {
  const _Grosor({
    required this.grosor,
    required this.maximo,
    required this.elegido,
    required this.color,
    required this.onTap,
  });

  final double grosor;
  final double maximo;
  final bool elegido;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final diametro = 6 + 16 * grosor / maximo;
    return Semantics(
      button: true,
      selected: elegido,
      label: 'Grosor ${grosor.round()}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: elegido ? const Color(0x1A2B2622) : null,
          ),
          child: Container(
            width: diametro,
            height: diametro,
            decoration: BoxDecoration(
              color: color.computeLuminance() > 0.9
                  ? const Color(0xFFBDB3A6)
                  : color,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _PintorLienzo extends CustomPainter {
  _PintorLienzo({
    required this.pan,
    required this.escala,
    required this.alto,
    required this.fondo,
    required this.foto,
    required this.grabado,
    required this.activo,
    required this.lazo,
    required this.seleccion,
    required this.cursorBorrador,
    required this.radioBorrador,
  });

  final Offset pan;
  final double escala;
  final double alto;
  final FondoLienzo fondo;
  final ui.Image? foto;
  final ui.Picture? grabado;
  final Trazo? activo;
  final List<Offset>? lazo;
  final Rect? seleccion;
  final Offset? cursorBorrador;
  final double radioBorrador;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(pan.dx, pan.dy);
    canvas.scale(escala);
    final hoja = Rect.fromLTWH(0, 0, DatosDibujo.ancho, alto);
    canvas.drawShadow(Path()..addRect(hoja), const Color(0xFF000000), 4, false);
    final foto = this.foto;
    if (foto != null) {
      paintImage(
        canvas: canvas,
        rect: hoja,
        image: foto,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      );
    } else {
      canvas.drawRect(hoja, Paint()..color = colorHoja);
      pintarFondoHoja(canvas, hoja.size, fondo);
    }
    canvas.save();
    canvas.clipRect(hoja);
    if (grabado != null) canvas.drawPicture(grabado!);
    if (activo != null) pintarTrazo(canvas, activo!);
    canvas.restore();

    final linea = Paint()
      ..color = VecColores.azul
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 / escala;
    final lazo = this.lazo;
    if (lazo != null && lazo.length > 1) {
      canvas.drawPath(_punteado(Path()..addPolygon(lazo, false), 10 / escala), linea);
    }
    final seleccion = this.seleccion;
    if (seleccion != null) {
      canvas.drawPath(
        _punteado(Path()..addRect(seleccion.inflate(8)), 10 / escala),
        linea,
      );
    }
    final cursor = cursorBorrador;
    if (cursor != null) {
      canvas.drawCircle(
        cursor,
        radioBorrador,
        Paint()
          ..color = const Color(0x553A332C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / escala,
      );
    }
    canvas.restore();
  }

  Path _punteado(Path fuente, double guion) {
    final resultado = Path();
    for (final m in fuente.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += guion * 2) {
        resultado.addPath(m.extractPath(d, math.min(d + guion, m.length)), Offset.zero);
      }
    }
    return resultado;
  }

  @override
  bool shouldRepaint(_PintorLienzo old) => true;
}
