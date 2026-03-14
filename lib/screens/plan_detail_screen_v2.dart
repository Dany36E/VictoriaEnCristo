import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../models/plan.dart';
import '../models/plan_day.dart';
import '../models/plan_metadata.dart';
import '../models/content_enums.dart';
import '../services/plan_repository.dart';
import '../services/plan_progress_service.dart';
import '../widgets/plan_cover.dart';
import 'plan_reader_screen.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN DETAIL SCREEN V2
/// Pantalla de detalle usando el modelo Plan actualizado
/// Hero image, descripción, metadata, y navegación a días
/// ═══════════════════════════════════════════════════════════════════════════

class PlanDetailScreenV2 extends StatefulWidget {
  final Plan plan;
  final PlanProgress? initialProgress;

  const PlanDetailScreenV2({
    super.key,
    required this.plan,
    this.initialProgress,
  });

  @override
  State<PlanDetailScreenV2> createState() => _PlanDetailScreenV2State();
}

class _PlanDetailScreenV2State extends State<PlanDetailScreenV2> {
  late Plan _plan;
  PlanProgress? _progress;
  bool _isLoading = true;
  bool _hasReminder = false;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
    _progress = widget.initialProgress;
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Cargar días completos si hay daysRef
      if (_plan.daysRef != null && _plan.days.length < _plan.durationDays) {
        final repo = PlanRepository();
        final fullPlan = repo.getPlan(_plan.id);
        if (fullPlan != null) {
          _plan = fullPlan;
        }
      }

      // Cargar progreso
      final progressService = PlanProgressService();
      await progressService.init();
      
      _progress = progressService.getProgress(_plan.id);
      _hasReminder = progressService.hasReminder(_plan.id);

      // Marcar como abierto
      await progressService.markOpened(_plan.id);

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading plan data: $e');
      setState(() => _isLoading = false);
    }
  }

  double get _progressPercent => 
      _progress?.progressPercentage(_plan.durationDays) ?? 0.0;

  bool get _isStarted => 
      _progress != null && _progress!.completedDays.isNotEmpty;

  bool get _isCompleted => _progressPercent >= 1.0;

  int get _currentDayIndex => 
      _progress?.currentDay ?? 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      body: _isLoading
          ? _buildLoadingState()
          : Stack(
              children: [
                _buildContent(context),
                _buildFAB(context),
              ],
            ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(AppDesignSystem.gold),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildHeroAppBar(context),
        SliverToBoxAdapter(child: _buildPlanInfo(context)),
        SliverToBoxAdapter(child: _buildMetadataSection(context)),
        SliverToBoxAdapter(child: _buildProgressSection(context)),
        _buildDaysList(context),
        const SliverToBoxAdapter(child: SizedBox(height: 120)),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HERO APP BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeroAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: AppDesignSystem.midnight,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: _buildBackButton(context),
      actions: [
        _buildShareButton(),
        _buildReminderButton(),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
          StretchMode.blurBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Cover Image
            _buildCoverImage(),
            
            // Gradient overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      AppDesignSystem.midnight.withOpacity(0.8),
                      AppDesignSystem.midnight,
                    ],
                    stops: const [0.0, 0.3, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Bottom content
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type badge
                  _buildTypeBadge(),
                  const SizedBox(height: 8),
                  
                  // Title
                  Text(
                    _plan.title,
                    style: AppDesignSystem.headlineMedium(context, color: AppDesignSystem.pureWhite),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Subtitle
                  Text(
                    _plan.subtitle,
                    style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.coolGray),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Completed badge
            if (_isCompleted)
              Positioned(
                top: 100,
                right: 20,
                child: _buildCompletedBadge(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppDesignSystem.midnight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: AppDesignSystem.pureWhite,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppDesignSystem.midnight.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            color: AppDesignSystem.pureWhite,
            onPressed: _sharePlan,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hasReminder 
                  ? AppDesignSystem.gold.withOpacity(0.3)
                  : AppDesignSystem.midnight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _hasReminder ? Icons.notifications_active : Icons.notifications_outlined,
                size: 20,
              ),
              color: _hasReminder ? AppDesignSystem.gold : AppDesignSystem.pureWhite,
              onPressed: _toggleReminder,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverImage() {
    // Usar PlanCover premium - funciona con imagen real o genera cover editorial
    return PlanCover(
      plan: _plan,
      showTitle: false, // El título se muestra por separado en el hero
      showBadge: false, // El badge de tipo se maneja aparte
    );
  }

  Widget _buildTypeBadge() {
    final type = _plan.metadata.planType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getPlanTypeIcon(type), size: 14, color: AppDesignSystem.gold),
          const SizedBox(width: 6),
          Text(
            type.displayName,
            style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignSystem.victory,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppDesignSystem.victory.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 18, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            '¡Completado!',
            style: AppDesignSystem.labelMedium(context, color: Colors.white).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PLAN INFO SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildPlanInfo(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick stats - usar Wrap para evitar overflow en pantallas pequeñas
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip(Icons.calendar_today_outlined, _plan.durationLabel),
              _buildStatChip(Icons.access_time_outlined, '${_plan.minutesPerDay} min/día'),
              _buildDifficultyChip(),
            ],
          ),
          const SizedBox(height: 20),

          // Description
          Text(
            _plan.description,
            style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.softWhite).copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppDesignSystem.midnightLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignSystem.goldSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppDesignSystem.gold),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
          ),
        ],
      ),
    );
  }

  Widget _buildDifficultyChip() {
    final difficulty = _plan.metadata.difficulty;
    Color color;
    IconData icon;

    switch (difficulty) {
      case PlanDifficulty.easy:
        color = AppDesignSystem.victory;
        icon = Icons.spa_outlined;
        break;
      case PlanDifficulty.medium:
        color = AppDesignSystem.hope;
        icon = Icons.local_fire_department_outlined;
        break;
      case PlanDifficulty.hard:
        color = AppDesignSystem.struggle;
        icon = Icons.bolt;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            difficulty.displayName,
            style: AppDesignSystem.labelSmall(context, color: color),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // METADATA SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildMetadataSection(BuildContext context) {
    if (_plan.metadata.giants.isEmpty && _plan.metadata.techniques.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Giants
          if (_plan.metadata.giants.isNotEmpty) ...[
            Text(
              'Ayuda con:',
              style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.coolGray),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plan.metadata.giants.map((giant) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getGiantColor(giant).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _getGiantColor(giant).withOpacity(0.3)),
                  ),
                  child: Text(
                    giant.displayName,
                    style: AppDesignSystem.labelSmall(context, color: _getGiantColor(giant)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],

          // Techniques
          if (_plan.metadata.techniques.isNotEmpty) ...[
            Text(
              'Técnicas:',
              style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.coolGray),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plan.metadata.techniques.take(4).map((technique) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.midnight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppDesignSystem.coolGray.withOpacity(0.2)),
                  ),
                  child: Text(
                    technique.displayName,
                    style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
                  ),
                );
              }).toList(),
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PROGRESS SECTION
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildProgressSection(BuildContext context) {
    if (!_isStarted) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppDesignSystem.gold.withOpacity(0.15),
              AppDesignSystem.gold.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignSystem.gold.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            // Progress ring
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progressPercent,
                    strokeWidth: 5,
                    backgroundColor: AppDesignSystem.midnight.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
                  ),
                  Text(
                    '${(_progressPercent * 100).toInt()}%',
                    style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold).copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Stats
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu progreso',
                    style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_progress!.completedDays.length} de ${_plan.durationDays} días completados',
                    style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.coolGray),
                  ),
                  if (_progress!.currentStreak > 1) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 14, color: AppDesignSystem.gold),
                        const SizedBox(width: 4),
                        Text(
                          'Racha: ${_progress!.currentStreak} días',
                          style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // DAYS LIST
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildDaysList(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'Días del plan',
                  style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.pureWhite),
                ),
              );
            }
            
            final dayIndex = index - 1;
            final isCompleted = _progress?.isDayCompleted(dayIndex) ?? false;
            final isCurrentDay = dayIndex == _currentDayIndex;
            final isLocked = dayIndex > _currentDayIndex && !isCompleted;
            
            // Check if we have the day content
            final hasContent = dayIndex < _plan.days.length;
            final day = hasContent ? _plan.days[dayIndex] : null;

            return _buildDayTile(
              context,
              dayIndex: dayIndex,
              day: day,
              isCompleted: isCompleted,
              isCurrentDay: isCurrentDay,
              isLocked: isLocked,
            );
          },
          childCount: _plan.durationDays + 1,
        ),
      ),
    );
  }

  Widget _buildDayTile(
    BuildContext context, {
    required int dayIndex,
    PlanDay? day,
    required bool isCompleted,
    required bool isCurrentDay,
    required bool isLocked,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLocked ? null : () => _openDay(dayIndex),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentDay
                  ? AppDesignSystem.gold.withOpacity(0.1)
                  : AppDesignSystem.midnightLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentDay
                    ? AppDesignSystem.gold.withOpacity(0.3)
                    : isCompleted
                        ? AppDesignSystem.victory.withOpacity(0.3)
                        : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                // Day number
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? AppDesignSystem.victory
                        : isCurrentDay
                            ? AppDesignSystem.gold
                            : AppDesignSystem.midnight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : Text(
                            '${dayIndex + 1}',
                            style: AppDesignSystem.labelLarge(
                              context,
                              color: isCurrentDay
                                  ? AppDesignSystem.midnight
                                  : AppDesignSystem.coolGray,
                            ).copyWith(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        day?.title ?? 'Día ${dayIndex + 1}',
                        style: AppDesignSystem.labelLarge(
                          context,
                          color: isLocked
                              ? AppDesignSystem.coolGray.withOpacity(0.5)
                              : AppDesignSystem.pureWhite,
                        ),
                      ),
                      if (day != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (day.estimatedMinutes > 0) ...[
                              Icon(
                                Icons.access_time_outlined,
                                size: 12,
                                color: AppDesignSystem.coolGray.withOpacity(isLocked ? 0.3 : 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${day.estimatedMinutes} min',
                                style: AppDesignSystem.labelSmall(
                                  context,
                                  color: AppDesignSystem.coolGray.withOpacity(isLocked ? 0.3 : 0.7),
                                ),
                              ),
                            ],
                            if (day.estimatedMinutes > 3) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppDesignSystem.hope.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '2 min',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: AppDesignSystem.hope.withOpacity(isLocked ? 0.3 : 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Arrow or lock
                Icon(
                  isLocked ? Icons.lock_outline : Icons.chevron_right,
                  color: isLocked
                      ? AppDesignSystem.coolGray.withOpacity(0.3)
                      : isCurrentDay
                          ? AppDesignSystem.gold
                          : AppDesignSystem.coolGray,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FLOATING ACTION BUTTON
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildFAB(BuildContext context) {
    String label;
    IconData icon;

    if (_isCompleted) {
      label = 'Repetir plan';
      icon = Icons.replay;
    } else if (_isStarted) {
      label = 'Continuar día ${_currentDayIndex + 1}';
      icon = Icons.play_arrow;
    } else {
      label = 'Comenzar plan';
      icon = Icons.play_arrow;
    }

    return Positioned(
      bottom: 20 + MediaQuery.of(context).padding.bottom,
      left: 20,
      right: 20,
      child: ElevatedButton.icon(
        onPressed: () => _openDay(_currentDayIndex),
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDesignSystem.gold,
          foregroundColor: AppDesignSystem.midnight,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppDesignSystem.labelLarge(context, color: AppDesignSystem.midnight).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

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

  void _sharePlan() {
    // TODO: Implement share
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compartir próximamente')),
    );
  }

  void _toggleReminder() async {
    if (_hasReminder) {
      final progressService = PlanProgressService();
      await progressService.disableReminder(_plan.id);
      setState(() => _hasReminder = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Recordatorio desactivado')),
        );
      }
    } else {
      // Show time picker
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.dark(
                primary: AppDesignSystem.gold,
                surface: AppDesignSystem.midnightLight,
              ),
            ),
            child: child!,
          );
        },
      );

      if (time != null) {
        final timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final progressService = PlanProgressService();
        await progressService.setReminder(_plan.id, timeString);
        
        setState(() {
          _hasReminder = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Recordatorio configurado a las $timeString')),
          );
        }
      }
    }
  }

  void _openDay(int dayIndex) {
    if (dayIndex >= _plan.days.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contenido del día próximamente')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanReaderScreen(
          plan: _plan,
          dayIndex: dayIndex,
          progress: _progress,
        ),
      ),
    ).then((_) => _loadData()); // Refresh progress on return
  }
}
