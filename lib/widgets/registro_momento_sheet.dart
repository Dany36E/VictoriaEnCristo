/// Hoja para registrar una tentación fuerte o una caída con sus detonantes.
library;

import 'package:flutter/material.dart';

import '../services/feedback_engine.dart';
import '../services/registro_momentos_service.dart';
import '../theme/app_theme_data.dart';

/// Abre la hoja. Devuelve el registro guardado o `null` si se canceló.
Future<RegistroMomento?> mostrarRegistroMomento(
  BuildContext context, {
  TipoMomento tipo = TipoMomento.tentacion,
}) {
  return showModalBottomSheet<RegistroMomento>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppThemeData.of(context).cardBg,
    builder: (_) => _RegistroMomentoSheet(tipoInicial: tipo),
  );
}

class _RegistroMomentoSheet extends StatefulWidget {
  const _RegistroMomentoSheet({required this.tipoInicial});
  final TipoMomento tipoInicial;

  @override
  State<_RegistroMomentoSheet> createState() => _RegistroMomentoSheetState();
}

class _RegistroMomentoSheetState extends State<_RegistroMomentoSheet> {
  late TipoMomento _tipo = widget.tipoInicial;
  bool _resistio = true;
  DateTime _fecha = DateTime.now();
  final Set<String> _emociones = {};
  final Set<String> _situaciones = {};
  String? _lugar;
  String? _dispositivo;
  bool _guardando = false;

  Future<void> _cambiarHora() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fecha),
      helpText: '¿A qué hora fue?',
    );
    if (hora == null || !mounted) return;
    final ahora = DateTime.now();
    var nueva = DateTime(
      ahora.year,
      ahora.month,
      ahora.day,
      hora.hour,
      hora.minute,
    );
    // Una hora "futura" se refiere a ayer (p. ej. registrar en la mañana lo
    // de la noche anterior).
    if (nueva.isAfter(ahora)) {
      nueva = DateTime(
        ahora.year,
        ahora.month,
        ahora.day - 1,
        hora.hour,
        hora.minute,
      );
    }
    setState(() => _fecha = nueva);
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final servicio = RegistroMomentosService.I;
    final registro = RegistroMomento(
      id: servicio.nuevoId(),
      fecha: _fecha,
      tipo: _tipo,
      resistio: _tipo == TipoMomento.tentacion ? _resistio : null,
      emociones: _emociones.toList(),
      situaciones: _situaciones.toList(),
      lugar: _lugar,
      dispositivo: _dispositivo,
    );
    await servicio.agregar(registro);
    FeedbackEngine.I.confirm();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop(registro);
    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          _tipo == TipoMomento.caida
              ? 'Gracias por tu honestidad. Esto te ayudará a prepararte; '
                    'la gracia de Dios es nueva cada mañana.'
              : (_resistio
                    ? 'Registrado. ¡Bien hecho por resistir!'
                    : 'Registrado. Sigue adelante: no estás solo.'),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _titulo(String texto) {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Semantics(
        header: true,
        child: Text(
          texto,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: t.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _chipsMultiples(List<String> opciones, Set<String> elegidas) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in opciones)
          FilterChip(
            label: Text(o),
            selected: elegidas.contains(o),
            onSelected: (v) => setState(() {
              v ? elegidas.add(o) : elegidas.remove(o);
            }),
          ),
      ],
    );
  }

  Widget _chipsUnico(
    List<String> opciones,
    String? elegida,
    ValueChanged<String?> alCambiar,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in opciones)
          ChoiceChip(
            label: Text(o),
            selected: elegida == o,
            onSelected: (v) => alCambiar(v ? o : null),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final hora =
        '${_fecha.hour.toString().padLeft(2, '0')}:'
        '${_fecha.minute.toString().padLeft(2, '0')}';
    final esHoy = _fecha.day == DateTime.now().day;
    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(
              'Registrar un momento',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: t.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Sin juicio: solo para conocerte mejor. Elige lo que aplique; '
              'todo es opcional.',
              style: TextStyle(color: t.textSecondary),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TipoMomento>(
              segments: [
                for (final tipo in TipoMomento.values)
                  ButtonSegment(value: tipo, label: Text(tipo.etiqueta)),
              ],
              selected: {_tipo},
              onSelectionChanged: (s) => setState(() => _tipo = s.first),
            ),
            if (_tipo == TipoMomento.tentacion)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _resistio,
                onChanged: (v) => setState(() => _resistio = v),
                title: Text(
                  '¿La venciste?',
                  style: TextStyle(color: t.textPrimary),
                ),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule_rounded),
              title: Text(
                '${esHoy ? 'Hoy' : 'Ayer'} a las $hora',
                style: TextStyle(color: t.textPrimary),
              ),
              trailing: TextButton(
                onPressed: _cambiarHora,
                child: const Text('Cambiar hora'),
              ),
            ),
            _titulo('¿Qué sentías?'),
            _chipsMultiples(CatalogoMomentos.emociones, _emociones),
            _titulo('¿Qué estaba pasando?'),
            _chipsMultiples(CatalogoMomentos.situaciones, _situaciones),
            _titulo('¿Dónde estabas?'),
            _chipsUnico(
              CatalogoMomentos.lugares,
              _lugar,
              (v) => setState(() => _lugar = v),
            ),
            _titulo('¿Con qué dispositivo?'),
            _chipsUnico(
              CatalogoMomentos.dispositivos,
              _dispositivo,
              (v) => setState(() => _dispositivo = v),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _guardando ? null : _guardar,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
