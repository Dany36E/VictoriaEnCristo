import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../data/bible_verses.dart';
import '../widgets/premium_components.dart';
import '../services/feedback_engine.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _breatheController;
  late Animation<double> _pulseAnimation;
  int _currentStep = 0;
  late BibleVerse _currentVerse;

  final List<EmergencyStep> _steps = [
    EmergencyStep(
      emoji: '🛑',
      title: 'DETENTE',
      instruction: 'Respira profundo. Cierra los ojos por un momento.',
      duration: 5,
    ),
    EmergencyStep(
      emoji: '🙏',
      title: 'ORA',
      instruction: 'Di en voz alta: "Señor, necesito Tu ayuda ahora mismo"',
      duration: 10,
    ),
    EmergencyStep(
      emoji: '📖',
      title: 'LEE',
      instruction: 'Medita en este versículo:',
      duration: 15,
    ),
    EmergencyStep(
      emoji: '🚶',
      title: 'MUÉVETE',
      instruction: 'Levántate y cambia de ambiente. Sal de donde estás.',
      duration: 5,
    ),
    EmergencyStep(
      emoji: '📞',
      title: 'CONECTA',
      instruction: 'Llama o escribe a alguien de confianza. No enfrentes esto solo.',
      duration: 5,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentVerse = BibleVerses.getRandomVerseByCategory('tentación');
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  void _nextStep() {
    FeedbackEngine.I.confirm();  // Haptic + SFX confirm
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        if (_currentStep == 2) {
          _currentVerse = BibleVerses.getRandomVerseByCategory('tentación');
        }
      });
    } else {
      _showVictoryDialog();
    }
  }

  void _showVictoryDialog() {
    FeedbackEngine.I.confirm();  // Haptic + SFX confirm (victoria)
    final t = AppThemeData.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              border: Border.all(
                color: AppDesignSystem.victory.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: AppDesignSystem.shadowVictory,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy icon with glow
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppDesignSystem.victory.withOpacity(0.2),
                        AppDesignSystem.victoryLight.withOpacity(0.1),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: AppDesignSystem.shadowVictory,
                  ),
                  child: const Icon(
                    Icons.emoji_events,
                    size: 64,
                    color: AppDesignSystem.victory,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 1000.ms,
                    ),
                
                const SizedBox(height: AppDesignSystem.spacingL),
                
                // Victory title
                Text(
                  '¡VICTORIA!',
                  style: AppDesignSystem.displaySmall(
                    context,
                    color: AppDesignSystem.victory,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .scale(begin: const Offset(0.5, 0.5)),
                
                const SizedBox(height: AppDesignSystem.spacingM),
                
                Text(
                  'Has resistido la tentación.\nCada victoria te hace más fuerte.',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.bodyLarge(
                    context,
                    color: t.textSecondary,
                  ),
                ),
                
                const SizedBox(height: AppDesignSystem.spacingM),
                
                Container(
                  padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.goldSubtle,
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '"Resistid al diablo, y huirá de vosotros"',
                        textAlign: TextAlign.center,
                        style: AppDesignSystem.scripture(
                          context,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppDesignSystem.spacingS),
                      Text(
                        'Santiago 4:7',
                        style: AppDesignSystem.scriptureReference(context),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: AppDesignSystem.spacingL),
                
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    },
                    backgroundColor: AppDesignSystem.victory,
                    shadow: AppDesignSystem.shadowVictory,
                    child: Text(
                      'CONTINUAR EN VICTORIA',
                      style: AppDesignSystem.labelLarge(
                        context,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn()
              .scale(begin: const Offset(0.9, 0.9)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStepData = _steps[_currentStep];
    final t = AppThemeData.of(context);
    
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: t.textPrimary),
          onPressed: () {
            FeedbackEngine.I.tap();  // Haptic + SFX tap
            Navigator.pop(context);
          },
        ),
        title: Text(
          'AYUDA DE EMERGENCIA',
          style: AppDesignSystem.labelLarge(
            context,
            color: t.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Animated background gradient
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5 + (_breatheController.value * 0.2),
                    colors: [
                      AppDesignSystem.struggle.withOpacity(0.15),
                      t.scaffoldBg,
                    ],
                  ),
                ),
              );
            },
          ),
          
          // Content
          SafeArea(
            bottom: false, // Manejamos el bottom manualmente
            child: Padding(
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              child: Column(
                children: [
                  // Progress indicator
                  _buildProgressIndicator(),
                  const SizedBox(height: AppDesignSystem.spacingXL),
                  
                  // Step content
                  Expanded(
                    child: _buildStepContent(currentStepData),
                  ),
                  
                  // Next button
                  _buildNextButton(),
                  // Safe Area bottom padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom + AppDesignSystem.spacingM),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final t = AppThemeData.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_steps.length, (index) {
        final isActive = index <= _currentStep;
        final isCurrent = index == _currentStep;
        
        return AnimatedContainer(
          duration: AppDesignSystem.durationMedium,
          curve: AppDesignSystem.curveDefault,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isCurrent ? 36 : 12,
          height: 12,
          decoration: BoxDecoration(
            gradient: isActive ? AppDesignSystem.goldShimmer : null,
            color: isActive ? null : t.textSecondary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isCurrent ? AppDesignSystem.shadowGold : null,
          ),
        );
      }),
    )
        .animate()
        .fadeIn(delay: 100.ms);
  }

  Widget _buildStepContent(EmergencyStep step) {
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppDesignSystem.spacingL),
          
          // Emoji with pulse
          ScaleTransition(
            scale: _pulseAnimation,
            child: Text(
              step.emoji,
              style: const TextStyle(fontSize: 64),
            ),
          ),
          
          const SizedBox(height: AppDesignSystem.spacingM),
          
          // Step title
          Text(
            step.title,
            style: AppDesignSystem.displayMedium(
              context,
              color: t.textPrimary,
            ),
          )
              .animate(key: ValueKey('title-$_currentStep'))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.2, end: 0),
          
          const SizedBox(height: AppDesignSystem.spacingL),
          
          // Instruction card
          GlassContainer(
            backgroundColor: t.textPrimary.withOpacity(0.08),
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            child: Column(
              children: [
                Text(
                  step.instruction,
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.bodyLarge(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                if (_currentStep == 2) ...[
                  const SizedBox(height: AppDesignSystem.spacingL),
                  const GoldenDivider(),
                  const SizedBox(height: AppDesignSystem.spacingL),
                  Container(
                    padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                    decoration: BoxDecoration(
                      color: AppDesignSystem.goldSubtle,
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '"${_currentVerse.verse}"',
                          textAlign: TextAlign.center,
                          style: AppDesignSystem.scripture(
                            context,
                            color: t.textPrimary,
                          ),
                        ),
                        const SizedBox(height: AppDesignSystem.spacingM),
                        Text(
                          _currentVerse.reference,
                          style: AppDesignSystem.scriptureReference(context),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          )
              .animate(key: ValueKey('card-$_currentStep'))
              .fadeIn(delay: 150.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
          
          if (_currentStep == 1) ...[
            const SizedBox(height: AppDesignSystem.spacingL),
            _buildQuickPrayer(),
          ],
          
          const SizedBox(height: AppDesignSystem.spacingL),
        ],
      ),
    );
  }

  Widget _buildQuickPrayer() {
    final t = AppThemeData.of(context);
    return GlassContainer(
      backgroundColor: t.textPrimary.withOpacity(0.05),
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote,
                color: t.accent,
                size: 20,
              ),
              const SizedBox(width: AppDesignSystem.spacingS),
              Text(
                'ORACIÓN RÁPIDA',
                style: AppDesignSystem.labelMedium(
                  context,
                  color: t.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            '"Señor Jesús, en este momento de debilidad vengo a Ti. Dame la fuerza para resistir. En Tu nombre, Amén."',
            textAlign: TextAlign.center,
            style: AppDesignSystem.bodyMedium(
              context,
              color: t.textSecondary,
            ),
          ),
        ],
      ),
    )
        .animate(delay: 300.ms)
        .fadeIn()
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildNextButton() {
    final t = AppThemeData.of(context);
    final isLastStep = _currentStep == _steps.length - 1;
    
    return SizedBox(
      width: double.infinity,
      child: PremiumButton(
        onPressed: _nextStep,
        backgroundColor: isLastStep ? AppDesignSystem.victory : t.accent,
        shadow: isLastStep ? AppDesignSystem.shadowVictory : AppDesignSystem.shadowGold,
        padding: const EdgeInsets.symmetric(
          vertical: AppDesignSystem.spacingL,
          horizontal: AppDesignSystem.spacingXL,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isLastStep ? '¡LO LOGRÉ!' : 'SIGUIENTE PASO',
              style: AppDesignSystem.labelLarge(
                context,
                color: isLastStep ? Colors.white : t.surface,
              ),
            ),
            const SizedBox(width: AppDesignSystem.spacingS),
            Icon(
              isLastStep ? Icons.celebration : Icons.arrow_forward,
              color: isLastStep ? Colors.white : t.surface,
            ),
          ],
        ),
      ),
    )
        .animate(key: ValueKey('button-$_currentStep'))
        .fadeIn(delay: 200.ms)
        .slideY(begin: 0.2, end: 0);
  }
}

class EmergencyStep {
  final String emoji;
  final String title;
  final String instruction;
  final int duration;

  EmergencyStep({
    required this.emoji,
    required this.title,
    required this.instruction,
    required this.duration,
  });
}
