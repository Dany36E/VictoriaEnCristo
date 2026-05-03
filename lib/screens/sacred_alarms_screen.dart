import 'package:flutter/material.dart';

import '../models/sacred_alarm.dart';
import '../services/notification_service.dart';
import '../services/sacred_alarm_service.dart';
import '../theme/app_theme_data.dart';
import '../utils/platform_capabilities.dart';
import 'sacred_alarm_active_screen.dart';

class SacredAlarmsScreen extends StatefulWidget {
  const SacredAlarmsScreen({super.key});

  @override
  State<SacredAlarmsScreen> createState() => _SacredAlarmsScreenState();
}

class _SacredAlarmsScreenState extends State<SacredAlarmsScreen> {
  final SacredAlarmService _service = SacredAlarmService.I;
  bool _loading = true;
  bool _exactAllowed = true;
  bool _inputLocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await _service.init();
    _exactAllowed = await _service.isExactAlarmAllowed();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggleEnabled(bool enabled) async {
    final messenger = ScaffoldMessenger.of(context);
    if (enabled && !PlatformCapabilities.supportsStrictSacredAlarms) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Campanas Sagradas estrictas estan disponibles en Android.')),
      );
      return;
    }
    if (enabled) {
      final ok = await NotificationService().requestPermissions();
      if (!ok && mounted) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Activa las notificaciones para usar Campanas Sagradas.')),
        );
        return;
      }
    }
    final changed = await _service.setEnabled(enabled);
    if (!changed && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Modo pacto: hay campanas futuras bloqueadas.')),
      );
    }
    _exactAllowed = await _service.isExactAlarmAllowed();
    if (mounted) setState(() {});
  }

  Future<void> _updateConfig(SacredAlarmConfig next) async {
    final messenger = ScaffoldMessenger.of(context);
    final changed = await _service.updateConfig(next);
    if (!changed && mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Modo pacto: no se puede debilitar un compromiso activo.')),
      );
    }
    _exactAllowed = await _service.isExactAlarmAllowed();
    if (mounted) setState(() {});
  }

  Future<void> _editWindow([SacredAlarmWindow? window]) async {
    final result = await showDialog<SacredAlarmWindow>(
      context: context,
      builder: (_) => _WindowDialog(window: window),
    );
    if (result == null) return;
    final config = _service.config.value;
    final windows = config.effectiveWindows.toList();
    final index = windows.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      windows[index] = result;
    } else {
      windows.add(result);
    }
    await _updateConfig(config.copyWith(windows: windows));
  }

  Future<void> _removeWindow(SacredAlarmWindow window) async {
    final config = _service.config.value;
    final windows = config.effectiveWindows.where((item) => item.id != window.id).toList();
    if (windows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Deja al menos una ventana activa.')));
      return;
    }
    await _updateConfig(config.copyWith(windows: windows));
  }

  Future<void> _editRule([SacredAlarmFixedRule? rule]) async {
    final result = await showDialog<SacredAlarmFixedRule>(
      context: context,
      builder: (_) => _RuleDialog(rule: rule),
    );
    if (result == null) return;
    final config = _service.config.value;
    final rules = config.fixedRules.toList();
    final index = rules.indexWhere((item) => item.id == result.id);
    if (index >= 0) {
      rules[index] = result;
    } else {
      rules.add(result);
    }
    await _updateConfig(config.copyWith(fixedRules: rules));
  }

  Future<void> _removeRule(SacredAlarmFixedRule rule) async {
    final config = _service.config.value;
    final rules = config.fixedRules.where((item) => item.id != rule.id).toList();
    await _updateConfig(config.copyWith(fixedRules: rules));
  }

  Future<void> _testAlarm() async {
    if (_inputLocked) return;
    setState(() => _inputLocked = true);
    try {
      final event = await _service.triggerTestAlarm();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SacredAlarmActiveScreen(sessionId: event.id),
          fullscreenDialog: true,
        ),
      );
      if (mounted) setState(() {});
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) setState(() => _inputLocked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(title: const Text('Campanas Sagradas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : IgnorePointer(
              ignoring: _inputLocked,
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _service.config,
                  _service.todayEvents,
                  _service.scheduledEvents,
                ]),
                builder: (context, _) {
                  final config = _service.config.value;
                  final todayEvents = _service.todayEvents.value;
                  final upcoming = _service.upcomingEvents();
                  final lockedCount = upcoming.where((event) => event.locked).length;
                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HeroPanel(
                        enabled: config.enabled,
                        exactAllowed: _exactAllowed,
                        supported: PlatformCapabilities.supportsStrictSacredAlarms,
                        lockedCount: lockedCount,
                        daysAhead: config.scheduleDaysAhead,
                      ),
                      const SizedBox(height: 16),
                      _Card(
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              value: config.enabled,
                              activeColor: t.accent,
                              title: const Text('Activar Campanas Sagradas'),
                              subtitle: Text(
                                config.enabled
                                    ? '$lockedCount campanas futuras protegidas'
                                    : 'Programa desde ahora tus horas vulnerables.',
                              ),
                              secondary: Icon(Icons.notifications_active, color: t.accent),
                              onChanged: _toggleEnabled,
                            ),
                            const Divider(height: 1),
                            SwitchListTile.adaptive(
                              value: config.strictMode,
                              activeColor: t.accent,
                              title: const Text('Modo pacto'),
                              subtitle: const Text(
                                'Lo ya programado permanece bloqueado hasta completarse.',
                              ),
                              secondary: Icon(Icons.lock_clock, color: t.accent),
                              onChanged: (value) =>
                                  _updateConfig(config.copyWith(strictMode: value)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Ventanas de vulnerabilidad',
                        icon: Icons.schedule,
                        color: t.accent,
                      ),
                      _Card(
                        child: Column(
                          children: [
                            ...config.effectiveWindows.map(
                              (window) => _WindowTile(
                                window: window,
                                onTap: () => _editWindow(window),
                                onDelete: () => _removeWindow(window),
                              ),
                            ),
                            const Divider(height: 1),
                            _ActionRow(
                              icon: Icons.add_alarm,
                              label: 'Agregar ventana',
                              onTap: () => _editWindow(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Horarios fijos semanales',
                        icon: Icons.event_repeat,
                        color: t.accent,
                      ),
                      _Card(
                        child: Column(
                          children: [
                            if (config.fixedRules.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Aun no hay horarios fijos repetitivos.'),
                                ),
                              )
                            else
                              ...config.fixedRules.map(
                                (rule) => _RuleTile(
                                  rule: rule,
                                  onTap: () => _editRule(rule),
                                  onDelete: () => _removeRule(rule),
                                  onEnabledChanged: (enabled) => _updateConfig(
                                    config.copyWith(
                                      fixedRules: config.fixedRules
                                          .map(
                                            (item) => item.id == rule.id
                                                ? item.copyWith(enabled: enabled)
                                                : item,
                                          )
                                          .toList(),
                                    ),
                                  ),
                                ),
                              ),
                            const Divider(height: 1),
                            _ActionRow(
                              icon: Icons.add,
                              label: 'Agregar horario fijo',
                              onTap: () => _editRule(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Momentos aleatorios',
                        icon: Icons.shuffle,
                        color: t.accent,
                      ),
                      _Card(
                        child: Column(
                          children: [
                            _CountStepper(
                              label: 'Campanas por dia',
                              value: config.randomCount,
                              min: 0,
                              max: 24,
                              onChanged: (value) =>
                                  _updateConfig(config.copyWith(randomCount: value)),
                            ),
                            const Divider(height: 1),
                            _CountStepper(
                              label: 'Separacion minima',
                              value: config.minGapMinutes,
                              min: 15,
                              max: 240,
                              step: 15,
                              suffix: 'min',
                              onChanged: (value) =>
                                  _updateConfig(config.copyWith(minGapMinutes: value)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(title: 'Volumen', icon: Icons.volume_up, color: t.accent),
                      _Card(
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              value: config.enforceMinimumVolume,
                              activeColor: t.accent,
                              title: const Text('Forzar volumen minimo'),
                              subtitle: const Text('Al sonar, Android sube el canal de alarma.'),
                              secondary: Icon(Icons.volume_up, color: t.accent),
                              onChanged: (value) =>
                                  _updateConfig(config.copyWith(enforceMinimumVolume: value)),
                            ),
                            if (config.enforceMinimumVolume)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Slider(
                                        min: 30,
                                        max: 100,
                                        divisions: 7,
                                        value: config.minimumVolumePercent.toDouble(),
                                        activeColor: t.accent,
                                        onChanged: (value) => _updateConfig(
                                          config.copyWith(minimumVolumePercent: value.round()),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 52,
                                      child: Text(
                                        '${config.minimumVolumePercent}%',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: t.accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(title: 'Actividades', icon: Icons.checklist, color: t.accent),
                      _Card(
                        child: Column(
                          children: SacredAlarmActivityType.values.map((activity) {
                            final selected = config.activities.contains(activity);
                            return CheckboxListTile(
                              value: selected,
                              activeColor: t.accent,
                              title: Text('${activity.iconGlyph} ${activity.label}'),
                              subtitle: Text(activity.shortInstruction),
                              onChanged: (value) async {
                                final next = config.activities.toSet();
                                if (value == true) {
                                  next.add(activity);
                                } else if (next.length > 1) {
                                  next.remove(activity);
                                }
                                await _updateConfig(config.copyWith(activities: next.toList()));
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(title: 'Hoy', icon: Icons.today, color: t.accent),
                      _Card(
                        child: todayEvents.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('Activa las campanas para generar el horario de hoy.'),
                              )
                            : Column(
                                children: todayEvents
                                    .map((event) => _EventTile(event: event))
                                    .toList(growable: false),
                              ),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(title: 'Proximas', icon: Icons.lock, color: t.accent),
                      _Card(
                        child: upcoming.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text('No hay campanas futuras programadas.'),
                              )
                            : Column(
                                children: upcoming
                                    .take(10)
                                    .map((event) => _EventTile(event: event, showDate: true))
                                    .toList(growable: false),
                              ),
                      ),
                      const SizedBox(height: 16),
                      if (!_exactAllowed)
                        _PermissionPanel(onOpenSettings: _service.openExactAlarmSettings),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: PlatformCapabilities.supportsStrictSacredAlarms
                            ? _testAlarm
                            : null,
                        icon: const Icon(Icons.campaign),
                        label: const Text('Probar campana ahora'),
                      ),
                      const SizedBox(height: 32),
                    ],
                  );
                },
              ),
            ),
    );
  }
}

class _HeroPanel extends StatelessWidget {
  final bool enabled;
  final bool exactAllowed;
  final bool supported;
  final int lockedCount;
  final int daysAhead;

  const _HeroPanel({
    required this.enabled,
    required this.exactAllowed,
    required this.supported,
    required this.lockedCount,
    required this.daysAhead,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.accent.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(enabled ? Icons.lock_clock : Icons.notifications_active, color: t.accent),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enabled ? 'Pacto activo' : 'Prepara tu defensa',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: t.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  !supported
                      ? 'El modo anti-trampa necesita el servicio nativo de Android.'
                      : !exactAllowed
                      ? 'Falta permitir alarmas exactas para que Android respete mejor los horarios.'
                      : enabled
                      ? '$lockedCount campanas protegidas durante los proximos $daysAhead dias.'
                      : 'Agenda tus horas debiles mientras estas fuerte.',
                  style: TextStyle(color: t.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(t.isDark ? 0.24 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _WindowTile extends StatelessWidget {
  final SacredAlarmWindow window;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _WindowTile({required this.window, required this.onTap, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return ListTile(
      leading: Icon(Icons.schedule, color: t.accent),
      title: Text('${_formatMinute(window.startMinute)} - ${_formatMinute(window.endMinute)}'),
      subtitle: const Text('Rango habilitado para campanas aleatorias'),
      trailing: IconButton(
        tooltip: 'Eliminar',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _RuleTile extends StatelessWidget {
  final SacredAlarmFixedRule rule;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final ValueChanged<bool> onEnabledChanged;

  const _RuleTile({
    required this.rule,
    required this.onTap,
    required this.onDelete,
    required this.onEnabledChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final activity = rule.activityType;
    return ListTile(
      leading: Switch.adaptive(
        value: rule.enabled,
        activeColor: t.accent,
        onChanged: onEnabledChanged,
      ),
      title: Text(_formatMinute(rule.minuteOfDay)),
      subtitle: Text(
        '${_formatWeekdays(rule.weekdays)} · ${activity == null ? 'Actividad rotativa' : activity.label}',
      ),
      trailing: IconButton(
        tooltip: 'Eliminar',
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
      onTap: onTap,
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return ListTile(
      leading: Icon(icon, color: t.accent),
      title: Text(
        label,
        style: TextStyle(color: t.accent, fontWeight: FontWeight.w800),
      ),
      onTap: onTap,
    );
  }
}

class _CountStepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String? suffix;
  final ValueChanged<int> onChanged;

  const _CountStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.step = 1,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.filledTonal(
            tooltip: 'Bajar',
            onPressed: value <= min ? null : () => onChanged((value - step).clamp(min, max)),
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 70,
            child: Text(
              suffix == null ? '$value' : '$value $suffix',
              textAlign: TextAlign.center,
              style: TextStyle(color: t.accent, fontWeight: FontWeight.w900),
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Subir',
            onPressed: value >= max ? null : () => onChanged((value + step).clamp(min, max)),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final SacredAlarmEvent event;
  final bool showDate;

  const _EventTile({required this.event, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final time = TimeOfDay.fromDateTime(event.scheduledAt);
    final statusText = switch (event.status) {
      SacredAlarmEventStatus.scheduled => event.sourceType == 'fixed' ? 'Fija' : 'Aleatoria',
      SacredAlarmEventStatus.ringing => 'Sonando',
      SacredAlarmEventStatus.completed => 'Completada',
      SacredAlarmEventStatus.missed => 'Pendiente',
    };
    final dateText = showDate ? '${event.scheduledAt.day}/${event.scheduledAt.month} · ' : '';
    return ListTile(
      leading: Text(event.activityType.iconGlyph, style: const TextStyle(fontSize: 24)),
      title: Text(event.activityType.label),
      subtitle: Text('$dateText${event.reference} · $statusText'),
      trailing: Text(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        style: TextStyle(color: t.accent, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PermissionPanel extends StatelessWidget {
  final Future<void> Function() onOpenSettings;

  const _PermissionPanel({required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Permiso recomendado',
            style: TextStyle(color: t.textPrimary, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Android puede retrasar alarmas si no permites alarmas exactas.',
            style: TextStyle(color: t.textSecondary),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Abrir permiso de alarmas'),
          ),
        ],
      ),
    );
  }
}

class _WindowDialog extends StatefulWidget {
  final SacredAlarmWindow? window;

  const _WindowDialog({this.window});

  @override
  State<_WindowDialog> createState() => _WindowDialogState();
}

class _WindowDialogState extends State<_WindowDialog> {
  late int _startMinute;
  late int _endMinute;
  late String _id;

  @override
  void initState() {
    super.initState();
    final window = widget.window;
    _id = window?.id ?? 'window-${DateTime.now().millisecondsSinceEpoch}';
    _startMinute = window?.startMinute ?? 19 * 60;
    _endMinute = window?.endMinute ?? 21 * 60 + 15;
  }

  Future<void> _pick({required bool start}) async {
    final minute = start ? _startMinute : _endMinute;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (picked == null) return;
    final next = picked.hour * 60 + picked.minute;
    setState(() {
      if (start) {
        _startMinute = next;
        if (_endMinute <= _startMinute) {
          _endMinute = (_startMinute + 60).clamp(1, 24 * 60 - 1);
        }
      } else {
        _endMinute = next <= _startMinute ? (_startMinute + 60).clamp(1, 24 * 60 - 1) : next;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ventana'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Inicio'),
            trailing: Text(_formatMinute(_startMinute)),
            onTap: () => _pick(start: true),
          ),
          ListTile(
            title: const Text('Fin'),
            trailing: Text(_formatMinute(_endMinute)),
            onTap: () => _pick(start: false),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(
            context,
          ).pop(SacredAlarmWindow(id: _id, startMinute: _startMinute, endMinute: _endMinute)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _RuleDialog extends StatefulWidget {
  final SacredAlarmFixedRule? rule;

  const _RuleDialog({this.rule});

  @override
  State<_RuleDialog> createState() => _RuleDialogState();
}

class _RuleDialogState extends State<_RuleDialog> {
  late String _id;
  late bool _enabled;
  late int _minute;
  late Set<int> _weekdays;
  SacredAlarmActivityType? _activityType;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _id = rule?.id ?? 'rule-${DateTime.now().millisecondsSinceEpoch}';
    _enabled = rule?.enabled ?? true;
    _minute = rule?.minuteOfDay ?? 19 * 60 + 15;
    _weekdays = (rule?.weekdays ?? [DateTime.now().weekday]).toSet();
    _activityType = rule?.activityType;
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _minute ~/ 60, minute: _minute % 60),
    );
    if (picked == null) return;
    setState(() => _minute = picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return AlertDialog(
      title: const Text('Horario fijo'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile.adaptive(
              value: _enabled,
              activeColor: t.accent,
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              onChanged: (value) => setState(() => _enabled = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Hora'),
              trailing: Text(_formatMinute(_minute)),
              onTap: _pickTime,
            ),
            const SizedBox(height: 8),
            Text(
              'Dias',
              style: TextStyle(color: t.textSecondary, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: List<int>.generate(7, (index) => index + 1).map((weekday) {
                final selected = _weekdays.contains(weekday);
                return FilterChip(
                  label: Text(_weekdayShort(weekday)),
                  selected: selected,
                  selectedColor: t.accent.withOpacity(0.22),
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _weekdays.add(weekday);
                      } else if (_weekdays.length > 1) {
                        _weekdays.remove(weekday);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<SacredAlarmActivityType?>(
              value: _activityType,
              decoration: const InputDecoration(labelText: 'Actividad'),
              items: [
                const DropdownMenuItem<SacredAlarmActivityType?>(
                  value: null,
                  child: Text('Rotativa'),
                ),
                ...SacredAlarmActivityType.values.map(
                  (activity) => DropdownMenuItem<SacredAlarmActivityType?>(
                    value: activity,
                    child: Text('${activity.iconGlyph} ${activity.label}'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _activityType = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            SacredAlarmFixedRule(
              id: _id,
              enabled: _enabled,
              minuteOfDay: _minute,
              weekdays: _weekdays.toList()..sort(),
              activityType: _activityType,
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

String _formatMinute(int minute) {
  final hour = (minute ~/ 60).toString().padLeft(2, '0');
  final min = (minute % 60).toString().padLeft(2, '0');
  return '$hour:$min';
}

String _weekdayShort(int weekday) {
  return switch (weekday) {
    DateTime.monday => 'L',
    DateTime.tuesday => 'M',
    DateTime.wednesday => 'X',
    DateTime.thursday => 'J',
    DateTime.friday => 'V',
    DateTime.saturday => 'S',
    DateTime.sunday => 'D',
    _ => '?',
  };
}

String _formatWeekdays(List<int> weekdays) {
  if (weekdays.length == 7) return 'Todos los dias';
  return weekdays.map(_weekdayShort).join(' ');
}
