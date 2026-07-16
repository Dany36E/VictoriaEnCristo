import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/notification_service.dart';
import '../../theme/bible_reader_theme.dart';

/// ═══════════════════════════════════════════════════════════════════════
/// Recordatorio del Versículo del Día — hoja adaptativa reutilizada desde
/// dos lugares:
///   • BibleHomeScreen: chip sobre la tarjeta del Versículo del Día.
///   • BibleSettingsScreen: fila de "Recordatorios".
///
/// Es la misma hoja en ambos casos: si el recordatorio está apagado, ofrece
/// activarlo con una hora sugerida; si ya está activo, permite cambiar la
/// hora o desactivarlo.
/// ═══════════════════════════════════════════════════════════════════════

String _fmt(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

Future<void> showDailyVerseReminderSheet(
  BuildContext context, {
  required BibleReaderThemeData theme,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _DailyVerseReminderSheet(theme: theme),
  );
}

class _DailyVerseReminderSheet extends StatefulWidget {
  final BibleReaderThemeData theme;
  const _DailyVerseReminderSheet({required this.theme});

  @override
  State<_DailyVerseReminderSheet> createState() =>
      _DailyVerseReminderSheetState();
}

class _DailyVerseReminderSheetState extends State<_DailyVerseReminderSheet> {
  final _svc = NotificationService();
  bool _busy = false;

  Future<void> _enableAt(TimeOfDay time) async {
    setState(() => _busy = true);
    final ok = await _svc.requestPermissions();
    if (!ok) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Activa el permiso de notificaciones para recibir el recordatorio.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }
    await _svc.enableDailyVerseReminderAt(time);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Listo. Te recordaré el versículo a las ${_fmt(time)}.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _disable() async {
    setState(() => _busy = true);
    await _svc.setDailyVerseReminderEnabled(false);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickOtherTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _svc.dailyVerseReminderTime,
    );
    if (picked != null) await _enableAt(picked);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final enabled = _svc.dailyVerseReminderEnabled;
    final time = _svc.dailyVerseReminderTime;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
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
                  color: t.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Icon(
              enabled
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded,
              color: t.accent,
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              enabled
                  ? 'Recordatorio activo a las ${_fmt(time)}'
                  : '¿Quieres un recordatorio diario?',
              textAlign: TextAlign.center,
              style: GoogleFonts.cinzel(
                color: t.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              enabled
                  ? 'Te avisaré cada día a esta hora con el Versículo del Día. Al tocarlo, se abre directo en la Biblia.'
                  : 'Te aviso cada día con el Versículo del Día. Al tocar la notificación, se abre directo en la Biblia.',
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                color: t.textSecondary,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            if (!enabled)
              ElevatedButton.icon(
                onPressed: _busy ? null : () => _enableAt(time),
                icon: const Icon(Icons.check_circle_rounded, size: 20),
                label: Text('Recordarme a las ${_fmt(time)}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.isDark ? Colors.black : Colors.white,
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
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickOtherTime,
              icon: const Icon(Icons.schedule_rounded, size: 20),
              label: const Text('Elegir otra hora'),
              style: OutlinedButton.styleFrom(
                foregroundColor: t.textPrimary,
                minimumSize: const Size.fromHeight(48),
                side: BorderSide(color: t.textSecondary.withValues(alpha: 0.25)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            if (enabled) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _busy ? null : _disable,
                child: Text(
                  'Desactivar recordatorio',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Ahora no',
                  style: GoogleFonts.manrope(
                    color: t.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
