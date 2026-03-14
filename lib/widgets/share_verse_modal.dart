import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/bible_verses.dart';
import '../utils/share_utils.dart';

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
  static const Color _darkBg = Color(0xFF0A0E14);
  static const Color _goldAccent = Color(0xFFD4A853);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.85,
      ),
      decoration: const BoxDecoration(
        color: _darkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══════════════════════════════════════════════════════════════
            // HANDLE BAR
            // ═══════════════════════════════════════════════════════════════
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // ═══════════════════════════════════════════════════════════════
            // HEADER
            // ═══════════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _goldAccent.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.share_rounded,
                      color: _goldAccent,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Compartir Versículo',
                          style: GoogleFonts.manrope(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Descarga la imagen para compartir',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white54,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            
            // ═══════════════════════════════════════════════════════════════
            // FORMAT SELECTOR
            // ═══════════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _FormatChip(
                    label: '1:1',
                    subtitle: 'Cuadrado',
                    isSelected: _selectedFormat == 0,
                    onTap: () => setState(() => _selectedFormat = 0),
                  ),
                  const SizedBox(width: 12),
                  _FormatChip(
                    label: '4:5',
                    subtitle: 'Vertical',
                    isSelected: _selectedFormat == 1,
                    onTap: () => setState(() => _selectedFormat = 1),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // ═══════════════════════════════════════════════════════════════
            // QUOTE CARD PREVIEW
            // ═══════════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _goldAccent.withOpacity(0.15),
                      blurRadius: 30,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: RepaintBoundary(
                    key: _quoteCardKey,
                    child: _QuoteCard(
                      verse: widget.verse,
                      accentColor: widget.accentColor ?? _goldAccent,
                      aspectRatio: _selectedFormat == 0 ? 1.0 : 0.8,
                    ),
                  ),
                ),
              ),
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutCubic),
            
            const SizedBox(height: 24),
            
            // ═══════════════════════════════════════════════════════════════
            // ACTION BUTTONS
            // ═══════════════════════════════════════════════════════════════
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Column(
                children: [
                  // Botón principal: Descargar Imagen
                  _PrimaryShareButton(
                    isLoading: _isGenerating,
                    label: 'Descargar Imagen',
                    icon: Icons.download_rounded,
                    onTap: _shareAsImage,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Botón secundario: Copiar solo texto
                  _SecondaryButton(
                    icon: Icons.copy_rounded,
                    label: 'Copiar solo texto',
                    onTap: _copyText,
                  ),
                ],
              ),
            ),
            
            // Safe area bottom
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
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
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        backgroundColor: _goldAccent,
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
              style: GoogleFonts.manrope(fontWeight: FontWeight.w600),
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
class _QuoteCard extends StatelessWidget {
  final BibleVerse verse;
  final Color accentColor;
  final double aspectRatio;

  const _QuoteCard({
    required this.verse,
    required this.accentColor,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D1B2A),
              Color(0xFF0A0E14),
              Color(0xFF1A2D42),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Fondo de estrellas
            Positioned.fill(
              child: CustomPaint(
                painter: _StarfieldPainter(),
              ),
            ),
            
            // Decoración: círculos
            Positioned(
              top: -50,
              right: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      accentColor.withOpacity(0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Contenido principal
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // Comillas
                  Icon(
                    Icons.format_quote_rounded,
                    color: accentColor.withOpacity(0.4),
                    size: 48,
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Versículo
                  Text(
                    verse.verse,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.crimsonPro(
                      fontSize: _calculateFontSize(verse.verse.length),
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: Colors.white,
                      height: 1.5,
                      letterSpacing: 0.3,
                    ),
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Línea decorativa
                  Container(
                    width: 60,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.3),
                          accentColor,
                          accentColor.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Referencia
                  Text(
                    verse.reference,
                    style: GoogleFonts.cinzel(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                      letterSpacing: 2,
                    ),
                  ),
                  
                  const Spacer(flex: 3),
                  
                  // Branding
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.church_rounded,
                        color: Colors.white.withOpacity(0.4),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Victoria en Cristo',
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.4),
                          letterSpacing: 1,
                        ),
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

  double _calculateFontSize(int length) {
    if (length < 80) return 22;
    if (length < 150) return 19;
    if (length < 250) return 17;
    return 15;
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGETS AUXILIARES
// ═══════════════════════════════════════════════════════════════════════════════

class _FormatChip extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatChip({
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFD4A853).withOpacity(0.15)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFD4A853)
                : Colors.white.withOpacity(0.1),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: isSelected ? 28 : 35,
              decoration: BoxDecoration(
                color: isSelected 
                    ? const Color(0xFFD4A853).withOpacity(0.3)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? const Color(0xFFD4A853) : Colors.white70,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 11,
                    color: Colors.white38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryShareButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryShareButton({
    required this.isLoading,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFD4A853), Color(0xFFE8C97A)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD4A853).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            else
              Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Generando...' : label,
              style: GoogleFonts.manrope(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTER: CAMPO DE ESTRELLAS
// ═══════════════════════════════════════════════════════════════════════════════
class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (int i = 0; i < 80; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;
      final opacity = random.nextDouble() * 0.4 + 0.1;
      
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
