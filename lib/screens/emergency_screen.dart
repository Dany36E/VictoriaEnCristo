import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../widgets/premium_components.dart';
import '../services/feedback_engine.dart';
import '../services/emergency_sos_service.dart';
import 'battle_partner/battle_partner_screen.dart';
import 'wall/wall_screen.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _breatheController;
  late Animation<double> _pulseAnimation;
  int _currentStep = 0;

  late List<PersonalizedStep> _steps;
  late String _giantName;

  @override
  void initState() {
    super.initState();

    final sos = EmergencySosService.I;
    _steps = sos.getPersonalizedSteps();
    _giantName = sos.getGiantDisplayName();

    // Fallback por si el servicio no cargó
    if (_steps.isEmpty) {
      _steps = [
        const PersonalizedStep(
          emoji: '🛑',
          title: 'DETENTE',
          instruction: 'Respira profundo. Cierra los ojos por un momento.',
          duration: 5,
        ),
        const PersonalizedStep(
          emoji: '🙏',
          title: 'ORA',
          instruction: 'Di en voz alta: "Señor, necesito Tu ayuda ahora mismo"',
          duration: 10,
          prayer:
              'Señor Jesús, en este momento de debilidad vengo a Ti. Dame la fuerza para resistir. En Tu nombre, Amén.',
        ),
        const PersonalizedStep(
          emoji: '📖',
          title: 'LEE',
          instruction: 'Medita en la Palabra de Dios.',
          duration: 15,
        ),
        const PersonalizedStep(
          emoji: '🚶',
          title: 'MUÉVETE',
          instruction: 'Levántate y cambia de ambiente. Sal de donde estás.',
          duration: 5,
        ),
        const PersonalizedStep(
          emoji: '📞',
          title: 'CONECTA',
          instruction: 'Llama o escribe a alguien de confianza.',
          duration: 5,
        ),
      ];
      _giantName = 'General';
    }

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _breatheController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  void _nextStep() {
    FeedbackEngine.I.confirm();
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
    } else {
      _showPostSosCheckin();
    }
  }

  /// Check-in tras los 5 pasos: "¿Estás bien ahora?"
  /// - Sí → diálogo de victoria + logra la victoria emocional.
  /// - Sigo luchando → ofrece escalación (partner, wall, repetir pasos).
  void _showPostSosCheckin() {
    FeedbackEngine.I.confirm();
    final t = AppThemeData.of(context);
    if (t.isPaper) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PopIn(
                  child: Sticker(
                    'assets/vec/personajes/victoria_piensa.png',
                    alto: 140,
                  ),
                ),
                const SizedBox(height: 12),
                const TituloVec(
                  '¿Cómo te sientes ahora?',
                  clave: 'ahora',
                  tamano: 24,
                  alineacion: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'No hay respuesta incorrecta. Solo queremos acompañarte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 18,
                    color: VecColores.gris,
                  ),
                ),
                const SizedBox(height: 20),
                BotonVec(
                  texto: 'Ya estoy bien',
                  iconoWidget: const IconoVec('palomita'),
                  color: VecColores.verde,
                  expandido: true,
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showVictoryDialog();
                  },
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showEscalationSheet();
                  },
                  child: const Text('Sigo luchando'),
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.3)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_border_rounded, size: 56, color: AppDesignSystem.gold),
                const SizedBox(height: AppDesignSystem.spacingM),
                Text(
                  '¿Cómo te sientes ahora?',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.displaySmall(context, color: t.textPrimary),
                ),
                const SizedBox(height: AppDesignSystem.spacingS),
                Text(
                  'No hay respuesta incorrecta. Solo queremos acompañarte.',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                ),
                const SizedBox(height: AppDesignSystem.spacingL),
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      _showVictoryDialog();
                    },
                    backgroundColor: AppDesignSystem.victory,
                    shadow: AppDesignSystem.shadowVictory,
                    child: Text(
                      'Ya estoy bien',
                      style: AppDesignSystem.labelLarge(context, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingS),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _showEscalationSheet();
                  },
                  child: Text(
                    'Sigo luchando',
                    style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.gold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Hoja de escalación: si tras los 5 pasos el usuario sigue luchando.
  void _showEscalationSheet() {
    final t = AppThemeData.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingL),
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDesignSystem.radiusL),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppDesignSystem.spacingM),
                  decoration: BoxDecoration(
                    color: t.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'No estás solo en esto',
                textAlign: TextAlign.center,
                style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                'La valentía no es no caer — es pedir ayuda. Elige un paso:',
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
              _EscalationTile(
                icon: Icons.people_alt_rounded,
                title: 'Escribir a mi compañero de batalla',
                subtitle: 'Un mensaje corto basta.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(
                    context,
                  ).pushReplacement(MaterialPageRoute(builder: (_) => const BattlePartnerScreen()));
                },
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              _EscalationTile(
                icon: Icons.forum_rounded,
                title: 'Pedir oración en el muro',
                subtitle: 'Anónimo. Hay gente orando por ti ahora.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(
                    context,
                  ).pushReplacement(MaterialPageRoute(builder: (_) => const WallScreen()));
                },
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              _EscalationTile(
                icon: Icons.replay_rounded,
                title: 'Repetir los 5 pasos',
                subtitle: 'Sin prisa. Este momento pasará.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _currentStep = 0);
                },
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              _EscalationTile(
                icon: Icons.phone_rounded,
                title: 'Línea de ayuda en crisis',
                subtitle: 'México 800 290 0024 · España 024 · USA 988',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showCrisisLinesDialog();
                },
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
            ],
          ),
        ),
      ),
    );
  }

  void _showCrisisLinesDialog() {
    final t = AppThemeData.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.surface,
        title: Text(
          'Líneas de ayuda',
          style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CrisisLine(country: 'México', number: '800 290 0024'),
            const _CrisisLine(country: 'España', number: '024'),
            const _CrisisLine(country: 'USA/CA', number: '988'),
            const _CrisisLine(country: 'Argentina', number: '135'),
            const _CrisisLine(country: 'Colombia', number: '106'),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              'Si estás en peligro inmediato, llama al número de emergencias local.',
              style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  void _showVictoryDialog() {
    FeedbackEngine.I.confirm();
    final t = AppThemeData.of(context);
    if (t.isPaper) {
      // Mensaje de éxito: Victoria celebra contigo.
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const PopIn(
                  child: Sticker(
                    'assets/vec/personajes/victoria_corazon.png',
                    alto: 150,
                  ),
                ),
                const SizedBox(height: 4),
                const Letrero('¡VICTORIA!', tamano: 40),
                const SizedBox(height: 10),
                Text(
                  'Has resistido la tentación. Cada victoria te hace más fuerte.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 18,
                    height: 1.3,
                    color: VecColores.tinta,
                  ),
                ),
                const SizedBox(height: 22),
                const TarjetaVersiculo(
                  referencia: 'Santiago 4:7',
                  texto: 'Resistid al diablo, y huirá de vosotros.',
                ),
                const SizedBox(height: 22),
                BotonVec(
                  texto: 'Continuar en victoria',
                  color: VecColores.verde,
                  expandido: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingL),
            decoration: BoxDecoration(
              color: t.surface,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
              border: Border.all(color: AppDesignSystem.victory.withValues(alpha: 0.3), width: 2),
              boxShadow: AppDesignSystem.shadowVictory,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppDesignSystem.victory.withValues(alpha: 0.2),
                            AppDesignSystem.victoryLight.withValues(alpha: 0.1),
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

                Text(
                  '¡VICTORIA!',
                  style: AppDesignSystem.displaySmall(context, color: AppDesignSystem.victory),
                ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.5, 0.5)),

                const SizedBox(height: AppDesignSystem.spacingM),

                Text(
                  'Has resistido la tentación.\nCada victoria te hace más fuerte.',
                  textAlign: TextAlign.center,
                  style: AppDesignSystem.bodyLarge(context, color: t.textSecondary),
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
                        style: AppDesignSystem.scripture(context, color: t.textPrimary),
                      ),
                      const SizedBox(height: AppDesignSystem.spacingS),
                      Text('Santiago 4:7', style: AppDesignSystem.scriptureReference(context)),
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
                      style: AppDesignSystem.labelLarge(context, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentStepData = _steps[_currentStep];
    final t = AppThemeData.of(context);

    return Scaffold(
      backgroundColor: t.pageBg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: t.textPrimary),
          onPressed: () {
            FeedbackEngine.I.tap();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'AYUDA DE EMERGENCIA',
          style: AppDesignSystem.labelLarge(context, color: t.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Animated background gradient (en papel, la hoja con textura)
          if (!t.isPaper)
          AnimatedBuilder(
            animation: _breatheController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.topCenter,
                    radius: 1.5 + (_breatheController.value * 0.2),
                    colors: [AppDesignSystem.struggle.withValues(alpha: 0.15), t.scaffoldBg],
                  ),
                ),
              );
            },
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              child: Column(
                children: [
                  // Giant badge
                  _buildGiantBadge(),
                  const SizedBox(height: AppDesignSystem.spacingM),

                  // Progress indicator
                  _buildProgressIndicator(),
                  const SizedBox(height: AppDesignSystem.spacingXL),

                  // Step content
                  Expanded(child: _buildStepContent(currentStepData)),

                  // Next button
                  _buildNextButton(),
                  SizedBox(
                    height: MediaQuery.of(context).padding.bottom + AppDesignSystem.spacingM,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiantBadge() {
    final t = AppThemeData.of(context);
    if (t.isPaper) {
      return PopIn(
        child: ChipVec(
          texto: 'Plan personalizado: $_giantName',
          color: VecColores.terracota,
          iconoWidget: IconoVec('escudo', color: VecColores.papel),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingM,
        vertical: AppDesignSystem.spacingXS,
      ),
      decoration: BoxDecoration(
        color: AppDesignSystem.struggle.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.struggle.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Plan personalizado: $_giantName',
        style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
      ),
    ).animate().fadeIn(delay: 50.ms);
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
          decoration: t.isPaper
              ? BoxDecoration(
                  color: isActive
                      ? VecColores.terracota
                      : VecColores.cremaOscuro,
                  borderRadius: BorderRadius.circular(VecRadios.pildora),
                )
              : BoxDecoration(
            gradient: isActive ? AppDesignSystem.goldShimmer : null,
            color: isActive ? null : t.textSecondary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: isCurrent ? AppDesignSystem.shadowGold : null,
          ),
        );
      }),
    ).animate().fadeIn(delay: 100.ms);
  }

  /// Personaje que acompaña cada paso en el tema papel.
  static const _personajesPaso = [
    'assets/vec/personajes/victoria_preocupado.png',
    'assets/vec/personajes/timoteo_explica.png',
    'assets/vec/personajes/victoria_ora.png',
    'assets/vec/personajes/timoteo_corazon.png',
    'assets/vec/personajes/victoria_presenta.png',
  ];

  Widget _buildStepContentPapel(PersonalizedStep step) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          const SizedBox(height: 8),
          PopIn(
            key: ValueKey('personaje-$_currentStep'),
            child: Sticker(
              _personajesPaso[_currentStep % _personajesPaso.length],
              alto: 160,
            ),
          ),
          const SizedBox(height: 10),
          TituloVec(
            step.title,
            tamano: 34,
            alineacion: TextAlign.center,
          ),
          const SizedBox(height: 22),
          PopIn(
            key: ValueKey('tarjeta-$_currentStep'),
            retraso: const Duration(milliseconds: 120),
            child: TarjetaPapel(
              child: Column(
                children: [
                  Text(
                    step.instruction,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: VecFuentes.texto,
                      fontSize: 21,
                      height: 1.3,
                      color: VecColores.tinta,
                    ),
                  ),
                  if (step.detail != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      step.detail!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 17,
                        height: 1.3,
                        color: VecColores.gris,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (step.verse != null) ...[
            const SizedBox(height: 26),
            TarjetaVersiculo(
              referencia: step.verse!.reference,
              texto: step.verse!.title,
              version: '',
            ),
          ],
          if (step.prayer != null) ...[
            const SizedBox(height: 26),
            Row(
              children: [
                CirculoIcono(
                  iconoVec: 'orar',
                  color: VecColores.noche,
                  tamano: 38,
                  giro: -4,
                ),
                const SizedBox(width: 10),
                const TituloVec('Oración', tamano: 22),
              ],
            ),
            const SizedBox(height: 20),
            HojaRayada(child: Text(step.prayer!)),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildStepContent(PersonalizedStep step) {
    final t = AppThemeData.of(context);
    if (t.isPaper) return _buildStepContentPapel(step);
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: AppDesignSystem.spacingL),

          // Emoji with pulse
          ScaleTransition(
            scale: _pulseAnimation,
            child: Text(step.emoji, style: const TextStyle(fontSize: 64)),
          ),

          const SizedBox(height: AppDesignSystem.spacingM),

          // Step title
          Text(step.title, style: AppDesignSystem.displayMedium(context, color: t.textPrimary))
              .animate(key: ValueKey('title-$_currentStep'))
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.2, end: 0),

          const SizedBox(height: AppDesignSystem.spacingL),

          // Instruction card
          GlassContainer(
                backgroundColor: t.textPrimary.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(AppDesignSystem.spacingL),
                child: Column(
                  children: [
                    Text(
                      step.instruction,
                      textAlign: TextAlign.center,
                      style: AppDesignSystem.bodyLarge(context, color: t.textPrimary),
                    ),
                    // Detalle psicológico
                    if (step.detail != null) ...[
                      const SizedBox(height: AppDesignSystem.spacingM),
                      Text(
                        step.detail!,
                        textAlign: TextAlign.center,
                        style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                      ),
                    ],
                    // Versículo personalizado
                    if (step.verse != null) ...[
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
                              '"${step.verse!.title}"',
                              textAlign: TextAlign.center,
                              style: AppDesignSystem.scripture(context, color: t.textPrimary),
                            ),
                            const SizedBox(height: AppDesignSystem.spacingM),
                            Text(
                              step.verse!.reference,
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

          // Oración personalizada
          if (step.prayer != null) ...[
            const SizedBox(height: AppDesignSystem.spacingL),
            _buildPrayerCard(step.prayer!),
          ],

          const SizedBox(height: AppDesignSystem.spacingL),
        ],
      ),
    );
  }

  Widget _buildPrayerCard(String prayer) {
    final t = AppThemeData.of(context);
    return GlassContainer(
      backgroundColor: t.textPrimary.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.format_quote, color: t.accent, size: 20),
              const SizedBox(width: AppDesignSystem.spacingS),
              Text('ORACIÓN', style: AppDesignSystem.labelMedium(context, color: t.accent)),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            prayer,
            textAlign: TextAlign.center,
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
        ],
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.2, end: 0);
  }

  Widget _buildNextButton() {
    final t = AppThemeData.of(context);
    final isLastStep = _currentStep == _steps.length - 1;
    if (t.isPaper) {
      return BotonVec(
        texto: isLastStep ? '¡Lo logré!' : 'Siguiente paso',
        icono: isLastStep ? Icons.celebration_rounded : Icons.arrow_forward_rounded,
        color: isLastStep ? VecColores.verde : VecColores.terracota,
        expandido: true,
        onPressed: _nextStep,
      );
    }

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

// ═══════════════════════════════════════════════════════════════════════════
// Helpers para escalación post-SOS
// ═══════════════════════════════════════════════════════════════════════════

class _EscalationTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EscalationTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Semantics(
      button: true,
      label: title,
      hint: subtitle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            decoration: t.isPaper
                ? t.cardDecoration
                : BoxDecoration(
              color: t.scaffoldBg,
              borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
              border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                if (t.isPaper)
                  CirculoIcono(icono: icon, color: VecColores.azul, tamano: 40)
                else
                Icon(icon, color: AppDesignSystem.gold, size: 26),
                const SizedBox(width: AppDesignSystem.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppDesignSystem.bodyLarge(context, color: t.textPrimary)),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: t.textSecondary.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CrisisLine extends StatelessWidget {
  final String country;
  final String number;
  const _CrisisLine({required this.country, required this.number});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              country,
              style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
            ),
          ),
          Text(
            number,
            style: AppDesignSystem.bodyLarge(
              context,
              color: t.isPaper ? VecColores.terracota : AppDesignSystem.gold,
            ),
          ),
        ],
      ),
    );
  }
}
