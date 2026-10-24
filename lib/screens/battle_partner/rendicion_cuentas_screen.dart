/// ═══════════════════════════════════════════════════════════════════════════
/// LO QUE VERÁ TU COMPAÑERO — privacidad exacta + avisos opcionales.
///
/// Explica qué ve siempre un compañero, y deja activar por compañero:
/// - avisos si el Escudo de Pureza se apaga o se queda sin señal,
/// - el resumen semanal (con vista previa del texto que recibirá).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/battle_partner_data.dart';
import '../../services/accountability_service.dart';
import '../../services/battle_partner_service.dart';
import '../../services/purity_guard_service.dart';
import '../../services/victory_scoring_service.dart';
import '../../theme/app_theme_data.dart';
import '../../utils/fecha_calendario.dart';
import '../../utils/resumen_semanal.dart';
import '../../vec/vec_tema.dart';
import '../../vec/vec_widgets.dart';

class RendicionCuentasScreen extends StatefulWidget {
  const RendicionCuentasScreen({super.key, this.nombrePublico});

  /// Nombre con el que te ven tus compañeros (para la vista previa).
  final String? nombrePublico;

  @override
  State<RendicionCuentasScreen> createState() => _RendicionCuentasScreenState();
}

class _RendicionCuentasScreenState extends State<RendicionCuentasScreen> {
  late AjustesRendicion _ajustes;
  bool _cargando = true;
  bool _guardando = false;
  bool _cambios = false;
  bool? _escudoActivo;
  int? _bloqueosSemana;

  @override
  void initState() {
    super.initState();
    _ajustes = AccountabilityService.I.ajustes.value;
    unawaited(_cargar());
  }

  Future<void> _cargar() async {
    await AccountabilityService.I.cargar(forzar: true);
    final guard = PurityGuardService.I;
    bool? escudo;
    int? bloqueos;
    if (guard.isEngineSupported &&
        (await guard.isDesired() || guard.active.value)) {
      escudo = guard.active.value;
      final porDia = await guard.blocksByDay();
      final claves = _clavesSemana();
      bloqueos = claves.fold<int>(0, (t, k) => t + (porDia[k] ?? 0));
    }
    if (!mounted) return;
    setState(() {
      _ajustes = AccountabilityService.I.ajustes.value;
      _escudoActivo = escudo;
      _bloqueosSemana = bloqueos;
      _cargando = false;
    });
  }

  /// Lunes a hoy de la semana actual.
  List<String> _clavesSemana() {
    final hoy = DateTime.now();
    final lunes = FechaCalendario.sumarDias(hoy, -(hoy.weekday - 1));
    return [
      for (var i = 0; i < hoy.weekday; i++)
        FechaCalendario.clave(FechaCalendario.sumarDias(lunes, i)),
    ];
  }

  DatosResumenSemanal _datosSemana() {
    final scoring = VictoryScoringService.I;
    var registrados = 0;
    var victorias = 0;
    for (final clave in _clavesSemana()) {
      final fecha = FechaCalendario.desdeClave(clave)!;
      if (scoring.isDateLogged(fecha)) {
        registrados++;
        if (scoring.isVictoryDay(fecha)) victorias++;
      }
    }
    return DatosResumenSemanal(
      diasRegistrados: registrados,
      victorias: victorias,
      gracias: registrados - victorias,
      racha: scoring.getCurrentStreak(),
      escudoActivo: _escudoActivo,
      bloqueos: _escudoActivo == null ? null : _bloqueosSemana,
    );
  }

  void _cambiar(AjustesRendicion nuevos) {
    setState(() {
      _ajustes = nuevos;
      _cambios = true;
    });
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    final ok = await AccountabilityService.I.guardar(_ajustes);
    if (!mounted) return;
    setState(() {
      _guardando = false;
      if (ok) _cambios = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Listo. Tus compañeros recibirán solo lo que elegiste.'
              : 'No se pudo guardar. Revisa tu conexión e intenta de nuevo.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final partners = BattlePartnerService.I.partnersNotifier.value;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Lo que verá tu compañero')),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                children: [
                  _seccionSiempre(),
                  const SizedBox(height: 22),
                  _seccionEscudo(partners),
                  const SizedBox(height: 22),
                  _seccionResumen(partners),
                  const SizedBox(height: 22),
                  _vistaPrevia(),
                  const SizedBox(height: 22),
                  BotonVec(
                    texto: 'Guardar',
                    icono: Icons.check_rounded,
                    expandido: true,
                    cargando: _guardando,
                    onPressed: _cambios && !_guardando ? _guardar : null,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _parrafo(String texto, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      texto,
      style: TextStyle(
        fontFamily: VecFuentes.texto,
        fontSize: 17,
        height: 1.25,
        color: color ?? VecColores.tinta,
      ),
    ),
  );

  Widget _seccionSiempre() {
    return TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloVec('Siempre ve', tamano: 22),
          const SizedBox(height: 8),
          _parrafo('• Tu racha de días.'),
          _parrafo(
            '• Si hoy registraste victoria o gracia (solo el día de hoy).',
          ),
          _parrafo('• Cuándo abriste la app por última vez.'),
          _parrafo(
            '• Solo si le activas los avisos del Escudo: si tu Escudo está '
            'activo o apagado.',
          ),
          const SizedBox(height: 10),
          const TituloVec('Nunca ve', tamano: 22),
          const SizedBox(height: 8),
          _parrafo(
            'Tu diario, tus oraciones, tus gigantes, tus registros de '
            'tentaciones o caídas, ni qué sitios bloqueó el Escudo.',
            color: VecColores.gris,
          ),
        ],
      ),
    );
  }

  Widget _sinCompaneros() => _parrafo(
    'Cuando conectes un compañero podrás elegirlo aquí.',
    color: VecColores.gris,
  );

  Widget _interruptor({
    required String titulo,
    required bool valor,
    required ValueChanged<bool> alCambiar,
    String? subtitulo,
  }) {
    final t = AppThemeData.of(context);
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: valor,
      onChanged: alCambiar,
      title: Text(titulo, style: TextStyle(color: t.textPrimary)),
      subtitle: subtitulo == null
          ? null
          : Text(subtitulo, style: TextStyle(color: t.textSecondary)),
    );
  }

  Widget _seccionEscudo(List<BattlePartnerData> partners) {
    final soportado = PurityGuardService.I.isEngineSupported;
    return TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloVec('Avisos del Escudo', clave: 'Escudo', tamano: 22),
          const SizedBox(height: 8),
          _parrafo(
            'Si tu Escudo de Pureza se apaga (por ti, por el sistema o al '
            'quitar el permiso) o pasa más de un día sin señal, el compañero '
            'que elijas recibe un aviso breve. No ve qué sitios visitas ni '
            'la hora exacta.',
          ),
          if (!soportado)
            _parrafo(
              'El Escudo funciona en Android. En este dispositivo no se '
              'enviarán avisos.',
              color: VecColores.gris,
            ),
          if (partners.isEmpty) _sinCompaneros(),
          for (final p in partners)
            _interruptor(
              titulo: p.name,
              subtitulo: 'Recibe avisos del Escudo',
              valor: _ajustes.avisosEscudo.contains(p.uid),
              alCambiar: (v) => _cambiar(
                _ajustes.copyWith(
                  avisosEscudo: v
                      ? {..._ajustes.avisosEscudo, p.uid}
                      : ({..._ajustes.avisosEscudo}..remove(p.uid)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _seccionResumen(List<BattlePartnerData> partners) {
    final c = _ajustes.compartir;
    void compartir(CompartirResumen n) =>
        _cambiar(_ajustes.copyWith(compartir: n));
    return TarjetaPapel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TituloVec('Resumen semanal', clave: 'semanal', tamano: 22),
          const SizedBox(height: 8),
          _parrafo(
            'Los domingos por la tarde (tu hora) tu compañero recibe un '
            'resumen de tu semana para orar por ti. Tú decides qué incluye.',
          ),
          if (partners.isEmpty) _sinCompaneros(),
          for (final p in partners)
            _interruptor(
              titulo: p.name,
              subtitulo: 'Recibe tu resumen semanal',
              valor: _ajustes.resumenSemanal.contains(p.uid),
              alCambiar: (v) => _cambiar(
                _ajustes.copyWith(
                  resumenSemanal: v
                      ? {..._ajustes.resumenSemanal, p.uid}
                      : ({..._ajustes.resumenSemanal}..remove(p.uid)),
                ),
              ),
            ),
          const Divider(height: 24),
          _interruptor(
            titulo: 'Días que registraste',
            valor: c.registro,
            alCambiar: (v) => compartir(c.copyWith(registro: v)),
          ),
          _interruptor(
            titulo: 'Días de victoria y de gracia',
            valor: c.victoriaGracia,
            alCambiar: (v) => compartir(c.copyWith(victoriaGracia: v)),
          ),
          _interruptor(
            titulo: 'Tu racha actual',
            valor: c.racha,
            alCambiar: (v) => compartir(c.copyWith(racha: v)),
          ),
          _interruptor(
            titulo: 'Estado del Escudo y cuántos bloqueos',
            subtitulo: 'Solo el número, nunca qué sitios.',
            valor: c.escudo,
            alCambiar: (v) => compartir(c.copyWith(escudo: v)),
          ),
        ],
      ),
    );
  }

  Widget _vistaPrevia() {
    final propio = widget.nombrePublico ?? BattlePartnerService.I.publicName;
    final nombre = propio?.trim().isNotEmpty == true
        ? propio!.trim()
        : 'tu nombre';
    final texto = textoResumenSemanal(
      nombre: nombre,
      datos: _datosSemana(),
      compartir: _ajustes.compartir,
    );
    return Semantics(
      container: true,
      label: 'Vista previa del resumen semanal: $texto',
      excludeSemantics: true,
      child: TarjetaPapel(
        giro: -0.5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const TituloVec('Así lo verá (semana actual)', tamano: 20),
            const SizedBox(height: 10),
            _parrafo(texto),
          ],
        ),
      ),
    );
  }
}
