/// ═══════════════════════════════════════════════════════════════════════════
/// AVISAR A MI COMPAÑERO — un toque, con unos segundos para deshacer.
///
/// Usa el SOS de oración existente (Cloud Function `sendBattleSos`): llega a
/// todos los compañeros activos como "Necesito oración ahora". No hace falta
/// completar los 5 pasos de emergencia.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/battle_partner_service.dart';
import '../services/feedback_engine.dart';
import '../services/user_scoped_services.dart';
import '../vec/vec_tema.dart';

/// Fases del aviso.
enum EstadoAviso { inactivo, esperando, enviando, enviado, fallido }

/// Programa el envío y permite deshacerlo durante [ventana].
class AvisoCompaneroController {
  AvisoCompaneroController({
    required Future<int> Function() enviar,
    this.ventana = const Duration(seconds: 5),
  }) : _enviar = enviar;

  /// Instancia de la app (envía el SOS del Compañero de batalla).
  static final AvisoCompaneroController I = AvisoCompaneroController(
    enviar: () => BattlePartnerService.I.sendSos(),
  );

  final Future<int> Function() _enviar;
  final Duration ventana;

  final ValueNotifier<EstadoAviso> estado = ValueNotifier(EstadoAviso.inactivo);
  Timer? _timer;

  /// Inicia la cuenta regresiva. [alTerminar] recibe a cuántos compañeros
  /// se avisó (0 = no se pudo). Devuelve `false` si ya había uno en curso.
  bool programar({void Function(int enviados)? alTerminar}) {
    if (estado.value == EstadoAviso.esperando ||
        estado.value == EstadoAviso.enviando) {
      return false;
    }
    estado.value = EstadoAviso.esperando;
    _timer = Timer(ventana, () async {
      _timer = null;
      if (estado.value != EstadoAviso.esperando) return;
      estado.value = EstadoAviso.enviando;
      var enviados = 0;
      try {
        enviados = await _enviar();
      } catch (_) {
        enviados = 0;
      }
      estado.value = enviados > 0 ? EstadoAviso.enviado : EstadoAviso.fallido;
      alTerminar?.call(enviados);
    });
    return true;
  }

  /// Cancela el aviso si todavía no salió.
  bool deshacer() {
    if (estado.value != EstadoAviso.esperando) return false;
    _timer?.cancel();
    _timer = null;
    estado.value = EstadoAviso.inactivo;
    return true;
  }

  @visibleForTesting
  void reiniciar() {
    _timer?.cancel();
    _timer = null;
    estado.value = EstadoAviso.inactivo;
  }
}

/// ¿Tiene sentido mostrar el botón? (hay compañeros activos).
bool hayCompanerosParaAvisar() {
  try {
    return BattlePartnerService.I.activePartnerCount > 0;
  } catch (_) {
    return false;
  }
}

/// Carga los compañeros si aún no se cargaron (sin bloquear la pantalla).
void prepararAvisoCompanero() {
  // Sin Firebase (pruebas) o sin sesión: el botón simplemente no aparece.
  unawaited(
    Future<void>.sync(
      () => UserScopedServices.I.ensureBattlePartners(),
    ).catchError((Object e) {
      debugPrint('🤝 [AVISO] No se pudieron cargar los compañeros: $e');
    }),
  );
}

/// Un toque: avisa a los compañeros con 5 s para deshacer y confirma.
void avisarACompanero(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final servicio = BattlePartnerService.I;
  FeedbackEngine.I.confirm();

  if (servicio.remainingSosToday() <= 0) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Ya avisaste a tus compañeros hoy. Puedes escribirles desde '
          'Compañero de batalla; seguimos contigo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  final controller = AvisoCompaneroController.I;
  final segundos = controller.ventana.inSeconds;
  final programado = controller.programar(
    alTerminar: (enviados) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            enviados > 0
                ? 'Avisamos a $enviados compañero${enviados == 1 ? '' : 's'}. '
                      'No estás solo: están orando contigo.'
                : 'No pudimos avisar ahora. Revisa tu conexión o escríbele '
                      'directamente a tu compañero.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    },
  );
  if (!programado) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text('Avisaremos a tus compañeros en $segundos segundos…'),
      behavior: SnackBarBehavior.floating,
      duration: controller.ventana,
      action: SnackBarAction(
        label: 'Deshacer',
        onPressed: () {
          if (controller.deshacer()) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Aviso cancelado. No se envió nada.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    ),
  );
}

/// Botón "Avisar a mi compañero". Solo aparece si hay compañeros activos.
class BotonAvisarCompanero extends StatelessWidget {
  const BotonAvisarCompanero({super.key, this.compacto = false});

  /// Versión de texto (Inicio) en lugar de botón de papel.
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final BattlePartnerService servicio;
    try {
      servicio = BattlePartnerService.I;
    } catch (_) {
      return const SizedBox.shrink();
    }
    return ValueListenableBuilder(
      valueListenable: servicio.partnersNotifier,
      builder: (context, _, _) {
        if (!hayCompanerosParaAvisar()) return const SizedBox.shrink();
        return ValueListenableBuilder<EstadoAviso>(
          valueListenable: AvisoCompaneroController.I.estado,
          builder: (context, estado, _) {
            final ocupado =
                estado == EstadoAviso.esperando ||
                estado == EstadoAviso.enviando;
            final texto = switch (estado) {
              EstadoAviso.esperando => 'Avisando… (puedes deshacer)',
              EstadoAviso.enviando => 'Enviando aviso…',
              _ => 'Avisar a mi compañero',
            };
            return Semantics(
              button: true,
              label: 'Avisar a mi compañero',
              hint:
                  'Envía "Necesito oración ahora" a tus compañeros. '
                  'Tendrás $_segundos segundos para deshacer.',
              excludeSemantics: true,
              child: compacto
                  ? FilledButton.tonalIcon(
                      // Papel con borde: se lee sobre cualquier fondo de Inicio.
                      style: FilledButton.styleFrom(
                        backgroundColor: VecColores.papel,
                        foregroundColor: VecColores.tinta,
                        minimumSize: const Size(0, 48),
                        side: BorderSide(color: VecColores.lapiz),
                      ),
                      onPressed: ocupado
                          ? null
                          : () => avisarACompanero(context),
                      icon: const Icon(Icons.campaign_rounded),
                      label: Text(texto),
                    )
                  : OutlinedButton.icon(
                      onPressed: ocupado
                          ? null
                          : () => avisarACompanero(context),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      icon: const Icon(Icons.campaign_rounded),
                      label: Text(texto, textAlign: TextAlign.center),
                    ),
            );
          },
        );
      },
    );
  }

  static int get _segundos => AvisoCompaneroController.I.ventana.inSeconds;
}
