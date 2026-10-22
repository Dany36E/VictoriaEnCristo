import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';
import '../data/bible_verses.dart';
import '../utils/share_utils.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import 'compartir/tarjeta_compartir_papel.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// SHARE VERSE MODAL - Modal de Previsualización y Compartir
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// Muestra una previsualización de la Quote Card estética antes de compartir.
/// Genera una imagen PNG lista para redes sociales (Instagram Stories/WhatsApp).
/// ═══════════════════════════════════════════════════════════════════════════════

class ShareVerseModal extends StatefulWidget {
  final BibleVerse verse;
  final Color? accentColor;

  const ShareVerseModal({
    super.key,
    required this.verse,
    this.accentColor,
  });

  /// Método estático para mostrar el modal
  static Future<void> show(BuildContext context, BibleVerse verse, {Color? accentColor}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVerseModal(
        verse: verse,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<ShareVerseModal> createState() => _ShareVerseModalState();
}

class _ShareVerseModalState extends State<ShareVerseModal> {
  final GlobalKey _quoteCardKey = GlobalKey();
  bool _isGenerating = false;
  int _selectedFormat = 0; // 0 = 1:1 (Square), 1 = 4:5 (Portrait)

  // Colores del Design System


  @override
  Widget build(BuildContext context) {
    return _buildPapel(context);
  }

  /// Hoja crema con la tarjeta de papel recortado del kit.
  Widget _buildPapel(BuildContext context) {
    final proporcion = _selectedFormat == 0 ? 1.0 : 0.8;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: VecColores.crema,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            22,
            12,
            22,
            MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  // Gris del kit: el crema oscuro casi no se veía sobre la
                  // hoja (contraste de más de 3:1, como pide WCAG 1.4.11).
                  color: VecColores.gris,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const CirculoIcono(icono: Icons.share_rounded, tamano: 42),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: TituloVec(
                      'Compartir versículo',
                      clave: 'versículo',
                      tamano: 24,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: VecColores.tinta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final (i, etiqueta) in [
                    (0, 'Cuadrado 1:1'),
                    (1, 'Vertical 4:5'),
                  ]) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: _selectedFormat == i,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFormat = i),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _selectedFormat == i
                                  ? VecColores.terracota
                                  : VecColores.papel,
                              borderRadius: BorderRadius.circular(
                                VecRadios.pildora,
                              ),
                              boxShadow: VecSombras.chip,
                            ),
                            child: Text(
                              etiqueta,
                              style: TextStyle(
                                fontFamily: VecFuentes.titulo,
                                fontSize: 16,
                                color: _selectedFormat == i
                                    ? VecColores.papel
                                    : VecColores.tinta,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 18),
              // Se captura dentro del FittedBox: la imagen sale de 1080 px
              // de ancho aunque la vista previa sea más chica. El borde de
              // lápiz y la sombra marcan dónde termina la imagen sobre la
              // hoja (no salen en ella).
              Container(
                decoration: BoxDecoration(boxShadow: VecSombras.papel),
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: VecColores.lapiz, width: 1.5),
                ),
                child: FittedBox(
                  child: RepaintBoundary(
                    key: _quoteCardKey,
                    child: TarjetaCompartirPapel(
                      texto: widget.verse.verse,
                      referencia: widget.verse.reference,
                      etiqueta: 'Versículo',
                      proporcion: proporcion,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BotonVec(
                texto: 'Descargar imagen',
                icono: Icons.download_rounded,
                cargando: _isGenerating,
                expandido: true,
                onPressed: _shareAsImage,
              ),
              const SizedBox(height: 12),
              BotonVec(
                texto: 'Copiar solo texto',
                icono: Icons.copy_rounded,
                color: VecColores.papel,
                colorTexto: VecColores.tinta,
                expandido: true,
                onPressed: _copyText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Genera la imagen y la descarga
  Future<void> _shareAsImage() async {
    if (_isGenerating) return;
    
    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();
    
    try {
      // Esperar para asegurar que el widget esté renderizado completamente
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Capturar el widget como imagen
      final boundary = _quoteCardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('No se encontró el widget para capturar');
      }
      
      // Renderizar a alta resolución (3x para calidad)
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception('Error al convertir la imagen');
      }
      
      final bytes = byteData.buffer.asUint8List();
      final fileName = 'VictoriaEnCristo_${DateTime.now().millisecondsSinceEpoch}.png';
      
      // Compartir/descargar según la plataforma
      final success = await ShareUtils.shareImage(bytes, fileName);
      
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          _showSuccessSnackbar('Imagen lista ✓');
        }
      }
    } catch (e) {
      debugPrint('Error al generar imagen: $e');
      _showErrorSnackbar('Error al generar. Intenta de nuevo.');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// Copia solo el texto del versículo
  void _copyText() {
    HapticFeedback.mediumImpact();
    final text = '"${widget.verse.verse}"\n\n— ${widget.verse.reference}\n\n✝️ Victoria en Cristo App';
    Clipboard.setData(ClipboardData(text: text));
    Navigator.pop(context);
    _showSuccessSnackbar('Texto copiado al portapapeles');
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              message,
              style: AppFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: VecColores.verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              message,
              style: AppFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUOTE CARD - Imagen Estética para Redes Sociales
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════════


// ═══════════════════════════════════════════════════════════════════════════════
// PAINTER: CAMPO DE ESTRELLAS
// ═══════════════════════════════════════════════════════════════════════════════
