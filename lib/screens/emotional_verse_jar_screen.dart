import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../data/bible_verses.dart';
import '../widgets/share_verse_modal.dart';
import '../services/favorites_service.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

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
    with SingleTickerProviderStateMixin {
  
  // Estados de la experiencia
  bool _isRevealing = false;
  bool _showVerse = false;
  EmotionData? _selectedEmotion;
  BibleVerse? _revealedVerse;

  // Controladores de animación
  late AnimationController _unfoldController;
  late Animation<double> _unfoldAnimation;

  // Definición de emociones
  final List<EmotionData> _emotions = [
    const EmotionData(
      id: 'feliz',
      name: 'Feliz',
      label: 'PARA LA ALEGRÍA',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFFFD700), // Amarillo Ámbar
      darkColor: Color(0xFFB8860B),
    ),
    const EmotionData(
      id: 'ansioso',
      name: 'Ansioso',
      label: 'PARA LA ANSIEDAD',
      icon: Icons.air_rounded,
      color: Color(0xFF98FF98), // Verde Salvia
      darkColor: Color(0xFF2E8B57),
    ),
    const EmotionData(
      id: 'agradecido',
      name: 'Agradecido',
      label: 'PARA LA GRATITUD',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF7F50), // Naranja Coral
      darkColor: Color(0xFFCD5C5C),
    ),
    const EmotionData(
      id: 'solo',
      name: 'Solo',
      label: 'PARA LA SOLEDAD',
      icon: Icons.cloud_rounded,
      color: Color(0xFF87CEEB), // Azul Cielo
      darkColor: Color(0xFF4682B4),
    ),
    const EmotionData(
      id: 'enojado',
      name: 'Enojado',
      label: 'PARA LA IRA',
      icon: Icons.flash_on_rounded,
      color: Color(0xFFFF6B6B), // Rosa/Rojo Suave
      darkColor: Color(0xFFDC143C),
    ),
    const EmotionData(
      id: 'triste',
      name: 'Triste',
      label: 'PARA LA TRISTEZA',
      icon: Icons.water_drop_rounded,
      color: Color(0xFF6A5ACD), // Azul Índigo
      darkColor: Color(0xFF483D8B),
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
  }

  @override
  void dispose() {
    _unfoldController.dispose();
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
    return _buildPapel();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO 1: GRID DE EMOCIONES - Diseño Elegante y Compacto
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO 2: REVELACIÓN DEL VERSÍCULO
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  // TARJETA DE VERSÍCULO REVELADO
  // ═══════════════════════════════════════════════════════════════════════════

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
            Icon(
              icon,
              color: VecColores.papel,
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              message,
              style: AppFonts.manrope(
                fontWeight: FontWeight.w600,
                color: VecColores.papel,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PAPEL RECORTADO
  // ═══════════════════════════════════════════════════════════════════════════

  /// Color del kit e ícono (SVG del kit o Material relleno) por emoción.
  static Map<String, (Color, String?, IconData)> get _estiloPapel => {
    'feliz': (VecColores.mostaza, 'sol', Icons.wb_sunny_rounded),
    'ansioso': (VecColores.salvia, null, Icons.air_rounded),
    'agradecido': (VecColores.terracota, 'corazon', Icons.favorite_rounded),
    'solo': (VecColores.azulClaro, null, Icons.cloud_rounded),
    'enojado': (VecColores.kraft, null, Icons.flash_on_rounded),
    'triste': (VecColores.noche, null, Icons.water_drop_rounded),
  };

  (Color, String?, IconData) _estilo(EmotionData e) =>
      _estiloPapel[e.id] ?? (VecColores.terracota, null, e.icon);

  Widget _buildPapel() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: _isRevealing ? null : const Text('Frasco de versículos'),
      ),
      body: SafeArea(
        top: false,
        child: _isRevealing ? _buildRevealPapel() : _buildGridPapel(),
      ),
    );
  }

  Widget _buildGridPapel() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 4, 22, 32),
      child: Column(
        children: [
          const PopIn(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Sticker(
                  'assets/vec/personajes/victoria_corazon.png',
                  alto: 130,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Subtitulo(
                    quien: 'Victoria',
                    texto: '¿Cómo está tu corazón hoy?',
                    clave: 'corazón',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Selecciona cómo te sientes y recibe una palabra de Dios para ti',
            textAlign: TextAlign.center,
            style: AppFonts.manrope(fontSize: 17, color: VecColores.gris),
          ),
          const SizedBox(height: 26),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.05,
                ),
                itemCount: _emotions.length,
                itemBuilder: (context, index) {
                  final emotion = _emotions[index];
                  final (color, iconoVec, icono) = _estilo(emotion);
                  return PopIn(
                    retraso: Duration(milliseconds: 60 * index),
                    giroFinal: index.isEven ? -1 : 1,
                    child: Semantics(
                      button: true,
                      label: emotion.name,
                      onTap: () => _selectEmotion(emotion),
                      excludeSemantics: true,
                      child: GestureDetector(
                        onTap: () => _selectEmotion(emotion),
                        child: Container(
                          decoration: AppThemeData.of(context).cardDecoration,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CirculoIcono(
                                iconoVec: iconoVec,
                                icono: icono,
                                color: color,
                                tamano: 62,
                                giro: index.isEven ? -4 : 4,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                emotion.name,
                                style: TextStyle(
                                  fontFamily: VecFuentes.titulo,
                                  fontSize: 20,
                                  color: VecColores.tinta,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevealPapel() {
    final emotion = _selectedEmotion;
    if (emotion == null) return const SizedBox();
    final (color, iconoVec, icono) = _estilo(emotion);
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Column(
          children: [
            PopIn(
              child: ChipVec(
                texto: emotion.label,
                color: color,
                // Sin color propio: el chip les da el de su texto.
                iconoWidget: iconoVec != null
                    ? IconoVec(iconoVec)
                    : Icon(icono, size: 22),
              ),
            ),
            const SizedBox(height: 34),
            // El papelito sale del frasco y se desdobla.
            // La tarjeta se arma dentro del builder: el versículo se asigna
            // después del primer build y no hay setState hasta el final.
            AnimatedBuilder(
              animation: _unfoldAnimation,
              builder: (context, _) {
                final verso = _revealedVerse;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateX((1 - _unfoldAnimation.value) * pi / 2),
                  child: Opacity(
                    opacity: _unfoldAnimation.value,
                    child: verso == null
                        ? const SizedBox()
                        : TarjetaVersiculo(
                            referencia: verso.reference,
                            texto: verso.verse,
                            version: '',
                          ),
                  ),
                );
              },
            ),
            const SizedBox(height: 36),
            if (_showVerse) ...[
              PopIn(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _accionPapel(
                      icono: Icons.copy_rounded,
                      texto: 'Copiar',
                      color: VecColores.azul,
                      onTap: _copyVerse,
                    ),
                    _accionPapel(
                      icono: Icons.share_rounded,
                      texto: 'Compartir',
                      color: VecColores.verde,
                      onTap: _shareVerse,
                    ),
                    _accionPapel(
                      icono: _isCurrentVerseFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_add_rounded,
                      texto: _isCurrentVerseFavorite ? 'Guardado' : 'Guardar',
                      color: VecColores.terracota,
                      onTap: _saveVerse,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              PopIn(
                retraso: const Duration(milliseconds: 150),
                child: BotonVec(
                  texto: 'Sacar otro papelito',
                  icono: Icons.refresh_rounded,
                  color: VecColores.papel,
                  colorTexto: VecColores.tinta,
                  onPressed: _resetExperience,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _accionPapel({
    required IconData icono,
    required String texto,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: texto,
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            CirculoIcono(icono: icono, color: color, tamano: 56),
            const SizedBox(height: 8),
            Text(
              texto,
              style: TextStyle(
                fontFamily: VecFuentes.titulo,
                fontSize: 15,
                color: VecColores.tinta,
              ),
            ),
          ],
        ),
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
                widget.emotion.color.withValues(alpha: 0.12),
                widget.emotion.color.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            // Borde brillante del color de la emoción
            border: Border.all(
              color: widget.emotion.color.withValues(alpha: 0.5),
              width: 1.5,
            ),
            // Sombra sutil con el color de la emoción
            boxShadow: [
              BoxShadow(
                color: widget.emotion.color.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 6),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                decoration: BoxDecoration(
                  // Overlay sutil para efecto glass
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
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
                        color: widget.emotion.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.emotion.color.withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: widget.emotion.color.withValues(alpha: 0.4),
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
                      style: AppFonts.manrope(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white.withValues(alpha: 0.9),
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

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTER: CAMPO DE ESTRELLAS SUTIL
// ═══════════════════════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════════════════════
// PAINTER: TEXTURA DE PAPEL SUTIL
// ═══════════════════════════════════════════════════════════════════════════════
