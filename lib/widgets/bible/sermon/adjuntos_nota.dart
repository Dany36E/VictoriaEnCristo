/// Fotos y dibujos dentro de la sección Notas de Apuntes: tarjetas con pie
/// de foto, estado en la nube y un visor a pantalla completa con zoom.
library;

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../models/bible/adjunto_nota.dart';
import '../../../models/bible/dibujo_nota.dart';
import '../../../services/bible/adjuntos_nota_service.dart';
import '../../../services/bible/sermon_note_export_service.dart';
import '../../../theme/bible_reader_theme.dart';
import 'lienzo/pintura_dibujo.dart';

/// Lo que se puede hacer con un adjunto desde su tarjeta o el visor.
enum AccionAdjunto { ver, editar, pie, subir, bajar, quitar }

/// Contenido cargado de un adjunto: la foto decodificada y/o el dibujo.
class ContenidoAdjunto {
  final Uint8List? bytesFoto;
  final ui.Image? foto;
  final DatosDibujo? dibujo;

  const ContenidoAdjunto({this.bytesFoto, this.foto, this.dibujo});

  bool get vacio => foto == null && dibujo == null;
}

/// Carga la foto (con sus marcas) o el dibujo de un adjunto.
Future<ContenidoAdjunto> cargarAdjunto(String notaId, AdjuntoNota a) async {
  final servicio = AdjuntosNotaService.I;
  if (a.tipo == TipoAdjunto.dibujo) {
    return ContenidoAdjunto(dibujo: await servicio.leerDibujo(notaId, a.archivo));
  }
  final bytes = await servicio.leerArchivo(notaId, a.archivo);
  ui.Image? foto;
  if (bytes != null) {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      foto = (await codec.getNextFrame()).image;
    } catch (_) {}
  }
  final marcas = a.conMarcas
      ? await servicio.leerDibujo(notaId, a.archivoMarcas)
      : null;
  return ContenidoAdjunto(bytesFoto: bytes, foto: foto, dibujo: marcas);
}

/// Imagen lista para compartir o para el PDF: la foto tal cual (jpg), la
/// foto con sus marcas o el dibujo sobre su hoja (png).
Future<(Uint8List, String)?> imagenDeAdjunto(String notaId, AdjuntoNota a) async {
  final contenido = await cargarAdjunto(notaId, a);
  if (a.tipo == TipoAdjunto.dibujo) {
    if (contenido.dibujo == null) return null;
    final png = await dibujoAPng(contenido.dibujo!);
    return png == null ? null : (png, 'png');
  }
  if (contenido.dibujo != null && contenido.foto != null) {
    final png = await dibujoAPng(contenido.dibujo!, foto: contenido.foto);
    if (png != null) return (png, 'png');
  }
  final bytes = contenido.bytesFoto;
  return bytes == null ? null : (bytes, 'jpg');
}

/// Fotos y dibujos de la nota para el PDF, en orden; se saltan los que no
/// se pudieron leer (por ejemplo, sin conexión y sin copia en el teléfono).
Future<List<ImagenPdf>> imagenesParaPdf(
  String notaId,
  List<AdjuntoNota> adjuntos,
) async {
  final imagenes = <ImagenPdf>[];
  for (final a in adjuntos) {
    try {
      final imagen = await imagenDeAdjunto(notaId, a);
      if (imagen != null) imagenes.add(ImagenPdf(imagen.$1, a.pie));
    } catch (_) {}
  }
  return imagenes;
}

/// Vista del adjunto: foto con marcas encima, o dibujo sobre su hoja.
class VistaAdjunto extends StatefulWidget {
  const VistaAdjunto({
    super.key,
    required this.notaId,
    required this.adjunto,
    required this.theme,
  });

  final String notaId;
  final AdjuntoNota adjunto;
  final BibleReaderThemeData theme;

  @override
  State<VistaAdjunto> createState() => _VistaAdjuntoState();
}

class _VistaAdjuntoState extends State<VistaAdjunto> {
  Future<ContenidoAdjunto>? _carga;
  int _version = -1;

  void _cargar() {
    _version = AdjuntosNotaService.I.cambios.value;
    _carga = cargarAdjunto(widget.notaId, widget.adjunto);
  }

  @override
  void didUpdateWidget(VistaAdjunto old) {
    super.didUpdateWidget(old);
    if (old.adjunto != widget.adjunto) _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    return ValueListenableBuilder<int>(
      valueListenable: AdjuntosNotaService.I.cambios,
      builder: (context, cambios, _) {
        if (_carga == null || cambios != _version) _cargar();
        return AspectRatio(
          aspectRatio: widget.adjunto.proporcion.clamp(0.45, 2.4),
          child: FutureBuilder<ContenidoAdjunto>(
            future: _carga,
            builder: (context, snap) {
              final c = snap.data;
              if (c == null) {
                return Container(
                  color: t.textSecondary.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  child: snap.connectionState == ConnectionState.done
                      ? const SizedBox.shrink()
                      : SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: t.accent,
                          ),
                        ),
                );
              }
              if (c.vacio) {
                return Container(
                  color: t.textSecondary.withValues(alpha: 0.08),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off_rounded, color: t.textSecondary),
                      const SizedBox(height: 6),
                      Text(
                        'No se pudo abrir. Revisa tu conexión.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: t.textSecondary, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }
              if (widget.adjunto.tipo == TipoAdjunto.dibujo) {
                return VistaDibujo(dibujo: c.dibujo!);
              }
              return Stack(
                fit: StackFit.expand,
                children: [
                  RawImage(image: c.foto, fit: BoxFit.cover),
                  if (c.dibujo != null)
                    VistaDibujo(dibujo: c.dibujo!, conHoja: false),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

/// Lista de fotos y dibujos dentro de la tarjeta Notas.
class GaleriaAdjuntos extends StatelessWidget {
  const GaleriaAdjuntos({
    super.key,
    required this.theme,
    required this.notaId,
    required this.adjuntos,
    required this.onAccion,
  });

  final BibleReaderThemeData theme;
  final String notaId;
  final List<AdjuntoNota> adjuntos;
  final void Function(AdjuntoNota adjunto, AccionAdjunto accion) onAccion;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < adjuntos.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _TarjetaAdjunto(
              theme: theme,
              notaId: notaId,
              adjunto: adjuntos[i],
              esPrimero: i == 0,
              esUltimo: i == adjuntos.length - 1,
              onAccion: (accion) => onAccion(adjuntos[i], accion),
            ),
          ),
      ],
    );
  }
}

class _TarjetaAdjunto extends StatelessWidget {
  const _TarjetaAdjunto({
    required this.theme,
    required this.notaId,
    required this.adjunto,
    required this.esPrimero,
    required this.esUltimo,
    required this.onAccion,
  });

  final BibleReaderThemeData theme;
  final String notaId;
  final AdjuntoNota adjunto;
  final bool esPrimero;
  final bool esUltimo;
  final ValueChanged<AccionAdjunto> onAccion;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    final esFoto = adjunto.tipo == TipoAdjunto.foto;
    final nombre = esFoto ? 'Foto' : 'Dibujo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: adjunto.pie.isEmpty ? '$nombre. Toca para verlo' : '$nombre: ${adjunto.pie}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: () => onAccion(AccionAdjunto.ver),
                    child: Center(
                      child: VistaAdjunto(
                        notaId: notaId,
                        adjunto: adjunto,
                        theme: t,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Row(
                      children: [
                        _EstadoNube(notaId: notaId, archivo: adjunto.archivo),
                        const SizedBox(width: 6),
                        _MenuAdjunto(
                          esFoto: esFoto,
                          esPrimero: esPrimero,
                          esUltimo: esUltimo,
                          onAccion: onAccion,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        InkWell(
          onTap: () => onAccion(AccionAdjunto.pie),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 2),
            child: Text(
              adjunto.pie.isEmpty ? 'Agregar pie de foto' : adjunto.pie,
              style: TextStyle(
                color: adjunto.pie.isEmpty
                    ? t.textSecondary.withValues(alpha: 0.75)
                    : t.textSecondary,
                fontSize: 13,
                fontStyle: adjunto.pie.isEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EstadoNube extends StatelessWidget {
  const _EstadoNube({required this.notaId, required this.archivo});

  final String notaId;
  final String archivo;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, EstadoNube>>(
      valueListenable: AdjuntosNotaService.I.estados,
      builder: (context, _, _) {
        final estado = AdjuntosNotaService.I.estadoDe(notaId, archivo);
        if (estado == EstadoNube.enNube) return const SizedBox.shrink();
        final subiendo = estado == EstadoNube.subiendo;
        return Tooltip(
          message: subiendo ? 'Subiendo a la nube' : 'Guardado en el teléfono; se subirá con conexión',
          child: _Burbuja(
            child: subiendo
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.cloud_upload_outlined, size: 16, color: Colors.white),
          ),
        );
      },
    );
  }
}

class _Burbuja extends StatelessWidget {
  const _Burbuja({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: const BoxDecoration(
        color: Color(0x992B2622),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

class _MenuAdjunto extends StatelessWidget {
  const _MenuAdjunto({
    required this.esFoto,
    required this.esPrimero,
    required this.esUltimo,
    required this.onAccion,
  });

  final bool esFoto;
  final bool esPrimero;
  final bool esUltimo;
  final ValueChanged<AccionAdjunto> onAccion;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AccionAdjunto>(
      tooltip: 'Opciones',
      onSelected: onAccion,
      itemBuilder: (_) => [
        _item(AccionAdjunto.ver, Icons.open_in_full_rounded, 'Ver'),
        _item(
          AccionAdjunto.editar,
          esFoto ? Icons.draw_rounded : Icons.edit_rounded,
          esFoto ? 'Marcar la foto' : 'Editar dibujo',
        ),
        _item(AccionAdjunto.pie, Icons.short_text_rounded, 'Pie de foto'),
        if (!esPrimero) _item(AccionAdjunto.subir, Icons.arrow_upward_rounded, 'Mover arriba'),
        if (!esUltimo) _item(AccionAdjunto.bajar, Icons.arrow_downward_rounded, 'Mover abajo'),
        _item(AccionAdjunto.quitar, Icons.delete_outline_rounded, 'Quitar'),
      ],
      child: const _Burbuja(
        child: Icon(Icons.more_horiz_rounded, size: 16, color: Colors.white),
      ),
    );
  }

  PopupMenuItem<AccionAdjunto> _item(AccionAdjunto a, IconData icono, String texto) {
    return PopupMenuItem(
      value: a,
      child: Row(
        children: [Icon(icono, size: 20), const SizedBox(width: 12), Text(texto)],
      ),
    );
  }
}

/// Visor a pantalla completa con zoom, para leer de cerca una foto o un
/// dibujo. Devuelve la acción elegida (editar o quitar), si hubo.
class VisorAdjunto extends StatelessWidget {
  const VisorAdjunto({
    super.key,
    required this.notaId,
    required this.adjunto,
    required this.theme,
  });

  final String notaId;
  final AdjuntoNota adjunto;
  final BibleReaderThemeData theme;

  static Future<AccionAdjunto?> abrir(
    BuildContext context, {
    required String notaId,
    required AdjuntoNota adjunto,
    required BibleReaderThemeData theme,
  }) {
    return Navigator.push<AccionAdjunto>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => VisorAdjunto(notaId: notaId, adjunto: adjunto, theme: theme),
      ),
    );
  }

  Future<void> _compartir(BuildContext context) async {
    final imagen = await imagenDeAdjunto(notaId, adjunto);
    if (imagen == null) return;
    final (bytes, extension) = imagen;
    final dir = await getTemporaryDirectory();
    final archivo = File('${dir.path}/apunte_${adjunto.id}.$extension');
    await archivo.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([
      XFile(archivo.path, mimeType: extension == 'jpg' ? 'image/jpeg' : 'image/png'),
    ], text: adjunto.pie.isEmpty ? null : adjunto.pie);
  }

  @override
  Widget build(BuildContext context) {
    final esFoto = adjunto.tipo == TipoAdjunto.foto;
    return Scaffold(
      backgroundColor: const Color(0xFF14110F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14110F),
        foregroundColor: Colors.white,
        title: Text(
          adjunto.pie.isEmpty ? (esFoto ? 'Foto' : 'Dibujo') : adjunto.pie,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Compartir',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _compartir(context),
          ),
          IconButton(
            tooltip: esFoto ? 'Marcar la foto' : 'Editar dibujo',
            icon: Icon(esFoto ? Icons.draw_rounded : Icons.edit_rounded),
            onPressed: () => Navigator.pop(context, AccionAdjunto.editar),
          ),
          IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => Navigator.pop(context, AccionAdjunto.quitar),
          ),
        ],
      ),
      body: SafeArea(
        child: InteractiveViewer(
          maxScale: 6,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: VistaAdjunto(notaId: notaId, adjunto: adjunto, theme: theme),
            ),
          ),
        ),
      ),
    );
  }
}
