import 'package:flutter/material.dart';

import '../../models/content_enums.dart';
import '../../models/content_item.dart';
import '../../services/content_repository.dart';
import '../../services/feedback_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

/// Hoja modal de acceso rápido a ejercicios de crisis.
///
/// Pensada para ser invocada desde el botón SOS, el header de Ejercicios
/// o cualquier punto de la app donde el usuario reporte que está en crisis.
/// Muestra los ejercicios de stage=crisis en cards grandes (1 tap = arrancar).
class CrisisExercisesSheet extends StatelessWidget {
  /// Callback al tocar un ejercicio. Recibe el item para que el padre
  /// decida cómo navegar (evita acoplar este widget a una pantalla concreta).
  final void Function(ExerciseItem) onTapExercise;

  const CrisisExercisesSheet({super.key, required this.onTapExercise});

  /// Helper para mostrar la hoja con la lista de ejercicios de crisis.
  static Future<void> show(
    BuildContext context, {
    required void Function(ExerciseItem) onTapExercise,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CrisisExercisesSheet(onTapExercise: onTapExercise),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final repo = ContentRepository.I;
    final crisisExercises = repo.exercises
        .where((e) => e.metadata.stage == ContentStage.crisis)
        .take(3)
        .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: t.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: t.cardBorder)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: t.textSecondary.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppDesignSystem.struggle.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_moon,
                          color: AppDesignSystem.struggle, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Estás en buenas manos',
                            style: TextStyle(
                              color: t.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Elige una herramienta y úsala ahora',
                            style: TextStyle(
                              color: t.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Lista
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(
                      16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
                  itemCount: crisisExercises.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final ex = crisisExercises[i];
                    return _BigCrisisCard(
                      exercise: ex,
                      onTap: () {
                        FeedbackEngine.I.tap();
                        Navigator.of(context).pop();
                        onTapExercise(ex);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BigCrisisCard extends StatelessWidget {
  final ExerciseItem exercise;
  final VoidCallback onTap;

  const _BigCrisisCard({required this.exercise, required this.onTap});

  IconData _icon() {
    switch (exercise.id) {
      case 'e001':
        return Icons.air;
      case 'e002':
        return Icons.touch_app;
      case 'e003':
        return Icons.waves;
      case 'e004':
        return Icons.timer;
      default:
        return Icons.shield;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    const color = AppDesignSystem.struggle;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(color: color.withOpacity(0.4), width: 1.2),
            boxShadow: AppDesignSystem.shadowSoft,
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_icon(), color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      style: TextStyle(
                        color: t.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (exercise.subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        exercise.subtitle!,
                        style: TextStyle(
                          color: t.textSecondary,
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined,
                            color: color, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${exercise.durationMinutes} min',
                          style: const TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow,
                    color: Colors.white, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
