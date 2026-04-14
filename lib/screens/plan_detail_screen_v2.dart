import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
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
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.surface,
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
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(AppThemeData.of(context).accent),
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
    final t = AppThemeData.of(context);
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      backgroundColor: t.surface,
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
                      t.surface.withOpacity(0.8),
                      t.surface,
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
                    style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Subtitle
                  Text(
                    _plan.subtitle,
                    style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
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
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: t.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, size: 20),
              color: t.textPrimary,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShareButton() {
    final t = AppThemeData.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: t.surface.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            color: t.textPrimary,
            onPressed: _sharePlan,
          ),
        ),
      ),
    );
  }

  Widget _buildReminderButton() {
    final t = AppThemeData.of(context);
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
                  ? t.accent.withOpacity(0.3)
                  : t.surface.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _hasReminder ? Icons.notifications_active : Icons.notifications_outlined,
                size: 20,
              ),
              color: _hasReminder ? t.accent : t.textPrimary,
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
    final t = AppThemeData.of(context);
    final type = _plan.metadata.planType;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: t.accent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.accent.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getPlanTypeIcon(type), size: 14, color: t.accent),
          const SizedBox(width: 6),
          Text(
            type.displayName,
            style: AppDesignSystem.labelSmall(context, color: t.accent).copyWith(
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
    final t = AppThemeData.of(context);
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
            style: AppDesignSystem.bodyMedium(context, color: t.textPrimary).copyWith(
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String label) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: t.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppDesignSystem.goldSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: t.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
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
    final t = AppThemeData.of(context);
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
              style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
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
              style: AppDesignSystem.labelMedium(context, color: t.textSecondary),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _plan.metadata.techniques.take(4).map((technique) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: t.surface.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: t.textSecondary.withOpacity(0.2)),
                  ),
                  child: Text(
                    technique.displayName,
                    style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
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
    final t = AppThemeData.of(context);
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
                    backgroundColor: t.surface.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation(t.accent),
                  ),
                  Text(
                    '${(_progressPercent * 100).toInt()}%',
                    style: AppDesignSystem.labelMedium(context, color: t.accent).copyWith(
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
                    style: AppDesignSystem.labelMedium(context, color: t.accent),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_progress!.completedDays.length} de ${_plan.durationDays} días completados',
                    style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
                  ),
                  if (_progress!.currentStreak > 1) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department, size: 14, color: AppDesignSystem.gold),
                        const SizedBox(width: 4),
                        Text(
                          'Racha: ${_progress!.currentStreak} días',
                          style: AppDesignSystem.labelSmall(context, color: t.accent),
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
    final t = AppThemeData.of(context);
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
                  style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
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
    final t = AppThemeData.of(context);
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
                  ? t.accent.withOpacity(0.1)
                  : t.inputBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentDay
                    ? t.accent.withOpacity(0.3)
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
                            : t.surface,
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
                                  ? t.surface
                                  : t.textSecondary,
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
                              ? t.textSecondary.withOpacity(0.5)
                              : t.textPrimary,
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
                                color: t.textSecondary.withOpacity(isLocked ? 0.3 : 0.7),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${day.estimatedMinutes} min',
                                style: AppDesignSystem.labelSmall(
                                  context,
                                  color: t.textSecondary.withOpacity(isLocked ? 0.3 : 0.7),
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
                      ? t.textSecondary.withOpacity(0.3)
                      : isCurrentDay
                          ? t.accent
                          : t.textSecondary,
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
    final t = AppThemeData.of(context);
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
          backgroundColor: t.accent,
          foregroundColor: t.surface,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: AppDesignSystem.labelLarge(context, color: t.surface).copyWith(
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
    final completedDays = _progress?.completedDays.length ?? 0;
    final totalDays = _plan.durationDays;
    final percent = (_progressPercent * 100).round();
    
    final buffer = StringBuffer();
    buffer.writeln('📖 ${_plan.title}');
    if (_plan.subtitle.isNotEmpty) {
      buffer.writeln(_plan.subtitle);
    }
    buffer.writeln();
    if (completedDays > 0) {
      buffer.writeln('📊 Progreso: $completedDays/$totalDays días ($percent%)');
      buffer.writeln();
    }
    // Descripción truncada a 200 chars
    final desc = _plan.description;
    if (desc.isNotEmpty) {
      buffer.writeln(desc.length > 200 ? '${desc.substring(0, 200)}...' : desc);
      buffer.writeln();
    }
    buffer.write('— Victoria en Cristo');
    
    Share.share(buffer.toString());
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
              colorScheme: ColorScheme.dark(
                primary: AppDesignSystem.gold,
                surface: AppThemeData.of(context).inputBg,
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
        SnackBar(content: Text('El día ${dayIndex + 1} aún no tiene contenido disponible')),
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
    ).then((_) => _loadData())
     .catchError((e) { debugPrint('⚠️ [PlanDetail] Nav reader error: $e'); });
  }
}
