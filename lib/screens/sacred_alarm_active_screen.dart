import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sacred_alarm.dart';
import '../services/audio_engine.dart';
import '../services/sacred_alarm_service.dart';
import '../theme/app_theme_data.dart';

const int _requiredPresenceSeconds = 20;

class SacredAlarmActiveScreen extends StatefulWidget {
  final String? sessionId;

  const SacredAlarmActiveScreen({super.key, this.sessionId});

  @override
  State<SacredAlarmActiveScreen> createState() => _SacredAlarmActiveScreenState();
}

class _SacredAlarmActiveScreenState extends State<SacredAlarmActiveScreen> {
  SacredAlarmEvent? _event;
  bool _loading = true;
  bool _readConfirmed = false;
  bool _activityConfirmed = false;
  bool _completing = false;
  int _secondsPresent = 0;
  Timer? _timer;

  bool get _canComplete =>
      !_completing &&
      _readConfirmed &&
      _activityConfirmed &&
      _secondsPresent >= _requiredPresenceSeconds;

  @override
  void initState() {
    super.initState();
    AudioEngine.I.muteForScreen();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _secondsPresent < _requiredPresenceSeconds) {
        setState(() => _secondsPresent++);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    AudioEngine.I.unmuteForScreen();
    super.dispose();
  }

  Future<void> _load() async {
    final event = await SacredAlarmService.I.activateFromRoute(widget.sessionId);
    if (mounted) {
      setState(() {
        _event = event;
        _loading = false;
      });
    }
    // Si no se encontro un evento que coincida (p.ej. la alarma quedo
    // huerfana tras un cambio de configuracion o reinstalacion), apagamos
    // de forma defensiva la campana nativa para que el usuario no quede
    // atrapado escuchandola.
    if (event == null) {
      await SacredAlarmService.I.stopAnyRingingAlarm();
    }
  }

  Future<void> _complete() async {
    final event = _event;
    if (event == null || !_canComplete) return;
    setState(() => _completing = true);
    await SacredAlarmService.I.completeActiveAlarm(event.id);
    if (!mounted) return;
    setState(() {
      _event = event.copyWith(
        status: SacredAlarmEventStatus.completed,
        completedAtMs: DateTime.now().millisecondsSinceEpoch,
      );
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Campana completada. Bien hecho.')));
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final event = _event;
    return PopScope(
      canPop: event == null || event.status == SacredAlarmEventStatus.completed,
      child: Scaffold(
        backgroundColor: t.scaffoldBg,
        appBar: AppBar(
          automaticallyImplyLeading: event == null,
          title: const Text('Campana Sagrada'),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : event == null
            ? const _NoActiveAlarm()
            : SafeArea(
                child: ListView(
                  padding: const EdgeInsets.all(18),
                  children: [
                    _ActivityHeader(event: event),
                    const SizedBox(height: 18),
                    _VerseCard(event: event),
                    const SizedBox(height: 18),
                    _ResolutionCard(
                      secondsPresent: _secondsPresent,
                      readConfirmed: _readConfirmed,
                      activityConfirmed: _activityConfirmed,
                      onReadChanged: (value) => setState(() => _readConfirmed = value),
                      onActivityChanged: (value) => setState(() => _activityConfirmed = value),
                      instruction: event.activityType.shortInstruction,
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: _canComplete ? _complete : null,
                      icon: const Icon(Icons.notifications_off),
                      label: Text(
                        _completing
                            ? 'Apagando campana...'
                            : _canComplete
                            ? 'Completar y apagar campana'
                            : 'Permanece presente ${_requiredPresenceSeconds - _secondsPresent}s',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'La campana no se apaga desde la notificacion. Este momento se cierra aqui, con presencia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: t.textSecondary, fontSize: 12, height: 1.35),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _ActivityHeader extends StatelessWidget {
  final SacredAlarmEvent event;

  const _ActivityHeader({required this.event});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Text(event.activityType.iconGlyph, style: const TextStyle(fontSize: 38)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.activityType.label,
                  style: TextStyle(color: t.textPrimary, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dios te esta llamando a hacer una pausa.',
                  style: TextStyle(color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VerseCard extends StatelessWidget {
  final SacredAlarmEvent event;

  const _VerseCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${event.verse}"',
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 21,
              height: 1.45,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            event.reference,
            style: TextStyle(color: t.accent, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  final int secondsPresent;
  final bool readConfirmed;
  final bool activityConfirmed;
  final ValueChanged<bool> onReadChanged;
  final ValueChanged<bool> onActivityChanged;
  final String instruction;

  const _ResolutionCard({
    required this.secondsPresent,
    required this.readConfirmed,
    required this.activityConfirmed,
    required this.onReadChanged,
    required this.onActivityChanged,
    required this.instruction,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.cardBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: (secondsPresent / _requiredPresenceSeconds).clamp(0, 1),
            color: t.accent,
            backgroundColor: t.textSecondary.withOpacity(0.16),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: readConfirmed,
            activeColor: t.accent,
            title: const Text('Lei el pasaje con atencion'),
            onChanged: (value) => onReadChanged(value ?? false),
          ),
          CheckboxListTile(
            value: activityConfirmed,
            activeColor: t.accent,
            title: Text(instruction),
            onChanged: (value) => onActivityChanged(value ?? false),
          ),
        ],
      ),
    );
  }
}

class _NoActiveAlarm extends StatefulWidget {
  const _NoActiveAlarm();

  @override
  State<_NoActiveAlarm> createState() => _NoActiveAlarmState();
}

class _NoActiveAlarmState extends State<_NoActiveAlarm> {
  bool _stopping = false;
  bool _stopped = false;

  Future<void> _forceStop() async {
    if (_stopping) return;
    setState(() => _stopping = true);
    await SacredAlarmService.I.stopAnyRingingAlarm();
    if (!mounted) return;
    setState(() {
      _stopping = false;
      _stopped = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off, size: 56, color: t.textSecondary),
            const SizedBox(height: 16),
            Text(
              'No hay una campana activa en este momento.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              _stopped
                  ? 'Listo. Si seguia sonando, ya esta apagada.'
                  : 'Si aun escuchas la campana, presiona el boton para apagarla.',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _stopping || _stopped ? null : _forceStop,
              icon: const Icon(Icons.notifications_off),
              label: Text(
                _stopping
                    ? 'Apagando...'
                    : _stopped
                    ? 'Campana apagada'
                    : 'Apagar campana',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
