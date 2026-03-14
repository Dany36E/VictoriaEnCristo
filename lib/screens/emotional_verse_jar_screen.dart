import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/bible_verses.dart';
import '../widgets/share_verse_modal.dart';
import '../services/favorites_service.dart';
import '../services/feedback_engine.dart';

/// ═══════════════════════════════════════════════════════════════════════════════
/// EMOTIONAL VERSE JAR - Experiencia Inmersiva
/// ═══════════════════════════════════════════════════════════════════════════════
/// 
/// Concepto: Digitalizar la experiencia de un "Frasco de la Calma"
/// El usuario selecciona su emoción y recibe un versículo mediante
/// una animación de "papel desdoblándose"
/// ═══════════════════════════════════════════════════════════════════════════════

class EmotionalVerseJarScreen extends StatefulWidget {
  const EmotionalVerseJarScreen({super.key});

  @override
  State<EmotionalVerseJarScreen> createState() => _EmotionalVerseJarScreenState();
}

class _EmotionalVerseJarScreenState extends State<EmotionalVerseJarScreen>
    with TickerProviderStateMixin {
  
  // Estados de la experiencia
  bool _isRevealing = false;
  bool _showVerse = false;
  EmotionData? _selectedEmotion;
  BibleVerse? _revealedVerse;

  // Controladores de animación
  late AnimationController _unfoldController;
  late AnimationController _glowController;
  late Animation<double> _unfoldAnimation;
  late Animation<double> _glowAnimation;

  // Definición de emociones
  final List<EmotionData> _emotions = [
    EmotionData(
      id: 'feliz',
      name: 'Feliz',
      label: 'PARA LA ALEGRÍA',
      icon: Icons.wb_sunny_rounded,
      color: const Color(0xFFFFD700), // Amarillo Ámbar
      darkColor: const Color(0xFFB8860B),
    ),
    EmotionData(
      id: 'ansioso',
      name: 'Ansioso',
      label: 'PARA LA ANSIEDAD',
      icon: Icons.air_rounded,
      color: const Color(0xFF98FF98), // Verde Salvia
      darkColor: const Color(0xFF2E8B57),
    ),
    EmotionData(
      id: 'agradecido',
      name: 'Agradecido',
      label: 'PARA LA GRATITUD',
      icon: Icons.favorite_rounded,
      color: const Color(0xFFFF7F50), // Naranja Coral
      darkColor: const Color(0xFFCD5C5C),
    ),
    EmotionData(
      id: 'solo',
      name: 'Solo',
      label: 'PARA LA SOLEDAD',
      icon: Icons.cloud_rounded,
      color: const Color(0xFF87CEEB), // Azul Cielo
      darkColor: const Color(0xFF4682B4),
    ),
    EmotionData(
      id: 'enojado',
      name: 'Enojado',
      label: 'PARA LA IRA',
      icon: Icons.flash_on_rounded,
      color: const Color(0xFFFF6B6B), // Rosa/Rojo Suave
      darkColor: const Color(0xFFDC143C),
    ),
    EmotionData(
      id: 'triste',
      name: 'Triste',
      label: 'PARA LA TRISTEZA',
      icon: Icons.water_drop_rounded,
      color: const Color(0xFF6A5ACD), // Azul Índigo
      darkColor: const Color(0xFF483D8B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    // Animación de despliegue del papel
    _unfoldController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _unfoldAnimation = CurvedAnimation(
      parent: _unfoldController,
      curve: Curves.easeInOutCubic,
    );

    // Animación de glow pulsante
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _unfoldController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _selectEmotion(EmotionData emotion) async {
    FeedbackEngine.I.select();  // Haptic + SFX select (selección de emoción)
    
    setState(() {
      _selectedEmotion = emotion;
      _isRevealing = true;
    });

    // Esperar a que las otras emociones se desvanezcan
    await Future.delayed(const Duration(milliseconds: 400));
    
    // Obtener versículo aleatorio
    _revealedVerse = BibleVerses.getRandomVerseByCategory(emotion.id);
    
    // Iniciar animación de despliegue
    await _unfoldController.forward();
    
    setState(() {
      _showVerse = true;
    });
    
    FeedbackEngine.I.paper();  // Haptic + SFX paper (efecto papelito)
  }

  void _resetExperience() {
    FeedbackEngine.I.tap();  // Haptic + SFX tap
    
    _unfoldController.reset();
    
    setState(() {
      _isRevealing = false;
      _showVerse = false;
      _selectedEmotion = null;
      _revealedVerse = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E14),
      body: Stack(
        children: [
          // ═══════════════════════════════════════════════════════════════
          // FONDO CON PARTÍCULAS SUTILES
          // ═══════════════════════════════════════════════════════════════
          Positioned.fill(
            child: CustomPaint(
              painter: _StarfieldPainter(),
            ),
          ),
          
          // Gradiente oscuro overlay
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF0A0E14).withOpacity(0.8),
                  ],
                ),
              ),
            ),
          ),

          // ═══════════════════════════════════════════════════════════════
          // CONTENIDO PRINCIPAL
          // ═══════════════════════════════════════════════════════════════
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isRevealing 
                      ? _buildRevealState() 
                      : _buildEmotionGrid(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
          const Spacer(),
          if (!_isRevealing)
            Text(
              'Frasco de Versículos',
              style: GoogleFonts.cinzel(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white60,
                letterSpacing: 1,
              ),
            ),
          const Spacer(),
          const SizedBox(width: 48), // Balance
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO 1: GRID DE EMOCIONES - Diseño Elegante y Compacto
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildEmotionGrid() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          
          // Título empático
          Text(
            '¿Cómo está tu\ncorazón hoy?',
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
              letterSpacing: 1,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: -0.2, end: 0),
          
          const SizedBox(height: 12),
          
          Text(
            'Selecciona cómo te sientes y recibe\nuna palabra de Dios para ti',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.white54,
              height: 1.5,
            ),
          )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms),
          
          const SizedBox(height: 40),
          
          // ═══════════════════════════════════════════════════════════════
          // GRID CENTRADO CON MAX-WIDTH
          // ═══════════════════════════════════════════════════════════════
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.0, // Cuadradas perfectas
                ),
                itemCount: _emotions.length,
                itemBuilder: (context, index) {
                  return _EmotionCard(
                    emotion: _emotions[index],
                    onTap: () => _selectEmotion(_emotions[index]),
                    delay: Duration(milliseconds: 300 + (index * 80)),
                  );
                },
              ),
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO 2: REVELACIÓN DEL VERSÍCULO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildRevealState() {
    if (_selectedEmotion == null) return const SizedBox();
    
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Etiqueta de emoción flotando arriba
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedEmotion!.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: _selectedEmotion!.color.withOpacity(0.5 * _glowAnimation.value),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _selectedEmotion!.color.withOpacity(0.2 * _glowAnimation.value),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _selectedEmotion!.icon,
                        color: _selectedEmotion!.color,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedEmotion!.label,
                        style: GoogleFonts.manrope(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _selectedEmotion!.color,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
            
            const SizedBox(height: 32),
            
            // ═══════════════════════════════════════════════════════════════
            // ANIMACIÓN DE PAPEL DESDOBLÁNDOSE
            // ═══════════════════════════════════════════════════════════════
            AnimatedBuilder(
              animation: _unfoldAnimation,
              builder: (context, child) {
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001) // Perspectiva
                    ..rotateX((1 - _unfoldAnimation.value) * pi / 2),
                  child: Opacity(
                    opacity: _unfoldAnimation.value,
                    child: _buildVerseCard(),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            // Botones de acción
            if (_showVerse) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copiar',
                    color: _selectedEmotion!.color,
                    onTap: () => _copyVerse(),
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: Icons.share_rounded,
                    label: 'Compartir',
                    color: _selectedEmotion!.color,
                    onTap: () => _shareVerse(),
                  ),
                  const SizedBox(width: 16),
                  _ActionButton(
                    icon: _isCurrentVerseFavorite 
                        ? Icons.bookmark_rounded 
                        : Icons.bookmark_outline_rounded,
                    label: _isCurrentVerseFavorite ? 'Guardado' : 'Guardar',
                    color: _selectedEmotion!.color,
                    onTap: () => _saveVerse(),
                    isActive: _isCurrentVerseFavorite,
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),
              
              const SizedBox(height: 32),
              
              // Botón de reinicio
              GestureDetector(
                onTap: _resetExperience,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        color: Colors.white70,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Sacar otro papelito',
                        style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TARJETA DE VERSÍCULO REVELADO
  // ═══════════════════════════════════════════════════════════════════════════
  Widget _buildVerseCard() {
    if (_revealedVerse == null || _selectedEmotion == null) {
      return const SizedBox();
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        // Fondo crema/papel
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(24),
        // Borde brillante del color de la emoción
        border: Border.all(
          color: _selectedEmotion!.color,
          width: 2,
        ),
        boxShadow: [
          // Glow del color de la emoción
          BoxShadow(
            color: _selectedEmotion!.color.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 0,
          ),
          // Sombra suave
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Textura de papel sutil
            Positioned.fill(
              child: CustomPaint(
                painter: _PaperTexturePainter(color: _selectedEmotion!.color),
              ),
            ),
            
            // Contenido
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icono decorativo
                  Icon(
                    Icons.format_quote_rounded,
                    color: _selectedEmotion!.color.withOpacity(0.3),
                    size: 40,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Texto del versículo
                  Text(
                    _revealedVerse!.verse,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.crimsonPro(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                      color: const Color(0xFF1A1A1A),
                      height: 1.6,
                      letterSpacing: 0.3,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Línea decorativa
                  Container(
                    width: 60,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _selectedEmotion!.color.withOpacity(0.3),
                          _selectedEmotion!.color,
                          _selectedEmotion!.color.withOpacity(0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Referencia bíblica
                  Text(
                    _revealedVerse!.reference,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: _selectedEmotion!.darkColor,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES
  // ═══════════════════════════════════════════════════════════════════════════
  void _copyVerse() {
    if (_revealedVerse == null) return;
    HapticFeedback.mediumImpact();
    final text = '"${_revealedVerse!.verse}" — ${_revealedVerse!.reference}';
    Clipboard.setData(ClipboardData(text: text));
    _showSnackBar('Versículo copiado ✓', Icons.check_circle_rounded);
  }

  void _shareVerse() {
    if (_revealedVerse == null || _selectedEmotion == null) return;
    HapticFeedback.mediumImpact();
    // Abrir modal con previsualización usando el color de la emoción
    ShareVerseModal.show(
      context, 
      _revealedVerse!, 
      accentColor: _selectedEmotion!.color,
    );
  }

  void _saveVerse() async {
    if (_revealedVerse == null) return;
    HapticFeedback.mediumImpact();
    
    final favoritesService = FavoritesService();
    final isAlreadyFavorite = favoritesService.isFavorite(_revealedVerse!);
    
    if (isAlreadyFavorite) {
      await favoritesService.removeFavorite(_revealedVerse!);
      _showSnackBar('Eliminado de favoritos', Icons.bookmark_remove_rounded);
    } else {
      await favoritesService.addFavorite(_revealedVerse!);
      _showSnackBar('¡Guardado en favoritos! ♥', Icons.bookmark_added_rounded);
    }
    
    // Actualizar UI para reflejar el cambio de estado
    setState(() {});
  }

  /// Verifica si el versículo actual está en favoritos
  bool get _isCurrentVerseFavorite {
    if (_revealedVerse == null) return false;
    return FavoritesService().isFavorite(_revealedVerse!);
  }

  void _showSnackBar(String message, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              message,
              style: GoogleFonts.manrope(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: _selectedEmotion?.darkColor ?? const Color(0xFF0D1B2A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MODELO DE DATOS DE EMOCIÓN
// ═══════════════════════════════════════════════════════════════════════════════
class EmotionData {
  final String id;
  final String name;
  final String label;
  final IconData icon;
  final Color color;
  final Color darkColor;

  const EmotionData({
    required this.id,
    required this.name,
    required this.label,
    required this.icon,
    required this.color,
    required this.darkColor,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: TARJETA DE EMOCIÓN - Estilo Elegante Glassmorphism
// ═══════════════════════════════════════════════════════════════════════════════
class _EmotionCard extends StatefulWidget {
  final EmotionData emotion;
  final VoidCallback onTap;
  final Duration delay;

  const _EmotionCard({
    required this.emotion,
    required this.onTap,
    required this.delay,
  });

  @override
  State<_EmotionCard> createState() => _EmotionCardState();
}

class _EmotionCardState extends State<_EmotionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            // Fondo con color de la emoción al 10-15% opacidad
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.emotion.color.withOpacity(0.12),
                widget.emotion.color.withOpacity(0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            // Borde brillante del color de la emoción
            border: Border.all(
              color: widget.emotion.color.withOpacity(0.5),
              width: 1.5,
            ),
            // Sombra sutil con el color de la emoción
            boxShadow: [
              BoxShadow(
                color: widget.emotion.color.withOpacity(0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                decoration: BoxDecoration(
                  // Overlay sutil para efecto glass
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ═══════════════════════════════════════════════════════
                    // ICONO CON GLOW RING
                    // ═══════════════════════════════════════════════════════
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: widget.emotion.color.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.emotion.color.withOpacity(0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.emotion.color.withOpacity(0.4),
                            blurRadius: 16,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.emotion.icon,
                        color: widget.emotion.color,
                        size: 28,
                      ),
                    ),
                    
                    const SizedBox(height: 14),
                    
                    // ═══════════════════════════════════════════════════════
                    // NOMBRE DE LA EMOCIÓN
                    // ═══════════════════════════════════════════════════════
                    Text(
                      widget.emotion.name.toUpperCase(),
                      style: GoogleFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withOpacity(0.9),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    )
        .animate()
        .fadeIn(delay: widget.delay, duration: 500.ms)
        .scale(
          delay: widget.delay,
          duration: 500.ms,
          begin: const Offset(0.85, 0.85),
          end: const Offset(1, 1),
          curve: Curves.easeOutBack,
        );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// WIDGET: BOTÓN DE ACCIÓN
// ═══════════════════════════════════════════════════════════════════════════════
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isActive ? color.withOpacity(0.3) : color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? color : color.withOpacity(0.3),
                width: isActive ? 2 : 1,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.manrope(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTER: CAMPO DE ESTRELLAS SUTIL
// ═══════════════════════════════════════════════════════════════════════════════
class _StarfieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(42);
    final paint = Paint()..style = PaintingStyle.fill;
    
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5 + 0.5;
      final opacity = random.nextDouble() * 0.3 + 0.1;
      
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTER: TEXTURA DE PAPEL SUTIL
// ═══════════════════════════════════════════════════════════════════════════════
class _PaperTexturePainter extends CustomPainter {
  final Color color;
  
  _PaperTexturePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(123);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withOpacity(0.03);
    
    // Puntos sutiles de textura
    for (int i = 0; i < 200; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 2 + 1;
      
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
    
    // Gradiente decorativo en esquina
    final gradientPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topRight,
        radius: 0.8,
        colors: [
          color.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), gradientPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
