import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../models/plan.dart';
import '../models/plan_day.dart';
import '../services/plan_progress_service.dart';
import '../services/badge_service.dart';
import '../services/feedback_engine.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN READER SCREEN
/// Lector inmersivo para el contenido de cada día del plan
/// Soporta: scripture, herramientas, acciones, check-in, y modo rápido 2min
/// ═══════════════════════════════════════════════════════════════════════════

class PlanReaderScreen extends StatefulWidget {
  final Plan plan;
  final int dayIndex;
  final PlanProgress? progress;

  const PlanReaderScreen({
    super.key,
    required this.plan,
    required this.dayIndex,
    this.progress,
  });

  @override
  State<PlanReaderScreen> createState() => _PlanReaderScreenState();
}

class _PlanReaderScreenState extends State<PlanReaderScreen> 
    with SingleTickerProviderStateMixin {
  
  late PageController _pageController;
  late AnimationController _animationController;
  
  bool _isQuickMode = false;
  bool _isDayCompleted = false;
  int _currentSection = 0;
  
  List<_Section> _sections = [];

  PlanDay get _day => widget.plan.days[widget.dayIndex];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _isDayCompleted = widget.progress?.isDayCompleted(widget.dayIndex) ?? false;
    _buildSections();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _buildSections() {
    _sections = [];
    
    // Si estamos en modo rápido, usar versión simplificada
    if (_isQuickMode) {
      final quick = _day.quickVersion;
      _sections = [
        _Section(
          type: _SectionType.scripture,
          title: quick.scripture.reference,
          content: quick.scripture.text,
        ),
        if (quick.prayer.isNotEmpty)
          _Section(
            type: _SectionType.prayer,
            title: 'Oración',
            content: quick.prayer,
          ),
        if (quick.actionSteps.isNotEmpty)
          _Section(
            type: _SectionType.action,
            title: 'Tu acción',
            content: quick.actionSteps.first,
          ),
      ];
      return;
    }

    // 1. Scripture
    _sections.add(_Section(
      type: _SectionType.scripture,
      title: _day.scripture.reference,
      content: _day.scripture.text,
    ));

    // 2. Reflection/Main content
    if (_day.reflection.isNotEmpty) {
      _sections.add(_Section(
        type: _SectionType.reflection,
        title: 'Reflexión',
        content: _day.reflection,
      ));
    }

    // 3. Crisis tool (si existe)
    if (_day.crisisTool != null) {
      _sections.add(_Section(
        type: _SectionType.crisisTool,
        title: _day.crisisTool!.name,
        content: _day.crisisTool!.steps.join('\n\n'),
        steps: _day.crisisTool!.steps,
      ));
    }

    // 4. Action/Challenge
    if (_day.actionSteps.isNotEmpty) {
      _sections.add(_Section(
        type: _SectionType.action,
        title: 'Tu acción de hoy',
        content: _day.actionSteps.join('\n• '),
      ));
    }

    // 5. Check-in questions
    if (_day.checkInQuestions.isNotEmpty) {
      _sections.add(_Section(
        type: _SectionType.checkIn,
        title: 'Reflexiona',
        content: _day.checkInQuestions.join('\n\n'),
        questions: _day.checkInQuestions,
      ));
    }

    // 6. Prayer (si existe)
    if (_day.prayer.isNotEmpty) {
      _sections.add(_Section(
        type: _SectionType.prayer,
        title: 'Oración',
        content: _day.prayer,
      ));
    }

    // 7. Completion - siempre al final
    _sections.add(_Section(
      type: _SectionType.completion,
      title: '¡Lo lograste!',
      content: '',
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeData.of(context).surface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(child: _buildContent()),
              _buildNavigationBar(context),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HEADER
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildHeader(BuildContext context) {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: Icon(Icons.close, color: t.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          
          Expanded(
            child: Column(
              children: [
                Text(
                  'Día ${widget.dayIndex + 1}',
                  style: AppDesignSystem.labelSmall(context, color: t.accent),
                ),
                const SizedBox(height: 2),
                Text(
                  _day.title,
                  style: AppDesignSystem.labelMedium(context, color: t.textPrimary),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Quick mode toggle (siempre disponible)
          _buildQuickModeToggle(context),
        ],
      ),
    );
  }

  Widget _buildQuickModeToggle(BuildContext context) {
    final t = AppThemeData.of(context);
    return GestureDetector(
      onTap: () {
        setState(() {
          _isQuickMode = !_isQuickMode;
          _currentSection = 0;
          _buildSections();
        });
        FeedbackEngine.I.select();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _isQuickMode 
              ? AppDesignSystem.hope 
              : AppDesignSystem.hope.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppDesignSystem.hope.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt,
              size: 14,
              color: _isQuickMode ? t.surface : AppDesignSystem.hope,
            ),
            const SizedBox(width: 4),
            Text(
              '2 min',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isQuickMode ? t.surface : AppDesignSystem.hope,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONTENT
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildContent() {
    if (_sections.isEmpty) {
      return Center(
        child: Text(
          'No hay contenido disponible',
          style: AppDesignSystem.bodyMedium(context, color: AppThemeData.of(context).textSecondary),
        ),
      );
    }

    return PageView.builder(
      controller: _pageController,
      physics: const BouncingScrollPhysics(),
      itemCount: _sections.length,
      onPageChanged: (index) {
        setState(() => _currentSection = index);
      },
      itemBuilder: (context, index) {
        final section = _sections[index];
        return _buildSectionContent(section);
      },
    );
  }

  Widget _buildSectionContent(_Section section) {
    switch (section.type) {
      case _SectionType.scripture:
        return _buildScriptureSection(section);
      case _SectionType.reflection:
        return _buildReflectionSection(section);
      case _SectionType.crisisTool:
        return _buildCrisisToolSection(section);
      case _SectionType.action:
        return _buildActionSection(section);
      case _SectionType.checkIn:
        return _buildCheckInSection(section);
      case _SectionType.prayer:
        return _buildPrayerSection(section);
      case _SectionType.completion:
        return _buildCompletionSection(section);
      case _SectionType.quickVersion:
        return _buildQuickVersionSection(section);
    }
  }

  Widget _buildScriptureSection(_Section section) {
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          
          // Scripture icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: t.accent.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.menu_book_outlined,
              color: t.accent,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          // Reference
          Text(
            section.title,
            style: AppDesignSystem.labelLarge(context, color: t.accent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Scripture text
          Text(
            '"${section.content}"',
            style: AppDesignSystem.displaySmall(context, color: t.textPrimary).copyWith(
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildReflectionSection(_Section section) {
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Section header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppDesignSystem.hope.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lightbulb_outline,
                  color: AppDesignSystem.hope,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                section.title,
                style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content
          Text(
            section.content,
            style: AppDesignSystem.bodyLarge(context, color: t.textPrimary).copyWith(
              height: 1.7,
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildCrisisToolSection(_Section section) {
    final t = AppThemeData.of(context);
    final steps = section.steps ?? section.content.split('\n\n');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Section header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppDesignSystem.struggle.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppDesignSystem.struggle,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Steps
          ...steps.asMap().entries.map((entry) {
            final index = entry.key;
            final step = entry.value;
            
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: t.accent.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: AppDesignSystem.labelMedium(context, color: t.accent).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: AppDesignSystem.bodyMedium(context, color: t.textPrimary).copyWith(
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildActionSection(_Section section) {
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Icon
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  t.accent.withOpacity(0.3),
                  t.accent.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: t.accent.withOpacity(0.3)),
            ),
            child: Icon(
              Icons.flash_on,
              color: t.accent,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            section.title,
            style: AppDesignSystem.headlineSmall(context, color: t.accent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Content
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: t.inputBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.accent.withOpacity(0.2)),
            ),
            child: Text(
              section.content,
              style: AppDesignSystem.bodyLarge(context, color: t.textPrimary).copyWith(
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildCheckInSection(_Section section) {
    final t = AppThemeData.of(context);
    final questions = section.questions ?? section.content.split('\n\n');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Section header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppDesignSystem.hope.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: AppDesignSystem.hope,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                section.title,
                style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Questions
          ...questions.map((question) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppDesignSystem.hope.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.help_outline,
                      size: 20,
                      color: AppDesignSystem.hope.withOpacity(0.7),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        question,
                        style: AppDesignSystem.bodyMedium(context, color: t.textPrimary).copyWith(
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildPrayerSection(_Section section) {
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppDesignSystem.victory.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.self_improvement,
              color: AppDesignSystem.victory,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            section.title,
            style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.victory),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Prayer text
          Text(
            section.content,
            style: AppDesignSystem.bodyLarge(context, color: t.textPrimary).copyWith(
              height: 1.7,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildCompletionSection(_Section section) {
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 60),

          // Celebration icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppDesignSystem.victory.withOpacity(0.3),
                  AppDesignSystem.victory.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppDesignSystem.victory.withOpacity(0.3), width: 2),
            ),
            child: Icon(
              _isDayCompleted ? Icons.check_circle : Icons.emoji_events_outlined,
              color: AppDesignSystem.victory,
              size: 48,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            _isDayCompleted ? '¡Día completado!' : '¡Terminaste el día ${widget.dayIndex + 1}!',
            style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            _isDayCompleted
                ? 'Vuelve mañana para continuar tu progreso'
                : 'Marca este día como completado',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Complete button
          if (!_isDayCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _completeDay,
                icon: const Icon(Icons.check),
                label: const Text('Marcar como completado'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppDesignSystem.victory,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildQuickVersionSection(_Section section) {
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          // Quick mode badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppDesignSystem.hope.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 16, color: AppDesignSystem.hope),
                const SizedBox(width: 6),
                Text(
                  'Versión de 2 minutos',
                  style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.hope),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Content
          Text(
            section.content,
            style: AppDesignSystem.bodyLarge(context, color: t.textPrimary).copyWith(
              height: 1.7,
            ),
          ),

          const SizedBox(height: 32),

          // Complete button
          if (!_isDayCompleted)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _completeDay,
                icon: const Icon(Icons.check),
                label: const Text('Completar día'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.surface,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NAVIGATION BAR
  // ═══════════════════════════════════════════════════════════════════════════

  Widget _buildNavigationBar(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: t.inputBg,
        border: Border(
          top: BorderSide(color: t.surface.withOpacity(0.5)),
        ),
      ),
      child: Row(
        children: [
          // Progress dots
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_sections.length, (index) {
                final isActive = index == _currentSection;
                final isCompleted = index < _currentSection;
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      width: isActive ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? t.accent
                            : isCompleted
                                ? t.accent.withOpacity(0.5)
                                : t.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Next button
          if (_currentSection < _sections.length - 1)
            IconButton(
              onPressed: _nextSection,
              icon: Icon(Icons.arrow_forward, color: t.accent),
            )
          else if (!_isDayCompleted)
            TextButton.icon(
              onPressed: _completeDay,
              icon: const Icon(Icons.check, color: AppDesignSystem.victory),
              label: Text(
                'Completar',
                style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.victory),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  void _nextSection() {
    if (_currentSection < _sections.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeDay() async {
    try {
      final progressService = PlanProgressService();
      await progressService.init();
      final result = await progressService.completeDay(widget.plan.id, widget.dayIndex);
      
      if (result.isFailure && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(child: Text('Error guardando progreso. Tu avance podría no persistir.',
                    style: TextStyle(color: AppThemeData.of(context).textPrimary))),
              ],
            ),
            backgroundColor: AppThemeData.of(context).inputBg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }

      setState(() => _isDayCompleted = true);
      
      FeedbackEngine.I.confirm();

      // Check if entire plan is now completed
      final progress = progressService.getProgress(widget.plan.id);
      final totalDays = widget.plan.durationDays;
      final completedCount = progress?.completedDays.length ?? 0;
      final isPlanComplete = completedCount >= totalDays;

      // Check for new badges
      BadgeService.I.checkForNewBadges();
      
      if (isPlanComplete && mounted) {
        _showPlanCompletionDialog();
      } else if (result.isSuccess && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.celebration, color: AppThemeData.of(context).accent),
                const SizedBox(width: 12),
                Text(
                  '¡Día ${widget.dayIndex + 1} completado!',
                  style: TextStyle(color: AppThemeData.of(context).textPrimary),
                ),
              ],
            ),
            backgroundColor: AppThemeData.of(context).inputBg,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing day: $e');
    }
  }

  void _showPlanCompletionDialog() {
    final td = AppThemeData.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: td.cardBg,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFD4AF37).withOpacity(0.4),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFD4AF37).withOpacity(0.15),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFD4AF37),
                      const Color(0xFFD4AF37).withOpacity(0.6),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ).animate()
                .scale(begin: const Offset(0, 0), end: const Offset(1, 1),
                    duration: 500.ms, curve: Curves.elasticOut)
                .shimmer(delay: 500.ms, duration: 1500.ms,
                    color: Colors.white.withOpacity(0.3)),
              const SizedBox(height: 24),
              Text(
                '¡PLAN COMPLETADO!',
                style: GoogleFonts.cinzel(
                  color: const Color(0xFFD4AF37),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
              const SizedBox(height: 12),
              Text(
                widget.plan.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.manrope(
                  color: td.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ).animate().fadeIn(delay: 500.ms, duration: 500.ms),
              const SizedBox(height: 8),
              Text(
                '${widget.plan.durationDays} días completados',
                style: GoogleFonts.manrope(
                  color: td.textSecondary,
                  fontSize: 13,
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 500.ms),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Continuar',
                    style: GoogleFonts.manrope(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SECTION MODEL
// ═══════════════════════════════════════════════════════════════════════════

enum _SectionType {
  scripture,
  reflection,
  crisisTool,
  action,
  checkIn,
  prayer,
  completion,
  quickVersion,
}

class _Section {
  final _SectionType type;
  final String title;
  final String content;
  final List<String>? steps;
  final List<String>? questions;

  _Section({
    required this.type,
    required this.title,
    required this.content,
    this.steps,
    this.questions,
  });
}
