import 'package:flutter/material.dart';
import '../../theme/app_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/giant_frequency.dart';
import '../../services/onboarding_service.dart';
import '../../services/feedback_engine.dart';
import '../../repositories/profile_repository.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import 'onboarding_papel.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// GIANT FREQUENCY SCREEN
/// El usuario asigna una frecuencia de lucha a CADA gigante seleccionado
/// ═══════════════════════════════════════════════════════════════════════════

class GiantFrequencyScreen extends StatefulWidget {
  final List<String> selectedGiants;

  const GiantFrequencyScreen({super.key, required this.selectedGiants});

  @override
  State<GiantFrequencyScreen> createState() => _GiantFrequencyScreenState();
}

class _GiantFrequencyScreenState extends State<GiantFrequencyScreen> {
  // Mapa de frecuencias por gigante
  late Map<String, BattleFrequency?> _frequencies;

  // Lista de gigantes con sus datos completos
  late List<GiantWithFrequency> _giants;

  // Estado de guardado
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeGiants();
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

      final success = await OnboardingService()
          .completeOnboardingWithFrequencies(
            giants: widget.selectedGiants,
            frequencies: freqMap,
          );

      if (!mounted) return;

      if (success) {
        debugPrint(
          '🎯 [FREQ_SCREEN] Save successful, verifying profile state...',
        );

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
          debugPrint(
            '🎯 [FREQ_SCREEN] ✅ Profile verified: onboardingCompleted=true, popping to root',
          );
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        } else {
          debugPrint(
            '🎯 [FREQ_SCREEN] ⚠️ Profile NOT verified after save, forcing pop anyway',
          );
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
    return _buildPapel();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAPEL RECORTADO
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPapel() {
    final total = widget.selectedGiants.length;
    return FondoPapel(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              EncabezadoPasoPapel(
                paso: 'Paso 2 de 2',
                progreso: 0.5 + 0.5 * (_completedCount / (total == 0 ? 1 : total)),
                conAudio: false,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 22, 18, 24),
                  children: [
                    const PopIn(
                      child: TituloVec(
                        '¿Con qué frecuencia luchas?',
                        clave: 'frecuencia',
                        tamano: 30,
                        alineacion: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Configura cada batalla. Puedes cambiarlo después.',
                      textAlign: TextAlign.center,
                      style: AppFonts.manrope(
                        fontSize: 17,
                        color: VecColores.gris,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: ChipVec(
                        texto: '$_completedCount de $total configurados',
                        color: _isComplete
                            ? VecColores.verde
                            : VecColores.azulClaro,
                        iconoWidget: _isComplete
                            ? IconoVec(
                              'palomita',
                              color: VecColores.papel,
                            )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 30),
                    for (var i = 0; i < _giants.length; i++) ...[
                      _buildGiantCardPapel(_giants[i], i),
                      const SizedBox(height: 26),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: BotonVec(
                  texto: _isComplete
                      ? 'Guardar y continuar'
                      : 'Completa todas las opciones',
                  icono: _isComplete ? Icons.arrow_forward_rounded : null,
                  color: VecColores.verde,
                  cargando: _isSaving,
                  expandido: true,
                  onPressed: _isComplete ? _saveAndContinue : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGiantCardPapel(GiantWithFrequency giant, int index) {
    final par = index.isEven;
    return PopIn(
      retraso: Duration(milliseconds: 70 * index),
      child: TarjetaPapel(
        giro: par ? -1 : 1,
        cintaDerecha: !par,
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CirculoIcono(
                  iconoVec: iconosGigantesPapel[giant.id] ?? 'escudo',
                  color: giant.hasFrequency
                      ? VecColores.verde
                      : VecColores.azul,
                  tamano: 48,
                  giro: par ? -4 : 4,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        giant.name,
                        style: TextStyle(
                          fontFamily: VecFuentes.titulo,
                          fontSize: 19,
                          color: VecColores.tinta,
                        ),
                      ),
                      Text(
                        giant.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 16,
                          height: 1.15,
                          color: VecColores.gris,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 14,
              children: BattleFrequency.values.map((frequency) {
                final isSelected = giant.frequency == frequency;
                return Semantics(
                  button: true,
                  selected: isSelected,
                  label: frequency.displayName,
                  onTap: () => _updateFrequency(giant.id, frequency),
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () => _updateFrequency(giant.id, frequency),
                    child: isSelected
                        ? ChipVec(
                            texto: frequency.displayName,
                            color: VecColores.terracota,
                            giro: -1,
                          )
                        : Container(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
                            decoration: BoxDecoration(
                              color: VecColores.cremaOscuro,
                              borderRadius: BorderRadius.circular(
                                VecRadios.pildora,
                              ),
                            ),
                            child: Text(
                              frequency.displayName,
                              style: TextStyle(
                                fontFamily: VecFuentes.titulo,
                                fontSize: 16,
                                color: VecColores.tinta,
                              ),
                            ),
                          ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
