library;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../models/learning/book_models.dart';
import '../../models/learning/kingdom_models.dart';
import '../../models/learning/learning_models.dart';
import '../../services/audio_engine.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/bible_map_progress_service.dart';
import '../../services/learning/bible_map_repository.dart';
import '../../services/learning/bible_order_progress_service.dart';
import '../../services/learning/book_progress_service.dart';
import '../../services/learning/book_repository.dart';
import '../../services/learning/fruit_progress_service.dart';
import '../../services/learning/fruit_repository.dart';
import '../../services/learning/heroes_progress_service.dart';
import '../../services/learning/heroes_repository.dart';
import '../../services/learning/journey_progress_service.dart';
import '../../services/learning/journey_repository.dart';
import '../../services/learning/kingdom_curriculum_repository.dart';
import '../../services/learning/kingdom_mission_service.dart';
import '../../services/learning/kingdom_progress_service.dart';
import '../../services/learning/kingdom_recommendation_service.dart';
import '../../services/learning/kingdom_review_service.dart';
import '../../services/learning/learning_progress_service.dart';
import '../../services/learning/learning_registry.dart';
import '../../services/learning/parable_progress_service.dart';
import '../../services/learning/parable_repository.dart';
import '../../services/learning/prophecy_progress_service.dart';
import '../../services/learning/prophecy_repository.dart';
import '../../services/learning/timeline_progress_service.dart';
import '../../services/learning/timeline_repository.dart';
import '../../services/learning/verse_memory_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import '../../utils/platform_capabilities.dart';
import '../../widgets/learning/xp_bar.dart';
import 'armory_deck_screen.dart';
import 'bible_order_learn_screen.dart';
import 'bible_order_quiz_screen.dart';
import 'bible_maps_screen.dart';
import 'bible_order_screen.dart';
import 'bookshelf_screen.dart';
import 'fruit_garden_screen.dart';
import 'games_home_screen.dart';
import 'heroes_gallery_screen.dart';
import 'journey_map_screen.dart';
import 'kingdom_lesson_screen.dart';
import 'mana_session_screen.dart';
import 'my_kingdom_screen.dart';
import 'parables_gallery_screen.dart';
import 'prophecies_home_screen.dart';
import 'timeline_lessons_screen.dart';

enum _KingdomArea { today, path, practice, kingdom }

class _KingdomNavItem {
  final _KingdomArea? area;
  final String label;
  final IconData icon;
  final String? actionModuleKey;

  const _KingdomNavItem.area({
    required this.area,
    required this.label,
    required this.icon,
  }) : actionModuleKey = null;

  const _KingdomNavItem.action({
    required this.actionModuleKey,
    required this.label,
    required this.icon,
  }) : area = null;
}

class LearningHomeScreen extends StatefulWidget {
  const LearningHomeScreen({super.key});

  @override
  State<LearningHomeScreen> createState() => _LearningHomeScreenState();
}

class _LearningHomeScreenState extends State<LearningHomeScreen> {
  _KingdomArea _area = _KingdomArea.today;
  String _libraryQuery = '';

  @override
  void initState() {
    super.initState();
    LearningRegistry.I.initAll();
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    _logEvent('learning_home_open_v2');
  }

  @override
  void dispose() {
    AudioEngine.I.switchBgmContext(BgmContext.home);
    super.dispose();
  }

  Future<void> _openModule(
    String moduleKey,
    Widget Function() build,
    BgmContext bgmContext,
  ) async {
    FeedbackEngine.I.tap();
    _logEvent('learning_module_open', params: {'module': moduleKey});
    AudioEngine.I.switchBgmContext(bgmContext);
    await Navigator.push(context, MaterialPageRoute(builder: (_) => build()));
    if (!mounted) return;
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    setState(() {});
  }

  void _openByModuleKey(String moduleKey) {
    switch (moduleKey) {
      case 'armory':
        _openModule(
          'armory',
          () => const ArmoryDeckScreen(),
          BgmContext.learningQuiz,
        );
        break;
      case 'books':
        _openModule('books', () => const BookshelfScreen(), BgmContext.bible);
        break;
      case 'bible_order':
        _openModule(
          'bible_order',
          () => const BibleOrderScreen(),
          BgmContext.learningBibleOrder,
        );
        break;
      case 'journey':
        _openModule(
          'journey',
          () => const JourneyMapScreen(),
          BgmContext.learningStory,
        );
        break;
      case 'heroes':
        _openModule(
          'heroes',
          () => const HeroesGalleryScreen(),
          BgmContext.learningStory,
        );
        break;
      case 'parables':
        _openModule(
          'parables',
          () => const ParablesGalleryScreen(),
          BgmContext.learningStory,
        );
        break;
      case 'timeline':
        _openModule(
          'timeline',
          () => const TimelineLessonsScreen(),
          BgmContext.learningStory,
        );
        break;
      case 'fruit':
        _openModule(
          'fruit',
          () => const FruitGardenScreen(),
          BgmContext.learningQuiz,
        );
        break;
      case 'maps':
        _openModule(
          'maps',
          () => const BibleMapsScreen(),
          BgmContext.learningMap,
        );
        break;
      case 'prophecies':
        _openModule(
          'prophecies',
          () => const PropheciesHomeScreen(),
          BgmContext.learningProphecy,
        );
        break;
      case 'games':
        _openModule(
          'games',
          () => const GamesHomeScreen(),
          BgmContext.learningHeadbanz,
        );
        break;
      case 'kingdom_lesson':
        _showLessonInPreparation();
        break;
      case 'mana':
      default:
        _openModule(
          'mana',
          () => const ManaSessionScreen(),
          BgmContext.learningQuiz,
        );
        break;
    }
  }

  Future<void> _openLesson(LearningLesson lesson) async {
    if (lesson.moduleKey == 'bible_order' && lesson.targetKey.isNotEmpty) {
      await _openBibleOrderLesson(lesson);
      return;
    }
    if (lesson.hasBiblicalContent) {
      FeedbackEngine.I.tap();
      _logEvent(
        'kingdom_structured_lesson_open',
        params: {'lesson': lesson.id, 'module': lesson.moduleKey},
      );
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => KingdomLessonScreen(lesson: lesson)),
      );
      if (!mounted) return;
      AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
      setState(() {});
      return;
    }
    if (lesson.moduleKey == 'kingdom_lesson') {
      _showLessonInPreparation(lesson);
      return;
    }
    _openByModuleKey(lesson.moduleKey);
  }

  void _showLessonInPreparation([LearningLesson? lesson]) {
    FeedbackEngine.I.tap();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lección en preparación'),
        content: Text(
          lesson == null
              ? 'Esta lección bíblica todavía está en desarrollo.'
              : '"${lesson.title}" todavía necesita contenido bíblico revisado antes de abrirse.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _openRecommendation(KingdomRecommendation recommendation) async {
    final lessonId = recommendation.lessonId;
    if (lessonId != null && lessonId.isNotEmpty) {
      final lesson = KingdomCurriculumRepository.I.lessonById(lessonId);
      if (lesson != null) {
        await _openLesson(lesson);
        return;
      }
    }
    _openByModuleKey(recommendation.moduleKey);
  }

  Future<void> _openBibleOrderLesson(LearningLesson lesson) async {
    final target = _resolveBibleOrderTarget(lesson.targetKey);
    if (target == null || target.books.length < 2) {
      _openByModuleKey('bible_order');
      return;
    }

    FeedbackEngine.I.tap();
    _logEvent(
      'learning_lesson_open',
      params: {
        'lesson': lesson.id,
        'module': lesson.moduleKey,
        'target': lesson.targetKey,
      },
    );
    AudioEngine.I.switchBgmContext(BgmContext.learningBibleOrder);

    final Widget screen;
    if (lesson.type == KingdomLessonType.quiz ||
        lesson.type == KingdomLessonType.assessment) {
      screen = BibleOrderQuizScreen(
        categoryKey: target.categoryKey,
        title: target.title,
        books: target.books,
      );
    } else {
      screen = BibleOrderLearnScreen(
        categoryKey: target.categoryKey,
        title: target.title,
        books: target.books,
      );
    }

    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    AudioEngine.I.switchBgmContext(BgmContext.learningExplore);
    setState(() {});
  }

  _BibleOrderTarget? _resolveBibleOrderTarget(String targetKey) {
    final normalized = _normalizeLearningKey(targetKey);
    if (normalized == 'at_all') {
      return _BibleOrderTarget(
        categoryKey: 'AT_all',
        title: 'Antiguo Testamento completo',
        books: BookRepository.I.ot,
      );
    }
    if (normalized == 'nt_all') {
      return _BibleOrderTarget(
        categoryKey: 'NT_all',
        title: 'Nuevo Testamento completo',
        books: BookRepository.I.nt,
      );
    }
    if (normalized == 'all_bible' || normalized == 'biblia_completa') {
      return _BibleOrderTarget(
        categoryKey: 'all_bible',
        title: 'Toda la Biblia',
        books: BookRepository.I.all,
      );
    }

    final isOt = normalized.startsWith('at_');
    final isNt = normalized.startsWith('nt_');
    if (!isOt && !isNt) return null;
    final testament = isOt ? 'AT' : 'NT';
    final wantedCategory = normalized.substring(3);
    final source = isOt ? BookRepository.I.ot : BookRepository.I.nt;
    final categories = source.map((book) => book.category).toSet();
    var category = '';
    for (final candidate in categories) {
      if (_normalizeLearningKey(candidate) == wantedCategory) {
        category = candidate;
        break;
      }
    }
    if (category.isEmpty) return null;
    return _BibleOrderTarget(
      categoryKey: '${testament}_${_normalizeLearningKey(category)}',
      title: category,
      books: source.where((book) => book.category == category).toList(),
    );
  }

  void _logEvent(String name, {Map<String, Object>? params}) {
    if (!PlatformCapabilities.supportsFirebaseAnalytics) return;
    try {
      FirebaseAnalytics.instance.logEvent(name: name, parameters: params);
    } catch (_) {}
  }

  List<_KingdomNavItem> get _navItems => const [
    _KingdomNavItem.area(
      area: _KingdomArea.today,
      label: 'Hoy',
      icon: Icons.wb_sunny_rounded,
    ),
    _KingdomNavItem.area(
      area: _KingdomArea.path,
      label: 'Ruta',
      icon: Icons.route_rounded,
    ),
    _KingdomNavItem.area(
      area: _KingdomArea.practice,
      label: 'Práctica',
      icon: Icons.fitness_center_rounded,
    ),
    _KingdomNavItem.action(
      actionModuleKey: 'games',
      label: 'Juegos',
      icon: Icons.sports_esports_rounded,
    ),
    _KingdomNavItem.area(
      area: _KingdomArea.kingdom,
      label: 'Reino',
      icon: Icons.emoji_events_rounded,
    ),
  ];

  int get _selectedNavIndex {
    final index = _navItems.indexWhere((item) => item.area == _area);
    return index < 0 ? 0 : index;
  }

  void _onNavSelected(int index) {
    final item = _navItems[index];
    if (item.actionModuleKey != null) {
      _openByModuleKey(item.actionModuleKey!);
      return;
    }
    if (item.area != null) {
      setState(() => _area = item.area!);
    }
  }

  void _openLibraryHub() {
    _openModule(
      'library_hub',
      () => _LibraryHubScreen(onOpenModuleKey: _openByModuleKey),
      BgmContext.learningExplore,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 920;
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Escuela del Reino',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        actions: [
          IconButton(
            tooltip: 'Mi Reino',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => _openModule(
              'my_kingdom',
              () => const MyKingdomScreen(),
              BgmContext.learningExplore,
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: LearningRegistry.I.readyNotifier,
        builder: (context, ready, _) {
          if (!ready) return const Center(child: CircularProgressIndicator());
          return AnimatedBuilder(
            animation: Listenable.merge([
              LearningProgressService.I.progressNotifier,
              KingdomProgressService.I.stateNotifier,
              VerseMemoryService.I.changeTickNotifier,
              JourneyProgressService.I.stateNotifier,
              HeroesProgressService.I.stateNotifier,
              BookProgressService.I.stateNotifier,
            ]),
            builder: (context, _) {
              final content = _MainKingdomScroll(
                progress: LearningProgressService.I.progressNotifier.value,
                children: _areaContent(),
              );
              if (!isWide) return content;
              return Row(
                children: [
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                      child: _KingdomNavigationRail(
                        items: _navItems,
                        selectedIndex: _selectedNavIndex,
                        onSelected: _onNavSelected,
                      ),
                    ),
                  ),
                  VerticalDivider(color: t.cardBorder, width: 1),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: content,
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomNavigationBar: isWide
          ? null
          : _KingdomBottomBar(
              items: _navItems,
              selectedIndex: _selectedNavIndex,
              onSelected: _onNavSelected,
            ),
    );
  }

  List<Widget> _areaContent() {
    switch (_area) {
      case _KingdomArea.today:
        return _todayContent();
      case _KingdomArea.path:
        return _pathContent();
      case _KingdomArea.practice:
        return _practiceContent();
      case _KingdomArea.kingdom:
        return _kingdomContent();
    }
  }

  List<Widget> _todayContent() {
    final missions = KingdomMissionService.I.dailyMissions();
    final summary = KingdomProgressService.I.summary(
      dueReviews: KingdomReviewService.I.dueItems().length,
      missionsDone: missions.where((m) => m.completed).length,
      missionsTotal: missions.length,
    );
    final deepLesson = KingdomCurriculumRepository.I.lessons
        .where((lesson) => lesson.deepSession)
        .cast<LearningLesson?>()
        .firstWhere((lesson) => lesson != null, orElse: () => null);
    return [
      _TodayCard(onOpen: _openRecommendation),
      const SizedBox(height: AppDesignSystem.spacingM),
      _QuickActionsRow(
        onOpenGames: () => _openByModuleKey('games'),
        onOpenLibrary: _openLibraryHub,
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      _MissionPanel(missions: missions),
      const SizedBox(height: AppDesignSystem.spacingM),
      _ProgressPanel(summary: summary),
      if (deepLesson != null) ...[
        const SizedBox(height: AppDesignSystem.spacingM),
        _ModuleCard(
          icon: Icons.auto_stories_rounded,
          iconColor: AppDesignSystem.hope,
          title: 'Sesión profunda',
          subtitle: '${deepLesson.estimatedMinutes} min · ${deepLesson.title}',
          cta: 'Abrir',
          onTap: () => _openByModuleKey(deepLesson.moduleKey),
        ),
      ],
    ];
  }

  List<Widget> _pathContent() {
    final repo = KingdomCurriculumRepository.I;
    return [
      const _AreaTitle(
        title: 'Camino de Luz',
        subtitle:
            'Avanza por estaciones. Fundamentos abre las rutas de liderazgo y maestro.',
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      _KingdomPathView(
        tracks: repo.tracks,
        onOpenLesson: (lesson) {
          _openLesson(lesson);
        },
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      _ModuleCard(
        icon: Icons.local_library_rounded,
        iconColor: AppDesignSystem.gold,
        title: 'Explorar Biblioteca',
        subtitle: 'Mapas, profecias, parabolas y recursos fuera de la ruta',
        cta: 'Abrir',
        onTap: _openLibraryHub,
      ),
    ];
  }

  List<Widget> _practiceContent() {
    final reviews = KingdomReviewService.I.dueItems();
    return [
      const _AreaTitle(
        title: 'Práctica',
        subtitle:
            'Repasa lo vencido, refuerza lo débil y vuelve a intentarlo sin presión.',
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      _ArmoryCard(onOpen: () => _openByModuleKey('armory')),
      const SizedBox(height: AppDesignSystem.spacingM),
      _ManaCard(onOpen: () => _openByModuleKey('mana')),
      const SizedBox(height: AppDesignSystem.spacingM),
      _ModuleCard(
        icon: Icons.sports_esports_rounded,
        iconColor: AppDesignSystem.struggle,
        title: 'Jugar con amigos',
        subtitle: 'Abre retos rápidos para jugar en grupo o 1 vs 1',
        cta: 'Ir',
        onTap: () => _openByModuleKey('games'),
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      if (reviews.isEmpty)
        const _QuietNote(
          text:
              'No hay repasos urgentes. Puedes practicar la rutina diaria o Armadura.',
        )
      else
        ...reviews
            .take(4)
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(
                  bottom: AppDesignSystem.spacingM,
                ),
                child: _ModuleCard(
                  icon: Icons.replay_rounded,
                  iconColor: AppDesignSystem.gold,
                  title: item.title,
                  subtitle: item.reason,
                  cta: 'Repasar',
                  onTap: () => _openReviewItem(item),
                ),
              ),
            ),
    ];
  }

  void _openReviewItem(ReviewItem item) {
    final lessonId = item.lessonId;
    if (lessonId != null && lessonId.isNotEmpty) {
      final lesson = KingdomCurriculumRepository.I.lessonById(lessonId);
      if (lesson != null) {
        _openLesson(lesson);
        return;
      }
    }
    _openByModuleKey(item.moduleKey);
  }

  // ignore: unused_element
  List<Widget> _libraryContent() {
    final query = _libraryQuery.trim().toLowerCase();
    final items = <_LibraryEntry>[
      _LibraryEntry(
        'biblia libros 66',
        _BooksCard(onOpen: () => _openByModuleKey('books')),
      ),
      _LibraryEntry(
        'biblia orden libros',
        _BibleOrderCard(onOpen: () => _openByModuleKey('bible_order')),
      ),
      _LibraryEntry(
        'historia travesia biblica',
        _JourneyCard(onOpen: () => _openByModuleKey('journey')),
      ),
      _LibraryEntry(
        'personajes heroes fe',
        _HeroesCard(onOpen: () => _openByModuleKey('heroes')),
      ),
      _LibraryEntry(
        'jesus parabolas',
        _ParablesCard(onOpen: () => _openByModuleKey('parables')),
      ),
      _LibraryEntry(
        'historia linea tiempo',
        _TimelineCard(onOpen: () => _openByModuleKey('timeline')),
      ),
      _LibraryEntry(
        'crecimiento fruto espiritu',
        _FruitCard(onOpen: () => _openByModuleKey('fruit')),
      ),
      _LibraryEntry(
        'mapas tierras biblicas',
        _MapsCard(onOpen: () => _openByModuleKey('maps')),
      ),
      _LibraryEntry(
        'profecias mesianicas',
        _ProphecyCard(onOpen: () => _openByModuleKey('prophecies')),
      ),
      _LibraryEntry(
        'juegos biblicos retos',
        _GamesCard(onOpen: () => _openByModuleKey('games')),
      ),
    ];
    final filtered = query.isEmpty
        ? items
        : items.where((entry) => entry.searchText.contains(query)).toList();
    return [
      const _AreaTitle(
        title: 'Biblioteca',
        subtitle: 'Explora recursos sin perder la ruta principal.',
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      _LibrarySearch(
        value: _libraryQuery,
        onChanged: (value) => setState(() => _libraryQuery = value),
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      const _LibraryCategories(),
      const SizedBox(height: AppDesignSystem.spacingM),
      if (filtered.isEmpty)
        const _QuietNote(text: 'No encontré recursos con ese nombre.')
      else
        ...filtered.expand(
          (entry) => [
            entry.child,
            const SizedBox(height: AppDesignSystem.spacingM),
          ],
        ),
    ];
  }

  List<Widget> _kingdomContent() {
    final progress = LearningProgressService.I.progressNotifier.value;
    final summary = KingdomProgressService.I.summary(
      dueReviews: KingdomReviewService.I.dueItems().length,
      missionsDone: KingdomMissionService.I.completedToday(),
    );
    return [
      const _AreaTitle(
        title: 'Mi Reino',
        subtitle: 'Tu progreso visible y tu siguiente meta.',
      ),
      const SizedBox(height: AppDesignSystem.spacingM),
      _ProgressPanel(summary: summary),
      const SizedBox(height: AppDesignSystem.spacingM),
      _StatsRow(progress: progress),
      const SizedBox(height: AppDesignSystem.spacingM),
      _BadgeStrip(summary: summary, progress: progress),
      const SizedBox(height: AppDesignSystem.spacingM),
      _ModuleCard(
        icon: Icons.emoji_events_rounded,
        iconColor: AppDesignSystem.gold,
        title: 'Sala de progreso',
        subtitle: 'Insignias, talentos, coleccionables y avance por módulo',
        cta: 'Ver',
        onTap: () => _openModule(
          'my_kingdom',
          () => const MyKingdomScreen(),
          BgmContext.learningExplore,
        ),
      ),
    ];
  }
}

class _Hero extends StatelessWidget {
  final LearningProgress progress;
  const _Hero({required this.progress});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t.surface, t.cardBg],
        ),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.22)),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Escuela del Reino',
            style: AppDesignSystem.headlineLarge(context, color: t.textPrimary),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            'Un camino diario para conocer la Biblia, practicar y crecer paso a paso.',
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          XpBar(progress: progress),
          const SizedBox(height: AppDesignSystem.spacingM),
          Row(
            children: [
              StreakPill(progress: progress),
              const SizedBox(width: AppDesignSystem.spacingS),
              _MiniPill(text: '${progress.hearts} corazones'),
            ],
          ),
        ],
      ),
    );
  }
}

class _MainKingdomScroll extends StatelessWidget {
  final LearningProgress progress;
  final List<Widget> children;

  const _MainKingdomScroll({required this.progress, required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      children: [
        _Hero(progress: progress),
        const SizedBox(height: AppDesignSystem.spacingL),
        ...children,
        const SizedBox(height: AppDesignSystem.spacingL),
      ],
    );
  }
}

class _KingdomNavigationRail extends StatelessWidget {
  final List<_KingdomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _KingdomNavigationRail({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        border: Border.all(color: t.cardBorder),
      ),
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.all,
        backgroundColor: Colors.transparent,
        indicatorColor: AppDesignSystem.gold.withValues(alpha: 0.18),
        selectedIconTheme: const IconThemeData(color: AppDesignSystem.gold),
        unselectedIconTheme: IconThemeData(color: t.textSecondary),
        selectedLabelTextStyle: AppDesignSystem.labelLarge(
          context,
          color: AppDesignSystem.gold,
        ),
        unselectedLabelTextStyle: AppDesignSystem.labelLarge(
          context,
          color: t.textSecondary,
        ),
        destinations: items
            .map(
              (item) => NavigationRailDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.icon),
                label: Text(item.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _KingdomBottomBar extends StatelessWidget {
  final List<_KingdomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _KingdomBottomBar({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelected,
      backgroundColor: t.surface,
      indicatorColor: AppDesignSystem.gold.withValues(alpha: 0.2),
      destinations: items
          .map(
            (item) => NavigationDestination(
              icon: Icon(item.icon),
              selectedIcon: Icon(item.icon),
              label: item.label,
            ),
          )
          .toList(),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  final VoidCallback onOpenGames;
  final VoidCallback onOpenLibrary;

  const _QuickActionsRow({
    required this.onOpenGames,
    required this.onOpenLibrary,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final vertical = constraints.maxWidth < 560;
        final gamesCard = _QuickActionCard(
          icon: Icons.sports_esports_rounded,
          color: AppDesignSystem.struggle,
          title: 'Jugar con amigos',
          subtitle: 'Carrera, duelo rapido y retos para pasar el celular',
          onTap: onOpenGames,
        );
        final libraryCard = _QuickActionCard(
          icon: Icons.local_library_rounded,
          color: AppDesignSystem.gold,
          title: 'Explorar Biblioteca',
          subtitle: 'Mapas, profecias, personajes y recursos libres',
          onTap: onOpenLibrary,
        );
        if (vertical) {
          return Column(
            children: [
              gamesCard,
              const SizedBox(height: AppDesignSystem.spacingM),
              libraryCard,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: gamesCard),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(child: libraryCard),
          ],
        );
      },
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: BoxDecoration(
          color: t.cardBg,
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: t.cardShadow,
        ),
        child: Row(
          children: [
            _IconOrb(icon: icon, color: color, size: 48),
            const SizedBox(width: AppDesignSystem.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppDesignSystem.headlineSmall(
                      context,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppDesignSystem.bodyMedium(
                      context,
                      color: t.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: t.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final ValueChanged<KingdomRecommendation> onOpen;
  const _TodayCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final r = KingdomRecommendationService.I.today();
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingL),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppDesignSystem.gold.withValues(alpha: t.isDark ? 0.18 : 0.13),
            t.cardBg,
          ],
        ),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.38)),
        boxShadow: t.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconOrb(
                icon: _iconForRecommendation(r.kind),
                color: AppDesignSystem.gold,
                size: 54,
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoy en tu camino',
                      style: AppDesignSystem.labelLarge(
                        context,
                        color: AppDesignSystem.gold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      r.title,
                      style: AppDesignSystem.headlineMedium(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          Text(
            r.subtitle,
            style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          PrimaryKingdomButton(
            label: r.cta.isEmpty ? 'Ruta al día' : r.cta,
            icon: r.moduleKey.isEmpty
                ? Icons.check_rounded
                : Icons.play_arrow_rounded,
            enabled: r.moduleKey.isNotEmpty,
            onPressed: () => onOpen(r),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 320.ms).slideY(begin: 0.04, end: 0);
  }

  IconData _iconForRecommendation(KingdomRecommendationKind kind) {
    switch (kind) {
      case KingdomRecommendationKind.review:
        return Icons.replay_rounded;
      case KingdomRecommendationKind.nextLesson:
        return Icons.play_circle_fill_rounded;
      case KingdomRecommendationKind.dailyPractice:
        return Icons.wb_sunny_rounded;
      case KingdomRecommendationKind.deepSession:
        return Icons.auto_stories_rounded;
      case KingdomRecommendationKind.rest:
        return Icons.spa_rounded;
    }
  }
}

class _MissionPanel extends StatelessWidget {
  final List<DailyMission> missions;
  const _MissionPanel({required this.missions});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: _panelDecoration(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Misiones de hoy',
            style: AppDesignSystem.headlineSmall(context, color: t.textPrimary),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          ...missions.map((mission) => DailyMissionRow(mission: mission)),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final KingdomProgressSummary summary;
  const _ProgressPanel({required this.summary});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: _panelDecoration(t),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Progreso de ruta',
                  style: AppDesignSystem.headlineSmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
              ),
              Text(
                '${summary.completedLessons}/${summary.totalLessons}',
                style: AppDesignSystem.labelLarge(
                  context,
                  color: AppDesignSystem.gold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
            child: LinearProgressIndicator(
              value: summary.progress.clamp(0, 1),
              minHeight: 9,
              backgroundColor: t.cardBorder,
              valueColor: const AlwaysStoppedAnimation(AppDesignSystem.gold),
            ),
          ),
          const SizedBox(height: AppDesignSystem.spacingS),
          Text(
            '${summary.dueReviews} repasos · ${summary.dailyMissionsCompleted}/${summary.dailyMissionsTotal} misiones · ${summary.masteredLessons} dominadas',
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _KingdomPathView extends StatelessWidget {
  final List<LearningTrack> tracks;
  final ValueChanged<LearningLesson> onOpenLesson;

  const _KingdomPathView({required this.tracks, required this.onOpenLesson});

  @override
  Widget build(BuildContext context) {
    final repo = KingdomCurriculumRepository.I;
    final children = <Widget>[];
    for (final track in tracks) {
      final trackUnlocked = KingdomProgressService.I.isTrackUnlocked(track.id);
      final units = repo.unitsForTrack(track.id);
      if (units.isEmpty) {
        continue;
      }
      for (final unit in units) {
        final lessons = repo
            .lessonsForUnit(unit.id)
            .where((lesson) => lesson.isCorePath)
            .toList(growable: false);
        if (lessons.isEmpty) continue;
        final completed = lessons
            .where(
              (lesson) =>
                  KingdomProgressService.I.effectiveStatus(lesson) !=
                  KingdomLessonStatus.notStarted,
            )
            .length;
        final unitUnlocked = trackUnlocked && _unitUnlocked(unit);
        children.add(
          KingdomUnitBand(
            track: track,
            unit: unit,
            completed: completed,
            total: lessons.length,
            unlocked: unitUnlocked,
          ),
        );
        children.add(const SizedBox(height: AppDesignSystem.spacingM));
        children.add(
          _UnitPath(
            lessons: lessons,
            unlocked: unitUnlocked,
            onOpenLesson: onOpenLesson,
          ),
        );
        children.add(const SizedBox(height: AppDesignSystem.spacingL));
      }
    }
    return Column(children: children);
  }

  bool _unitUnlocked(LearningUnit unit) {
    if (unit.prerequisiteUnitIds.isEmpty) return true;
    return unit.prerequisiteUnitIds.every((unitId) {
      final lessons = KingdomCurriculumRepository.I
          .lessonsForUnit(unitId)
          .where((lesson) => lesson.isCorePath)
          .toList(growable: false);
      return lessons.isNotEmpty &&
          lessons.every(
            (lesson) =>
                KingdomProgressService.I.effectiveStatus(lesson) !=
                KingdomLessonStatus.notStarted,
          );
    });
  }
}

class _UnitPath extends StatelessWidget {
  final List<LearningLesson> lessons;
  final bool unlocked;
  final ValueChanged<LearningLesson> onOpenLesson;

  const _UnitPath({
    required this.lessons,
    required this.unlocked,
    required this.onOpenLesson,
  });

  @override
  Widget build(BuildContext context) {
    final next = KingdomProgressService.I.nextLesson();
    final reviewIds = KingdomReviewService.I
        .dueItems()
        .map(
          (item) => item.id.replaceFirst('weak_', '').replaceFirst('due_', ''),
        )
        .toSet();

    return Column(
      children: [
        for (var i = 0; i < lessons.length; i++)
          _PathStep(
            lesson: lessons[i],
            alignLeft: i.isEven,
            isLast: i == lessons.length - 1,
            locked: !unlocked || _lessonLocked(lessons[i]),
            recommended: next?.id == lessons[i].id,
            needsReview: reviewIds.contains(lessons[i].id),
            onOpen: onOpenLesson,
          ),
      ],
    );
  }

  bool _lessonLocked(LearningLesson lesson) {
    if (lesson.leadershipLocked &&
        !KingdomProgressService.I.fundamentalsComplete) {
      return true;
    }
    if (lesson.prerequisiteLessonIds.isEmpty) return false;
    return !lesson.prerequisiteLessonIds.every((id) {
      final prerequisite = KingdomCurriculumRepository.I.lessonById(id);
      if (prerequisite == null) return false;
      final status = KingdomProgressService.I.effectiveStatus(prerequisite);
      return status == KingdomLessonStatus.completed ||
          status == KingdomLessonStatus.mastered;
    });
  }
}

class _PathStep extends StatelessWidget {
  final LearningLesson lesson;
  final bool alignLeft;
  final bool isLast;
  final bool locked;
  final bool recommended;
  final bool needsReview;
  final ValueChanged<LearningLesson> onOpen;

  const _PathStep({
    required this.lesson,
    required this.alignLeft,
    required this.isLast,
    required this.locked,
    required this.recommended,
    required this.needsReview,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final status = KingdomProgressService.I.effectiveStatus(lesson);
    final completed =
        status == KingdomLessonStatus.completed ||
        status == KingdomLessonStatus.mastered;
    return SizedBox(
      height: isLast ? 108 : 132,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (!isLast)
            Positioned(
              top: 68,
              bottom: 0,
              child: ProgressRail(completed: completed, active: recommended),
            ),
          Align(
            alignment: alignLeft ? Alignment.topLeft : Alignment.topRight,
            child: FractionallySizedBox(
              widthFactor: 0.78,
              alignment: alignLeft
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Row(
                mainAxisAlignment: alignLeft
                    ? MainAxisAlignment.start
                    : MainAxisAlignment.end,
                children: [
                  if (!alignLeft)
                    Expanded(child: _LessonBubble(lesson: lesson)),
                  KingdomPathNode(
                    lesson: lesson,
                    status: status,
                    locked: locked,
                    recommended: recommended,
                    needsReview: needsReview,
                    onTap: locked ? null : () => onOpen(lesson),
                  ),
                  if (alignLeft) Expanded(child: _LessonBubble(lesson: lesson)),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: 0.04, end: 0);
  }
}

class _LessonBubble extends StatelessWidget {
  final LearningLesson lesson;
  const _LessonBubble({required this.lesson});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingS),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesignSystem.labelLarge(context, color: t.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            '${lesson.estimatedMinutes} min · ${_lessonTypeLabel(lesson.type)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

class KingdomPathNode extends StatelessWidget {
  final LearningLesson lesson;
  final KingdomLessonStatus status;
  final bool locked;
  final bool recommended;
  final bool needsReview;
  final VoidCallback? onTap;

  const KingdomPathNode({
    super.key,
    required this.lesson,
    required this.status,
    required this.locked,
    required this.recommended,
    required this.needsReview,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = status == KingdomLessonStatus.completed;
    final mastered = status == KingdomLessonStatus.mastered;
    final color = locked
        ? Colors.grey
        : mastered
        ? AppDesignSystem.gold
        : completed
        ? const Color(0xFF5FA777)
        : recommended
        ? AppDesignSystem.gold
        : const Color(0xFF64B5F6);
    final size = locked
        ? 56.0
        : recommended
        ? 76.0
        : 64.0;
    final icon = locked
        ? Icons.lock_rounded
        : mastered
        ? Icons.workspace_premium_rounded
        : completed
        ? Icons.check_circle_rounded
        : _iconForLesson(lesson);

    Widget node = InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (recommended)
            Container(
                  width: size + 18,
                  height: size + 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppDesignSystem.gold.withValues(alpha: 0.16),
                    border: Border.all(
                      color: AppDesignSystem.gold.withValues(alpha: 0.35),
                    ),
                  ),
                )
                .animate(
                  onPlay: (controller) => controller.repeat(reverse: true),
                )
                .scale(
                  begin: const Offset(0.96, 0.96),
                  end: const Offset(1.06, 1.06),
                  duration: 1100.ms,
                ),
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: locked ? color.withValues(alpha: 0.22) : color,
              border: Border.all(
                color: mastered
                    ? AppDesignSystem.goldLight
                    : Colors.white.withValues(alpha: 0.56),
                width: mastered ? 3 : 2,
              ),
              boxShadow: locked
                  ? const []
                  : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: recommended ? 22 : 14,
                        offset: const Offset(0, 8),
                      ),
                    ],
            ),
            child: Icon(
              icon,
              color: locked ? Colors.grey.shade500 : Colors.black,
              size: recommended ? 32 : 28,
            ),
          ),
          if (needsReview && !locked)
            Positioned(
              right: 0,
              top: 1,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: AppDesignSystem.struggle,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
          if (recommended)
            Positioned(
              bottom: -22,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppDesignSystem.gold,
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                ),
                child: const Text(
                  'Siguiente',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (completed || mastered) {
      node = node.animate().scale(
        begin: const Offset(0.94, 0.94),
        end: const Offset(1, 1),
        duration: 360.ms,
        curve: Curves.easeOutBack,
      );
    }
    return Semantics(
      button: !locked,
      label: locked ? '${lesson.title}, bloqueada' : lesson.title,
      child: node,
    );
  }
}

class KingdomUnitBand extends StatelessWidget {
  final LearningTrack track;
  final LearningUnit unit;
  final int completed;
  final int total;
  final bool unlocked;

  const KingdomUnitBand({
    super.key,
    required this.track,
    required this.unit,
    required this.completed,
    required this.total,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final color = _colorForTrack(track.level);
    final progress = total == 0 ? 0.0 : (completed / total).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: unlocked ? color.withValues(alpha: 0.11) : t.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked ? color.withValues(alpha: 0.36) : t.cardBorder,
        ),
      ),
      child: Row(
        children: [
          _IconOrb(
            icon: _iconForTrack(track.level),
            color: unlocked ? color : Colors.grey,
            size: 48,
          ),
          const SizedBox(width: AppDesignSystem.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unit.title,
                  style: AppDesignSystem.headlineSmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unlocked
                      ? unit.subtitle
                      : 'Se abre al completar la base previa',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: t.textSecondary,
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingS),
                ClipRRect(
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: t.cardBorder,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDesignSystem.spacingS),
          _MiniPill(text: '$completed/$total'),
        ],
      ),
    );
  }
}

class ProgressRail extends StatelessWidget {
  final bool completed;
  final bool active;

  const ProgressRail({
    super.key,
    required this.completed,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? const Color(0xFF5FA777)
        : active
        ? AppDesignSystem.gold
        : AppThemeData.of(context).cardBorder;
    return Container(
          width: 8,
          decoration: BoxDecoration(
            color: color.withValues(alpha: active ? 0.78 : 0.52),
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
          ),
        )
        .animate(target: active ? 1 : 0)
        .shimmer(
          duration: 900.ms,
          color: AppDesignSystem.gold.withValues(alpha: 0.35),
        );
  }
}

class PrimaryKingdomButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  const PrimaryKingdomButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: AppDesignSystem.gold,
          disabledBackgroundColor: AppThemeData.of(context).cardBorder,
          foregroundColor: Colors.black,
          disabledForegroundColor: AppThemeData.of(context).textSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: AppDesignSystem.labelLarge(context),
        ),
      ),
    );
  }
}

class DailyMissionRow extends StatelessWidget {
  final DailyMission mission;

  const DailyMissionRow({super.key, required this.mission});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      margin: const EdgeInsets.symmetric(vertical: 5),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingS,
        vertical: AppDesignSystem.spacingS,
      ),
      decoration: BoxDecoration(
        color: mission.completed
            ? AppDesignSystem.victory.withValues(alpha: 0.09)
            : t.inputBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: mission.completed
              ? AppDesignSystem.victory.withValues(alpha: 0.32)
              : t.cardBorder,
        ),
      ),
      child: Row(
        children: [
          Icon(
                mission.completed
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: mission.completed
                    ? AppDesignSystem.victory
                    : t.textSecondary,
              )
              .animate(target: mission.completed ? 1 : 0)
              .scale(
                begin: const Offset(0.9, 0.9),
                end: const Offset(1.08, 1.08),
                duration: 260.ms,
              ),
          const SizedBox(width: AppDesignSystem.spacingS),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.title,
                  style: AppDesignSystem.bodyMedium(
                    context,
                    color: t.textPrimary,
                  ),
                ),
                Text(
                  mission.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppDesignSystem.labelSmall(
                    context,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppDesignSystem.spacingS),
          _MiniPill(text: '+${mission.xpReward} XP'),
        ],
      ),
    );
  }
}

class StreakPill extends StatelessWidget {
  final LearningProgress progress;

  const StreakPill({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    final usedGrace = progress.lastGraceShieldDate.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            usedGrace
                ? Icons.shield_rounded
                : Icons.local_fire_department_rounded,
            size: 17,
            color: AppDesignSystem.gold,
          ),
          const SizedBox(width: 6),
          Text(
            '${progress.studyStreak} días',
            style: AppDesignSystem.labelSmall(
              context,
              color: AppDesignSystem.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeStrip extends StatelessWidget {
  final KingdomProgressSummary summary;
  final LearningProgress progress;

  const _BadgeStrip({required this.summary, required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: BadgeMedal(
            title: 'Fundamentos',
            icon: Icons.menu_book_rounded,
            unlocked: summary.fundamentalsComplete,
            hint: 'Completa la base',
          ),
        ),
        const SizedBox(width: AppDesignSystem.spacingS),
        Expanded(
          child: BadgeMedal(
            title: '7 días',
            icon: Icons.local_fire_department_rounded,
            unlocked: progress.studyStreak >= 7,
            hint: 'Racha semanal',
          ),
        ),
        const SizedBox(width: AppDesignSystem.spacingS),
        Expanded(
          child: BadgeMedal(
            title: 'Dominio',
            icon: Icons.workspace_premium_rounded,
            unlocked: summary.masteredLessons > 0,
            hint: 'Domina una lección',
          ),
        ),
      ],
    );
  }
}

class BadgeMedal extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool unlocked;
  final String hint;

  const BadgeMedal({
    super.key,
    required this.title,
    required this.icon,
    required this.unlocked,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final color = unlocked ? AppDesignSystem.gold : t.textSecondary;
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingS),
      decoration: BoxDecoration(
        color: unlocked ? AppDesignSystem.gold.withValues(alpha: 0.11) : t.inputBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked
              ? AppDesignSystem.gold.withValues(alpha: 0.32)
              : t.cardBorder,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 5),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesignSystem.labelSmall(context, color: t.textPrimary),
          ),
          Text(
            unlocked ? 'Ganada' : hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _IconOrb({required this.icon, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(icon, color: color, size: size * 0.52),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String text;

  const _MiniPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppDesignSystem.gold.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: AppDesignSystem.gold.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
      ),
    );
  }
}

class TrackCard extends StatelessWidget {
  final LearningTrack track;
  final int completed;
  final int total;
  final bool unlocked;
  final VoidCallback onTap;

  const TrackCard({
    super.key,
    required this.track,
    required this.completed,
    required this.total,
    required this.unlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = unlocked
        ? '$completed/$total lecciones · ${track.subtitle}'
        : 'Se desbloquea al completar Fundamentos';
    return _ModuleCard(
      icon: unlocked ? Icons.route_rounded : Icons.lock_rounded,
      iconColor: unlocked ? AppDesignSystem.gold : Colors.grey,
      title: track.title,
      subtitle: subtitle,
      cta: unlocked ? 'Abrir' : 'Bloqueado',
      enabled: unlocked,
      onTap: onTap,
    );
  }
}

class _AreaTitle extends StatelessWidget {
  final String title;
  final String subtitle;
  const _AreaTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
        ),
      ],
    );
  }
}

class _QuietNote extends StatelessWidget {
  final String text;
  const _QuietNote({required this.text});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Text(
      text,
      style: AppDesignSystem.bodyMedium(context, color: t.textSecondary),
    );
  }
}

class _LibraryHubScreen extends StatefulWidget {
  final ValueChanged<String> onOpenModuleKey;

  const _LibraryHubScreen({required this.onOpenModuleKey});

  @override
  State<_LibraryHubScreen> createState() => _LibraryHubScreenState();
}

class _LibraryHubScreenState extends State<_LibraryHubScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final query = _query.trim().toLowerCase();
    final items = <_LibraryEntry>[
      _LibraryEntry(
        'biblia libros 66',
        _BooksCard(onOpen: () => _open('books')),
      ),
      _LibraryEntry(
        'biblia orden libros',
        _BibleOrderCard(onOpen: () => _open('bible_order')),
      ),
      _LibraryEntry(
        'historia travesia biblica',
        _JourneyCard(onOpen: () => _open('journey')),
      ),
      _LibraryEntry(
        'personajes heroes fe',
        _HeroesCard(onOpen: () => _open('heroes')),
      ),
      _LibraryEntry(
        'jesus parabolas',
        _ParablesCard(onOpen: () => _open('parables')),
      ),
      _LibraryEntry(
        'historia linea tiempo',
        _TimelineCard(onOpen: () => _open('timeline')),
      ),
      _LibraryEntry(
        'crecimiento fruto espiritu',
        _FruitCard(onOpen: () => _open('fruit')),
      ),
      _LibraryEntry(
        'mapas tierras biblicas',
        _MapsCard(onOpen: () => _open('maps')),
      ),
      _LibraryEntry(
        'profecias mesianicas',
        _ProphecyCard(onOpen: () => _open('prophecies')),
      ),
    ];
    final filtered = query.isEmpty
        ? items
        : items.where((entry) => entry.searchText.contains(query)).toList();

    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Biblioteca',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        children: [
          const _AreaTitle(
            title: 'Biblioteca',
            subtitle: 'Explora recursos sin perder tu ruta principal.',
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          _LibrarySearch(
            value: _query,
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppDesignSystem.spacingM),
          const _LibraryCategories(),
          const SizedBox(height: AppDesignSystem.spacingM),
          if (filtered.isEmpty)
            const _QuietNote(text: 'No encontre recursos con ese nombre.')
          else
            ...filtered.expand(
              (entry) => [
                entry.child,
                const SizedBox(height: AppDesignSystem.spacingM),
              ],
            ),
        ],
      ),
    );
  }

  void _open(String moduleKey) {
    Navigator.of(context).pop();
    widget.onOpenModuleKey(moduleKey);
  }
}

class _LibraryEntry {
  final String searchText;
  final Widget child;

  const _LibraryEntry(this.searchText, this.child);
}

class _LibrarySearch extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _LibrarySearch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar en la Biblioteca',
        prefixIcon: Icon(Icons.search_rounded, color: t.textSecondary),
        filled: true,
        fillColor: t.inputBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppDesignSystem.gold),
        ),
      ),
      style: AppDesignSystem.bodyMedium(context, color: t.textPrimary),
    );
  }
}

class _LibraryCategories extends StatelessWidget {
  const _LibraryCategories();

  @override
  Widget build(BuildContext context) {
    const categories = [
      (icon: Icons.menu_book_rounded, text: 'Biblia'),
      (icon: Icons.history_edu_rounded, text: 'Historia'),
      (icon: Icons.groups_rounded, text: 'Personajes'),
      (icon: Icons.public_rounded, text: 'Mapas'),
      (icon: Icons.auto_awesome_rounded, text: 'Profecías'),
      (icon: Icons.sports_esports_rounded, text: 'Juegos'),
    ];
    final t = AppThemeData.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories
            .map(
              (category) => Container(
                margin: const EdgeInsets.only(right: AppDesignSystem.spacingS),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: t.inputBg,
                  borderRadius: BorderRadius.circular(
                    AppDesignSystem.radiusFull,
                  ),
                  border: Border.all(color: t.cardBorder),
                ),
                child: Row(
                  children: [
                    Icon(category.icon, size: 16, color: AppDesignSystem.gold),
                    const SizedBox(width: 6),
                    Text(
                      category.text,
                      style: AppDesignSystem.labelSmall(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback onTap;
  final bool enabled;
  final String? badge;

  const _ModuleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.cta,
    required this.onTap,
    this.enabled = true,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Opacity(
      opacity: enabled ? 1 : 0.58,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
            border: Border.all(color: t.cardBorder),
            boxShadow: t.cardShadow,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: iconColor, size: 27),
                  ),
                  if (badge != null)
                    Positioned(
                      right: -5,
                      top: -5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppDesignSystem.gold,
                          borderRadius: BorderRadius.circular(
                            AppDesignSystem.radiusFull,
                          ),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppDesignSystem.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppDesignSystem.headlineSmall(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppDesignSystem.bodyMedium(
                        context,
                        color: t.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingS),
              Text(
                cta,
                style: AppDesignSystem.labelLarge(
                  context,
                  color: AppDesignSystem.gold,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManaCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ManaCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _ModuleCard(
      icon: Icons.wb_sunny_rounded,
      iconColor: AppDesignSystem.gold,
      title: 'Práctica diaria',
      subtitle: '7 preguntas para repasar en menos de 5 minutos',
      cta: 'Practicar',
      onTap: onOpen,
    );
  }
}

class _ArmoryCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ArmoryCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final s = VerseMemoryService.I.summary();
    final subtitle = s.due > 0
        ? '${s.due} por repasar · ${s.mastered}/${s.total} dominados'
        : '${s.mastered}/${s.total} dominados · ${s.inProgress} en progreso';
    return _ModuleCard(
      icon: Icons.shield_moon_rounded,
      iconColor: AppDesignSystem.gold,
      title: 'Armadura',
      subtitle: subtitle,
      cta: 'Practicar',
      badge: s.due > 0 ? '${s.due}' : null,
      onTap: onOpen,
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _JourneyCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed = JourneyProgressService.I.completedCount;
    final total = JourneyRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.map_rounded,
      iconColor: const Color(0xFF7CB8E8),
      title: 'Travesía Bíblica',
      subtitle: '$completed/$total estaciones completadas',
      cta: 'Avanzar',
      onTap: onOpen,
    );
  }
}

class _HeroesCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _HeroesCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed = HeroesProgressService.I.unlockedCount;
    final total = HeroesRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.military_tech_rounded,
      iconColor: AppDesignSystem.victory,
      title: 'Héroes de la Fe',
      subtitle: '$completed/$total desbloqueados',
      cta: 'Ver',
      onTap: onOpen,
    );
  }
}

class _ParablesCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ParablesCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed =
        ParableProgressService.I.stateNotifier.value.completedIds.length;
    final total = ParableRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.forum_rounded,
      iconColor: AppDesignSystem.hope,
      title: 'Parábolas de Jesús',
      subtitle: '$completed/$total completadas',
      cta: 'Estudiar',
      onTap: onOpen,
    );
  }
}

class _TimelineCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _TimelineCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed =
        TimelineProgressService.I.stateNotifier.value.completed.length;
    final total = TimelineRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.timeline_rounded,
      iconColor: const Color(0xFFB79CED),
      title: 'Línea del Tiempo',
      subtitle: '$completed/$total retos completados',
      cta: 'Ordenar',
      onTap: onOpen,
    );
  }
}

class _FruitCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _FruitCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed = FruitProgressService.I.badgeCount;
    final total = FruitRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.local_florist_rounded,
      iconColor: AppDesignSystem.victory,
      title: 'Fruto del Espíritu',
      subtitle: '$completed/$total frutos completados',
      cta: 'Cultivar',
      onTap: onOpen,
    );
  }
}

class _BooksCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _BooksCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed = BookProgressService.I.state.studied.length;
    final total = BookRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.menu_book_rounded,
      iconColor: AppDesignSystem.gold,
      title: 'Los 66 Libros',
      subtitle: '$completed/$total libros estudiados',
      cta: 'Abrir',
      onTap: onOpen,
    );
  }
}

class _BibleOrderCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _BibleOrderCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final rounds = BibleOrderProgressService.I.state.bestStars.length;
    return _ModuleCard(
      icon: Icons.sort_rounded,
      iconColor: const Color(0xFF7CB8E8),
      title: 'Orden de la Biblia',
      subtitle: '$rounds categorias practicadas',
      cta: 'Practicar',
      onTap: onOpen,
    );
  }
}

class _MapsCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _MapsCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed = BibleMapProgressService.I.completedCount;
    final total = BibleMapRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.public_rounded,
      iconColor: const Color(0xFF5EC2A9),
      title: 'Tierras Bíblicas',
      subtitle: '$completed/$total mapas completados',
      cta: 'Explorar',
      onTap: onOpen,
    );
  }
}

class _ProphecyCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _ProphecyCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final completed = ProphecyProgressService.I.state.bestStars.length;
    final total = ProphecyRepository.I.all.length;
    return _ModuleCard(
      icon: Icons.auto_awesome_rounded,
      iconColor: AppDesignSystem.gold,
      title: 'Profecías Mesiánicas',
      subtitle: '$completed/$total rondas completadas',
      cta: 'Conectar',
      onTap: onOpen,
    );
  }
}

class _GamesCard extends StatelessWidget {
  final VoidCallback onOpen;
  const _GamesCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _ModuleCard(
      icon: Icons.sports_esports_rounded,
      iconColor: AppDesignSystem.struggle,
      title: 'Juegos Bíblicos',
      subtitle: 'Retos locales y dinámicas de grupo',
      cta: 'Jugar',
      onTap: onOpen,
    );
  }
}

class _StatsRow extends StatelessWidget {
  final LearningProgress progress;
  const _StatsRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'XP', value: '${progress.totalXp}'),
        const SizedBox(width: AppDesignSystem.spacingS),
        _Stat(label: 'Racha', value: '${progress.studyStreak}'),
        const SizedBox(width: AppDesignSystem.spacingS),
        _Stat(label: 'Versos', value: '${progress.versesMastered}'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppDesignSystem.spacingM),
        decoration: _panelDecoration(t),
        child: Column(
          children: [
            Text(
              value,
              style: AppDesignSystem.headlineMedium(
                context,
                color: AppDesignSystem.gold,
              ),
            ),
            Text(
              label,
              style: AppDesignSystem.labelSmall(
                context,
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _panelDecoration(AppThemeData t) {
  return BoxDecoration(
    color: t.cardBg,
    borderRadius: BorderRadius.circular(AppDesignSystem.radiusL),
    border: Border.all(color: t.cardBorder),
    boxShadow: t.cardShadow,
  );
}

IconData _iconForTrack(KingdomTrackLevel level) {
  switch (level) {
    case KingdomTrackLevel.fundamentals:
      return Icons.menu_book_rounded;
    case KingdomTrackLevel.growth:
      return Icons.local_florist_rounded;
    case KingdomTrackLevel.panorama:
      return Icons.route_rounded;
    case KingdomTrackLevel.comprehension:
      return Icons.travel_explore_rounded;
    case KingdomTrackLevel.leadership:
      return Icons.volunteer_activism_rounded;
    case KingdomTrackLevel.teacher:
      return Icons.school_rounded;
  }
}

Color _colorForTrack(KingdomTrackLevel level) {
  switch (level) {
    case KingdomTrackLevel.fundamentals:
      return AppDesignSystem.gold;
    case KingdomTrackLevel.growth:
      return const Color(0xFF5FA777);
    case KingdomTrackLevel.panorama:
      return const Color(0xFF64B5F6);
    case KingdomTrackLevel.comprehension:
      return const Color(0xFF5EC2A9);
    case KingdomTrackLevel.leadership:
      return const Color(0xFFB8956E);
    case KingdomTrackLevel.teacher:
      return const Color(0xFFB79CED);
  }
}

IconData _iconForLesson(LearningLesson lesson) {
  switch (lesson.type) {
    case KingdomLessonType.guidedStudy:
      return Icons.auto_stories_rounded;
    case KingdomLessonType.readingQuestions:
      return Icons.quiz_rounded;
    case KingdomLessonType.memory:
      return Icons.shield_moon_rounded;
    case KingdomLessonType.reflection:
      return Icons.edit_note_rounded;
    case KingdomLessonType.quiz:
      return Icons.psychology_alt_rounded;
    case KingdomLessonType.caseStudy:
      return Icons.lightbulb_rounded;
    case KingdomLessonType.devotional:
      return Icons.wb_sunny_rounded;
    case KingdomLessonType.doctrine:
      return Icons.account_tree_rounded;
    case KingdomLessonType.leadership:
      return Icons.volunteer_activism_rounded;
    case KingdomLessonType.assessment:
      return Icons.workspace_premium_rounded;
  }
}

String _lessonTypeLabel(KingdomLessonType type) {
  switch (type) {
    case KingdomLessonType.guidedStudy:
      return 'Estudio guiado';
    case KingdomLessonType.readingQuestions:
      return 'Lectura';
    case KingdomLessonType.memory:
      return 'Memoria';
    case KingdomLessonType.reflection:
      return 'Reflexión';
    case KingdomLessonType.quiz:
      return 'Quiz';
    case KingdomLessonType.caseStudy:
      return 'Caso práctico';
    case KingdomLessonType.devotional:
      return 'Devocional';
    case KingdomLessonType.doctrine:
      return 'Doctrina';
    case KingdomLessonType.leadership:
      return 'Liderazgo';
    case KingdomLessonType.assessment:
      return 'Evaluación';
  }
}

class _BibleOrderTarget {
  final String categoryKey;
  final String title;
  final List<BibleBook> books;

  const _BibleOrderTarget({
    required this.categoryKey,
    required this.title,
    required this.books,
  });
}

String _normalizeLearningKey(String value) {
  var text = value.trim().toLowerCase();
  const replacements = {
    'á': 'a',
    'é': 'e',
    'í': 'i',
    'ó': 'o',
    'ú': 'u',
    'ü': 'u',
    'ñ': 'n',
  };
  replacements.forEach((from, to) {
    text = text.replaceAll(from, to);
  });
  text = text.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  text = text.replaceAll(RegExp(r'_+'), '_');
  return text.replaceAll(RegExp(r'^_|_$'), '');
}
