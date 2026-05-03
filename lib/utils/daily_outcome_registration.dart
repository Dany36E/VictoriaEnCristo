import 'package:flutter/material.dart';
import '../screens/victory_celebration_screen.dart';
import '../services/feedback_engine.dart';
import '../services/victory_scoring_service.dart';
import '../services/widget_sync_service.dart';
import '../theme/app_theme_data.dart';

enum DailyOutcomeChoice { victory, grace }

enum DailyOutcomeStatus {
  cancelled,
  tooEarly,
  alreadyVictory,
  alreadyGrace,
  victoryLogged,
  graceLogged,
}

class DailyOutcomeRegistrationResult {
  final DailyOutcomeStatus status;
  final int streak;

  const DailyOutcomeRegistrationResult(this.status, {this.streak = 0});

  bool get changed =>
      status == DailyOutcomeStatus.victoryLogged || status == DailyOutcomeStatus.graceLogged;
}

Future<DailyOutcomeRegistrationResult> promptAndRegisterDailyOutcome(
  BuildContext context, {
  bool showVictoryCelebration = true,
  bool showAlreadyVictoryCelebration = false,
}) async {
  final scoring = VictoryScoringService.I;
  await scoring.init();

  if (scoring.hasDataForToday()) {
    final streak = scoring.getCurrentStreak();
    if (scoring.isTodayVictory()) {
      if (showAlreadyVictoryCelebration && context.mounted) {
        await _showVictoryCelebration(context, streak);
      }
      return DailyOutcomeRegistrationResult(DailyOutcomeStatus.alreadyVictory, streak: streak);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ya registraste gracia para hoy.')));
    }
    return DailyOutcomeRegistrationResult(DailyOutcomeStatus.alreadyGrace, streak: streak);
  }

  if (!scoring.canLogVictoryNow()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Podrás cerrar tu día después de las 6:00 PM.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    return const DailyOutcomeRegistrationResult(DailyOutcomeStatus.tooEarly);
  }

  if (!context.mounted) {
    return const DailyOutcomeRegistrationResult(DailyOutcomeStatus.cancelled);
  }

  final choice = await showDailyOutcomeChoiceSheet(context);
  if (choice == null) {
    return const DailyOutcomeRegistrationResult(DailyOutcomeStatus.cancelled);
  }

  if (choice == DailyOutcomeChoice.victory) {
    FeedbackEngine.I.confirm();
    await scoring.logVictoryForToday();
    await WidgetSyncService.I.syncWidget();
    final streak = scoring.getCurrentStreak();

    if (showVictoryCelebration && context.mounted) {
      await _showVictoryCelebration(context, streak);
    }

    return DailyOutcomeRegistrationResult(DailyOutcomeStatus.victoryLogged, streak: streak);
  }

  FeedbackEngine.I.select();
  await scoring.setDayAllGiants(DateTime.now(), 0);
  await WidgetSyncService.I.syncWidget();
  final streak = scoring.getCurrentStreak();

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Gracia registrada para hoy.')));
  }

  return DailyOutcomeRegistrationResult(DailyOutcomeStatus.graceLogged, streak: streak);
}

Future<DailyOutcomeChoice?> showDailyOutcomeChoiceSheet(BuildContext context) {
  final theme = AppThemeData.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<DailyOutcomeChoice>(
    context: context,
    showDragHandle: true,
    backgroundColor: isDark ? const Color(0xFF15151F) : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cierra tu día',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige cómo quieres registrar hoy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: theme.textSecondary),
              ),
              const SizedBox(height: 18),
              _OutcomeTile(
                icon: Icons.shield_rounded,
                title: 'Victoria',
                subtitle: 'Hoy resististe y quieres contar el día como victoria.',
                color: const Color(0xFF66BB6A),
                onTap: () => Navigator.of(context).pop(DailyOutcomeChoice.victory),
              ),
              const SizedBox(height: 12),
              _OutcomeTile(
                icon: Icons.spa_rounded,
                title: 'Gracia',
                subtitle: 'Hoy lo registras con honestidad, sin forzar una victoria.',
                color: const Color(0xFF90A4AE),
                onTap: () => Navigator.of(context).pop(DailyOutcomeChoice.grace),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> _showVictoryCelebration(BuildContext context, int streak) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) =>
          VictoryCelebrationScreen(streakDays: streak, isNewUser: streak <= 1),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(opacity: animation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 400),
    ),
  );
}

class _OutcomeTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _OutcomeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = AppThemeData.of(context);
    return Material(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.18), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: theme.textSecondary, height: 1.25),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right_rounded, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
