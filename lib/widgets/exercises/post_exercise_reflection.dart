import 'package:flutter/material.dart';

import '../../services/feedback_engine.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

/// Hoja modal mostrada al completar un ejercicio.
///
/// Pregunta una sola cosa: "¿Cómo te sientes ahora?" (1-5).
/// Devuelve el valor seleccionado vía `Navigator.pop`, o `null` si se omite.
///
/// Diseño deliberado:
///   • UNA pregunta (no fricción).
///   • Botón "Omitir" siempre visible (no obligatoria).
///   • Reactiva al estado de ánimo previo si se proporciona, mostrando delta.
class PostExerciseReflectionSheet extends StatefulWidget {
  final Color accentColor;
  final int? moodBefore;

  const PostExerciseReflectionSheet({
    super.key,
    required this.accentColor,
    this.moodBefore,
  });

  /// Helper para mostrar la hoja. Devuelve `int?` (1-5) o `null`.
  static Future<int?> show(
    BuildContext context, {
    required Color accentColor,
    int? moodBefore,
  }) {
    return showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostExerciseReflectionSheet(
        accentColor: accentColor,
        moodBefore: moodBefore,
      ),
    );
  }

  @override
  State<PostExerciseReflectionSheet> createState() =>
      _PostExerciseReflectionSheetState();
}

class _PostExerciseReflectionSheetState
    extends State<PostExerciseReflectionSheet> {
  int? _selected;

  static const _moods = [
    _MoodOption(value: 1, emoji: '😞', label: 'Mucho peor'),
    _MoodOption(value: 2, emoji: '😕', label: 'Peor'),
    _MoodOption(value: 3, emoji: '😐', label: 'Igual'),
    _MoodOption(value: 4, emoji: '🙂', label: 'Mejor'),
    _MoodOption(value: 5, emoji: '😊', label: 'Mucho mejor'),
  ];

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final color = widget.accentColor;

    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: t.cardBorder)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: t.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Título
          Text(
            '¿Cómo te sientes ahora?',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tu respuesta ayuda a personalizar tus próximos ejercicios.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: t.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Selector de mood
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _moods.map((m) {
              final isSelected = _selected == m.value;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    FeedbackEngine.I.tap();
                    setState(() => _selected = m.value);
                  },
                  child: AnimatedContainer(
                    duration: AppDesignSystem.durationFast,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.18)
                          : t.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : t.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.emoji, style: const TextStyle(fontSize: 26)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Etiqueta de la opción seleccionada
          AnimatedSwitcher(
            duration: AppDesignSystem.durationFast,
            child: Text(
              _selected != null
                  ? _moods.firstWhere((m) => m.value == _selected).label
                  : ' ',
              key: ValueKey(_selected),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Acciones
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  style: TextButton.styleFrom(
                    foregroundColor: t.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Omitir'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _selected != null
                      ? () {
                          FeedbackEngine.I.confirm();
                          Navigator.of(context).pop(_selected);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: color.withOpacity(0.3),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Guardar',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MoodOption {
  final int value;
  final String emoji;
  final String label;
  const _MoodOption({
    required this.value,
    required this.emoji,
    required this.label,
  });
}
