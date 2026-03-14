import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import 'giant_frequency_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PANTALLA 2: SELECCIÓN DE GIGANTES
/// El usuario selecciona las categorías de luchas/adicciones que enfrenta
/// ═══════════════════════════════════════════════════════════════════════════

class GiantSelectionScreen extends StatefulWidget {
  const GiantSelectionScreen({super.key});

  @override
  State<GiantSelectionScreen> createState() => _GiantSelectionScreenState();
}

class _GiantSelectionScreenState extends State<GiantSelectionScreen>
    with SingleTickerProviderStateMixin {
  
  // Set de gigantes seleccionados
  final Set<String> _selectedGiants = {};
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORES NEUTRALES (ANTISESGO)
  // Todos los gigantes usan el mismo color base para evitar que alguno "grite" más
  // La diferenciación es solo por icono/texto y estado seleccionado (borde dorado)
  // ═══════════════════════════════════════════════════════════════════════════
  static const Color _selectedAccent = Color(0xFFD4AF37); // Dorado (gold)
  
  // Los 6 gigantes principales - COLORES NEUTRALES UNIFORMES
  static const List<Map<String, dynamic>> _giants = [
    {
      'id': 'digital',
      'emoji': '📱',
      'name': 'MUNDO DIGITAL',
      'description': 'Redes sociales, videojuegos, doom scrolling',
    },
    {
      'id': 'sexual',
      'emoji': '🔞',
      'name': 'PUREZA SEXUAL',
      'description': 'Pornografía, lujuria, pensamientos impuros',
    },
    {
      'id': 'health',
      'emoji': '🍬',
      'name': 'CUERPO & SALUD',
      'description': 'Glotonería, desorden alimenticio, sedentarismo',
    },
    {
      'id': 'substances',
      'emoji': '🥃',
      'name': 'SUSTANCIAS',
      'description': 'Alcohol, tabaco, drogas, dependencias',
    },
    {
      'id': 'mental',
      'emoji': '🤯',
      'name': 'BATALLAS MENTALES',
      'description': 'Ansiedad, depresión, pensamientos negativos',
    },
    {
      'id': 'emotions',
      'emoji': '💔',
      'name': 'EMOCIONES TÓXICAS',
      'description': 'Ira, resentimiento, falta de perdón, envidia',
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleGiant(String id) {
    HapticFeedback.lightImpact();
    // SFX de selección - fire and forget
    FeedbackEngine.I.select();  // Haptic + SFX select
    setState(() {
      if (_selectedGiants.contains(id)) {
        _selectedGiants.remove(id);
      } else {
        _selectedGiants.add(id);
      }
    });
  }

  void _navigateToIntensity() {
    if (_selectedGiants.isEmpty) {
      // Mostrar mensaje si no hay selección
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecciona al menos un área de batalla',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: AppDesignSystem.midnightLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    FeedbackEngine.I.confirm();  // Haptic + SFX confirm
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            GiantFrequencyScreen(selectedGiants: _selectedGiants.toList()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.1, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      body: Stack(
        children: [
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // ═══════════════════════════════════════════════════════════════
                  // HEADER CON BARRA DE PROGRESO
                  // ═══════════════════════════════════════════════════════════════
                  _buildHeader(),
                  
                  const SizedBox(height: 24),
                  
                  // ═══════════════════════════════════════════════════════════════
                  // TÍTULO Y SUBTÍTULO
                  // ═══════════════════════════════════════════════════════════════
                  _buildTitleSection(),
                  
                  const SizedBox(height: 32),
                  
                  // ═══════════════════════════════════════════════════════════════
                  // GRID DE GIGANTES
                  // ═══════════════════════════════════════════════════════════════
                  Expanded(
                    child: _buildGiantsGrid(),
                  ),
                  
                  // ═══════════════════════════════════════════════════════════════
                  // BOTÓN CONTINUAR
                  // ═══════════════════════════════════════════════════════════════
                  _buildContinueButton(),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          
          // ═══════════════════════════════════════════════════════════════════
          // BOTÓN DE AUDIO (Toggle música)
          // ═══════════════════════════════════════════════════════════════════
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _buildAudioToggleButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioToggleButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioEngine.I.bgmEnabled,
      builder: (context, isBgmEnabled, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppDesignSystem.midnight.withOpacity(0.8),
            border: Border.all(
              color: isBgmEnabled 
                  ? AppDesignSystem.gold.withOpacity(0.5)
                  : Colors.grey.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () async {
                HapticFeedback.lightImpact();
                await AudioEngine.I.setBgmEnabled(!isBgmEnabled);
              },
              child: Center(
                child: Icon(
                  isBgmEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: isBgmEnabled ? AppDesignSystem.gold : Colors.grey,
                  size: 22,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Botón atrás
              IconButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.pop(context);
                },
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppDesignSystem.pureWhite.withOpacity(0.7),
                ),
              ),
              
              const Spacer(),
              
              // Indicador de paso
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppDesignSystem.gold.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  'Paso 1 de 2',
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppDesignSystem.gold,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Barra de progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.5,
              backgroundColor: AppDesignSystem.midnightLight,
              valueColor: AlwaysStoppedAnimation<Color>(AppDesignSystem.gold),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                AppDesignSystem.gold,
                AppDesignSystem.goldLight,
              ],
            ).createShader(bounds),
            child: Text(
              '¿CUÁL ES TU GIGANTE?',
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 2,
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          Text(
            'Selecciona las áreas donde necesitas más victoria.\nPuedes elegir una o varias.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: AppDesignSystem.pureWhite.withOpacity(0.75),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiantsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GridView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.95,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
        ),
        itemCount: _giants.length,
        itemBuilder: (context, index) {
          return _buildGiantCard(_giants[index], index);
        },
      ),
    );
  }

  Widget _buildGiantCard(Map<String, dynamic> giant, int index) {
    final bool isSelected = _selectedGiants.contains(giant['id']);
    // Color neutral uniforme para todos - antisesgo
    const Color accentColor = _selectedAccent;
    
    // Animación escalonada de entrada
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 400 + (index * 100)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _toggleGiant(giant['id']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          transform: isSelected 
              ? (Matrix4.identity()..scale(1.02)) // Micro-escala al seleccionar
              : Matrix4.identity(),
          decoration: BoxDecoration(
            // Color de fondo uniforme para todos
            color: isSelected
                ? const Color(0xFF1A1A2A) // Ligeramente más claro al seleccionar
                : const Color(0xFF121222), // Fondo base oscuro
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              // Borde dorado solo al seleccionar, gris tenue si no
              color: isSelected
                  ? accentColor
                  : const Color(0xFF2A2A3A),
              width: isSelected ? 2.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [],
          ),
          child: Stack(
            children: [
              // Contenido principal
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji grande
                    Text(
                      giant['emoji'],
                      style: const TextStyle(fontSize: 36),
                    ),
                    
                    const SizedBox(height: 10),
                    
                    // Nombre del gigante - COLOR NEUTRAL UNIFORME
                    Text(
                      giant['name'],
                      style: GoogleFonts.cinzel(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        // Dorado al seleccionar, blanco si no
                        color: isSelected
                            ? accentColor
                            : AppDesignSystem.pureWhite.withOpacity(0.9),
                        letterSpacing: 0.5,
                      ),
                    ),
                    
                    const SizedBox(height: 6),
                    
                    // Descripción
                    Expanded(
                      child: Text(
                        giant['description'],
                        style: GoogleFonts.manrope(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isSelected
                              ? AppDesignSystem.pureWhite.withOpacity(0.9)
                              : AppDesignSystem.pureWhite.withOpacity(0.6),
                          height: 1.4,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Checkmark de selección - DORADO UNIFORME
              if (isSelected)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: accentColor, // Dorado uniforme
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: AppDesignSystem.midnight,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    final bool hasSelection = _selectedGiants.isNotEmpty;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 60,
        decoration: BoxDecoration(
          gradient: hasSelection ? AppDesignSystem.goldShimmer : null,
          color: hasSelection ? null : AppDesignSystem.midnightLight,
          borderRadius: BorderRadius.circular(18),
          boxShadow: hasSelection
              ? [
                  BoxShadow(
                    color: AppDesignSystem.gold.withOpacity(0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _navigateToIntensity,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasSelection
                        ? 'CONTINUAR (${_selectedGiants.length})'
                        : 'SELECCIONA AL MENOS UNO',
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasSelection
                          ? AppDesignSystem.midnight
                          : AppDesignSystem.pureWhite.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                  if (hasSelection) ...[
                    const SizedBox(width: 10),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: AppDesignSystem.midnight,
                      size: 20,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
