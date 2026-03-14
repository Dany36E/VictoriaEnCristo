import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../models/giant_frequency.dart';
import '../../services/onboarding_service.dart';
import '../../services/feedback_engine.dart';
import '../../repositories/profile_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// GIANT FREQUENCY SCREEN
/// El usuario asigna una frecuencia de lucha a CADA gigante seleccionado
/// ═══════════════════════════════════════════════════════════════════════════

class GiantFrequencyScreen extends StatefulWidget {
  final List<String> selectedGiants;
  
  const GiantFrequencyScreen({
    super.key,
    required this.selectedGiants,
  });

  @override
  State<GiantFrequencyScreen> createState() => _GiantFrequencyScreenState();
}

class _GiantFrequencyScreenState extends State<GiantFrequencyScreen>
    with SingleTickerProviderStateMixin {
  
  // Mapa de frecuencias por gigante
  late Map<String, BattleFrequency?> _frequencies;
  
  // Lista de gigantes con sus datos completos
  late List<GiantWithFrequency> _giants;
  
  // Animación de entrada
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // Estado de guardado
  bool _isSaving = false;
  
  @override
  void initState() {
    super.initState();
    _initializeGiants();
    _setupAnimations();
    
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _animationController.forward();
    });
  }
  
  void _initializeGiants() {
    // Cargar frecuencias existentes (si vuelve a editar)
    final existingFreqs = OnboardingService().loadGiantFrequencies();
    
    _frequencies = {};
    _giants = [];
    
    for (final giantId in widget.selectedGiants) {
      // Buscar frecuencia existente
      final existingFreq = existingFreqs[giantId];
      final frequency = BattleFrequencyExtension.fromId(existingFreq);
      
      _frequencies[giantId] = frequency;
      
      final giant = Giants.fromId(giantId, frequency: frequency);
      if (giant != null) {
        _giants.add(giant);
      }
    }
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
  
  /// ¿Todas las frecuencias están asignadas?
  bool get _isComplete {
    return widget.selectedGiants.every((g) => _frequencies[g] != null);
  }
  
  /// Cantidad de gigantes con frecuencia asignada
  int get _completedCount {
    return _frequencies.values.where((f) => f != null).length;
  }
  
  /// Actualizar frecuencia de un gigante
  void _updateFrequency(String giantId, BattleFrequency frequency) {
    FeedbackEngine.I.select(); // SFX + Haptic al seleccionar
    
    setState(() {
      _frequencies[giantId] = frequency;
      
      // Actualizar lista de gigantes
      final index = _giants.indexWhere((g) => g.id == giantId);
      if (index != -1) {
        _giants[index] = _giants[index].copyWith(frequency: frequency);
      }
    });
  }
  
  /// Guardar y continuar
  Future<void> _saveAndContinue() async {
    if (!_isComplete || _isSaving) return;
    
    FeedbackEngine.I.confirm(); // SFX + Haptic de confirmación
    
    setState(() => _isSaving = true);
    
    try {
      // Convertir Map<String, BattleFrequency?> a Map<String, String>
      final freqMap = <String, String>{};
      for (final entry in _frequencies.entries) {
        if (entry.value != null) {
          freqMap[entry.key] = entry.value!.id;
        }
      }
      
      final success = await OnboardingService().completeOnboardingWithFrequencies(
        giants: widget.selectedGiants,
        frequencies: freqMap,
      );
      
      if (!mounted) return;
      
      if (success) {
        debugPrint('🎯 [FREQ_SCREEN] Save successful, verifying profile state...');
        
        // CRÍTICO: Forzar reconexión al ProfileRepository para asegurar
        // que el profileNotifier se actualizó y el ProfileGate lo detecte.
        // Esto resuelve el caso donde el realtime listener no se disparó a tiempo.
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await ProfileRepository.I.connectUser(uid);
        }
        
        // Pequeña pausa para permitir que el ProfileGate procese
        // el cambio de profileNotifier (setState → _bootstrapAndGoHome)
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Verificar que realmente se guardó correctamente
        final verifiedProfile = ProfileRepository.I.currentProfile;
        if (verifiedProfile != null && verifiedProfile.onboardingCompleted) {
          debugPrint('🎯 [FREQ_SCREEN] ✅ Profile verified: onboardingCompleted=true, popping to root');
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
          debugPrint('🎯 [FREQ_SCREEN] ⚠️ Profile NOT verified after save, forcing pop anyway');
          // Pop anyway - el ProfileGate tiene safety check en build
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        }
      } else {
        _showError('No se pudo guardar. Intenta de nuevo.');
      }
    } catch (e) {
      debugPrint('❌ Error saving: $e');
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            children: [
              // Header
              _buildHeader(),
              
              // Lista de gigantes
              Expanded(
                child: _buildGiantsList(),
              ),
              
              // Botón continuar
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Título
          Text(
            '¿CON QUÉ FRECUENCIA LUCHAS?',
            style: GoogleFonts.cinzel(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppDesignSystem.gold,
              letterSpacing: 2,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtítulo
          Text(
            'Configura cada batalla. Puedes cambiarlo después.',
            style: GoogleFonts.manrope(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Indicador de progreso
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
                color: _isComplete ? AppDesignSystem.victory : Colors.white38,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '$_completedCount de ${widget.selectedGiants.length} configurados',
                style: GoogleFonts.manrope(
                  fontSize: 13,
                  color: _isComplete ? AppDesignSystem.victory : Colors.white54,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildGiantsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _giants.length,
      itemBuilder: (context, index) {
        final giant = _giants[index];
        return _buildGiantCard(giant, index);
      },
    );
  }
  
  Widget _buildGiantCard(GiantWithFrequency giant, int index) {
    final isComplete = giant.hasFrequency;
    
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
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isComplete 
              ? AppDesignSystem.midnightLight.withOpacity(0.8)
              : AppDesignSystem.midnightLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isComplete 
                ? AppDesignSystem.gold.withOpacity(0.5) 
                : Colors.white12,
            width: isComplete ? 2 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header del gigante
              Row(
                children: [
                  // Emoji
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppDesignSystem.midnight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        giant.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Nombre y descripción
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          giant.name,
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          giant.description,
                          style: GoogleFonts.manrope(
                            fontSize: 12,
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  
                  // Check de completado
                  if (isComplete)
                    const Icon(
                      Icons.check_circle,
                      color: AppDesignSystem.victory,
                      size: 24,
                    ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Selector de frecuencia (chips)
              _buildFrequencySelector(giant),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildFrequencySelector(GiantWithFrequency giant) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BattleFrequency.values.map((frequency) {
        final isSelected = giant.frequency == frequency;
        
        return GestureDetector(
          onTap: () => _updateFrequency(giant.id, frequency),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected 
                  ? AppDesignSystem.gold.withOpacity(0.15) 
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected 
                    ? AppDesignSystem.gold 
                    : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  frequency.emoji,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                Text(
                  frequency.displayName,
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppDesignSystem.gold : Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppDesignSystem.midnight.withOpacity(0),
            AppDesignSystem.midnight,
          ],
        ),
      ),
      child: SafeArea(
        top: false,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _isComplete ? 1.0 : 0.5,
          child: GestureDetector(
            onTap: _isComplete ? _saveAndContinue : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                gradient: _isComplete
                    ? const LinearGradient(
                        colors: [AppDesignSystem.gold, Color(0xFFB8860B)],
                      )
                    : null,
                color: _isComplete ? null : Colors.white12,
                borderRadius: BorderRadius.circular(16),
                boxShadow: _isComplete
                    ? [
                        BoxShadow(
                          color: AppDesignSystem.gold.withOpacity(0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: _isSaving
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _isComplete 
                              ? 'GUARDAR Y CONTINUAR' 
                              : 'COMPLETA TODAS LAS OPCIONES',
                          style: GoogleFonts.cinzel(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _isComplete 
                                ? AppDesignSystem.midnight 
                                : Colors.white38,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (_isComplete) ...[
                          const SizedBox(width: 8),
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
