import 'package:flutter/material.dart';

import '../services/feedback_engine.dart';
import '../services/onboarding_service.dart';
import '../vec/vec_tema.dart';

/// Lista de gigantes para ordenar por prioridad (índice 0 = el que más
/// cuesta hoy). Se arrastra desde el asa grande o con los botones
/// accesibles «Subir»/«Bajar».
///
/// Se usa en el onboarding («Ordena tus gigantes») y en «Mis gigantes».
class ListaOrdenGigantes extends StatelessWidget {
  const ListaOrdenGigantes({
    super.key,
    required this.gigantes,
    required this.onCambio,
    this.pieDeItem,
    this.dentroDeScroll = false,
  });

  /// Ids de gigantes en el orden actual.
  final List<String> gigantes;

  /// Recibe la lista reordenada.
  final ValueChanged<List<String>> onCambio;

  /// Contenido extra bajo cada gigante (p. ej. frecuencia en el editor).
  final Widget Function(String id)? pieDeItem;

  /// true si la lista va dentro de otro scroll (se encoge y no desplaza).
  final bool dentroDeScroll;

  void _mover(int desde, int hasta) {
    if (hasta < 0 || hasta >= gigantes.length || desde == hasta) return;
    FeedbackEngine.I.select();
    final nueva = List<String>.from(gigantes);
    final id = nueva.removeAt(desde);
    nueva.insert(hasta, id);
    onCambio(nueva);
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      buildDefaultDragHandles: false,
      shrinkWrap: dentroDeScroll,
      physics: dentroDeScroll ? const NeverScrollableScrollPhysics() : null,
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: gigantes.length,
      onReorder: (desde, hasta) {
        if (hasta > desde) hasta -= 1;
        _mover(desde, hasta);
      },
      itemBuilder: (context, i) {
        final id = gigantes[i];
        return Padding(
          key: ValueKey('orden-$id'),
          padding: const EdgeInsets.only(bottom: 12),
          child: _ItemOrden(
            id: id,
            posicion: i,
            total: gigantes.length,
            onSubir: i > 0 ? () => _mover(i, i - 1) : null,
            onBajar: i < gigantes.length - 1 ? () => _mover(i, i + 1) : null,
            pie: pieDeItem?.call(id),
          ),
        );
      },
    );
  }
}

class _ItemOrden extends StatelessWidget {
  const _ItemOrden({
    required this.id,
    required this.posicion,
    required this.total,
    required this.onSubir,
    required this.onBajar,
    this.pie,
  });

  final String id;
  final int posicion;
  final int total;
  final VoidCallback? onSubir;
  final VoidCallback? onBajar;
  final Widget? pie;

  @override
  Widget build(BuildContext context) {
    final nombre = OnboardingService.getGiantName(id);
    final esPrimero = posicion == 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: VecColores.papel,
        borderRadius: BorderRadius.circular(VecRadios.m),
        border: Border.all(
          color: esPrimero ? VecColores.terracota : VecColores.cremaOscuro,
          width: esPrimero ? 3 : 2,
        ),
        boxShadow: VecSombras.papel,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Semantics(
                label: 'Lugar ${posicion + 1} de $total',
                excludeSemantics: true,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: esPrimero
                        ? VecColores.terracota
                        : VecColores.cremaOscuro,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${posicion + 1}°',
                    style: TextStyle(
                      fontFamily: VecFuentes.titulo,
                      fontSize: 19,
                      color: esPrimero ? VecColores.papel : VecColores.tinta,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      style: TextStyle(
                        fontFamily: VecFuentes.titulo,
                        fontSize: 18,
                        height: 1.1,
                        color: VecColores.tinta,
                      ),
                    ),
                    if (esPrimero && total > 1)
                      Text(
                        'El que más te cuesta',
                        style: TextStyle(
                          fontFamily: VecFuentes.texto,
                          fontSize: 15,
                          color: VecColores.terracota,
                        ),
                      ),
                  ],
                ),
              ),
              if (total > 1)
                ReorderableDragStartListener(
                  index: posicion,
                  child: Semantics(
                    label: 'Arrastrar para ordenar $nombre',
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.drag_indicator_rounded,
                        size: 36,
                        color: VecColores.gris,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (total > 1)
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                if (onSubir != null)
                  TextButton.icon(
                    key: ValueKey('subir-$id'),
                    onPressed: onSubir,
                    style: TextButton.styleFrom(
                      foregroundColor: VecColores.tinta,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 22),
                    label: Text(
                      'Subir',
                      semanticsLabel: 'Subir $nombre',
                      style: const TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 16,
                      ),
                    ),
                  ),
                if (onBajar != null)
                  TextButton.icon(
                    key: ValueKey('bajar-$id'),
                    onPressed: onBajar,
                    style: TextButton.styleFrom(
                      foregroundColor: VecColores.tinta,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.arrow_downward_rounded, size: 22),
                    label: Text(
                      'Bajar',
                      semanticsLabel: 'Bajar $nombre',
                      style: const TextStyle(
                        fontFamily: VecFuentes.texto,
                        fontSize: 16,
                      ),
                    ),
                  ),
              ],
            ),
          if (pie != null) ...[const SizedBox(height: 8), pie!],
        ],
      ),
    );
  }
}
