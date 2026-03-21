import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../models/plan.dart';
import '../models/plan_metadata.dart';
import '../models/content_enums.dart';
import '../services/plan_repository.dart';
import '../services/plan_progress_service.dart';
import '../services/audio_engine.dart';
import '../widgets/plan_list_tile.dart';
import '../widgets/plan_filter_sheet.dart';
import 'plan_detail_screen_v2.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// PLAN LIBRARY SCREEN
/// Biblioteca completa de planes con búsqueda, filtros y tabs
/// ═══════════════════════════════════════════════════════════════════════════

class PlanLibraryScreen extends StatefulWidget {
  const PlanLibraryScreen({super.key});

  @override
  State<PlanLibraryScreen> createState() => _PlanLibraryScreenState();
}

class _PlanLibraryScreenState extends State<PlanLibraryScreen> 
    with SingleTickerProviderStateMixin {
  
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  
  bool _isLoading = true;
  bool _isSearching = false;
  String _searchQuery = '';
  PlanFilters _filters = PlanFilters.empty;
  
  List<Plan> _allPlans = [];
  final Map<String, PlanProgress> _progressMap = {};

  // Tabs cubren todos los PlanType del JSON
  final List<_TabConfig> _tabs = [
    _TabConfig('Todos', Icons.apps, null),
    _TabConfig('Batalla', Icons.local_hospital_outlined, PlanType.giantFocused), // 12 planes
    _TabConfig('Emocional', Icons.spa_outlined, PlanType.emotionalRegulation), // 7 planes
    _TabConfig('Discipulado', Icons.school_outlined, PlanType.discipleship), // 4 planes  
    _TabConfig('Recuperación', Icons.refresh, PlanType.relapseRecovery), // 3 planes
    _TabConfig('Escritura', Icons.menu_book_outlined, PlanType.scriptureDepth), // 2 planes
    _TabConfig('Nuevos', Icons.child_care_outlined, PlanType.newInFaith), // 1 plan
  ];

  @override
  void initState() {
    super.initState();
    AudioEngine.I.muteForScreen();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadPlans();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    try {
      final repo = PlanRepository();
      await repo.init();
      
      final progressService = PlanProgressService();
      await progressService.init();
      
      setState(() {
        _allPlans = repo.plans;
        for (final progress in progressService.allProgress) {
          _progressMap[progress.planId] = progress;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading plans: $e');
      setState(() => _isLoading = false);
    }
  }

  List<Plan> get _filteredPlans {
    var plans = List<Plan>.from(_allPlans);
    
    // 1. Filtrar por tab actual (si no es "Todos")
    final currentTab = _tabs[_tabController.index];
    if (currentTab.planType != null) {
      plans = plans.where((p) => p.metadata.planType == currentTab.planType).toList();
    }
    
    // 2. Aplicar búsqueda sobre la lista filtrada por tab
    if (_searchQuery.isNotEmpty) {
      final lowerQuery = _searchQuery.toLowerCase();
      plans = plans.where((p) {
        return p.title.toLowerCase().contains(lowerQuery) ||
               p.subtitle.toLowerCase().contains(lowerQuery) ||
               p.description.toLowerCase().contains(lowerQuery) ||
               p.metadata.tags.any((t) => t.toLowerCase().contains(lowerQuery));
      }).toList();
    }
    
    // 3. Aplicar filtros adicionales del sheet sobre la lista ya filtrada
    if (!_filters.isEmpty) {
      // Filtrar por gigantes
      if (_filters.giants.isNotEmpty) {
        plans = plans.where((p) => 
            p.metadata.giants.any((g) => _filters.giants.contains(g))
        ).toList();
      }
      
      // Filtrar por tipo (adicional al tab)
      if (_filters.types.isNotEmpty) {
        plans = plans.where((p) => _filters.types.contains(p.metadata.planType)).toList();
      }
      
      // Filtrar por dificultad
      if (_filters.difficulties.isNotEmpty) {
        plans = plans.where((p) => _filters.difficulties.contains(p.metadata.difficulty)).toList();
      }
      
      // Filtrar por stage
      if (_filters.stages.isNotEmpty) {
        plans = plans.where((p) => _filters.stages.contains(p.metadata.stage)).toList();
      }
      
      // Filtrar por duración
      if (_filters.durations.isNotEmpty) {
        plans = plans.where((p) => _filters.durations.contains(p.durationDays)).toList();
      }
      
      // Filtrar por tiempo máximo
      if (_filters.maxMinutesPerDay != null) {
        plans = plans.where((p) => p.minutesPerDay <= _filters.maxMinutesPerDay!).toList();
      }
      
      // Filtrar para nuevos en la fe
      if (_filters.forNewBelievers == true) {
        plans = plans.where((p) => p.metadata.recommendedFor.newBeliever).toList();
      }
      
      // Filtrar para crisis
      if (_filters.forCrisis == true) {
        plans = plans.where((p) => p.metadata.recommendedFor.crisis).toList();
      }
    }
    
    return plans;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(context, innerBoxIsScrolled),
        ],
        body: _isLoading
            ? _buildLoadingState()
            : _buildContent(),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool innerBoxIsScrolled) {
    return SliverAppBar(
      pinned: true,
      floating: true,
      expandedHeight: 140,
      backgroundColor: AppDesignSystem.midnight,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: AppDesignSystem.pureWhite),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        // Filter button
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.tune, color: AppDesignSystem.pureWhite),
              onPressed: _showFilters,
            ),
            if (!_filters.isEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppDesignSystem.gold,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${_filters.activeCount}',
                      style: const TextStyle(
                        color: AppDesignSystem.midnight,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Search toggle
        IconButton(
          icon: Icon(
            _isSearching ? Icons.close : Icons.search,
            color: AppDesignSystem.pureWhite,
          ),
          onPressed: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchController.clear();
                _searchQuery = '';
              }
            });
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 60),
        title: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _isSearching
              ? Padding(
                  padding: const EdgeInsets.only(right: 100),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.pureWhite),
                    decoration: InputDecoration(
                      hintText: 'Buscar planes...',
                      hintStyle: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.coolGray),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                    },
                  ),
                )
              : Text(
                  'Planes',
                  style: AppDesignSystem.headlineSmall(context, color: AppDesignSystem.pureWhite),
                ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppDesignSystem.midnightGradient,
          ),
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(44),
        child: SizedBox(
          height: 44,
          child: TabBar(
            controller: _tabController,
            isScrollable: true,
            indicatorColor: AppDesignSystem.gold,
            indicatorWeight: 2,
            indicatorPadding: EdgeInsets.zero,
            dividerHeight: 0,
            labelColor: AppDesignSystem.gold,
            unselectedLabelColor: AppDesignSystem.coolGray,
            tabAlignment: TabAlignment.start,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            labelPadding: const EdgeInsets.symmetric(horizontal: 10),
            padding: EdgeInsets.zero,
            onTap: (_) => setState(() {}),
            tabs: _tabs.map((tab) => Tab(
              height: 40,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(tab.icon, size: 14),
                  const SizedBox(width: 3),
                  Text(tab.label),
                ],
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppDesignSystem.gold),
          ),
          const SizedBox(height: 16),
          Text(
            'Cargando planes...',
            style: AppDesignSystem.bodyMedium(context, color: AppDesignSystem.coolGray),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final plans = _filteredPlans;
    
    if (plans.isEmpty) {
      return _buildEmptyState();
    }
    
    return RefreshIndicator(
      onRefresh: _loadPlans,
      color: AppDesignSystem.gold,
      backgroundColor: AppDesignSystem.midnightLight,
      child: CustomScrollView(
        slivers: [
          // Active filters chips
          if (!_filters.isEmpty)
            SliverToBoxAdapter(child: _buildActiveFiltersRow()),
          
          // Stats row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    '${plans.length} planes',
                    style: AppDesignSystem.labelMedium(context, color: AppDesignSystem.coolGray),
                  ),
                  const Spacer(),
                  // View toggle could go here
                ],
              ),
            ),
          ),
          
          // Plans list (estilo YouVersion)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final plan = plans[index];
                final progress = _progressMap[plan.id];
                
                return PlanListTile(
                  plan: plan,
                  progress: progress,
                  onTap: () => _openPlanDetail(plan),
                );
              },
              childCount: plans.length,
            ),
          ),
          
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 100),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: AppDesignSystem.coolGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'No encontramos planes para "$_searchQuery"'
                  : 'No hay planes con estos filtros',
              style: AppDesignSystem.bodyLarge(context, color: AppDesignSystem.coolGray),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                  _filters = PlanFilters.empty;
                  _isSearching = false;
                });
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Limpiar filtros'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppDesignSystem.gold,
                side: const BorderSide(color: AppDesignSystem.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFiltersRow() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Giants
          for (final giant in _filters.giants)
            _buildFilterChip(
              giant.displayName,
              () => setState(() {
                final newGiants = Set<GiantId>.from(_filters.giants)..remove(giant);
                _filters = _filters.copyWith(giants: newGiants);
              }),
            ),
          // Types
          for (final type in _filters.types)
            _buildFilterChip(
              type.displayName,
              () => setState(() {
                final newTypes = Set<PlanType>.from(_filters.types)..remove(type);
                _filters = _filters.copyWith(types: newTypes);
              }),
            ),
          // Difficulties
          for (final difficulty in _filters.difficulties)
            _buildFilterChip(
              difficulty.displayName,
              () => setState(() {
                final newDifficulties = Set<PlanDifficulty>.from(_filters.difficulties)..remove(difficulty);
                _filters = _filters.copyWith(difficulties: newDifficulties);
              }),
            ),
          // Max minutes
          if (_filters.maxMinutesPerDay != null)
            _buildFilterChip(
              '≤${_filters.maxMinutesPerDay} min',
              () => setState(() {
                _filters = _filters.copyWith(clearMaxMinutes: true);
              }),
            ),
          // Clear all
          if (_filters.activeCount > 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: TextButton(
                onPressed: () => setState(() => _filters = PlanFilters.empty),
                child: Text(
                  'Limpiar',
                  style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppDesignSystem.gold.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppDesignSystem.gold.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppDesignSystem.labelSmall(context, color: AppDesignSystem.gold),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close,
                size: 14,
                color: AppDesignSystem.gold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilters() async {
    final result = await PlanFilterSheet.show(
      context,
      currentFilters: _filters,
    );
    
    if (result != null) {
      setState(() => _filters = result);
    }
  }

  void _openPlanDetail(Plan plan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlanDetailScreenV2(plan: plan),
      ),
    );
  }
}

class _TabConfig {
  final String label;
  final IconData icon;
  final PlanType? planType;

  _TabConfig(this.label, this.icon, this.planType);
}
