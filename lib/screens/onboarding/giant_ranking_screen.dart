import 'package:flutter/material.dart';

import '../../services/feedback_engine.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';
import '../../widgets/lista_orden_gigantes.dart';
import 'giant_frequency_screen.dart';
import 'onboarding_papel.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ORDENA TUS GIGANTES
/// Tras elegir 2+ gigantes, el usuario los ordena por prioridad. El primero
/// (índice 0) es «el que más te cuesta hoy» y define su plan principal.
/// ═══════════════════════════════════════════════════════════════════════════
class GiantRankingScreen extends StatefulWidget {
  const GiantRankingScreen({super.key, required this.selectedGiants});

  final List<String> selectedGiants;

  @override
  State<GiantRankingScreen> createState() => _GiantRankingScreenState();
}

class _GiantRankingScreenState extends State<GiantRankingScreen> {
  late List<String> _orden = List<String>.from(widget.selectedGiants);

  void _continuar() {
    FeedbackEngine.I.confirm();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            GiantFrequencyScreen(selectedGiants: List.unmodifiable(_orden)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FondoPapel(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              const EncabezadoPasoPapel(paso: 'Paso 1 de 2', progreso: 0.75),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
                child: Column(
                  children: [
                    const TituloVec(
                      'Ordena tus gigantes',
                      clave: 'gigantes',
                      tamano: 30,
                      alineacion: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El primero es el que más te cuesta hoy. '
                      'Arrastra o usa «Subir» y «Bajar».',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 17,
                        height: 1.3,
                        color: VecColores.gris,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ListaOrdenGigantes(
                    gigantes: _orden,
                    onCambio: (nueva) => setState(() => _orden = nueva),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: BotonVec(
                  texto: 'Continuar',
                  icono: Icons.arrow_forward_rounded,
                  expandido: true,
                  onPressed: _continuar,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
