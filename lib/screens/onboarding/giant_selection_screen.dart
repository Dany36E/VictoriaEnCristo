import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_fonts.dart';
import '../../theme/app_theme.dart';
import '../../services/feedback_engine.dart';
import '../purity/purity_intro_sheet.dart';
import 'giant_frequency_screen.dart';
import 'giant_ranking_screen.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import 'onboarding_papel.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PANTALLA 2: SELECCIÓN DE GIGANTES
/// El usuario selecciona las categorías de luchas/adicciones que enfrenta
/// ═══════════════════════════════════════════════════════════════════════════

class GiantSelectionScreen extends StatefulWidget {
  const GiantSelectionScreen({super.key});

  @override
  State<GiantSelectionScreen> createState() => _GiantSelectionScreenState();
}

class _GiantSelectionScreenState extends State<GiantSelectionScreen> {
  // Set de gigantes seleccionados
  final Set<String> _selectedGiants = {};

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORES NEUTRALES (ANTISESGO)
  // Todos los gigantes usan el mismo color base para evitar que alguno "grite" más
  // La diferenciación es solo por icono/texto y estado seleccionado (borde dorado)
  // ═══════════════════════════════════════════════════════════════════════════
  // Dorado (gold)

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

  void _toggleGiant(String id) {
    HapticFeedback.lightImpact();
    // SFX de selección - fire and forget
    FeedbackEngine.I.select(); // Haptic + SFX select
    setState(() {
      if (_selectedGiants.contains(id)) {
        _selectedGiants.remove(id);
      } else {
        _selectedGiants.add(id);
      }
    });
  }

  Future<void> _navigateToIntensity() async {
    if (_selectedGiants.isEmpty) {
      // Mostrar mensaje si no hay selección
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecciona al menos un área de batalla',
            style: AppFonts.manrope(fontWeight: FontWeight.w500),
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

    FeedbackEngine.I.confirm(); // Haptic + SFX confirm

    // Si eligió "Pureza Sexual", sugerir el Escudo de Pureza (bloqueador)
    // antes de continuar con la configuración de intensidad.
    if (_selectedGiants.contains('sexual')) {
      await showPuritySuggestionSheet(context);
      if (!mounted) return;
    }

    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            _selectedGiants.length >= 2
            ? GiantRankingScreen(selectedGiants: _selectedGiants.toList())
            : GiantFrequencyScreen(selectedGiants: _selectedGiants.toList()),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  ),
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
    return _buildPapel();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PAPEL RECORTADO
  // ═══════════════════════════════════════════════════════════════════════

  Widget _buildPapel() {
    final hasSelection = _selectedGiants.isNotEmpty;
    return FondoPapel(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const EncabezadoPasoPapel(paso: 'Paso 1 de 2', progreso: 0.5),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final gridWidth = constraints.maxWidth - 40;
                    final columns = gridWidth >= 700
                        ? 3
                        : (gridWidth < 360 && textScale >= 1.4)
                        ? 1
                        : 2;
                    return CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                            child: Column(
                              children: [
                                const PopIn(
                                  child: TituloVec(
                                    '¿Cuál es tu gigante?',
                                    clave: 'gigante',
                                    tamano: 32,
                                    alineacion: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Selecciona las áreas donde necesitas más victoria.\nPuedes elegir una o varias.',
                                  textAlign: TextAlign.center,
                                  style: AppFonts.manrope(
                                    fontSize: 17,
                                    color: VecColores.gris,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          sliver: SliverGrid(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) =>
                                  _buildGiantCardPapel(_giants[index], index),
                              childCount: _giants.length,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisExtent: textScale >= 1.4 ? 250 : 200,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 20,
                                ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: BotonVec(
                  texto: hasSelection
                      ? 'Continuar (${_selectedGiants.length})'
                      : 'Selecciona al menos uno',
                  icono: hasSelection ? Icons.arrow_forward_rounded : null,
                  expandido: true,
                  onPressed: hasSelection ? _navigateToIntensity : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tarjeta de gigante en papel. Mismo color para todos (antisesgo); la
  /// elegida lleva contorno terracota y palomita.
  Widget _buildGiantCardPapel(Map<String, dynamic> giant, int index) {
    final isSelected = _selectedGiants.contains(giant['id']);
    final icono = iconosGigantesPapel[giant['id']] ?? 'escudo';
    return PopIn(
      retraso: Duration(milliseconds: 60 * index),
      giroFinal: index.isEven ? -1 : 1,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: '${giant['name']}. ${giant['description']}',
        onTap: () => _toggleGiant(giant['id']),
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => _toggleGiant(giant['id']),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 12),
            decoration: BoxDecoration(
              color: VecColores.papel,
              borderRadius: BorderRadius.circular(VecRadios.m),
              border: Border.all(
                color: isSelected ? VecColores.terracota : VecColores.papel,
                width: 4,
              ),
              boxShadow: VecSombras.papel,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CirculoIcono(
                      iconoVec: icono,
                      color: isSelected
                          ? VecColores.terracota
                          : VecColores.cremaOscuro,
                      colorIcono: isSelected
                          ? VecColores.papel
                          : VecColores.gris,
                      tamano: 52,
                      sombra: isSelected,
                      giro: isSelected ? -4 : 0,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      giant['name'],
                      style: TextStyle(
                        fontFamily: VecFuentes.titulo,
                        fontSize: 17,
                        height: 1.05,
                        color: VecColores.tinta,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        giant['description'],
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 16,
                          height: 1.15,
                          color: VecColores.gris,
                        ),
                      ),
                    ),
                  ],
                ),
                if (isSelected)
                  Positioned(
                    top: -6,
                    right: -4,
                    child: CirculoIcono(
                      iconoVec: 'palomita',
                      color: VecColores.verde,
                      tamano: 34,
                      giro: 6,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
