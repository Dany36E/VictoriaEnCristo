import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../theme/app_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/bible/bible_verse.dart';
import '../../models/bible/share_template.dart';
import '../../services/bible/bible_user_data_service.dart';
import '../../services/bible/share_cache_service.dart';
import '../../theme/bible_reader_theme.dart';
import '../../theme/contraste.dart';
import '../../vec/vec_tema.dart';
import '../../widgets/bible/share_card_renderer.dart';
import '../../widgets/compartir/tarjeta_compartir_papel.dart';

/// Pantalla rediseñada para compartir versículos como imagen premium.
/// Preview grande arriba + selector horizontal de plantillas + personalización.
class TemplatePickerScreen extends StatefulWidget {
  final BibleVerse verse;
  final int initialTemplateIndex;
  const TemplatePickerScreen({
    super.key,
    required this.verse,
    this.initialTemplateIndex = 0,
  });

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> {
  late int _selectedIndex = widget.initialTemplateIndex;
  double _fontSize = 34;
  int _aspectIndex = 0; // 0=1:1, 1=9:16, 2=4:5
  bool _showLogo = true;
  TextAlign _textAlign = TextAlign.center;
  bool _customOpen = false;
  bool _sharing = false;
  final _repaintKey = GlobalKey();

  static const _aspects = [
    (label: '1:1', w: 1080.0, h: 1080.0),
    (label: '9:16', w: 1080.0, h: 1920.0),
    (label: '4:5', w: 1080.0, h: 1350.0),
  ];

  /// Las plantillas de papel van primero (mismo orden que en la hoja de
  /// acciones del versículo, que pasa el índice inicial).
  List<ShareCardTemplate> get _plantillas => plantillasCompartir();
  ShareCardTemplate get _template => _plantillas[_selectedIndex];
  bool get _papelSeleccionado => _template.layout == ShareLayout.papel;
  Size get _cardSize =>
      Size(_aspects[_aspectIndex].w, _aspects[_aspectIndex].h);

  @override
  Widget build(BuildContext context) {
    final t = BibleReaderThemeData.fromId(
      BibleReaderThemeData.migrateId(
        BibleUserDataService.I.readerThemeNotifier.value,
      ),
    );

    return Scaffold(
      backgroundColor: t.pageBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──
            _buildTopBar(t),

            // ── Preview (expandable) ──
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  // En papel la imagen es papel sobre papel: un borde de lápiz
                  // y su sombra marcan dónde termina (no salen en la imagen).
                  child: Container(
                    decoration: _papelSeleccionado
                        ? BoxDecoration(boxShadow: VecSombras.papel)
                        : null,
                    foregroundDecoration: _papelSeleccionado
                        ? BoxDecoration(
                            border: Border.all(
                              color: VecColores.lapiz,
                              width: 1.5,
                            ),
                          )
                        : null,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: RepaintBoundary(
                        key: _repaintKey,
                        child: ShareCardRenderer(
                          template: _template,
                          verseText: widget.verse.text,
                          reference: widget.verse.reference,
                          version: widget.verse.version,
                          customFontSize: _fontSize,
                          showLogo: _showLogo,
                          textAlign: _textAlign,
                          cardSize: _cardSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom controls ──
            // Hasta 60 % de la pantalla y desplazable: con «Personalizar»
            // abierto y letra grande en un teléfono chico no cabía.
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.6,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: t.surface.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Lo de arriba se desplaza; «Guardar» y «Compartir»
                    // quedan siempre a la vista.
                    Flexible(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 12),
                            // Template selector (horizontal scroll)
                            _buildTemplateSelector(t),
                            // Expandable customization
                            _buildCustomPanel(t),
                          ],
                        ),
                      ),
                    ),
                    // Action buttons
                    _buildActionButtons(t),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Top bar ──
  Widget _buildTopBar(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            tooltip: 'Volver',
            icon: Icon(Icons.arrow_back_ios, color: t.textSecondary, size: 20),
          ),
          const Spacer(),
          Text(
            'COMPARTIR',
            style: AppFonts.cinzel(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
              color: legibleSobre(t.accent, t.fondoVisible),
            ),
          ),
          const Spacer(),
          // Mismo ancho que el botón de volver, para centrar el título.
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  // ── Horizontal template thumbnails ──
  Widget _buildTemplateSelector(BibleReaderThemeData t) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _plantillas.length,
        itemBuilder: (_, i) {
          final tmpl = _plantillas[i];
          final isSelected = i == _selectedIndex;
          return GestureDetector(
            onTap: () => setState(() => _selectedIndex = i),
            child: Container(
              width: 64,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: isSelected
                    ? Border.all(color: t.accent, width: 2.5)
                    : Border.all(
                        color: t.textSecondary.withValues(alpha: 0.15),
                      ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Papel: la tarjeta en miniatura, con su personaje (la
                    // textura sola no dejaba ver la diferencia).
                    if (tmpl.layout == ShareLayout.papel)
                      ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: TarjetaCompartirPapel(
                            texto: widget.verse.text,
                            referencia: widget.verse.reference,
                            proporcion: 0.8,
                            personaje: PersonajeCompartir.dePlantilla(tmpl.id),
                            mostrarMarca: false,
                          ),
                        ),
                      )
                    else if (tmpl.backgroundAsset != null)
                      Image.asset(
                        tmpl.backgroundAsset!,
                        excludeFromSemantics: true,
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (_, _, _) => Container(
                          color: tmpl.isDark
                              ? const Color(0xFF1A1A2E)
                              : const Color(0xFFF5F0E8),
                        ),
                      )
                    else
                      Container(
                        color: tmpl.isDark
                            ? const Color(0xFF1A1A2E)
                            : const Color(0xFFF5F0E8),
                      ),
                    // Name overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 3,
                          horizontal: 2,
                        ),
                        color: Colors.black54,
                        child: Text(
                          tmpl.name,
                          style: AppFonts.manrope(
                            fontSize: 8,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Expandable customization panel ──
  Widget _buildCustomPanel(BibleReaderThemeData t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Toggle header (48 de alto: área táctil mínima).
        Semantics(
          button: true,
          expanded: _customOpen,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _customOpen = !_customOpen),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 16, color: t.textoTenue(0.6)),
                    const SizedBox(width: 8),
                    Text(
                      'Personalizar',
                      style: AppFonts.manrope(
                        fontSize: 13,
                        color: t.textoTenue(0.6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _customOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: 20,
                      color: t.textoTenue(0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Panel content
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Font size slider
                Row(
                  children: [
                    Text(
                      'TAMAÑO',
                      style: AppFonts.manrope(
                        color: t.textoTenue(0.4),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_fontSize.round()}',
                      style: AppFonts.manrope(
                        color: legibleSobre(t.accent, t.fondoVisible),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                SliderTheme(
                  data: SliderThemeData(
                    activeTrackColor: t.accent,
                    inactiveTrackColor: t.textSecondary.withValues(alpha: 0.12),
                    thumbColor: t.accent,
                    overlayColor: t.accent.withValues(alpha: 0.1),
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: _fontSize,
                    min: 34,
                    max: 56,
                    onChanged: (v) => setState(() => _fontSize = v),
                  ),
                ),
                // En papel la letra crece solo hasta llenar la tarjeta: con
                // versículos largos ya la llena y el control no la cambia.
                if (_papelSeleccionado)
                  Text(
                    'Con versículos largos, la letra no pasa del tamaño '
                    'que llena la tarjeta.',
                    style: AppFonts.manrope(
                      color: t.textoTenue(0.5),
                      fontSize: 11,
                    ),
                  ),

                const SizedBox(height: 4),

                // Aspect ratio selector
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A la altura de la primera fila de controles (48).
                    Padding(
                      padding: const EdgeInsets.only(top: 17),
                      child: Text(
                        'PROPORCIÓN',
                        style: AppFonts.manrope(
                          color: t.textoTenue(0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Con letra grande las fichas pasan al renglón de abajo.
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        children: [
                          for (int i = 0; i < _aspects.length; i++)
                            _aspectChip(i, t),
                        ],
                      ),
                    ),
                  ],
                ),

                // Alineación (cada ícono ocupa 48: ya quedan separados).
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // A la altura de la primera fila de controles (48).
                    Padding(
                      padding: const EdgeInsets.only(top: 17),
                      child: Text(
                        'ALINEACIÓN',
                        style: AppFonts.manrope(
                          color: t.textoTenue(0.4),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Con letra grande los íconos pasan al renglón de abajo.
                    Expanded(
                      child: Wrap(
                        children: [
                          _alignIcon(
                            Icons.format_align_left,
                            TextAlign.left,
                            'Alinear a la izquierda',
                            t,
                          ),
                          _alignIcon(
                            Icons.format_align_center,
                            TextAlign.center,
                            'Centrar',
                            t,
                          ),
                          _alignIcon(
                            Icons.format_align_right,
                            TextAlign.right,
                            'Alinear a la derecha',
                            t,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Logo en su propia fila: junto a la alineación no cabía en
                // 360 px, y así el lector de pantalla nombra el interruptor.
                MergeSemantics(
                  child: Row(
                    children: [
                      Text(
                        'Mostrar logo',
                        style: AppFonts.manrope(
                          color: t.textoTenue(0.5),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: _showLogo,
                        onChanged: (v) => setState(() => _showLogo = v),
                        activeThumbColor: t.accent,
                        inactiveTrackColor: t.textSecondary.withValues(
                          alpha: 0.12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          crossFadeState: _customOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    );
  }

  /// Área táctil de 48 alrededor de un control chico, sin cambiar cómo se ve.
  Widget _tocable({
    required Widget child,
    required VoidCallback onTap,
    required bool seleccionado,
    String? etiqueta,
  }) {
    return Semantics(
      button: true,
      selected: seleccionado,
      label: etiqueta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Align(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }

  Widget _aspectChip(int index, BibleReaderThemeData t) {
    final isSelected = _aspectIndex == index;
    return _tocable(
      seleccionado: isSelected,
      onTap: () => setState(() => _aspectIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? t.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: t.accent, width: 1.5)
              : Border.all(color: t.textSecondary.withValues(alpha: 0.15)),
        ),
        child: Text(
          _aspects[index].label,
          style: AppFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? legibleEnPastilla(
                  legibleEnPastilla(t.accent, 0.15, t.fondoVisible),
                  0.15,
                  t.surface,
                )
                : t.textoTenue(0.45),
          ),
        ),
      ),
    );
  }

  Widget _alignIcon(
    IconData icon,
    TextAlign align,
    String etiqueta,
    BibleReaderThemeData t,
  ) {
    final isSelected = _textAlign == align;
    return _tocable(
      seleccionado: isSelected,
      etiqueta: etiqueta,
      onTap: () => setState(() => _textAlign = align),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSelected
              ? t.accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isSelected
              ? Border.all(color: t.accent, width: 1)
              : Border.all(color: t.textSecondary.withValues(alpha: 0.12)),
        ),
        child: Icon(
          icon,
          color: isSelected ? t.accent : t.textoTenue(0.6),
          size: 16,
        ),
      ),
    );
  }

  // ── Action buttons ──
  Widget _buildActionButtons(BibleReaderThemeData t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Row(
        children: [
          // Download button
          Expanded(
            child: SizedBox(
              height: 48, // área táctil mínima
              child: OutlinedButton.icon(
                onPressed: _sharing ? null : _downloadImage,
                icon: const Icon(Icons.download_rounded, size: 18),
                // A 360 px no cabía y quedaba «Gua…».
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Guardar',
                    maxLines: 1,
                    style: AppFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  foregroundColor: legibleSobre(t.accent, t.fondoVisible),
                  side: BorderSide(color: t.accent.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Share button
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 48, // área táctil mínima
              child: ElevatedButton.icon(
                onPressed: _sharing ? null : _shareImage,
                icon: _sharing
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: t.background,
                        ),
                      )
                    : const Icon(Icons.share, size: 18),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Compartir',
                    maxLines: 1,
                    style: AppFonts.manrope(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  // Sin el relleno vertical del tema (16): con él, el texto
                  // salía recortado por abajo.
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  // Acento ajustado para que el texto del color del fondo
                  // se lea encima.
                  backgroundColor: legibleSobre(t.accent, t.background),
                  foregroundColor: t.background,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Image capture ──
  Future<File?> _captureImage() async {
    try {
      final boundary =
          _repaintKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final bytes = byteData.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/victoria_verse_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      return file;
    } catch (e) {
      debugPrint('📖 [SHARE] Error capturing image: $e');
      return null;
    }
  }

  Future<void> _shareImage() async {
    setState(() => _sharing = true);
    try {
      // La caché solo tiene tarjetas con los ajustes de fábrica: si se
      // cambió el tamaño, la alineación o el logo, se captura la vista previa.
      final ajustesDeFabrica =
          _fontSize == 34 && _textAlign == TextAlign.center && _showLogo;
      final cached = ajustesDeFabrica
          ? await ShareCacheService.I.getCachedCard(
              verseKey: widget.verse.uniqueKey,
              templateId: _template.id,
              cardSize: _cardSize,
            )
          : null;
      final file = cached ?? await _captureImage();
      if (file == null) return;
      await Share.shareXFiles([XFile(file.path)], text: 'Victoria en Cristo');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _downloadImage() async {
    final file = await _captureImage();
    if (file == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imagen guardada en: ${file.path}',
          style: AppFonts.manrope(fontSize: 12),
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
