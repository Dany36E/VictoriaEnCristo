/// ═══════════════════════════════════════════════════════════════════════════
/// AYUDA EN CRISIS — líneas de ayuda que se pueden marcar con un toque y la
/// hoja compasiva que aparece si alguien escribe sobre hacerse daño.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../screens/emergency_screen.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../vec/vec_tema.dart';
import 'aviso_companero.dart';

/// Una línea de ayuda en crisis.
class LineaCrisis {
  /// País o región.
  final String pais;

  /// Nombre del servicio.
  final String servicio;

  /// Cómo se muestra el número.
  final String numero;

  /// Lo que se marca (sin espacios).
  final String marcar;

  const LineaCrisis({
    required this.pais,
    required this.servicio,
    required this.numero,
    required this.marcar,
  });

  Uri get uri => Uri(scheme: 'tel', path: marcar);
}

/// Líneas de ayuda gratuitas (revisadas en octubre de 2026). Si una cambia,
/// actualízala aquí: la usan Emergencia, el Muro y la hoja de crisis.
const List<LineaCrisis> kLineasCrisis = [
  LineaCrisis(
    pais: 'México',
    servicio: 'Línea de la Vida',
    numero: '800 911 2000',
    marcar: '8009112000',
  ),
  LineaCrisis(
    pais: 'España',
    servicio: 'Línea 024',
    numero: '024',
    marcar: '024',
  ),
  LineaCrisis(
    pais: 'EE. UU. y Canadá',
    servicio: 'Línea 988',
    numero: '988',
    marcar: '988',
  ),
  LineaCrisis(
    pais: 'Argentina',
    servicio: 'Centro de Asistencia al Suicida',
    numero: '135',
    marcar: '135',
  ),
  LineaCrisis(
    pais: 'Colombia (Bogotá)',
    servicio: 'Línea 106',
    numero: '106',
    marcar: '106',
  ),
  LineaCrisis(
    pais: 'Chile',
    servicio: 'Prevención del suicidio',
    numero: '*4141',
    marcar: '*4141',
  ),
];

/// Abre el marcador del teléfono con [linea].
Future<void> marcarLinea(BuildContext context, LineaCrisis linea) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var ok = false;
  try {
    ok = await launchUrl(linea.uri);
  } catch (_) {
    ok = false;
  }
  if (!ok) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text('No se pudo abrir el teléfono. Marca ${linea.numero}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Fila de una línea de ayuda: un toque marca el número.
class LineaCrisisTile extends StatelessWidget {
  const LineaCrisisTile({super.key, required this.linea});

  final LineaCrisis linea;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Semantics(
      button: true,
      label: 'Llamar a ${linea.servicio}, ${linea.pais}: ${linea.numero}',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => marcarLinea(context, linea),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.phone_rounded,
                  color: VecColores.terracota,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        linea.pais,
                        style: AppDesignSystem.bodyMedium(
                          context,
                          color: t.textPrimary,
                        ),
                      ),
                      Text(
                        linea.servicio,
                        style: AppDesignSystem.labelSmall(
                          context,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  linea.numero,
                  style: AppDesignSystem.bodyLarge(
                    context,
                    color: VecColores.terracota,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lista de líneas + recordatorio de emergencias.
class ListaLineasCrisis extends StatelessWidget {
  const ListaLineasCrisis({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final linea in kLineasCrisis) LineaCrisisTile(linea: linea),
        const SizedBox(height: 8),
        Text(
          'Si estás en peligro inmediato, llama al número de emergencias '
          'de tu país (911 en gran parte de América, 112 en Europa).',
          style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
        ),
      ],
    );
  }
}

/// Hoja compasiva cuando alguien escribe sobre hacerse daño (Muro) o pide
/// ayuda urgente. No publica nada; ofrece ayuda inmediata.
Future<void> mostrarAyudaCrisis(BuildContext context, {String? mensaje}) {
  prepararAvisoCompanero();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppThemeData.of(context).cardBg,
    builder: (ctx) {
      final t = AppThemeData.of(ctx);
      return SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
            children: [
              Semantics(
                header: true,
                child: Text(
                  'No estás solo',
                  style: AppDesignSystem.headlineSmall(
                    ctx,
                    color: t.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                mensaje ??
                    'Lo que escribiste importa, y también tú. Por cuidado, no '
                        'lo publicamos en el Muro. Si estás pensando en hacerte '
                        'daño, habla hoy con alguien: hay personas listas para '
                        'escucharte ahora mismo, sin juzgarte.',
                style: AppDesignSystem.bodyLarge(ctx, color: t.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                '«Cercano está el Señor a los quebrantados de corazón» '
                '(Salmo 34:18).',
                style: AppDesignSystem.bodyMedium(ctx, color: t.textSecondary),
              ),
              const SizedBox(height: 18),
              const BotonAvisarCompanero(),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const EmergencyScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.health_and_safety_rounded),
                label: const Text('Abrir ayuda de emergencia'),
              ),
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  'Líneas de ayuda (toca para llamar)',
                  style: AppDesignSystem.labelLarge(
                    ctx,
                    color: t.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const ListaLineasCrisis(),
            ],
          ),
        ),
      );
    },
  );
}
