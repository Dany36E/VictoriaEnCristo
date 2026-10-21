/// Atajos de Inicio: accesos directos que elige el usuario (por defecto
/// Biblia, Estudio bíblico y Apuntes). Los mismos ids abren las pantallas
/// desde el widget «Atajos» de Android (rutas `/atajo/<id>`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../navigation/app_navigation.dart';
import '../../screens/bible/entradas_biblia.dart';
import '../../services/atajos_service.dart';
import '../../services/widget_sync_service.dart';
import '../../theme/app_theme_data.dart';
import '../../utils/platform_capabilities.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';

/// Prefijo de las rutas con que el widget de Android pide abrir un atajo.
const String prefijoRutaAtajo = '/atajo/';

/// Abre la pantalla de un atajo. Devuelve `false` si el id no existe.
bool abrirAtajo(BuildContext context, String id) {
  final Future<void> Function(BuildContext)? accion = switch (id) {
    'biblia' => AppNavigation.openBible,
    'estudio' => EntradasBiblia.abrirEstudio,
    'apuntes' => EntradasBiblia.abrirApuntes,
    'escuela' => AppNavigation.openLearning,
    'diario' => AppNavigation.openJournal,
    'devocional' => AppNavigation.openDevotional,
    'oracion' => AppNavigation.openPrayers,
    'versiculos' => AppNavigation.openVerses,
    'progreso' => AppNavigation.openProgress,
    'muro' => AppNavigation.openWall,
    _ => null,
  };
  if (accion == null) return false;
  accion(context);
  return true;
}

/// Cuadrícula de atajos de Inicio: tres por fila, o dos cuando la letra
/// grande no cabe en el ancho del teléfono.
class AtajosInicio extends StatelessWidget {
  const AtajosInicio({super.key});

  static const double _separacion = 12;

  @override
  Widget build(BuildContext context) {
    final escala = MediaQuery.textScalerOf(context).scale(1);
    return ValueListenableBuilder<List<String>>(
      valueListenable: AtajosService.I.elegidos,
      builder: (context, ids, _) {
        final atajos = ids
            .map(AtajosService.porId)
            .whereType<Atajo>()
            .toList(growable: false);
        if (atajos.isEmpty) return const _SinAtajos();
        return LayoutBuilder(
          builder: (context, c) {
            final columnas = c.maxWidth / escala >= 270 ? 3 : 2;
            final filas = <Widget>[];
            for (var i = 0; i < atajos.length; i += columnas) {
              final fila = atajos.skip(i).take(columnas).toList();
              filas.add(
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var j = 0; j < columnas; j++) ...[
                        if (j > 0) const SizedBox(width: _separacion),
                        Expanded(
                          child: j < fila.length
                              ? _TarjetaAtajo(atajo: fila[j], indice: i + j)
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < filas.length; i++) ...[
                  if (i > 0) const SizedBox(height: _separacion),
                  filas[i],
                ],
              ],
            );
          },
        );
      },
    );
  }
}

/// Botón «Editar» para el encabezado de la sección de atajos.
class BotonEditarAtajos extends StatelessWidget {
  const BotonEditarAtajos({super.key});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return TextButton.icon(
      onPressed: () => mostrarEditorAtajos(context),
      icon: Icon(
        Icons.tune_rounded,
        size: 18,
        color: t.isPaper ? VecColores.azul : t.accent,
      ),
      label: Text(
        'Editar',
        style: t.isPaper
            ? const TextStyle(
                fontFamily: VecFuentes.texto,
                fontSize: 18,
                color: VecColores.azul,
              )
            : TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: t.accent,
              ),
      ),
    );
  }
}

class _TarjetaAtajo extends StatefulWidget {
  const _TarjetaAtajo({required this.atajo, required this.indice});

  final Atajo atajo;
  final int indice;

  @override
  State<_TarjetaAtajo> createState() => _TarjetaAtajoState();
}

class _TarjetaAtajoState extends State<_TarjetaAtajo> {
  bool _presionado = false;

  void _abrir() {
    HapticFeedback.lightImpact();
    abrirAtajo(context, widget.atajo.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final contenido = t.isPaper ? _papel() : _normal(t);
    return Semantics(
      button: true,
      label: widget.atajo.titulo,
      onTap: _abrir,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _presionado = true),
        onTapUp: (_) => setState(() => _presionado = false),
        onTapCancel: () => setState(() => _presionado = false),
        onTap: _abrir,
        child: AnimatedScale(
          scale: _presionado ? 0.96 : 1,
          duration: const Duration(milliseconds: 110),
          child: contenido,
        ),
      ),
    );
  }

  /// Hojita de papel con el dibujo del atajo, un poco girada.
  Widget _papel() {
    final giro = widget.indice.isEven ? -1.5 : 1.5;
    return PopIn(
      retraso: Duration(milliseconds: 60 * widget.indice),
      child: Transform.rotate(
        angle: giro * math.pi / 180,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
          decoration: BoxDecoration(
            color: VecColores.papel,
            borderRadius: BorderRadius.circular(VecRadios.m),
            boxShadow: VecSombras.papel,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                widget.atajo.dibujo,
                height: 58,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                filterQuality: FilterQuality.medium,
              ),
              const SizedBox(height: 6),
              Text(
                widget.atajo.titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: VecFuentes.titulo,
                  fontSize: 15,
                  height: 1.1,
                  color: VecColores.tinta,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _normal(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.cardBorder, width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: t.accentSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(widget.atajo.icono, color: t.accent, size: 24),
          ),
          const SizedBox(height: 8),
          Text(
            widget.atajo.titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Sin atajos elegidos: invitación a agregarlos.
class _SinAtajos extends StatelessWidget {
  const _SinAtajos();

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    if (t.isPaper) {
      return BotonVec(
        texto: 'Agregar atajos',
        icono: Icons.add_rounded,
        color: VecColores.azul,
        expandido: true,
        onPressed: () => mostrarEditorAtajos(context),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => mostrarEditorAtajos(context),
      icon: const Icon(Icons.add_rounded),
      label: const Text('Agregar atajos'),
      style: OutlinedButton.styleFrom(
        foregroundColor: t.accent,
        side: BorderSide(color: t.cardBorder),
        minimumSize: const Size.fromHeight(48),
      ),
    );
  }
}

/// Hoja para elegir qué atajos aparecen en Inicio y en qué orden.
Future<void> mostrarEditorAtajos(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _EditorAtajos(),
  );
}

class _EditorAtajos extends StatefulWidget {
  const _EditorAtajos();

  @override
  State<_EditorAtajos> createState() => _EditorAtajosState();
}

class _EditorAtajosState extends State<_EditorAtajos> {
  late final List<String> _elegidos = [...AtajosService.I.elegidos.value];

  void _alternar(String id) {
    setState(() {
      if (!_elegidos.remove(id) && _elegidos.length < AtajosService.maximo) {
        _elegidos.add(id);
      }
    });
    AtajosService.I.guardar(_elegidos);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final tema = Theme.of(context);
    final lleno = _elegidos.length >= AtajosService.maximo;
    final titulo = t.isPaper
        ? const TituloVec('Tus atajos', tamano: 26)
        : Text('Tus atajos', style: tema.textTheme.titleLarge);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            titulo,
            const SizedBox(height: 4),
            Text(
              'Elige hasta ${AtajosService.maximo}. Aparecen en Inicio en el '
              'orden en que los elijas.',
              style: tema.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            for (final atajo in AtajosService.catalogo)
              _OpcionAtajo(
                atajo: atajo,
                orden: _elegidos.indexOf(atajo.id) + 1,
                habilitado: _elegidos.contains(atajo.id) || !lleno,
                onTap: () => _alternar(atajo.id),
              ),
            if (PlatformCapabilities.supportsHomeWidgets) ...[
              const SizedBox(height: 16),
              Text(
                'También puedes poner Biblia, Estudio bíblico y Apuntes en la '
                'pantalla de inicio del teléfono.',
                style: tema.textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              _BotonWidgetTelefono(papel: t.isPaper),
            ],
          ],
        ),
      ),
    );
  }
}

class _OpcionAtajo extends StatelessWidget {
  const _OpcionAtajo({
    required this.atajo,
    required this.orden,
    required this.habilitado,
    required this.onTap,
  });

  final Atajo atajo;

  /// Posición en Inicio (1, 2, …) o 0 si no está elegido.
  final int orden;
  final bool habilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final elegido = orden > 0;
    final color = t.isPaper ? VecColores.azul : t.accent;
    final icono = t.isPaper
        ? Image.asset(
            atajo.dibujo,
            width: 40,
            height: 40,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          )
        : Icon(atajo.icono, color: t.accent);
    return Semantics(
      label: elegido
          ? '${atajo.titulo}, atajo $orden en Inicio'
          : '${atajo.titulo}, no está en Inicio',
      checked: elegido,
      enabled: habilitado,
      onTap: habilitado ? onTap : null,
      excludeSemantics: true,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: habilitado,
        onTap: onTap,
        leading: SizedBox(width: 44, child: Center(child: icono)),
        title: Text(atajo.titulo),
        trailing: elegido
            ? CircleAvatar(
                radius: 14,
                backgroundColor: color,
                child: Text(
                  '$orden',
                  style: TextStyle(
                    color: t.isPaper ? VecColores.papel : t.scaffoldBg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            : Icon(Icons.add_circle_outline_rounded, color: color),
      ),
    );
  }
}

class _BotonWidgetTelefono extends StatelessWidget {
  const _BotonWidgetTelefono({required this.papel});

  final bool papel;

  Future<void> _pedir(BuildContext context) async {
    final ok = await WidgetSyncService.I.requestAtajosPin();
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tu teléfono no permite agregarlo desde aquí. Mantén presionada la '
          'pantalla de inicio, elige Widgets y busca «Atajos».',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (papel) {
      return BotonVec(
        texto: 'Agregar widget de atajos',
        icono: Icons.widgets_outlined,
        color: VecColores.verde,
        expandido: true,
        onPressed: () => _pedir(context),
      );
    }
    return FilledButton.icon(
      onPressed: () => _pedir(context),
      icon: const Icon(Icons.widgets_outlined),
      label: const Text('Agregar widget de atajos'),
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    );
  }
}
