/// Atajos de Inicio: accesos directos que elige el usuario (por defecto
/// Biblia, Estudio bíblico y Apuntes). Los mismos ids abren las pantallas
/// desde el widget «Atajos» y los accesos del ícono de Android (rutas
/// `/atajo/<id>`).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../navigation/app_navigation.dart';
import '../../screens/battle_partner/battle_partner_screen.dart';
import '../../screens/bible/bible_home_screen.dart';
import '../../screens/bible/entradas_biblia.dart';
import '../../screens/bible/saved_verses_screen.dart';
import '../../screens/devotional_screen.dart';
import '../../screens/emergency_screen.dart';
import '../../screens/emotional_verse_jar_screen.dart';
import '../../screens/favorites_screen.dart';
import '../../screens/journal_screen.dart';
import '../../screens/learning/bible_order_screen.dart';
import '../../screens/learning/game_headbanz_screen.dart';
import '../../screens/learning/game_lightning_screen.dart';
import '../../screens/learning/game_race_screen.dart';
import '../../screens/learning/games_home_screen.dart';
import '../../screens/learning/learning_home_screen.dart';
import '../../screens/learning/mana_session_screen.dart';
import '../../screens/prayers_screen.dart';
import '../../screens/progress_screen.dart';
import '../../screens/sacred_alarms_screen.dart';
import '../../screens/verses_screen.dart';
import '../../screens/wall/wall_screen.dart';
import '../../services/atajos_service.dart';
import '../../services/audio_engine.dart';
import '../../services/widget_sync_service.dart';
import '../../theme/app_theme_data.dart';
import '../../utils/platform_capabilities.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';

/// Prefijo de las rutas con que el widget de Android pide abrir un atajo.
const String prefijoRutaAtajo = '/atajo/';

/// Pantallas que se abren tal cual.
final Map<String, WidgetBuilder> _pantallas = {
  'biblia': (_) => const BibleHomeScreen(),
  'guardados': (_) => const SavedVersesScreen(),
  'mapa_oracion': (_) => const JournalScreen(),
  'versiculos': (_) => const VersesScreen(),
  'frasco': (_) => const EmotionalVerseJarScreen(),
  'devocional': (_) => const DevotionalScreen(),
  'oraciones': (_) => const PrayersScreen(),
  'progreso': (_) => const ProgressScreen(),
  'favoritos': (_) => const FavoritesScreen(),
  'escuela': (_) => const LearningHomeScreen(),
  'companero': (_) => const BattlePartnerScreen(),
  'muro': (_) => const WallScreen(),
  'sos': (_) => const EmergencyScreen(),
  'campanas': (_) => const SacredAlarmsScreen(),
};

/// Juegos y prácticas de la Escuela del Reino: suenan con su música, como al
/// abrirlos desde la Escuela, y al volver regresa la de Inicio.
final Map<String, (WidgetBuilder, BgmContext)> _juegos = {
  'juegos': ((_) => const GamesHomeScreen(), BgmContext.learningHeadbanz),
  'carrera': ((_) => const GameRaceScreen(), BgmContext.learningHeadbanz),
  'duelo': ((_) => const GameLightningScreen(), BgmContext.learningDuel),
  'quien_soy': ((_) => const GameHeadbanzScreen(), BgmContext.learningHeadbanz),
  'preguntas': ((_) => const ManaSessionScreen(), BgmContext.learningQuiz),
  'orden_biblia': (
    (_) => const BibleOrderScreen(),
    BgmContext.learningBibleOrder,
  ),
};

/// Ids que [abrirAtajo] sabe abrir (para comprobar el catálogo en pruebas).
Set<String> get idsQueSeAbren => {
  'estudio',
  'apuntes',
  ..._pantallas.keys,
  ..._juegos.keys,
};

/// Abre la pantalla de un atajo. Devuelve `false` si el id no existe.
bool abrirAtajo(BuildContext context, String id) {
  if (id == 'estudio') {
    EntradasBiblia.abrirEstudio(context);
    return true;
  }
  if (id == 'apuntes') {
    EntradasBiblia.abrirApuntes(context);
    return true;
  }
  final juego = _juegos[id];
  if (juego != null) {
    _abrirJuego(context, juego.$1, juego.$2);
    return true;
  }
  final pantalla = _pantallas[id];
  if (pantalla == null) return false;
  AppNavigation.push<void>(context, pantalla);
  return true;
}

Future<void> _abrirJuego(
  BuildContext context,
  WidgetBuilder pantalla,
  BgmContext musica,
) async {
  AudioEngine.I.switchBgmContext(musica);
  await AppNavigation.push<void>(context, pantalla);
  AudioEngine.I.switchBgmContext(BgmContext.home);
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
    return TextButton.icon(
      onPressed: () => mostrarEditorAtajos(context),
      icon: Icon(Icons.tune_rounded, size: 18, color: VecColores.azul),
      label: Text(
        'Editar',
        style: TextStyle(
          fontFamily: VecFuentes.texto,
          fontSize: 18,
          color: VecColores.azul,
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
    final contenido = _papel();
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
                style: TextStyle(
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
}

/// Sin atajos elegidos: invitación a agregarlos.
class _SinAtajos extends StatelessWidget {
  const _SinAtajos();

  @override
  Widget build(BuildContext context) {
    return BotonVec(
      texto: 'Agregar atajos',
      icono: Icons.add_rounded,
      color: VecColores.azul,
      expandido: true,
      onPressed: () => mostrarEditorAtajos(context),
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

  void _guardar() => AtajosService.I.guardar(_elegidos);

  void _agregar(String id) {
    if (_elegidos.length >= AtajosService.maximo) return;
    setState(() => _elegidos.add(id));
    _guardar();
  }

  void _quitar(String id) {
    setState(() => _elegidos.remove(id));
    _guardar();
  }

  void _mover(int desde, int hasta) {
    setState(() {
      if (hasta > desde) hasta--;
      _elegidos.insert(hasta, _elegidos.removeAt(desde));
    });
    _guardar();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final tema = Theme.of(context);
    final lleno = _elegidos.length >= AtajosService.maximo;
    final telefono = PlatformCapabilities.supportsHomeWidgets;
    const titulo = TituloVec('Tus atajos', tamano: 26);
    final elegidos = _elegidos
        .map(AtajosService.porId)
        .whereType<Atajo>()
        .toList(growable: false);
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
              'Elige hasta ${AtajosService.maximo} y arrástralos para '
              'cambiar el orden.'
              '${telefono ? ' Los primeros ${AtajosService.maximoTelefono} '
                        'también salen en el widget y al mantener presionado '
                        'el ícono de la app.' : ''}',
              style: tema.textTheme.bodyMedium,
            ),
            _Grupo('En Inicio (${elegidos.length} de ${AtajosService.maximo})'),
            if (elegidos.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Todavía no tienes atajos. Agrega los que más uses.',
                  style: tema.textTheme.bodyMedium,
                ),
              ),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              // onReorderItem llegó en Flutter 3.44 y el CI visual compila
              // con 3.41: se mantiene onReorder mientras convivan ambos.
              // ignore: deprecated_member_use
              onReorder: _mover,
              children: [
                for (var i = 0; i < elegidos.length; i++)
                  _FilaAtajo(
                    key: ValueKey(elegidos[i].id),
                    atajo: elegidos[i],
                    subtitulo: telefono && i < AtajosService.maximoTelefono
                        ? 'También en el teléfono'
                        : null,
                    accion: IconButton(
                      tooltip: 'Quitar ${elegidos[i].titulo}',
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                      color: VecColores.terracota,
                      onPressed: () => _quitar(elegidos[i].id),
                    ),
                    arrastre: ReorderableDragStartListener(
                      index: i,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle_rounded),
                      ),
                    ),
                  ),
              ],
            ),
            for (final grupo in AtajosService.grupos)
              ..._disponibles(grupo, lleno, t),
            if (telefono) ...[
              const SizedBox(height: 16),
              const _BotonWidgetTelefono(),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _disponibles(String grupo, bool lleno, AppThemeData t) {
    final libres = AtajosService.catalogo
        .where((a) => a.grupo == grupo && !_elegidos.contains(a.id))
        .toList(growable: false);
    if (libres.isEmpty) return const [];
    return [
      _Grupo(grupo),
      for (final atajo in libres)
        _FilaAtajo(
          atajo: atajo,
          habilitado: !lleno,
          onTap: () => _agregar(atajo.id),
          accion: IconButton(
            tooltip: 'Agregar ${atajo.titulo}',
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: VecColores.azul,
            onPressed: lleno ? null : () => _agregar(atajo.id),
          ),
        ),
    ];
  }
}

class _Grupo extends StatelessWidget {
  const _Grupo(this.texto);

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 4),
      child: Semantics(header: true, child: EtiquetaSeccion(texto)),
    );
  }
}

class _FilaAtajo extends StatelessWidget {
  const _FilaAtajo({
    super.key,
    required this.atajo,
    required this.accion,
    this.arrastre,
    this.subtitulo,
    this.habilitado = true,
    this.onTap,
  });

  final Atajo atajo;
  final Widget accion;
  final Widget? arrastre;
  final String? subtitulo;
  final bool habilitado;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final icono = Image.asset(
      atajo.dibujo,
      width: 40,
      height: 40,
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    );
    return ListTile(
      contentPadding: EdgeInsets.zero,
      enabled: habilitado,
      onTap: onTap,
      leading: SizedBox(width: 44, child: Center(child: icono)),
      title: Text(atajo.titulo),
      subtitle: subtitulo == null ? null : Text(subtitulo!),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [accion, ?arrastre],
      ),
    );
  }
}

class _BotonWidgetTelefono extends StatelessWidget {
  const _BotonWidgetTelefono();

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
    return BotonVec(
      texto: 'Agregar widget de atajos',
      icono: Icons.widgets_outlined,
      color: VecColores.verde,
      expandido: true,
      onPressed: () => _pedir(context),
    );
  }
}
