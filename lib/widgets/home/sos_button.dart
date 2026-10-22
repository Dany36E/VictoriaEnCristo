/// Botón de ayuda inmediata de Inicio (botón del kit que se hunde).
library;

import 'package:flutter/material.dart';
import '../../navigation/app_navigation.dart';
import '../../services/feedback_engine.dart';
import '../../vec/vec_widgets.dart';

class BreathingSosButton extends StatelessWidget {
  const BreathingSosButton({super.key});

  @override
  Widget build(BuildContext context) {
    return PopIn(
      retraso: const Duration(milliseconds: 300),
      child: BotonVec(
        texto: '¡Necesito ayuda!',
        iconoWidget: const IconoVec('mano_alto'),
        onPressed: () {
          FeedbackEngine.I.confirm();
          AppNavigation.openEmergency(context);
        },
      ),
    );
  }
}
