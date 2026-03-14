import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/plan_metadata.dart';
import '../models/content_enums.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN FILTER SHEET
/// Bottom sheet para filtrar planes por múltiples criterios
/// ═══════════════════════════════════════════════════════════════════════════

class PlanFilters {
  final Set<GiantId> giants;
  final Set<PlanType> types;
  final Set<PlanDifficulty> difficulties;
  final Set<ContentStage> stages;
  final int? maxMinutesPerDay;
  final Set<int> durations;
  final bool? forNewBelievers;
  final bool? forCrisis;

  const PlanFilters({
    this.giants = const {},
    this.types = const {},
    this.difficulties = const {},
    this.stages = const {},
    this.maxMinutesPerDay,
    this.durations = const {},
    this.forNewBelievers,
    this.forCrisis,
  });

  bool get isEmpty =>
      giants.isEmpty &&
      types.isEmpty &&
      difficulties.isEmpty &&
      stages.isEmpty &&
      maxMinutesPerDay == null &&
      durations.isEmpty &&
      forNewBelievers == null &&
      forCrisis == null;

  int get activeCount {
    int count = 0;
    if (giants.isNotEmpty) count++;
    if (types.isNotEmpty) count++;
    if (difficulties.isNotEmpty) count++;
    if (stages.isNotEmpty) count++;
    if (maxMinutesPerDay != null) count++;
    if (durations.isNotEmpty) count++;
    if (forNewBelievers == true) count++;
    if (forCrisis == true) count++;
    return count;
  }

  PlanFilters copyWith({
    Set<GiantId>? giants,
    Set<PlanType>? types,
    Set<PlanDifficulty>? difficulties,
    Set<ContentStage>? stages,
    int? maxMinutesPerDay,
    Set<int>? durations,
    bool? forNewBelievers,
    bool? forCrisis,
    bool clearMaxMinutes = false,
    bool clearForNewBelievers = false,
    bool clearForCrisis = false,
  }) {
    return PlanFilters(
      giants: giants ?? this.giants,
      types: types ?? this.types,
      difficulties: difficulties ?? this.difficulties,
      stages: stages ?? this.stages,
      maxMinutesPerDay: clearMaxMinutes ? null : (maxMinutesPerDay ?? this.maxMinutesPerDay),
      durations: durations ?? this.durations,
      forNewBelievers: clearForNewBelievers ? null : (forNewBelievers ?? this.forNewBelievers),
      forCrisis: clearForCrisis ? null : (forCrisis ?? this.forCrisis),
    );
  }

  static const empty = PlanFilters();
}

class PlanFilterSheet extends StatefulWidget {
  final PlanFilters initialFilters;
  final ValueChanged<PlanFilters> onApply;

  const PlanFilterSheet({
    super.key,
    required this.initialFilters,
    required this.onApply,
  });

  static Future<PlanFilters?> show(
    BuildContext context, {
    required PlanFilters currentFilters,
  }) {
    return showModalBottomSheet<PlanFilters>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PlanFilterSheet(
        initialFilters: currentFilters,
        onApply: (filters) => Navigator.of(context).pop(filters),
      ),
    );
  }

  @override
  State<PlanFilterSheet> createState() => _PlanFilterSheetState();
}

class _PlanFilterSheetState extends State<PlanFilterSheet> {
  late PlanFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppDesignSystem.midnightLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppDesignSystem.coolGray.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Filtrar Planes',
                  style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.pureWhite),
                ),
                if (!_filters.isEmpty)
                  TextButton(
                    onPressed: _clearAll,
                    child: Text(
                      'Limpiar todo',
                      style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold),
                    ),
                  ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),

                  // ══════════════════════════════════════════════════════════════
                  // GIGANTES
                  // ══════════════════════════════════════════════════════════════
                  _buildSectionTitle('¿Con qué luchas?'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: GiantId.values.map((giant) {
                      final isSelected = _filters.giants.contains(giant);
                      return _FilterChip(
                        label: giant.displayName,
                        icon: _getGiantIcon(giant),
                        isSelected: isSelected,
                        color: _getGiantColor(giant),
                        onTap: () => _toggleGiant(giant),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════════════════════
                  // TIPO DE PLAN
                  // ══════════════════════════════════════════════════════════════
                  _buildSectionTitle('Tipo de Plan'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PlanType.values.map((type) {
                      final isSelected = _filters.types.contains(type);
                      return _FilterChip(
                        label: type.displayName,
                        icon: _getPlanTypeIcon(type),
                        isSelected: isSelected,
                        onTap: () => _toggleType(type),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════════════════════
                  // DIFICULTAD
                  // ══════════════════════════════════════════════════════════════
                  _buildSectionTitle('Nivel'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: PlanDifficulty.values.map((difficulty) {
                      final isSelected = _filters.difficulties.contains(difficulty);
                      return _FilterChip(
                        label: difficulty.displayName,
                        icon: _getDifficultyIcon(difficulty),
                        isSelected: isSelected,
                        color: _getDifficultyColor(difficulty),
                        onTap: () => _toggleDifficulty(difficulty),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════════════════════
                  // ETAPA
                  // ══════════════════════════════════════════════════════════════
                  _buildSectionTitle('¿En qué etapa estás?'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ContentStage.values.map((stage) {
                      final isSelected = _filters.stages.contains(stage);
                      return _FilterChip(
                        label: stage.displayName,
                        isSelected: isSelected,
                        onTap: () => _toggleStage(stage),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════════════════════
                  // DURACIÓN
                  // ══════════════════════════════════════════════════════════════
                  _buildSectionTitle('Duración'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      (3, '3 días'),
                      (7, '7 días'),
                      (14, '14 días'),
                      (21, '21 días'),
                      (30, '30 días'),
                    ].map((item) {
                      final (days, label) = item;
                      final isSelected = _filters.durations.contains(days);
                      return _FilterChip(
                        label: label,
                        icon: Icons.calendar_today_outlined,
                        isSelected: isSelected,
                        onTap: () => _toggleDuration(days),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════════════════════
                  // TIEMPO DIARIO
                  // ══════════════════════════════════════════════════════════════
                  _buildSectionTitle('Tiempo diario máximo'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      (5, '5 min'),
                      (10, '10 min'),
                      (15, '15 min'),
                      (20, '20 min'),
                      (30, '30 min'),
                    ].map((item) {
                      final (minutes, label) = item;
                      final isSelected = _filters.maxMinutesPerDay == minutes;
                      return _FilterChip(
                        label: label,
                        icon: Icons.access_time_outlined,
                        isSelected: isSelected,
                        onTap: () => _setMaxMinutes(minutes),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // ══════════════════════════════════════════════════════════════
                  // OPCIONES ESPECIALES
                  // ══════════════════════════════════════════════════════════════
                  _buildSectionTitle('Mostrar solo'),
                  const SizedBox(height: 12),
                  _FilterChip(
                    label: 'Nuevos en la fe',
                    icon: Icons.child_care_outlined,
                    isSelected: _filters.forNewBelievers == true,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(
                        forNewBelievers: _filters.forNewBelievers == true ? null : true,
                        clearForNewBelievers: _filters.forNewBelievers == true,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  _FilterChip(
                    label: 'Situación de crisis',
                    icon: Icons.local_hospital_outlined,
                    isSelected: _filters.forCrisis == true,
                    color: AppDesignSystem.struggle,
                    onTap: () => setState(() {
                      _filters = _filters.copyWith(
                        forCrisis: _filters.forCrisis == true ? null : true,
                        clearForCrisis: _filters.forCrisis == true,
                      );
                    }),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),

          // Apply Button
          Padding(
            padding: EdgeInsets.fromLTRB(
              20, 
              16, 
              20, 
              16 + MediaQuery.of(context).padding.bottom,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => widget.onApply(_filters),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.gold,
                  foregroundColor: AppDesignSystem.midnight,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _filters.isEmpty 
                    ? 'Ver todos los planes' 
                    : 'Aplicar filtros (${_filters.activeCount})',
                  style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.midnight).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.pureWhite).copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  void _clearAll() {
    setState(() => _filters = PlanFilters.empty);
  }

  void _toggleGiant(GiantId giant) {
    setState(() {
      final newGiants = Set<GiantId>.from(_filters.giants);
      if (newGiants.contains(giant)) {
        newGiants.remove(giant);
      } else {
        newGiants.add(giant);
      }
      _filters = _filters.copyWith(giants: newGiants);
    });
  }

  void _toggleType(PlanType type) {
    setState(() {
      final newTypes = Set<PlanType>.from(_filters.types);
      if (newTypes.contains(type)) {
        newTypes.remove(type);
      } else {
        newTypes.add(type);
      }
      _filters = _filters.copyWith(types: newTypes);
    });
  }

  void _toggleDifficulty(PlanDifficulty difficulty) {
    setState(() {
      final newDifficulties = Set<PlanDifficulty>.from(_filters.difficulties);
      if (newDifficulties.contains(difficulty)) {
        newDifficulties.remove(difficulty);
      } else {
        newDifficulties.add(difficulty);
      }
      _filters = _filters.copyWith(difficulties: newDifficulties);
    });
  }

  void _toggleStage(ContentStage stage) {
    setState(() {
      final newStages = Set<ContentStage>.from(_filters.stages);
      if (newStages.contains(stage)) {
        newStages.remove(stage);
      } else {
        newStages.add(stage);
      }
      _filters = _filters.copyWith(stages: newStages);
    });
  }

  void _toggleDuration(int days) {
    setState(() {
      final newDurations = Set<int>.from(_filters.durations);
      if (newDurations.contains(days)) {
        newDurations.remove(days);
      } else {
        newDurations.add(days);
      }
      _filters = _filters.copyWith(durations: newDurations);
    });
  }

  void _setMaxMinutes(int minutes) {
    setState(() {
      if (_filters.maxMinutesPerDay == minutes) {
        _filters = _filters.copyWith(clearMaxMinutes: true);
      } else {
        _filters = _filters.copyWith(maxMinutesPerDay: minutes);
      }
    });
  }

  IconData _getGiantIcon(GiantId giant) {
    switch (giant) {
      case GiantId.digital:
        return Icons.phone_android_outlined;
      case GiantId.sexual:
        return Icons.visibility_off_outlined;
      case GiantId.health:
        return Icons.restaurant_outlined;
      case GiantId.substances:
        return Icons.local_bar_outlined;
      case GiantId.mental:
        return Icons.psychology_outlined;
      case GiantId.emotions:
        return Icons.heart_broken_outlined;
    }
  }

  Color _getGiantColor(GiantId giant) {
    switch (giant) {
      case GiantId.digital:
        return const Color(0xFF3498DB);
      case GiantId.sexual:
        return const Color(0xFF8E44AD);
      case GiantId.health:
        return const Color(0xFFE67E22);
      case GiantId.substances:
        return const Color(0xFFC0392B);
      case GiantId.mental:
        return const Color(0xFF2C3E50);
      case GiantId.emotions:
        return const Color(0xFFE74C3C);
    }
  }

  IconData _getPlanTypeIcon(PlanType type) {
    switch (type) {
      case PlanType.newInFaith:
        return Icons.child_care_outlined;
      case PlanType.giantFocused:
        return Icons.local_hospital_outlined;
      case PlanType.scriptureDepth:
        return Icons.menu_book_outlined;
      case PlanType.emotionalRegulation:
        return Icons.spa_outlined;
      case PlanType.relapseRecovery:
        return Icons.refresh;
      case PlanType.discipleship:
        return Icons.auto_awesome;
    }
  }

  IconData _getDifficultyIcon(PlanDifficulty difficulty) {
    switch (difficulty) {
      case PlanDifficulty.easy:
        return Icons.spa_outlined;
      case PlanDifficulty.medium:
        return Icons.local_fire_department_outlined;
      case PlanDifficulty.hard:
        return Icons.bolt;
    }
  }

  Color _getDifficultyColor(PlanDifficulty difficulty) {
    switch (difficulty) {
      case PlanDifficulty.easy:
        return AppDesignSystem.victory;
      case PlanDifficulty.medium:
        return AppDesignSystem.hope;
      case PlanDifficulty.hard:
        return AppDesignSystem.struggle;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// FILTER CHIP WIDGET
// ═══════════════════════════════════════════════════════════════════════════

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppDesignSystem.gold;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
            ? chipColor.withOpacity(0.2) 
            : AppDesignSystem.midnight.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
              ? chipColor 
              : AppDesignSystem.coolGray.withOpacity(0.2),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: isSelected ? chipColor : AppDesignSystem.coolGray,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: AppDesignSystem.labelSmall(context, 
                color: isSelected ? chipColor : AppDesignSystem.coolGray,
              ).copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.check,
                size: 14,
                color: chipColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
