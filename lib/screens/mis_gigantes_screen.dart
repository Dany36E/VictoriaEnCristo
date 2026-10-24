import 'package:flutter/material.dart';

import '../models/giant_frequency.dart';
import '../services/feedback_engine.dart';
import '../services/onboarding_service.dart';
import '../services/personalization_engine.dart';
import '../services/victory_scoring_service.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import '../widgets/lista_orden_gigantes.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// MIS GIGANTES
/// Editor de gigantes (desde Ajustes y Perfil): agregar, quitar, ordenar por
/// prioridad y ajustar la frecuencia. Al guardar conserva el historial: los
/// días ya registrados siguen contando y los gigantes nuevos empiezan hoy.
/// ═══════════════════════════════════════════════════════════════════════════
class MisGigantesScreen extends StatefulWidget {
  const MisGigantesScreen({super.key});

  /// Todos los gigantes disponibles (mismo orden que el onboarding).
  static const List<String> todos = [
    'digital',
    'sexual',
    'health',
    'substances',
    'mental',
    'emotions',
  ];

  @override
  State<MisGigantesScreen> createState() => _MisGigantesScreenState();
}

class _MisGigantesScreenState extends State<MisGigantesScreen> {
  late List<String> _orden;
  late Map<String, String> _frecuencias;
  late List<String> _ordenInicial;
  late Map<String, String> _frecuenciasIniciales;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final onboarding = OnboardingService();
    final guardados = onboarding.selectedGiants
        .where(MisGigantesScreen.todos.contains)
        .toList();
    // Usuarios antiguos sin orden explícito: se parte del orden calculado.
    List<String> ranked;
    try {
      ranked = PersonalizationEngine.I.rankedGiants.map((g) => g.name).toList();
    } catch (_) {
      ranked = const [];
    }
    _orden = [
      ...ranked.where(guardados.contains),
      ...guardados.where((g) => !ranked.contains(g)),
    ];
    _frecuencias = Map<String, String>.from(onboarding.loadGiantFrequencies())
      ..removeWhere((k, _) => !_orden.contains(k));
    _ordenInicial = List<String>.from(_orden);
    _frecuenciasIniciales = Map<String, String>.from(_frecuencias);
  }

  bool get _completo =>
      _orden.isNotEmpty && _orden.every((g) => _frecuencias[g] != null);

  bool get _hayCambios {
    if (_orden.length != _ordenInicial.length) return true;
    for (var i = 0; i < _orden.length; i++) {
      if (_orden[i] != _ordenInicial[i]) return true;
    }
    for (final g in _orden) {
      if (_frecuencias[g] != _frecuenciasIniciales[g]) return true;
    }
    return false;
  }

  void _agregar(String id) {
    FeedbackEngine.I.select();
    setState(() => _orden = [..._orden, id]);
  }

  Future<void> _quitar(String id) async {
    final nombre = OnboardingService.getGiantName(id);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar «$nombre»?'),
        content: const Text(
          'Dejarás de registrar este gigante desde hoy. '
          'Tus días ya registrados se conservan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            key: const ValueKey('confirmar-quitar'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    FeedbackEngine.I.select();
    setState(() {
      _orden = _orden.where((g) => g != id).toList();
      _frecuencias.remove(id);
    });
  }

  Future<void> _guardar() async {
    if (!_completo || _guardando) return;
    setState(() => _guardando = true);
    FeedbackEngine.I.confirm();
    final gigantes = List<String>.from(_orden);
    final frecuencias = {for (final g in gigantes) g: _frecuencias[g]!};
    final ok = await OnboardingService().saveGiantsConfiguration(
      giants: gigantes,
      frequencies: frecuencias,
    );
    if (ok) {
      try {
        await VictoryScoringService.I.actualizarGigantes(gigantes);
      } catch (e) {
        debugPrint('⚠️ [MIS_GIGANTES] No se actualizó el registro: $e');
      }
    }
    if (!mounted) return;
    setState(() => _guardando = false);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Gigantes guardados'
              : 'No se pudo guardar. Revisa tu conexión e inténtalo de nuevo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (ok) Navigator.of(context).maybePop();
  }

  Widget _pieDeItem(String id) {
    final actual = BattleFrequencyExtension.fromId(_frecuencias[id]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          actual == null ? '¿Con qué frecuencia? (elige una)' : 'Frecuencia',
          style: TextStyle(
            fontFamily: VecFuentes.texto,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: actual == null ? VecColores.terracota : VecColores.gris,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in BattleFrequency.values)
              ChoiceChip(
                key: ValueKey('frecuencia-$id-${f.id}'),
                label: Text(
                  f.displayName,
                  style: TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 15,
                    color: f == actual ? VecColores.papel : VecColores.tinta,
                  ),
                ),
                selected: f == actual,
                showCheckmark: false,
                selectedColor: VecColores.terracota,
                backgroundColor: VecColores.papel,
                side: BorderSide(
                  color: f == actual
                      ? VecColores.terracota
                      : VecColores.cremaOscuro,
                ),
                onSelected: (_) {
                  FeedbackEngine.I.select();
                  setState(() => _frecuencias[id] = f.id);
                },
              ),
          ],
        ),
        if (_orden.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey('quitar-$id'),
              onPressed: () => _quitar(id),
              style: TextButton.styleFrom(
                foregroundColor: VecColores.terracota,
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.remove_circle_outline_rounded),
              label: Text(
                'Quitar',
                semanticsLabel: 'Quitar ${OnboardingService.getGiantName(id)}',
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final disponibles = MisGigantesScreen.todos
        .where((g) => !_orden.contains(g))
        .toList();
    return Scaffold(
      backgroundColor: t.pageBg,
      appBar: AppBar(title: const Text('Mis gigantes')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  Text(
                    'El primero es el que más te cuesta hoy: tu plan de '
                    'emergencia y tus recomendaciones empiezan por él.',
                    style: TextStyle(
                      fontFamily: VecFuentes.texto,
                      fontSize: 17,
                      height: 1.3,
                      color: t.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_orden.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Agrega al menos un gigante.',
                        style: TextStyle(color: t.textPrimary, fontSize: 16),
                      ),
                    )
                  else
                    ListaOrdenGigantes(
                      gigantes: _orden,
                      dentroDeScroll: true,
                      onCambio: (nueva) => setState(() => _orden = nueva),
                      pieDeItem: _pieDeItem,
                    ),
                  if (disponibles.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Agregar gigante',
                      style: TextStyle(
                        fontFamily: VecFuentes.titulo,
                        fontSize: 20,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Empieza a contar desde hoy.',
                      style: TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 15,
                        color: t.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final g in disponibles)
                          ActionChip(
                            key: ValueKey('agregar-$g'),
                            avatar: Icon(
                              Icons.add_rounded,
                              color: VecColores.tinta,
                            ),
                            label: Text(
                              OnboardingService.getGiantName(g),
                              style: TextStyle(
                                fontFamily: VecFuentes.texto,
                                fontSize: 16,
                                color: VecColores.tinta,
                              ),
                            ),
                            backgroundColor: VecColores.papel,
                            side: BorderSide(color: VecColores.cremaOscuro),
                            onPressed: () => _agregar(g),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: BotonVec(
                key: const ValueKey('guardar-gigantes'),
                texto: _guardando
                    ? 'Guardando…'
                    : !_completo
                    ? 'Elige la frecuencia de cada gigante'
                    : 'Guardar',
                icono: Icons.check_rounded,
                expandido: true,
                onPressed: _completo && _hayCambios && !_guardando
                    ? _guardar
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
