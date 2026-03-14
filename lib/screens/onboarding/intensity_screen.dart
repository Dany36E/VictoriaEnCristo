import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/onboarding_service.dart';
import '../../services/audio_engine.dart';
import '../../repositories/profile_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PANTALLA 3: INTENSIDAD Y CIERRE
/// El usuario selecciona la frecuencia de lucha y ve la animación de confirmación
/// ═══════════════════════════════════════════════════════════════════════════

class IntensityScreen extends StatefulWidget {
  final List<String> selectedGiants;
  
  const IntensityScreen({
    super.key,
    required this.selectedGiants,
  });

  @override
  State<IntensityScreen> createState() => _IntensityScreenState();
}

class _IntensityScreenState extends State<IntensityScreen>
    with TickerProviderStateMixin {
  
  String? _selectedIntensity;
  bool _showConfirmation = false;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  late AnimationController _confirmationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _glowAnimation;

  // Opciones de intensidad
  static const List<Map<String, dynamic>> _intensities = [
    {
      'id': 'daily',
      'emoji': '🔥',
      'label': 'DIARIO',
      'subtitle': 'Lucho con esto todos los días',
      'color': Color(0xFFEF4444), // Red
    },
    {
      'id': 'weekly',
      'emoji': '🟡',
      'label': 'SEMANAL',
      'subtitle': 'Me afecta varias veces por semana',
      'color': Color(0xFFF59E0B), // Amber
    },
    {
      'id': 'occasional',
      'emoji': '🟢',
      'label': 'OCASIONAL',
      'subtitle': 'Es algo que aparece de vez en cuando',
      'color': Color(0xFF22C55E), // Green
    },
  ];

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _fadeController.forward();
    });
  }

  void _setupAnimations() {
    // Animación de entrada
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: Curves.easeOut,
      ),
    );

    // Animación de confirmación
    _confirmationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 50,
      ),
    ]).animate(_confirmationController);

    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.1).animate(
      CurvedAnimation(
        parent: _confirmationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _confirmationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  void _selectIntensity(String id) {
    HapticFeedback.lightImpact();
    AudioEngine.I.playSelect();
    setState(() {
      _selectedIntensity = id;
    });
  }

  void _completeOnboarding() {
    if (_selectedIntensity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecciona una frecuencia',
            style: GoogleFonts.manrope(fontWeight: FontWeight.w500),
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

    HapticFeedback.heavyImpact();
    AudioEngine.I.playConfirm();
    
    setState(() {
      _showConfirmation = true;
    });
    
    _confirmationController.forward();

    // Navegar después de la animación
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _saveAndNavigate();
      }
    });
  }

  Future<void> _saveAndNavigate() async {
    // PRIORIDAD: Guardar datos EN CLOUD, luego volver a la raíz
    debugPrint('🚀 OnboardingComplete: Iniciando guardado de gigantes/frecuencia...');
    
    try {
      // Guardar usando OnboardingService (local + cloud) CON TIMEOUT
      final onboardingService = OnboardingService();
      
      // Timeout de 5 segundos para init + guardado
      await Future.any([
        _persistOnboardingData(onboardingService),
        Future.delayed(const Duration(seconds: 5), () {
          throw TimeoutException('Timeout guardando onboarding');
        }),
      ]);
      
      debugPrint('✅ OnboardingComplete: Datos guardados correctamente');
    } on TimeoutException catch (e) {
      debugPrint('⚠️ OnboardingComplete: Timeout guardando datos (continuando): $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado lento, pero continuamos...'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ OnboardingComplete: Error guardando (continuando): $e');
    }
    
    // Volver a la raíz: ProfileGate escucha profileNotifier y detectará
    // que onboardingCompleted=true → transicionará a HomeScreen
    if (!mounted) return;
    
    // Forzar reconexión al ProfileRepository para asegurar que el
    // profileNotifier se actualizó correctamente antes de pop
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      try {
        await ProfileRepository.I.connectUser(uid);
      } catch (_) {}
    }
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!mounted) return;
    debugPrint('🏠 OnboardingComplete: Volviendo a ProfileGate...');
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
  
  /// Persiste los datos del onboarding (separado para permitir timeout)
  Future<void> _persistOnboardingData(OnboardingService service) async {
    await service.init();
    await service.completeOnboarding(
      giants: widget.selectedGiants,
      intensity: _selectedIntensity!,
    );
    debugPrint('📝 OnboardingComplete: giants=${widget.selectedGiants}, intensity=$_selectedIntensity');
  }

  @override
  Widget build(BuildContext context) {
    if (_showConfirmation) {
      return _buildConfirmationView();
    }
    
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
                  
                  const SizedBox(height: 32),
                  
                  // ═══════════════════════════════════════════════════════════════
                  // TÍTULO Y SUBTÍTULO
                  // ═══════════════════════════════════════════════════════════════
                  _buildTitleSection(),
                  
                  const SizedBox(height: 40),
                  
                  // ═══════════════════════════════════════════════════════════════
                  // OPCIONES DE INTENSIDAD
                  // ═══════════════════════════════════════════════════════════════
                  Expanded(
                    child: _buildIntensityOptions(),
                  ),
                  
                  // ═══════════════════════════════════════════════════════════════
                  // BOTÓN FINALIZAR
                  // ═══════════════════════════════════════════════════════════════
                  _buildFinishButton(),
                  
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
                final newState = !isBgmEnabled;
                final success = await AudioEngine.I.setBgmEnabled(newState);
                
                // Si intentó activar pero falló, mostrar feedback
                if (newState && !success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No se pudo cargar la música',
                        style: GoogleFonts.manrope(fontWeight: FontWeight.w500),
                      ),
                      backgroundColor: Colors.red.shade700,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
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
                  'Paso 2 de 2',
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
          
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 1.0,
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
              '¿CON QUÉ FRECUENCIA?',
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
            '¿Qué tan seguido enfrentas esta batalla?\nEsto nos ayuda a personalizar tu plan.',
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

  Widget _buildIntensityOptions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _intensities.asMap().entries.map((entry) {
          final index = entry.key;
          final intensity = entry.value;
          
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 150)),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(30 * (1 - value), 0),
                child: Opacity(
                  opacity: value,
                  child: child,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildIntensityCard(intensity),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIntensityCard(Map<String, dynamic> intensity) {
    final bool isSelected = _selectedIntensity == intensity['id'];
    final Color intensityColor = intensity['color'] as Color;
    
    return GestureDetector(
      onTap: () => _selectIntensity(intensity['id']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? intensityColor.withOpacity(0.15)
              : AppDesignSystem.midnightLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? intensityColor.withOpacity(0.7)
                : AppDesignSystem.pureWhite.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: intensityColor.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Emoji
            Text(
              intensity['emoji'],
              style: const TextStyle(fontSize: 32),
            ),
            
            const SizedBox(width: 16),
            
            // Texto
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    intensity['label'],
                    style: GoogleFonts.cinzel(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? intensityColor
                          : AppDesignSystem.pureWhite.withOpacity(0.9),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    intensity['subtitle'],
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: isSelected
                          ? AppDesignSystem.pureWhite.withOpacity(0.85)
                          : AppDesignSystem.pureWhite.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? intensityColor : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? intensityColor
                      : AppDesignSystem.pureWhite.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinishButton() {
    final bool hasSelection = _selectedIntensity != null;
    
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
            onTap: _completeOnboarding,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shield_rounded,
                    color: hasSelection
                        ? AppDesignSystem.midnight
                        : AppDesignSystem.pureWhite.withOpacity(0.5),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '¡PREPARAR MI ARSENAL!',
                    style: GoogleFonts.cinzel(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: hasSelection
                          ? AppDesignSystem.midnight
                          : AppDesignSystem.pureWhite.withOpacity(0.5),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// ═══════════════════════════════════════════════════════════════════════════
  /// VISTA DE CONFIRMACIÓN CON ANIMACIÓN
  /// ═══════════════════════════════════════════════════════════════════════════
  Widget _buildConfirmationView() {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      body: AnimatedBuilder(
        animation: _confirmationController,
        builder: (context, child) {
          return Stack(
            children: [
              // Glow de fondo
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 0.8 * _glowAnimation.value + 0.3,
                      colors: [
                        AppDesignSystem.gold.withOpacity(0.3 * _glowAnimation.value),
                        AppDesignSystem.gold.withOpacity(0.1 * _glowAnimation.value),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.4, 1.0],
                    ),
                  ),
                ),
              ),
              
              // Contenido central
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icono con animación
                    Transform.scale(
                      scale: _scaleAnimation.value,
                      child: Transform.rotate(
                        angle: _rotationAnimation.value,
                        child: Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppDesignSystem.goldShimmer,
                            boxShadow: [
                              BoxShadow(
                                color: AppDesignSystem.gold.withOpacity(0.5 * _glowAnimation.value),
                                blurRadius: 40,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '⚔️',
                              style: TextStyle(fontSize: 60),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Título
                    Opacity(
                      opacity: _glowAnimation.value,
                      child: ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [
                            AppDesignSystem.gold,
                            AppDesignSystem.goldLight,
                            AppDesignSystem.gold,
                          ],
                        ).createShader(bounds),
                        child: Text(
                          '¡TU ARSENAL\nESTÁ LISTO!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.cinzel(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            height: 1.2,
                            letterSpacing: 3,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Subtítulo
                    Opacity(
                      opacity: _glowAnimation.value,
                      child: Text(
                        'Hemos preparado tu plan de batalla\npersonalizado.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.manrope(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: AppDesignSystem.pureWhite.withOpacity(0.8),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
