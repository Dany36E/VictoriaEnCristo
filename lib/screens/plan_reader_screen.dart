import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/plan.dart';
import '../models/plan_day.dart';
import '../services/plan_progress_service.dart';
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
      backgroundColor: AppDesignSystem.midnight,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          // Back button
          IconButton(
            icon: const Icon(Icons.close, color: AppDesignSystem.pureWhite),
            onPressed: () => Navigator.of(context).pop(),
          ),
          
          Expanded(
            child: Column(
              children: [
                Text(
                  'Día ${widget.dayIndex + 1}',
                  style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
                ),
                const SizedBox(height: 2),
                Text(
                  _day.title,
                  style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.pureWhite),
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
              color: _isQuickMode ? AppDesignSystem.midnight : AppDesignSystem.hope,
            ),
            const SizedBox(width: 4),
            Text(
              '2 min',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _isQuickMode ? AppDesignSystem.midnight : AppDesignSystem.hope,
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
          style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.coolGray),
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
              color: AppDesignSystem.gold.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.menu_book_outlined,
              color: AppDesignSystem.gold,
              size: 28,
            ),
          ),
          const SizedBox(height: 20),

          // Reference
          Text(
            section.title,
            style: AppDesignSystem.labelLarge(context, color: AppDesignSystem.gold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Scripture text
          Text(
            '"${section.content}"',
            style: AppDesignSystem.displaySmall(context, color: AppDesignSystem.pureWhite).copyWith(
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
                style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.pureWhite),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Content
          Text(
            section.content,
            style: AppDesignSystem.bodyLarge(context, color: AppDesignSystem.softWhite).copyWith(
              height: 1.7,
            ),
          ),

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildCrisisToolSection(_Section section) {
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
                  style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.pureWhite),
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
                      color: AppDesignSystem.gold.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.gold).copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step,
                      style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.softWhite).copyWith(
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
                  AppDesignSystem.gold.withOpacity(0.3),
                  AppDesignSystem.gold.withOpacity(0.1),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
            ),
            child: const Icon(
              Icons.flash_on,
              color: AppDesignSystem.gold,
              size: 32,
            ),
          ),
          const SizedBox(height: 24),

          // Title
          Text(
            section.title,
            style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.gold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Content
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppDesignSystem.midnightLight,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppDesignSystem.gold.withOpacity(0.2)),
            ),
            child: Text(
              section.content,
              style: AppDesignSystem.bodyLarge(context, color: AppDesignSystem.pureWhite).copyWith(
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
                style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.pureWhite),
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
                  color: AppDesignSystem.midnightLight,
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
                        style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.softWhite).copyWith(
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
            style: AppDesignSystem.bodyLarge(context, color: AppDesignSystem.softWhite).copyWith(
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
            style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.pureWhite),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),

          // Subtitle
          Text(
            _isDayCompleted
                ? 'Vuelve mañana para continuar tu progreso'
                : 'Marca este día como completado',
            style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.coolGray),
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
            style: AppDesignSystem.bodyLarge(context, color: AppDesignSystem.softWhite).copyWith(
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
                  backgroundColor: AppDesignSystem.gold,
                  foregroundColor: AppDesignSystem.midnight,
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
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: AppDesignSystem.midnightLight,
        border: Border(
          top: BorderSide(color: AppDesignSystem.midnight.withOpacity(0.5)),
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
                            ? AppDesignSystem.gold
                            : isCompleted
                                ? AppDesignSystem.gold.withOpacity(0.5)
                                : AppDesignSystem.coolGray.withOpacity(0.3),
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
              icon: const Icon(Icons.arrow_forward, color: AppDesignSystem.gold),
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
      await progressService.completeDay(widget.plan.id, widget.dayIndex);
      
      setState(() => _isDayCompleted = true);
      
      FeedbackEngine.I.confirm();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.celebration, color: AppDesignSystem.gold),
                const SizedBox(width: 12),
                Text(
                  '¡Día ${widget.dayIndex + 1} completado!',
                  style: const TextStyle(color: AppDesignSystem.pureWhite),
                ),
              ],
            ),
            backgroundColor: AppDesignSystem.midnightLight,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error completing day: $e');
    }
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
