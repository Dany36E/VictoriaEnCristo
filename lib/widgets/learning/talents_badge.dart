/// ═══════════════════════════════════════════════════════════════════════════
/// TalentsBadge — pill dorado para el AppBar que muestra el balance actual
/// y reproduce un pulso + counter animado cuando entran nuevos talentos.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../screens/learning/talents_library_screen.dart';
import '../../services/learning/talents_service.dart';
import '../../theme/app_theme.dart';
import 'animated_counter.dart';

class TalentsBadge extends StatefulWidget {
  /// Si se pasa, sobreescribe el tap por defecto (abrir biblioteca).
  final VoidCallback? onTap;

  const TalentsBadge({super.key, this.onTap});

  @override
  State<TalentsBadge> createState() => _TalentsBadgeState();
}

class _TalentsBadgeState extends State<TalentsBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  int _previousBalance = TalentsService.I.stateNotifier.value.balance;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    TalentsService.I.stateNotifier.addListener(_maybePulse);
  }

  void _maybePulse() {
    final current = TalentsService.I.stateNotifier.value.balance;
    if (current > _previousBalance) {
      _pulse.forward(from: 0);
    }
    _previousBalance = current;
  }

  @override
  void dispose() {
    TalentsService.I.stateNotifier.removeListener(_maybePulse);
    _pulse.dispose();
    super.dispose();
  }

  void _defaultTap(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TalentsLibraryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap ?? () => _defaultTap(context),
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1.0, end: 1.18).animate(
          CurvedAnimation(parent: _pulse, curve: Curves.elasticOut),
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingS,
            vertical: AppDesignSystem.spacingS,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.spacingM,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppDesignSystem.goldDark, AppDesignSystem.gold],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
            boxShadow: [
              BoxShadow(
                color: AppDesignSystem.gold.withOpacity(0.35),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star_rounded,
                size: 18,
                color: AppDesignSystem.midnightDeep,
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<TalentsState>(
                valueListenable: TalentsService.I.stateNotifier,
                builder: (_, s, child) => AnimatedCounter(
                  value: s.balance,
                  from: _previousBalance == s.balance
                      ? s.balance
                      : (_previousBalance < s.balance
                          ? _previousBalance
                          : 0),
                  duration: const Duration(milliseconds: 600),
                  style: AppDesignSystem.labelLarge(
                    context,
                    color: AppDesignSystem.midnightDeep,
                  ).copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
