/// ═══════════════════════════════════════════════════════════════════════════
/// FruitWeekScreen — una semana de un fruto
///
/// Muestra: definición + versículo + meditación + 3 acciones (toggleables)
/// + reflexión (textfield). Al cumplir las 3 acciones + reflexión ≥ 20 chars,
/// aparece el botón "Ganar insignia".
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/fruit_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/fruit_progress_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';

class FruitWeekScreen extends StatefulWidget {
  final SpiritFruit fruit;
  const FruitWeekScreen({super.key, required this.fruit});

  @override
  State<FruitWeekScreen> createState() => _FruitWeekScreenState();
}

class _FruitWeekScreenState extends State<FruitWeekScreen> {
  late TextEditingController _reflCtrl;
  bool _saved = false;

  SpiritFruit get f => widget.fruit;

  Color _parseHex(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  @override
  void initState() {
    super.initState();
    final existing =
        FruitProgressService.I.progressFor(f.id).reflection;
    _reflCtrl = TextEditingController(text: existing);
    _reflCtrl.addListener(_onReflChange);
  }

  @override
  void dispose() {
    _reflCtrl.removeListener(_onReflChange);
    _reflCtrl.dispose();
    super.dispose();
  }

  void _onReflChange() {
    _saved = false;
    setState(() {});
  }

  Future<void> _saveReflection() async {
    await FruitProgressService.I.setReflection(f.id, _reflCtrl.text);
    if (!mounted) return;
    setState(() => _saved = true);
    FeedbackEngine.I.confirm();
  }

  Future<void> _tryAwardBadge() async {
    // Guardar antes de intentar otorgar
    await FruitProgressService.I.setReflection(f.id, _reflCtrl.text);
    final xp = await FruitProgressService.I
        .tryAwardBadge(f.id, f.actions.length, f.xpReward);
    if (!mounted) return;
    FeedbackEngine.I.confirm();
    if (xp > 0) {
      showDialog(
        context: context,
        builder: (_) => _BadgeDialog(fruit: f, xp: xp),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final color = _parseHex(f.colorHex);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          f.name,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: ValueListenableBuilder<FruitProgressState>(
        valueListenable: FruitProgressService.I.stateNotifier,
        builder: (context, state, _) {
          final prog = FruitProgressService.I.progressFor(f.id);
          final hasBadge = state.badges.contains(f.id);
          final canAward =
              prog.isComplete(f.actions.length) && !hasBadge;
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              _banner(t, color, hasBadge),
              const SizedBox(height: AppDesignSystem.spacingM),
              _verse(t, color),
              const SizedBox(height: AppDesignSystem.spacingM),
              _meditation(t),
              const SizedBox(height: AppDesignSystem.spacingL),
              Text(
                'Microacciones de la semana',
                style: AppDesignSystem.headlineSmall(context,
                    color: t.textPrimary),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              ...f.actions.map((a) {
                final done = prog.doneActions.contains(a.id);
                return _actionTile(t, color, a, done);
              }),
              const SizedBox(height: AppDesignSystem.spacingL),
              Text(
                'Reflexión',
                style: AppDesignSystem.headlineSmall(context,
                    color: t.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                f.reflectionPrompt,
                style: AppDesignSystem.bodyMedium(context,
                    color: t.textSecondary),
              ),
              const SizedBox(height: AppDesignSystem.spacingS),
              TextField(
                controller: _reflCtrl,
                maxLines: 5,
                style: AppDesignSystem.bodyLarge(context,
                    color: t.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Escribe tu respuesta (mín. 20 caracteres)…',
                  hintStyle: AppDesignSystem.bodyMedium(context,
                      color: t.textSecondary),
                  filled: true,
                  fillColor: t.cardBg,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusL),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusL),
                    borderSide: BorderSide(color: t.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDesignSystem.radiusL),
                    borderSide: BorderSide(color: color),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _saveReflection,
                    icon: Icon(
                      _saved
                          ? Icons.check_circle_rounded
                          : Icons.save_rounded,
                      color: _saved
                          ? AppDesignSystem.gold
                          : t.textSecondary,
                      size: 18,
                    ),
                    label: Text(
                      _saved ? 'Guardado' : 'Guardar reflexión',
                      style: TextStyle(
                        color: _saved
                            ? AppDesignSystem.gold
                            : t.textSecondary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_reflCtrl.text.trim().length}/20',
                    style: AppDesignSystem.labelSmall(
                      context,
                      color: _reflCtrl.text.trim().length >= 20
                          ? AppDesignSystem.gold
                          : t.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
              if (hasBadge)
                _awardedCard(t, color)
              else
                SizedBox(
                  width: double.infinity,
                  child: PremiumButton(
                    onPressed: canAward ? _tryAwardBadge : () {},
                    child: Text(canAward
                        ? 'Ganar insignia de ${f.name}'
                        : 'Cumple las 3 acciones y escribe reflexión'),
                  ),
                ),
              const SizedBox(height: AppDesignSystem.spacingXL),
            ],
          );
        },
      ),
    );
  }

  Widget _banner(AppThemeData t, Color color, bool hasBadge) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.25), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.name,
                  style: AppDesignSystem.headlineMedium(context,
                      color: t.textPrimary),
                ),
                Text(
                  f.greek,
                  style: TextStyle(
                    color: color,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  f.definition,
                  style: AppDesignSystem.bodyMedium(context,
                      color: t.textSecondary),
                ),
              ],
            ),
          ),
          if (hasBadge)
            const Padding(
              padding: EdgeInsets.only(left: 10),
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppDesignSystem.gold,
                child: Icon(Icons.emoji_events_rounded,
                    color: Colors.black),
              ),
            ),
        ],
      ),
    );
  }

  Widget _verse(AppThemeData t, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: t.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            f.keyVerseRef,
            style: AppDesignSystem.labelSmall(context, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            '"${f.keyVerse}"',
            style: AppDesignSystem.scripture(context, color: t.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _meditation(AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded,
              color: AppDesignSystem.gold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              f.meditation,
              style: AppDesignSystem.bodyMedium(context,
                  color: t.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
      AppThemeData t, Color color, FruitAction a, bool done) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        onTap: () async {
          FeedbackEngine.I.tap();
          await FruitProgressService.I.toggleAction(f.id, a.id);
        },
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: done ? color.withOpacity(0.12) : t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(
              color: done ? color : t.cardBorder,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: done ? color : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? color : t.textSecondary,
                    width: 2,
                  ),
                ),
                child: done
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  a.text,
                  style: AppDesignSystem.bodyLarge(
                    context,
                    color: done
                        ? t.textPrimary
                        : t.textPrimary.withOpacity(0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _awardedCard(AppThemeData t, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.3),
            AppDesignSystem.gold.withOpacity(0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: AppDesignSystem.gold),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events_rounded,
              color: AppDesignSystem.gold, size: 32),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insignia ganada',
                  style: AppDesignSystem.headlineSmall(context,
                      color: t.textPrimary),
                ),
                Text(
                  'Regresa cuando quieras a repasar este fruto.',
                  style: AppDesignSystem.bodyMedium(context,
                      color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeDialog extends StatelessWidget {
  final SpiritFruit fruit;
  final int xp;
  const _BadgeDialog({required this.fruit, required this.xp});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Dialog(
      backgroundColor: t.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                    color: AppDesignSystem.gold, size: 80)
                .animate()
                .scale(
                    begin: const Offset(0.3, 0.3),
                    duration: 500.ms,
                    curve: Curves.elasticOut),
            const SizedBox(height: AppDesignSystem.spacingM),
            Text(
              '¡Insignia de ${fruit.name}!',
              style: AppDesignSystem.headlineMedium(context,
                  color: t.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '"$xp XP" · Sigue regando el huerto del Espíritu.',
              textAlign: TextAlign.center,
              style: AppDesignSystem.bodyMedium(context,
                  color: t.textSecondary),
            ),
            const SizedBox(height: AppDesignSystem.spacingL),
            SizedBox(
              width: double.infinity,
              child: PremiumButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Amén'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
