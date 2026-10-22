import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/audio_engine.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Piezas del onboarding en el tema «papel recortado» (kit vec).
/// ═══════════════════════════════════════════════════════════════════════════

/// Ícono del kit para cada gigante (en lugar de emojis). Todos se pintan
/// del mismo color para no sesgar la elección.
const Map<String, String> iconosGigantesPapel = {
  'digital': 'telefono',
  'sexual': 'ojo',
  'health': 'pelota',
  'substances': 'huir',
  'mental': 'idea',
  'emotions': 'corazon',
};

/// Botón redondo para encender o apagar la música de fondo.
class BotonAudioPapel extends StatelessWidget {
  const BotonAudioPapel({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AudioEngine.I.bgmEnabled,
      builder: (context, encendida, _) {
        return Semantics(
          button: true,
          label: encendida ? 'Apagar música' : 'Encender música',
          child: GestureDetector(
            onTap: () async {
              HapticFeedback.mediumImpact();
              await AudioEngine.I.setBgmEnabled(!encendida);
            },
            child: CirculoIcono(
              icono: encendida
                  ? Icons.music_note_rounded
                  : Icons.music_off_rounded,
              color: encendida ? VecColores.mostaza : VecColores.cremaOscuro,
              colorIcono: encendida ? VecColores.papel : VecColores.gris,
              tamano: 48,
              sombra: encendida,
              giro: encendida ? -4 : 0,
            ),
          ),
        );
      },
    );
  }
}

/// Barra superior de los pasos: volver, chip del paso y progreso.
class EncabezadoPasoPapel extends StatelessWidget {
  const EncabezadoPasoPapel({
    super.key,
    required this.paso,
    required this.progreso,
    this.conAudio = true,
  });

  final String paso;
  final double progreso;
  final bool conAudio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Semantics(
                button: true,
                label: 'Volver',
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.maybePop(context);
                  },
                  child: CirculoIcono(
                    icono: Icons.arrow_back_rounded,
                    color: VecColores.cremaOscuro,
                    colorIcono: VecColores.tinta,
                    tamano: 44,
                    sombra: false,
                  ),
                ),
              ),
              const Spacer(),
              ChipVec(texto: paso, color: VecColores.mostaza),
              const Spacer(),
              if (conAudio)
                const BotonAudioPapel()
              else
                const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 18),
          BarraProgresoPapel(valor: progreso),
        ],
      ),
    );
  }
}

/// Barra de progreso de papel: casilla apagada con relleno terracota.
class BarraProgresoPapel extends StatelessWidget {
  const BarraProgresoPapel({super.key, required this.valor});
  final double valor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 14,
      decoration: BoxDecoration(
        color: VecColores.cremaOscuro,
        borderRadius: BorderRadius.circular(VecRadios.pildora),
      ),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: valor.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: VecColores.terracota,
            borderRadius: BorderRadius.circular(VecRadios.pildora),
          ),
        ),
      ),
    );
  }
}
