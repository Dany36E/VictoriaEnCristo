import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/bible/bosquejo_sermon.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/bosquejo_export_service.dart';
import '../../theme/app_fonts.dart';
import '../../theme/bible_reader_theme.dart';

/// Una página del Modo púlpito: introducción, un punto, la ilustración o la
/// conclusión.
class PaginaPulpito {
  /// «Introducción», «Punto 2 de 5», «Ilustración», «Conclusión».
  final String etiqueta;
  final String titulo;
  final String texto;
  final List<VersiculoBosquejo> versiculos;

  /// Subpuntos con su letra («a. …») y sus versículos.
  final List<(String, List<VersiculoBosquejo>)> subpuntos;

  const PaginaPulpito({
    required this.etiqueta,
    required this.titulo,
    this.texto = '',
    this.versiculos = const [],
    this.subpuntos = const [],
  });

  /// Las páginas en orden: introducción (con el texto principal), cada
  /// punto, ilustración y conclusión. Las secciones vacías no salen.
  static List<PaginaPulpito> de(BosquejoSermon b) {
    final paginas = <PaginaPulpito>[];
    if (b.introduccion.trim().isNotEmpty ||
        b.textoPrincipal.trim().isNotEmpty) {
      paginas.add(
        PaginaPulpito(
          etiqueta: 'Introducción',
          titulo: b.tituloVisible,
          texto: [
            if (b.textoPrincipal.trim().isNotEmpty)
              'Texto: ${b.textoPrincipal.trim()}',
            if (b.introduccion.trim().isNotEmpty) b.introduccion.trim(),
          ].join('\n\n'),
        ),
      );
    }
    final total = b.puntos.length;
    for (var i = 0; i < total; i++) {
      final p = b.puntos[i];
      paginas.add(
        PaginaPulpito(
          etiqueta: 'Punto ${i + 1} de $total',
          titulo: p.titulo.trim().isEmpty ? 'Punto ${i + 1}' : p.titulo.trim(),
          texto: p.notas.trim(),
          versiculos: p.versiculos,
          subpuntos: [
            for (var j = 0; j < p.subpuntos.length; j++)
              (
                '${BosquejoExportService.letraSubpunto(j)}. '
                    '${p.subpuntos[j].texto.trim()}',
                p.subpuntos[j].versiculos,
              ),
          ],
        ),
      );
    }
    if (b.ilustracion.trim().isNotEmpty) {
      paginas.add(
        PaginaPulpito(
          etiqueta: 'Ilustración',
          titulo: 'Ilustración',
          texto: b.ilustracion.trim(),
        ),
      );
    }
    if (b.conclusion.trim().isNotEmpty) {
      paginas.add(
        PaginaPulpito(
          etiqueta: 'Conclusión',
          titulo: 'Conclusión',
          texto: b.conclusion.trim(),
        ),
      );
    }
    return paginas;
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MODO PÚLPITO — el bosquejo a pantalla completa, con letra grande, una
/// página por punto. Se pasa con los botones o deslizando.
/// ═══════════════════════════════════════════════════════════════════════════
class ModoPulpitoScreen extends StatefulWidget {
  const ModoPulpitoScreen({super.key, required this.bosquejo});

  final BosquejoSermon bosquejo;

  @override
  State<ModoPulpitoScreen> createState() => _ModoPulpitoScreenState();
}

class _ModoPulpitoScreenState extends State<ModoPulpitoScreen> {
  final _paginador = PageController();
  late final List<PaginaPulpito> _paginas = PaginaPulpito.de(widget.bosquejo);
  int _actual = 0;

  /// Tamaño base de la letra; se agranda o achica con A− / A+ (y además
  /// respeta el tamaño de texto del teléfono).
  double _tamano = 24;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _paginador.dispose();
    super.dispose();
  }

  void _ir(int pagina) {
    if (pagina < 0 || pagina >= _paginas.length) return;
    HapticFeedback.selectionClick();
    _paginador.animateToPage(
      pagina,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: BibleUserDataService.I.readerThemeNotifier,
      builder: (_, themeId, _) {
        final t = BibleReaderThemeData.fromId(
          BibleReaderThemeData.migrateId(themeId),
        );
        return Scaffold(
          backgroundColor: t.background,
          body: SafeArea(
            child: Column(
              children: [
                _barraSuperior(t),
                Expanded(
                  child: _paginas.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Text(
                              'Este bosquejo todavía no tiene puntos ni '
                              'introducción.',
                              textAlign: TextAlign.center,
                              style: AppFonts.manrope(
                                color: t.textPrimary,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        )
                      : PageView.builder(
                          controller: _paginador,
                          itemCount: _paginas.length,
                          onPageChanged: (i) => setState(() => _actual = i),
                          itemBuilder: (_, i) => _pagina(t, _paginas[i]),
                        ),
                ),
                if (_paginas.isNotEmpty) _barraInferior(t),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barraSuperior(BibleReaderThemeData t) {
    final etiqueta = _paginas.isEmpty ? '' : _paginas[_actual].etiqueta;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Salir del Modo púlpito',
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.close_rounded, color: t.textPrimary),
          ),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                etiqueta,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppFonts.manrope(
                  color: t.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Letra más chica',
            onPressed: _tamano <= 16
                ? null
                : () => setState(() => _tamano -= 2),
            icon: Icon(Icons.text_decrease_rounded, color: t.textPrimary),
          ),
          IconButton(
            tooltip: 'Letra más grande',
            onPressed: _tamano >= 40
                ? null
                : () => setState(() => _tamano += 2),
            icon: Icon(Icons.text_increase_rounded, color: t.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _pagina(BibleReaderThemeData t, PaginaPulpito p) {
    final cuerpo = AppFonts.lora(
      color: t.textPrimary,
      fontSize: _tamano,
      height: 1.45,
    );
    Widget versiculo(VersiculoBosquejo v) => Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: t.accent, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v.referencia,
            style: AppFonts.manrope(
              color: t.textPrimary,
              fontSize: _tamano * 0.75,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (v.texto.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(v.texto.trim(), style: cuerpo),
          ],
        ],
      ),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              p.titulo,
              style: AppFonts.cinzel(
                color: t.textPrimary,
                fontSize: _tamano * 1.3,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (p.texto.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(p.texto, style: cuerpo),
          ],
          for (final v in p.versiculos) versiculo(v),
          for (final (texto, versiculos) in p.subpuntos) ...[
            const SizedBox(height: 18),
            Text(
              texto,
              style: cuerpo.copyWith(fontWeight: FontWeight.w700),
            ),
            for (final v in versiculos) versiculo(v),
          ],
        ],
      ),
    );
  }

  Widget _barraInferior(BibleReaderThemeData t) {
    final hayAnterior = _actual > 0;
    final haySiguiente = _actual < _paginas.length - 1;
    Widget boton({
      required String texto,
      required IconData icono,
      required bool activo,
      required VoidCallback onTap,
      bool principal = false,
    }) {
      final fondo = principal ? t.accent : t.surface;
      final frente = principal ? t.sobreAcento : t.textPrimary;
      return Expanded(
        child: Semantics(
          button: true,
          enabled: activo,
          label: texto,
          excludeSemantics: true,
          child: Opacity(
            opacity: activo ? 1 : 0.45,
            child: Material(
              color: fondo,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: activo ? onTap : null,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 64),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icono, color: frente),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              texto,
                              style: AppFonts.manrope(
                                color: frente,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          boton(
            texto: 'Anterior',
            icono: Icons.chevron_left_rounded,
            activo: hayAnterior,
            onTap: () => _ir(_actual - 1),
          ),
          const SizedBox(width: 12),
          boton(
            texto: 'Siguiente',
            icono: Icons.chevron_right_rounded,
            activo: haySiguiente,
            onTap: () => _ir(_actual + 1),
            principal: true,
          ),
        ],
      ),
    );
  }
}
