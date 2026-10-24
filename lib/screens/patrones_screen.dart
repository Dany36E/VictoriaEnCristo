/// ═══════════════════════════════════════════════════════════════════════════
/// MIS PATRONES — cuándo y por qué llegan las tentaciones.
///
/// Junta los momentos registrados (tentaciones fuertes y caídas) con los
/// detonantes anotados en el diario. Muestra horas y días de más riesgo, los
/// detonantes más repetidos y cómo cambian las emociones semana a semana.
/// Cada gráfica tiene su resumen en texto (lectores de pantalla y quien
/// prefiera leer). Solo el usuario ve esto.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/feedback_engine.dart';
import '../services/journal_service.dart';
import '../services/registro_momentos_service.dart';
import '../theme/app_theme_data.dart';
import '../utils/analisis_patrones.dart';
import '../vec/vec_tema.dart';
import '../vec/vec_widgets.dart';
import '../widgets/registro_momento_sheet.dart';

class PatronesScreen extends StatefulWidget {
  const PatronesScreen({super.key});

  @override
  State<PatronesScreen> createState() => _PatronesScreenState();
}

class _PatronesScreenState extends State<PatronesScreen> {
  final _servicio = RegistroMomentosService.I;

  @override
  void initState() {
    super.initState();
    unawaited(_servicio.cargar());
  }

  List<EventoPatron> _eventos(List<RegistroMomento> registros) {
    final eventos = <EventoPatron>[
      for (final r in registros)
        EventoPatron(
          fecha: r.fecha,
          caida: r.tipo == TipoMomento.caida,
          etiquetas: r.detonantes,
        ),
    ];
    // Detonantes que ya anotaste en el diario.
    for (final e in JournalService().entries) {
      if (e.triggers.isEmpty) continue;
      eventos.add(
        EventoPatron(
          fecha: e.date,
          caida: !e.hadVictory,
          etiquetas: e.triggers,
        ),
      );
    }
    return eventos;
  }

  Future<void> _registrar() async {
    FeedbackEngine.I.tap();
    await mostrarRegistroMomento(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Mis patrones')),
      body: SafeArea(
        child: ValueListenableBuilder<List<RegistroMomento>>(
          valueListenable: _servicio.registros,
          builder: (context, registros, _) {
            final p = analizarPatrones(
              _eventos(registros),
              emociones: CatalogoMomentos.emociones.toSet(),
              hoy: DateTime.now(),
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
              children: [
                Text(
                  'Conocer tus momentos difíciles no es para culparte: es '
                  'para prepararte. Solo tú ves esto.',
                  style: TextStyle(
                    fontFamily: VecFuentes.texto,
                    fontSize: 17,
                    height: 1.25,
                    color: VecColores.gris,
                  ),
                ),
                const SizedBox(height: 14),
                BotonVec(
                  texto: 'Registrar un momento',
                  icono: Icons.add_rounded,
                  expandido: true,
                  onPressed: _registrar,
                ),
                const SizedBox(height: 22),
                if (p.vacio)
                  _vacio()
                else ...[
                  _resumen(p),
                  const SizedBox(height: 18),
                  _tarjetaGrafica(
                    titulo: 'Por hora del día',
                    resumen: p.horaPico == null
                        ? ''
                        : 'Hora de más riesgo: '
                              '${textoFranjaHora(p.horaPico!)} '
                              '(${p.porHora[p.horaPico!]} registros).',
                    grafica: BarrasPatron(
                      valores: p.porHora,
                      etiqueta: (i) => '${i}h',
                      etiquetasVisibles: const {0, 6, 12, 18, 23},
                      descripcion: (i, n) => '${textoFranjaHora(i)}: $n',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _tarjetaGrafica(
                    titulo: 'Por día de la semana',
                    resumen: p.diaPico == null
                        ? ''
                        : 'Día de más riesgo: ${kDiasSemana[p.diaPico!]} '
                              '(${p.porDia[p.diaPico!]} registros).',
                    grafica: BarrasPatron(
                      valores: p.porDia,
                      etiqueta: (i) => kDiasSemana[i].substring(0, 2),
                      etiquetasVisibles: const {0, 1, 2, 3, 4, 5, 6},
                      descripcion: (i, n) => '${kDiasSemana[i]}: $n',
                    ),
                  ),
                  const SizedBox(height: 18),
                  _detonantes(p),
                  if (p.emocionesPorSemana.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _emociones(p),
                  ],
                  const SizedBox(height: 18),
                  _recientes(registros),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  TextStyle get _texto => TextStyle(
    fontFamily: VecFuentes.texto,
    fontSize: 17,
    height: 1.25,
    color: VecColores.tinta,
  );

  Widget _vacio() {
    return TarjetaPapel(
      child: Text(
        'Todavía no hay registros. Cuando sientas una tentación fuerte o '
        'tengas una caída, anótalo aquí (o marca detonantes en tu diario). '
        'Con unos cuantos registros verás tus patrones.',
        style: _texto,
      ),
    );
  }

  Widget _resumen(Patrones p) {
    final top = p.detonantes.take(3).map((e) => e.key).join(', ');
    return TarjetaPapel(
      child: Semantics(
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TituloVec('Lo que vemos', tamano: 22),
            const SizedBox(height: 8),
            Text(
              '${p.total} ${p.total == 1 ? 'registro' : 'registros'}'
              '${p.caidas > 0 ? ' · ${p.caidas} ${p.caidas == 1 ? 'caída' : 'caídas'}' : ''}.',
              style: _texto,
            ),
            if (top.isNotEmpty)
              Text('Lo que más se repite: $top.', style: _texto),
            const SizedBox(height: 6),
            Text(
              'Plan: en esas horas y situaciones, ten a mano a tu compañero '
              'y el botón de ayuda.',
              style: _texto.copyWith(color: VecColores.gris),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaGrafica({
    required String titulo,
    required String resumen,
    required Widget grafica,
  }) {
    return TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(header: true, child: TituloVec(titulo, tamano: 20)),
          const SizedBox(height: 4),
          if (resumen.isNotEmpty) Text(resumen, style: _texto),
          const SizedBox(height: 12),
          grafica,
        ],
      ),
    );
  }

  Widget _detonantes(Patrones p) {
    final top = p.detonantes.take(6).toList();
    final max = top.isEmpty ? 1 : top.first.value;
    return TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const TituloVec('Detonantes más frecuentes', tamano: 20),
          ),
          const SizedBox(height: 10),
          if (top.isEmpty) Text('Aún no anotaste detonantes.', style: _texto),
          for (final e in top)
            Semantics(
              label:
                  '${e.key}: ${e.value} '
                  '${e.value == 1 ? 'vez' : 'veces'}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(e.key, style: _texto)),
                        Text('${e.value}', style: _texto),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LayoutBuilder(
                      builder: (context, c) => Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: c.maxWidth * e.value / max,
                          height: 8,
                          decoration: BoxDecoration(
                            color: VecColores.terracota,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _emociones(Patrones p) {
    final semanas = p.emocionesPorSemana.values.first.length;
    return TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const TituloVec('Emociones semana a semana', tamano: 20),
          ),
          const SizedBox(height: 4),
          Text(
            'Últimas $semanas semanas; la barra de la derecha es esta semana.',
            style: _texto.copyWith(color: VecColores.gris, fontSize: 15),
          ),
          const SizedBox(height: 10),
          for (final e in p.emocionesPorSemana.entries) ...[
            Text(e.key, style: _texto),
            const SizedBox(height: 4),
            BarrasPatron(
              valores: e.value,
              alto: 44,
              etiqueta: (i) => i == semanas - 1 ? 'esta' : '',
              etiquetasVisibles: {semanas - 1},
              descripcion: (i, n) {
                final hace = semanas - 1 - i;
                final cuando = hace == 0
                    ? 'esta semana'
                    : 'hace $hace ${hace == 1 ? 'semana' : 'semanas'}';
                return '$cuando: $n';
              },
              nombre: e.key,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _recientes(List<RegistroMomento> registros) {
    if (registros.isEmpty) return const SizedBox.shrink();
    final t = AppThemeData.of(context);
    return TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: const TituloVec('Tus registros', tamano: 20),
          ),
          for (final r in registros.take(10))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${r.tipo.etiqueta}'
                '${r.resistio == true ? ' (la venciste)' : ''}',
                style: TextStyle(color: t.textPrimary),
              ),
              subtitle: Text(
                '${r.fecha.day}/${r.fecha.month} '
                '${r.fecha.hour.toString().padLeft(2, '0')}:'
                '${r.fecha.minute.toString().padLeft(2, '0')}'
                '${r.detonantes.isEmpty ? '' : ' · ${r.detonantes.join(', ')}'}',
                style: TextStyle(color: t.textSecondary),
              ),
              trailing: IconButton(
                tooltip: 'Borrar registro',
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () => _servicio.borrar(r.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barras verticales de una sola serie (un tono). La barra más alta va en
/// tono pleno y el resto más suave; cada barra tiene su descripción para
/// lectores de pantalla y un globo al tocarla.
class BarrasPatron extends StatelessWidget {
  const BarrasPatron({
    super.key,
    required this.valores,
    required this.etiqueta,
    required this.etiquetasVisibles,
    required this.descripcion,
    this.alto = 96,
    this.nombre,
  });

  final List<int> valores;
  final String Function(int i) etiqueta;
  final Set<int> etiquetasVisibles;
  final String Function(int i, int n) descripcion;
  final double alto;
  final String? nombre;

  @override
  Widget build(BuildContext context) {
    final max = valores.fold<int>(0, (m, v) => v > m ? v : m);
    final pico = max == 0 ? -1 : valores.indexOf(max);
    final resumen = [
      ?nombre,
      for (var i = 0; i < valores.length; i++)
        if (valores[i] > 0) descripcion(i, valores[i]),
    ].join('; ');
    return Semantics(
      label: resumen.isEmpty ? 'Sin registros' : resumen,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: alto,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < valores.length; i++)
                  Expanded(
                    child: Tooltip(
                      message: descripcion(i, valores[i]),
                      child: Padding(
                        // 2 px de papel entre barras.
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            height: max == 0
                                ? 2
                                : (alto * valores[i] / max).clamp(2, alto),
                            decoration: BoxDecoration(
                              color: valores[i] == 0
                                  ? VecColores.cremaOscuro
                                  : i == pico
                                  ? VecColores.terracota
                                  : VecColores.terracota.withValues(
                                      alpha: 0.45,
                                    ),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (var i = 0; i < valores.length; i++)
                Expanded(
                  child: etiquetasVisibles.contains(i)
                      ? Text(
                          etiqueta(i),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          softWrap: false,
                          style: TextStyle(
                            fontFamily: VecFuentes.texto,
                            fontSize: 13,
                            color: VecColores.gris,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
