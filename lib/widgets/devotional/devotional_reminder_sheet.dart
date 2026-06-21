import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/notification_service.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Recordatorio de devocional — hoja de sugerencia + editor por día de semana.
///
/// Se reutiliza desde dos lugares:
///   • DevotionalScreen: tras leer el primer devocional, sugiere activar un
///     recordatorio diario a la hora actual (con opciones de elegir otra hora
///     o personalizar por día).
///   • SettingsScreen: para editar los horarios por día de la semana.
///
/// Es agnóstico al sistema de temas (recibe una [DevotionalSheetPalette]) para
/// poder pintarse sobre el lector del devocional (BibleReaderThemeData) o sobre
/// Ajustes (AppThemeData) con los mismos colores del contexto.
/// ═══════════════════════════════════════════════════════════════════════════

class DevotionalSheetPalette {
  final Color background;
  final Color surface;
  final Color border;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final bool isDark;

  const DevotionalSheetPalette({
    required this.background,
    required this.surface,
    required this.border,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.isDark,
  });
}

const List<String> _kWeekdayLabels = <String>[
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

enum _SuggestionKind { daily, perWeekday }

class _SuggestionResult {
  final _SuggestionKind kind;
  final TimeOfDay? time;
  const _SuggestionResult(this.kind, [this.time]);
}

/// Muestra la sugerencia de recordatorio tras leer el primer devocional.
/// [suggestedTime] es la hora a la que el usuario está leyendo hoy.
Future<void> showDevotionalReminderSuggestion(
  BuildContext context, {
  required DevotionalSheetPalette palette,
  required TimeOfDay suggestedTime,
}) async {
  final messenger = ScaffoldMessenger.of(context);

  final result = await showModalBottomSheet<_SuggestionResult>(
    context: context,
    backgroundColor: palette.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _SuggestionSheet(
      palette: palette,
      suggestedTime: suggestedTime,
    ),
  );

  if (result == null) return; // "Ahora no" o cierre

  final svc = NotificationService();
  final ok = await svc.requestPermissions();
  if (!ok) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'Activa el permiso de notificaciones para recibir el recordatorio.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  switch (result.kind) {
    case _SuggestionKind.daily:
      await svc.enableDailyDevotionalReminderAt(result.time ?? suggestedTime);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Listo. Te recordaré tu devocional a las '
            '${_fmt(result.time ?? suggestedTime)}.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      break;
    case _SuggestionKind.perWeekday:
      await svc.setDevotionalReminderPerWeekday(true);
      await svc.setDevotionalReminderEnabled(true);
      if (context.mounted) {
        await showDevotionalWeekdayEditor(context, palette: palette);
      }
      break;
  }
}

class _SuggestionSheet extends StatelessWidget {
  final DevotionalSheetPalette palette;
  final TimeOfDay suggestedTime;

  const _SuggestionSheet({required this.palette, required this.suggestedTime});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: p.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Icon(Icons.notifications_active_rounded, color: p.accent, size: 34),
            const SizedBox(height: 12),
            Text(
              '¿Quieres un recordatorio diario?',
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                color: p.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Acabas de leer tu devocional. Puedo recordarte cada día para que '
              'no pierdas tu momento con Dios.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: p.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            // Hora sugerida (= ahora)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: BoxDecoration(
                color: p.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.accent.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule_rounded, color: p.accent, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Sugerido: ${_fmt(suggestedTime)}',
                    style: GoogleFonts.manrope(
                      color: p.accent,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Acción principal
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(
                context,
                _SuggestionResult(_SuggestionKind.daily, suggestedTime),
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text('Recordarme a las ${_fmt(suggestedTime)}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.isDark ? Colors.black : Colors.white,
                minimumSize: const Size.fromHeight(50),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Elegir otra hora
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: suggestedTime,
                );
                if (picked != null && context.mounted) {
                  Navigator.pop(
                    context,
                    _SuggestionResult(_SuggestionKind.daily, picked),
                  );
                }
              },
              icon: const Icon(Icons.schedule_rounded, size: 20),
              label: const Text('Elegir otra hora'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.textPrimary,
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Personalizar por día
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(
                context,
                const _SuggestionResult(_SuggestionKind.perWeekday),
              ),
              icon: const Icon(Icons.calendar_view_week_rounded, size: 20),
              label: const Text('Personalizar por día de la semana'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.textPrimary,
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: p.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Ahora no',
                style: GoogleFonts.manrope(
                  color: p.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editor de horarios por día de la semana. Opera directamente sobre
/// [NotificationService] (persiste y reprograma en cada cambio).
Future<void> showDevotionalWeekdayEditor(
  BuildContext context, {
  required DevotionalSheetPalette palette,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: palette.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _WeekdayEditor(palette: palette),
  );
}

class _WeekdayEditor extends StatefulWidget {
  final DevotionalSheetPalette palette;
  const _WeekdayEditor({required this.palette});

  @override
  State<_WeekdayEditor> createState() => _WeekdayEditorState();
}

class _WeekdayEditorState extends State<_WeekdayEditor> {
  final NotificationService _svc = NotificationService();

  TimeOfDay get _defaultTime => _svc.devotionalReminderTime;

  Future<void> _toggleDay(int weekday, bool on) async {
    await _svc.setDevotionalWeekdayTime(weekday, on ? _defaultTime : null);
    if (mounted) setState(() {});
  }

  Future<void> _pickTime(int weekday, TimeOfDay current) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) return;
    await _svc.setDevotionalWeekdayTime(weekday, picked);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    final times = _svc.devotionalWeekdayTimes;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: p.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Horario por día',
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                color: p.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Define la hora de cada día. Apaga los días que no quieras.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: p.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < 7; i++) _dayRow(p, i, times[i]),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: p.accent,
                foregroundColor: p.isDark ? Colors.black : Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Listo',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayRow(DevotionalSheetPalette p, int index, TimeOfDay? time) {
    final weekday = index + 1;
    final on = time != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _kWeekdayLabels[index],
              style: GoogleFonts.manrope(
                color: on ? p.textPrimary : p.textSecondary,
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (on)
            TextButton(
              onPressed: () => _pickTime(weekday, time),
              child: Text(
                _fmt(time),
                style: GoogleFonts.manrope(
                  color: p.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Switch(
            value: on,
            onChanged: (v) => _toggleDay(weekday, v),
            activeThumbColor: p.accent,
          ),
        ],
      ),
    );
  }
}
