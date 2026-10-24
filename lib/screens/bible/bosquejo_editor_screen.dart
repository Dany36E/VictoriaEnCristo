import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bible_book.dart';
import '../../models/bible/bosquejo_sermon.dart';
import '../../services/bible/bible_download_service.dart';
import '../../services/bible/bible_parser_service.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bosquejo_export_service.dart';
import '../../services/bible/bosquejo_sermon_service.dart';
import '../../services/bible/notas_sync.dart';
import '../../services/bible/sermon_reference_parser.dart';
import '../../services/user_scoped_services.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';
import 'bosquejos_screen.dart' show BotonBosquejo;
import 'modo_pulpito_screen.dart';

enum _AccionExportar { pdfCompartir, pdfGuardar, markdown }

/// ═══════════════════════════════════════════════════════════════════════════
/// BOSQUEJO EDITOR — Bosquejo de sermón
///
/// Título, texto principal, introducción, puntos y subpuntos (se reordenan
/// arrastrando), versículos vinculados a cada uno, ilustración y conclusión.
/// Se guarda solo (en el teléfono primero) mientras se escribe y al salir.
/// ═══════════════════════════════════════════════════════════════════════════
class BosquejoEditorScreen extends StatefulWidget {
  const BosquejoEditorScreen({super.key, this.bosquejoId});

  /// Bosquejo a editar; null para uno nuevo.
  final String? bosquejoId;

  @override
  State<BosquejoEditorScreen> createState() => _BosquejoEditorScreenState();
}

class _BosquejoEditorScreenState extends State<BosquejoEditorScreen> {
  late BosquejoSermon _b;
  final Map<String, TextEditingController> _ctrls = {};
  Timer? _debounce;
  String? _huellaGuardada;
  late final Future<void> _listo;

  @override
  void initState() {
    super.initState();
    final existente = BosquejoSermonService.I.porId(widget.bosquejoId);
    _b = existente ?? BosquejoSermon.nuevo(id: widget.bosquejoId);
    _huellaGuardada = existente?.huellaContenido;
    // Guardar espera a que el servicio tenga la sesión lista: nada de lo que
    // se escriba antes se pierde.
    _listo = UserScopedServices.I.ensureSermonNotes().catchError((Object e) {
      debugPrint('[BOSQUEJOS] No se pudo preparar la sesión: $e');
    });
  }

  @override
  void dispose() {
    _guardarYa();
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Estado y guardado ─────────────────────────────────────────────────

  TextEditingController _c(String clave, String inicial) =>
      _ctrls.putIfAbsent(clave, () => TextEditingController(text: inicial));

  void _soltarControladores(String prefijo) {
    final claves = _ctrls.keys.where((k) => k.startsWith(prefijo)).toList();
    for (final k in claves) {
      final c = _ctrls.remove(k);
      // Se liberan después del cuadro: el campo todavía puede estar montado.
      WidgetsBinding.instance.addPostFrameCallback((_) => c?.dispose());
    }
  }

  /// Cambio que redibuja (agregar, quitar, mover).
  void _cambiar(BosquejoSermon nuevo) {
    setState(() => _b = nuevo);
    _programarGuardado();
  }

  /// Cambio de texto: el campo ya muestra lo escrito, no hace falta redibujar
  /// toda la pantalla.
  void _cambiarTexto(BosquejoSermon nuevo) {
    _b = nuevo;
    final estabaEsperando = _debounce != null;
    _programarGuardado();
    if (!estabaEsperando && mounted) setState(() {});
  }

  void _editarPunto(String id, PuntoBosquejo Function(PuntoBosquejo) f) {
    for (final p in _b.puntos) {
      if (p.id == id) {
        _cambiarTexto(_b.conPunto(f(p)));
        return;
      }
    }
  }

  void _programarGuardado() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 700), () {
      _debounce = null;
      _guardarYa();
      if (mounted) setState(() {});
    });
  }

  /// Guarda ahora (en el teléfono; la subida sigue sola).
  void _guardarYa() {
    _debounce?.cancel();
    _debounce = null;
    final b = _b;
    if (!b.hasContent) return;
    final huella = b.huellaContenido;
    if (huella == _huellaGuardada) return;
    _huellaGuardada = huella;
    unawaited(_listo.then((_) => BosquejoSermonService.I.guardar(b)));
  }

  // ── Puntos y subpuntos ────────────────────────────────────────────────

  void _agregarPunto() {
    HapticFeedback.selectionClick();
    _cambiar(_b.copyWith(puntos: [..._b.puntos, PuntoBosquejo.nuevo()]));
  }

  Future<void> _quitarPunto(PuntoBosquejo p) async {
    if (p.hasContent && !await _confirmar('¿Quitar este punto y sus subpuntos?')) {
      return;
    }
    _soltarControladores('p:${p.id}');
    for (final s in p.subpuntos) {
      _soltarControladores('s:${s.id}');
    }
    _cambiar(
      _b.copyWith(puntos: [for (final x in _b.puntos) if (x.id != p.id) x]),
    );
  }

  void _moverPunto(int indice, int delta) {
    final destino = indice + delta;
    if (destino < 0 || destino >= _b.puntos.length) return;
    // Semántica de ReorderableListView: al bajar, se cuenta el elemento.
    _cambiar(_b.reordenarPunto(indice, delta > 0 ? destino + 1 : destino));
  }

  void _agregarSubpunto(PuntoBosquejo p) {
    HapticFeedback.selectionClick();
    final actual = _b.puntos.firstWhere((x) => x.id == p.id);
    _cambiar(
      _b.conPunto(
        actual.copyWith(
          subpuntos: [...actual.subpuntos, SubpuntoBosquejo.nuevo()],
        ),
      ),
    );
  }

  void _quitarSubpunto(String puntoId, SubpuntoBosquejo s) {
    final actual = _b.puntos.firstWhere((x) => x.id == puntoId);
    _soltarControladores('s:${s.id}');
    _cambiar(
      _b.conPunto(
        actual.copyWith(
          subpuntos: [for (final x in actual.subpuntos) if (x.id != s.id) x],
        ),
      ),
    );
  }

  void _editarSubpunto(String puntoId, String subId, String texto) {
    _editarPunto(
      puntoId,
      (p) => p.copyWith(
        subpuntos: [
          for (final s in p.subpuntos) s.id == subId ? s.copyWith(texto: texto) : s,
        ],
      ),
    );
  }

  // ── Versículos ────────────────────────────────────────────────────────

  Future<void> _vincular(String puntoId, {String? subpuntoId}) async {
    final v = await _pedirVersiculo();
    if (v == null || !mounted) return;
    final p = _b.puntos.firstWhere((x) => x.id == puntoId);
    if (subpuntoId == null) {
      _cambiar(_b.conPunto(p.copyWith(versiculos: [...p.versiculos, v])));
    } else {
      _cambiar(
        _b.conPunto(
          p.copyWith(
            subpuntos: [
              for (final s in p.subpuntos)
                s.id == subpuntoId
                    ? s.copyWith(versiculos: [...s.versiculos, v])
                    : s,
            ],
          ),
        ),
      );
    }
  }

  void _quitarVersiculo(String puntoId, VersiculoBosquejo v, {String? subId}) {
    final p = _b.puntos.firstWhere((x) => x.id == puntoId);
    List<VersiculoBosquejo> sin(List<VersiculoBosquejo> l) => [
      for (final x in l)
        if (!identical(x, v)) x,
    ];
    _cambiar(
      _b.conPunto(
        subId == null
            ? p.copyWith(versiculos: sin(p.versiculos))
            : p.copyWith(
                subpuntos: [
                  for (final s in p.subpuntos)
                    s.id == subId ? s.copyWith(versiculos: sin(s.versiculos)) : s,
                ],
              ),
      ),
    );
  }

  /// Pide una cita («Juan 3:16-18»), la reconoce y trae el texto de la
  /// Biblia descargada. Sin el texto, la cita se guarda igual.
  Future<VersiculoBosquejo?> _pedirVersiculo() async {
    final version = BibleDownloadService.I.bestAvailableVersion(
      BibleUserDataService.I.preferredVersionNotifier.value,
    );
    final libros = await BibleParserService.I
        .getBooks(version)
        .catchError((Object _) => <BibleBook>[]);
    if (!mounted) return null;
    final t = _tema();
    final controller = TextEditingController();
    String? error;
    final cita = await showDialog<DetectedSermonReference>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) {
          void aceptar() {
            final encontradas = detectSermonReferences(controller.text, libros);
            if (encontradas.isEmpty) {
              setDialog(
                () => error = libros.isEmpty
                    ? 'No se pudo abrir la Biblia en este teléfono.'
                    : 'Escribe una cita como «Juan 3:16» o «Rom 8:28-30».',
              );
              return;
            }
            Navigator.pop(ctx, encontradas.first);
          }

          return AlertDialog(
            backgroundColor: t.surface,
            title: Text(
              'Vincular versículo',
              style: AppFonts.manrope(
                color: t.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              style: AppFonts.manrope(color: t.textPrimary, fontSize: 15),
              decoration: _decoracion(t, 'Ej. Juan 3:16-18').copyWith(
                errorText: error,
              ),
              onSubmitted: (_) => aceptar(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: AppFonts.manrope(color: t.textSecondary),
                ),
              ),
              TextButton(
                onPressed: aceptar,
                child: Text(
                  'Vincular',
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (cita == null) return null;

    var texto = '';
    try {
      final versos = await BibleParserService.I.getChapter(
        version: version,
        bookNumber: cita.book.number,
        chapter: cita.chapter,
      );
      final rango = versos
          .where((v) => v.verse >= cita.startVerse && v.verse <= cita.endVerse)
          .toList();
      texto = rango.length == 1
          ? rango.first.text
          : rango.map((v) => '${v.verse} ${v.text}').join(' ');
    } catch (e) {
      debugPrint('[BOSQUEJOS] No se pudo leer ${cita.label}: $e');
    }
    if (texto.isEmpty && mounted) {
      _aviso('Se vinculó ${cita.label}, pero su texto no está en el teléfono.');
    }
    return VersiculoBosquejo(
      referencia: cita.label,
      bookNumber: cita.book.number,
      chapter: cita.chapter,
      verseStart: cita.startVerse,
      verseEnd: cita.endVerse,
      versionId: version.id,
      texto: texto,
    );
  }

  // ── Acciones ──────────────────────────────────────────────────────────

  Future<void> _exportar(_AccionExportar accion) async {
    _guardarYa();
    if (!_b.hasContent) {
      _aviso('Escribe algo antes de exportar el bosquejo.');
      return;
    }
    try {
      switch (accion) {
        case _AccionExportar.pdfCompartir:
          await BosquejoExportService.I.compartirPdf(_b);
        case _AccionExportar.pdfGuardar:
          final archivo = await BosquejoExportService.I.exportarPdf(
            _b,
            guardarEnDescargas: true,
          );
          _aviso('PDF guardado: ${archivo.path}');
        case _AccionExportar.markdown:
          await BosquejoExportService.I.compartirMarkdown(_b);
      }
    } catch (e) {
      _aviso('No se pudo exportar el bosquejo: $e');
    }
  }

  Future<void> _abrirPulpito() async {
    _guardarYa();
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ModoPulpitoScreen(bosquejo: _b),
      ),
    );
  }

  Future<bool> _confirmar(String pregunta) async {
    final t = _tema();
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: t.surface,
            content: Text(
              pregunta,
              style: AppFonts.manrope(color: t.textPrimary, fontSize: 15),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Cancelar',
                  style: AppFonts.manrope(color: t.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Quitar',
                  style: AppFonts.manrope(color: const Color(0xFFC0392B)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _aviso(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto), behavior: SnackBarBehavior.floating),
    );
  }

  BibleReaderThemeData _tema() => BibleReaderThemeData.fromId(
    BibleReaderThemeData.migrateId(
      BibleUserDataService.I.readerThemeNotifier.value,
    ),
  );

  // ── Interfaz ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (_, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
        SystemChrome.setSystemUIOverlayStyle(
          t.oscuro ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        );
        return PopScope(
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) _guardarYa();
          },
          child: Scaffold(
            backgroundColor: t.pageBg,
            body: SafeArea(
              child: Column(
                children: [
                  _encabezado(t),
                  Expanded(child: _cuerpo(t)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _encabezado(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Volver',
                onPressed: () => Navigator.maybePop(context),
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: t.textSecondary,
                  size: 18,
                ),
              ),
              Expanded(
                child: Text(
                  'Bosquejo de sermón',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppFonts.cinzel(
                    color: t.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Modo púlpito',
                onPressed: _abrirPulpito,
                icon: Icon(Icons.slideshow_rounded, color: t.accent),
              ),
              PopupMenuButton<_AccionExportar>(
                tooltip: 'Exportar',
                color: t.surface,
                icon: Icon(Icons.ios_share_rounded, color: t.textSecondary),
                onSelected: _exportar,
                itemBuilder: (_) => [
                  _opcion(t, _AccionExportar.pdfCompartir, Icons.picture_as_pdf_outlined, 'Compartir PDF'),
                  _opcion(t, _AccionExportar.pdfGuardar, Icons.download_outlined, 'Guardar PDF'),
                  _opcion(t, _AccionExportar.markdown, Icons.notes_rounded, 'Compartir como texto (Markdown)'),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _EstadoGuardado(
              theme: t,
              vacio: !_b.hasContent,
              guardando: _debounce != null,
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<_AccionExportar> _opcion(
    BibleReaderThemeData t,
    _AccionExportar valor,
    IconData icono,
    String texto,
  ) {
    return PopupMenuItem(
      value: valor,
      child: Row(
        children: [
          Icon(icono, size: 20, color: t.textSecondary),
          const SizedBox(width: 12),
          Flexible(
            child: Text(texto, style: AppFonts.manrope(color: t.textPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _cuerpo(BibleReaderThemeData t) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(
            children: [
              _campo(
                t,
                clave: 'titulo',
                inicial: _b.titulo,
                pista: 'Título del sermón',
                etiqueta: 'Título',
                grande: true,
                alCambiar: (v) => _cambiarTexto(_b.copyWith(titulo: v)),
              ),
              const SizedBox(height: 12),
              _campo(
                t,
                clave: 'texto',
                inicial: _b.textoPrincipal,
                pista: 'Ej. Juan 3:16-18',
                etiqueta: 'Texto principal',
                alCambiar: (v) => _cambiarTexto(_b.copyWith(textoPrincipal: v)),
              ),
              const SizedBox(height: 12),
              _campo(
                t,
                clave: 'intro',
                inicial: _b.introduccion,
                pista: 'Cómo vas a abrir el mensaje',
                etiqueta: 'Introducción',
                lineas: 3,
                alCambiar: (v) => _cambiarTexto(_b.copyWith(introduccion: v)),
              ),
              const SizedBox(height: 20),
              _tituloSeccion(t, 'Puntos'),
              if (_b.puntos.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Text(
                    'Arrastra el ícono ⠿ para cambiar el orden.',
                    style: AppFonts.manrope(
                      color: t.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverReorderableList(
            itemCount: _b.puntos.length,
            onReorder: (viejo, nuevo) {
              HapticFeedback.selectionClick();
              _cambiar(_b.reordenarPunto(viejo, nuevo));
            },
            proxyDecorator: (child, _, _) =>
                Material(type: MaterialType.transparency, child: child),
            itemBuilder: (_, i) => _tarjetaPunto(t, i, _b.puntos[i]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
          sliver: SliverList.list(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: BotonBosquejo(
                  theme: t,
                  icono: Icons.add_rounded,
                  texto: 'Agregar punto',
                  onTap: _agregarPunto,
                ),
              ),
              const SizedBox(height: 24),
              _campo(
                t,
                clave: 'ilustracion',
                inicial: _b.ilustracion,
                pista: 'Una historia o ejemplo que aclare el mensaje',
                etiqueta: 'Ilustración',
                lineas: 3,
                alCambiar: (v) => _cambiarTexto(_b.copyWith(ilustracion: v)),
              ),
              const SizedBox(height: 12),
              _campo(
                t,
                clave: 'conclusion',
                inicial: _b.conclusion,
                pista: 'Cierre, llamado o aplicación',
                etiqueta: 'Conclusión',
                lineas: 3,
                alCambiar: (v) => _cambiarTexto(_b.copyWith(conclusion: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tarjetaPunto(BibleReaderThemeData t, int i, PuntoBosquejo p) {
    return Padding(
      key: ValueKey('punto_${p.id}'),
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.textSecondary.withValues(alpha: 0.16)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Asa(theme: t, indice: i, etiqueta: 'punto ${i + 1}'),
                Expanded(
                  child: Text(
                    'Punto ${i + 1}',
                    style: AppFonts.manrope(
                      color: t.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Opciones del punto ${i + 1}',
                  color: t.surface,
                  icon: Icon(Icons.more_vert, color: t.textSecondary),
                  onSelected: (accion) {
                    switch (accion) {
                      case 'subir':
                        _moverPunto(i, -1);
                      case 'bajar':
                        _moverPunto(i, 1);
                      case 'versiculo':
                        _vincular(p.id);
                      case 'quitar':
                        _quitarPunto(p);
                    }
                  },
                  itemBuilder: (_) => [
                    if (i > 0) _texto(t, 'subir', 'Mover arriba'),
                    if (i < _b.puntos.length - 1)
                      _texto(t, 'bajar', 'Mover abajo'),
                    _texto(t, 'versiculo', 'Vincular versículo'),
                    _texto(t, 'quitar', 'Quitar punto'),
                  ],
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _campo(
                    t,
                    clave: 'p:${p.id}:titulo',
                    inicial: p.titulo,
                    pista: 'Idea del punto',
                    etiqueta: 'Título del punto ${i + 1}',
                    negrita: true,
                    alCambiar: (v) =>
                        _editarPunto(p.id, (x) => x.copyWith(titulo: v)),
                  ),
                  const SizedBox(height: 8),
                  _campo(
                    t,
                    clave: 'p:${p.id}:notas',
                    inicial: p.notas,
                    pista: 'Explicación (opcional)',
                    etiqueta: 'Explicación del punto ${i + 1}',
                    lineas: 2,
                    alCambiar: (v) =>
                        _editarPunto(p.id, (x) => x.copyWith(notas: v)),
                  ),
                  for (final v in p.versiculos)
                    _TarjetaVersiculo(
                      theme: t,
                      versiculo: v,
                      onQuitar: () => _quitarVersiculo(p.id, v),
                    ),
                  if (p.subpuntos.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      buildDefaultDragHandles: false,
                      onReorder: (viejo, nuevo) {
                        HapticFeedback.selectionClick();
                        _cambiar(_b.reordenarSubpunto(p.id, viejo, nuevo));
                      },
                      children: [
                        for (var j = 0; j < p.subpuntos.length; j++)
                          _filaSubpunto(t, p, j, p.subpuntos[j]),
                      ],
                    ),
                  ],
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _BotonTexto(
                        theme: t,
                        icono: Icons.subdirectory_arrow_right_rounded,
                        texto: 'Subpunto',
                        onTap: () => _agregarSubpunto(p),
                      ),
                      _BotonTexto(
                        theme: t,
                        icono: Icons.menu_book_outlined,
                        texto: 'Vincular versículo',
                        onTap: () => _vincular(p.id),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filaSubpunto(
    BibleReaderThemeData t,
    PuntoBosquejo p,
    int j,
    SubpuntoBosquejo s,
  ) {
    final letra = BosquejoExportService.letraSubpunto(j);
    return Padding(
      key: ValueKey('sub_${s.id}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _Asa(theme: t, indice: j, etiqueta: 'subpunto $letra'),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  '$letra.',
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Expanded(
                child: _campo(
                  t,
                  clave: 's:${s.id}',
                  inicial: s.texto,
                  pista: 'Subpunto',
                  etiqueta: 'Subpunto $letra',
                  alCambiar: (v) => _editarSubpunto(p.id, s.id, v),
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Opciones del subpunto $letra',
                color: t.surface,
                icon: Icon(Icons.more_vert, color: t.textSecondary),
                onSelected: (accion) {
                  if (accion == 'versiculo') _vincular(p.id, subpuntoId: s.id);
                  if (accion == 'quitar') _quitarSubpunto(p.id, s);
                },
                itemBuilder: (_) => [
                  _texto(t, 'versiculo', 'Vincular versículo'),
                  _texto(t, 'quitar', 'Quitar subpunto'),
                ],
              ),
            ],
          ),
          for (final v in s.versiculos)
            Padding(
              padding: const EdgeInsets.only(left: 48),
              child: _TarjetaVersiculo(
                theme: t,
                versiculo: v,
                onQuitar: () => _quitarVersiculo(p.id, v, subId: s.id),
              ),
            ),
        ],
      ),
    );
  }

  PopupMenuItem<String> _texto(BibleReaderThemeData t, String valor, String texto) =>
      PopupMenuItem(
        value: valor,
        child: Text(texto, style: AppFonts.manrope(color: t.textPrimary)),
      );

  Widget _tituloSeccion(BibleReaderThemeData t, String texto) => Semantics(
    header: true,
    child: Text(
      texto,
      style: AppFonts.cinzel(
        color: t.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _campo(
    BibleReaderThemeData t, {
    required String clave,
    required String inicial,
    required String pista,
    required String etiqueta,
    required ValueChanged<String> alCambiar,
    int lineas = 1,
    bool grande = false,
    bool negrita = false,
  }) {
    return TextField(
      controller: _c(clave, inicial),
      onChanged: alCambiar,
      minLines: lineas,
      maxLines: null,
      textCapitalization: TextCapitalization.sentences,
      style: grande
          ? AppFonts.cinzel(
              color: t.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            )
          : AppFonts.lora(
              color: t.textPrimary,
              fontSize: 15,
              height: 1.45,
              fontWeight: negrita ? FontWeight.w700 : FontWeight.w400,
            ),
      decoration: _decoracion(t, pista).copyWith(
        labelText: etiqueta,
        labelStyle: AppFonts.manrope(color: t.textSecondary, fontSize: 13),
      ),
    );
  }
}

InputDecoration _decoracion(BibleReaderThemeData t, String pista) {
  final borde = OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: t.textSecondary.withValues(alpha: 0.18)),
  );
  return InputDecoration(
    hintText: pista,
    hintStyle: AppFonts.manrope(color: t.textoAtenuado(), fontSize: 13),
    filled: true,
    fillColor: t.background,
    border: borde,
    enabledBorder: borde,
    focusedBorder: borde.copyWith(
      borderSide: BorderSide(color: t.accent.withValues(alpha: 0.7)),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

/// Asa para arrastrar un punto o subpunto (48×48).
class _Asa extends StatelessWidget {
  const _Asa({required this.theme, required this.indice, required this.etiqueta});

  final BibleReaderThemeData theme;
  final int indice;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    return ReorderableDragStartListener(
      index: indice,
      child: Semantics(
        label: 'Arrastrar para mover el $etiqueta',
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.drag_indicator_rounded, color: theme.textSecondary),
        ),
      ),
    );
  }
}

class _TarjetaVersiculo extends StatelessWidget {
  const _TarjetaVersiculo({
    required this.theme,
    required this.versiculo,
    required this.onQuitar,
  });

  final BibleReaderThemeData theme;
  final VersiculoBosquejo versiculo;
  final VoidCallback onQuitar;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(12, 4, 0, 10),
      decoration: BoxDecoration(
        color: t.background,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: t.accent, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${versiculo.referencia} · ${versiculo.versionId}',
                  style: AppFonts.manrope(
                    color: t.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar ${versiculo.referencia}',
                onPressed: onQuitar,
                icon: Icon(Icons.close_rounded, color: t.textSecondary, size: 18),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              versiculo.texto.trim().isEmpty
                  ? 'Texto no disponible en este teléfono.'
                  : versiculo.texto.trim(),
              style: AppFonts.lora(
                color: t.textPrimary,
                fontSize: 14,
                height: 1.5,
                fontStyle: versiculo.texto.trim().isEmpty
                    ? FontStyle.italic
                    : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonTexto extends StatelessWidget {
  const _BotonTexto({
    required this.theme,
    required this.icono,
    required this.texto,
    required this.onTap,
  });

  final BibleReaderThemeData theme;
  final IconData icono;
  final String texto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: t.textPrimary,
      ),
      icon: Icon(icono, size: 18, color: t.accent),
      label: Text(
        texto,
        style: AppFonts.manrope(
          color: t.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Estado del guardado: en el teléfono primero, la nube después.
class _EstadoGuardado extends StatelessWidget {
  const _EstadoGuardado({
    required this.theme,
    required this.vacio,
    required this.guardando,
  });

  final BibleReaderThemeData theme;
  final bool vacio;
  final bool guardando;

  @override
  Widget build(BuildContext context) {
    final t = theme;
    return ValueListenableBuilder<EstadoNotasNube>(
      valueListenable: NotasSync.I.estado,
      builder: (_, estado, _) {
        final texto = vacio
            ? 'Borrador vacío: escribe algo para guardarlo'
            : guardando
            ? 'Guardando en el teléfono…'
            : etiquetaEstadoNotas(estado);
        final enNube =
            !vacio &&
            !guardando &&
            (estado == EstadoNotasNube.alDia ||
                estado == EstadoNotasNube.subiendo);
        return Semantics(
          liveRegion: true,
          child: Row(
            children: [
              Icon(
                vacio
                    ? Icons.edit_note_rounded
                    : enNube
                    ? Icons.cloud_done_outlined
                    : Icons.phone_android_rounded,
                size: 16,
                color: t.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  texto,
                  style: AppFonts.manrope(
                    color: t.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
