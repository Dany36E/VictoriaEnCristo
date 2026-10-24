import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../services/feedback_engine.dart';
import '../services/emergency_sos_service.dart';
import '../models/content_enums.dart';
import 'battle_partner/battle_partner_screen.dart';
import 'wall/wall_screen.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import '../widgets/aviso_companero.dart';
import '../widgets/ayuda_crisis.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  int _currentStep = 0;

  late List<PersonalizedStep> _steps;
  late String _giantName;

  /// Gigantes del usuario por prioridad (el 1° es el plan inicial).
  List<GiantId> _giants = const [];
  GiantId? _selectedGiant;

  @override
  void initState() {
    super.initState();

    final sos = EmergencySosService.I;
    try {
      _giants = sos.rankedGiants;
    } catch (_) {
      _giants = const [];
    }
    _selectedGiant = _giants.isNotEmpty ? _giants.first : null;
    _loadPlan(_selectedGiant);

    // Para el botón "Avisar a mi compañero" de esta primera pantalla.
    prepararAvisoCompanero();
  }

  /// Carga pasos, nombre, versículo y oración del gigante indicado.
  void _loadPlan(GiantId? giant) {
    final sos = EmergencySosService.I;
    _steps = sos.getPersonalizedSteps(giant: giant);
    _giantName = sos.getGiantDisplayName(giant: giant);

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
    if (_currentStep >= _steps.length) _currentStep = _steps.length - 1;
  }

  /// Cambia el plan al gigante elegido en los chips, al instante.
  void _selectGiant(GiantId giant) {
    if (giant == _selectedGiant) return;
    FeedbackEngine.I.select();
    setState(() {
      _selectedGiant = giant;
      _loadPlan(giant);
    });
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
                  margin: const EdgeInsets.only(
                    bottom: AppDesignSystem.spacingM,
                  ),
                  decoration: BoxDecoration(
                    color: t.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'No estás solo en esto',
                textAlign: TextAlign.center,
                style: AppDesignSystem.headlineSmall(
                  context,
                  color: t.textPrimary,
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              Text(
                'La valentía no es no caer — es pedir ayuda. Elige un paso:',
                textAlign: TextAlign.center,
                style: AppDesignSystem.bodyMedium(
                  context,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
              _EscalationTile(
                icon: Icons.people_alt_rounded,
                title: 'Escribir a mi compañero de batalla',
                subtitle: 'Un mensaje corto basta.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => const BattlePartnerScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              _EscalationTile(
                icon: Icons.forum_rounded,
                title: 'Pedir oración en el muro',
                subtitle: 'Anónimo. Hay gente orando por ti ahora.',
                onTap: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const WallScreen()),
                  );
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
                subtitle: 'Toca para ver los números y llamar con un toque.',
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
        content: const SingleChildScrollView(child: ListaLineasCrisis()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showVictoryDialog() {
    FeedbackEngine.I.confirm();
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
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(AppDesignSystem.spacingL),
              child: Column(
                children: [
                  // «¿Con cuál luchas ahora?» (solo con 2+ gigantes)
                  if (_giants.length > 1) ...[
                    _buildGiantSelector(),
                    const SizedBox(height: AppDesignSystem.spacingS),
                  ],
                  // Giant badge
                  _buildGiantBadge(),
                  const SizedBox(height: AppDesignSystem.spacingM),

                  // Progress indicator
                  _buildProgressIndicator(),
                  const SizedBox(height: AppDesignSystem.spacingM),

                  // Un toque para pedir oración sin terminar los 5 pasos.
                  const BotonAvisarCompanero(),
                  const SizedBox(height: AppDesignSystem.spacingM),

                  // Step content
                  Expanded(child: _buildStepContent(currentStepData)),

                  // Next button
                  _buildNextButton(),
                  SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom +
                        AppDesignSystem.spacingM,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiantSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '¿Con cuál luchas ahora?',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: VecFuentes.texto,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppThemeData.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final g in _giants)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    key: ValueKey('sos-gigante-${g.name}'),
                    label: Text(
                      g.displayName,
                      style: TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: g == _selectedGiant
                            ? VecColores.papel
                            : VecColores.tinta,
                      ),
                    ),
                    selected: g == _selectedGiant,
                    showCheckmark: false,
                    selectedColor: VecColores.terracota,
                    backgroundColor: VecColores.papel,
                    side: BorderSide(
                      color: g == _selectedGiant
                          ? VecColores.terracota
                          : VecColores.cremaOscuro,
                      width: 2,
                    ),
                    materialTapTargetSize: MaterialTapTargetSize.padded,
                    onSelected: (_) => _selectGiant(g),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGiantBadge() {
    return PopIn(
      key: ValueKey('badge-${_selectedGiant?.name ?? 'general'}'),
      child: ChipVec(
        texto: 'Plan personalizado: $_giantName',
        color: VecColores.terracota,
        iconoWidget: IconoVec('escudo', color: VecColores.papel),
      ),
    );
  }

  Widget _buildProgressIndicator() {
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
            color: isActive ? VecColores.terracota : VecColores.cremaOscuro,
            borderRadius: BorderRadius.circular(VecRadios.pildora),
          ),
        );
      }),
    ).animate().fadeIn(delay: 100.ms);
  }

  /// Personaje que acompaña cada paso.
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
          TituloVec(step.title, tamano: 34, alineacion: TextAlign.center),
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
    return _buildStepContentPapel(step);
  }

  Widget _buildNextButton() {
    final isLastStep = _currentStep == _steps.length - 1;
    return BotonVec(
      texto: isLastStep ? '¡Lo logré!' : 'Siguiente paso',
      icono: isLastStep
          ? Icons.celebration_rounded
          : Icons.arrow_forward_rounded,
      color: isLastStep ? VecColores.verde : VecColores.terracota,
      expandido: true,
      onPressed: _nextStep,
    );
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
            decoration: t.cardDecoration,
            child: Row(
              children: [
                CirculoIcono(icono: icon, color: VecColores.azul, tamano: 40),
                const SizedBox(width: AppDesignSystem.spacingM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppDesignSystem.bodyLarge(
                          context,
                          color: t.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppDesignSystem.bodyMedium(
                          context,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: t.textSecondary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
