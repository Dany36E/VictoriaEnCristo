/// ═══════════════════════════════════════════════════════════════════════════
/// WALL SCREEN - Muro de Batalla (Feed principal)
/// Feed anónimo filtrado por gigante con FAB para nuevo post.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../models/wall_post.dart';
import '../../models/content_enums.dart';
import '../../services/wall_service.dart';
import '../../services/feedback_engine.dart';
import '../../services/audio_engine.dart';
import '../../widgets/wall_post_card.dart';
import 'wall_composer_screen.dart';
import 'wall_thread_screen.dart';

class WallScreen extends StatefulWidget {
  const WallScreen({super.key});

  @override
  State<WallScreen> createState() => _WallScreenState();
}

class _WallScreenState extends State<WallScreen> {
  String? _selectedGiant;
  StreamSubscription? _feedSub;
  List<WallPost> _posts = [];
  bool _loading = true;
  bool _isEmpty = false;

  @override
  void initState() {
    super.initState();
    AudioEngine.I.muteForScreen();
    _subscribeFeed();
  }

  @override
  void dispose() {
    _feedSub?.cancel();
    super.dispose();
  }

  void _subscribeFeed() {
    _feedSub?.cancel();
    setState(() {
      _loading = true;
      _isEmpty = false;
    });

    _feedSub = WallService.I
        .watchApprovedFeed(giantFilter: _selectedGiant)
        .listen(
      (posts) {
        if (!mounted) return;
        setState(() {
          _posts = posts;
          _loading = false;
          _isEmpty = posts.isEmpty;
        });
      },
      onError: (e) {
        debugPrint('❌ [WALL] Feed error: $e');
        if (mounted) setState(() => _loading = false);
      },
    );
  }

  void _onGiantChanged(String? giantId) {
    FeedbackEngine.I.tabChange();
    setState(() => _selectedGiant = giantId);
    _subscribeFeed();
  }

  Future<void> _openComposer() async {
    FeedbackEngine.I.tap();
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const WallComposerScreen()),
    );
    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Tu mensaje fue enviado y será revisado pronto.',
            style: TextStyle(color: AppDesignSystem.pureWhite),
          ),
          backgroundColor: AppDesignSystem.midnightLight,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  void _openThread(WallPost post) {
    FeedbackEngine.I.tap();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WallThreadScreen(post: post)),
    );
  }

  void _showReportDialog(WallPost post) {
    FeedbackEngine.I.tap();
    showModalBottomSheet(
      context: context,
      backgroundColor: AppDesignSystem.midnightLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ReportSheet(
        onReport: (reason) async {
          Navigator.pop(ctx);
          final res = await WallService.I.reportContent(
            contentType: 'post',
            postId: post.id,
            reason: reason.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  res.success ? 'Gracias por reportar.' : res.message,
                  style: const TextStyle(color: AppDesignSystem.pureWhite),
                ),
                backgroundColor: AppDesignSystem.midnightLight,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Muro de Batalla',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppDesignSystem.pureWhite,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppDesignSystem.pureWhite),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openComposer,
        backgroundColor: AppDesignSystem.gold,
        icon: const Icon(Icons.edit_rounded, color: AppDesignSystem.midnightDeep),
        label: const Text(
          'Compartir',
          style: TextStyle(
            color: AppDesignSystem.midnightDeep,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Giant filter chips ──
          _buildGiantFilter(),
          const Divider(height: 1, color: Color(0x22D4A853)),
          // ── Feed ──
          Expanded(child: _buildFeedContent()),
        ],
      ),
    );
  }

  Widget _buildGiantFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppDesignSystem.spacingM,
        vertical: AppDesignSystem.spacingS,
      ),
      child: Row(
        children: [
          _GiantChip(
            label: 'Todos',
            selected: _selectedGiant == null,
            onTap: () => _onGiantChanged(null),
          ),
          const SizedBox(width: 8),
          ...GiantId.values.map((g) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _GiantChip(
                  label: g.displayName,
                  selected: _selectedGiant == g.id,
                  onTap: () => _onGiantChanged(g.id),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFeedContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppDesignSystem.gold),
      );
    }

    if (_isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.spacingXL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 64,
                color: AppDesignSystem.gold.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedGiant != null
                    ? 'No hay mensajes en esta categoría aún.'
                    : 'El muro está vacío.\n¡Sé el primero en compartir!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppDesignSystem.coolGray.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ).animate().fadeIn(duration: 400.ms),
        ),
      );
    }

    return RefreshIndicator(
      color: AppDesignSystem.gold,
      backgroundColor: AppDesignSystem.midnightLight,
      onRefresh: () async {
        _subscribeFeed();
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDesignSystem.spacingM,
          vertical: AppDesignSystem.spacingS,
        ),
        itemCount: _posts.length,
        itemBuilder: (context, index) {
          final post = _posts[index];
          return WallPostCard(
            post: post,
            onTap: () => _openThread(post),
            onReport: () => _showReportDialog(post),
          ).animate().fadeIn(
                duration: 300.ms,
                delay: Duration(milliseconds: index.clamp(0, 10) * 50),
              );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GIANT CHIP
// ═══════════════════════════════════════════════════════════════════════════

class _GiantChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GiantChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? AppDesignSystem.gold.withValues(alpha: 0.2)
              : AppDesignSystem.midnightLight.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? AppDesignSystem.gold.withValues(alpha: 0.5)
                : AppDesignSystem.gold.withValues(alpha: 0.1),
            width: selected ? 1.0 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? AppDesignSystem.gold
                : AppDesignSystem.coolGray,
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// REPORT BOTTOM SHEET
// ═══════════════════════════════════════════════════════════════════════════

class _ReportSheet extends StatelessWidget {
  final void Function(ReportReason reason) onReport;

  const _ReportSheet({required this.onReport});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppDesignSystem.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reportar contenido',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppDesignSystem.pureWhite,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Selecciona la razón del reporte:',
              style: TextStyle(
                fontSize: 13,
                color: AppDesignSystem.coolGray.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            ...ReportReason.values.map(
              (reason) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(
                  Icons.flag_outlined,
                  size: 18,
                  color: AppDesignSystem.struggle,
                ),
                title: Text(
                  reason.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppDesignSystem.pureWhite,
                  ),
                ),
                onTap: () {
                  FeedbackEngine.I.select();
                  onReport(reason);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
