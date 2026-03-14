/// ═══════════════════════════════════════════════════════════════════════════
/// ADMIN WALL SCREEN - Panel de moderación del Muro de Batalla
/// Tabs: Pendientes | Reportados | Aprobados | Rechazados
/// Solo accesible si isAdmin == true.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/wall_post.dart';
import '../../services/wall_service.dart';
import '../../services/feedback_engine.dart';
import '../../widgets/admin_post_card.dart';

class AdminWallScreen extends StatefulWidget {
  const AdminWallScreen({super.key});

  @override
  State<AdminWallScreen> createState() => _AdminWallScreenState();
}

class _AdminWallScreenState extends State<AdminWallScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Streams
  StreamSubscription? _pendingSub;
  StreamSubscription? _reportedSub;
  StreamSubscription? _approvedSub;
  StreamSubscription? _rejectedSub;

  List<WallPost> _pending = [];
  List<WallPost> _reported = [];
  List<WallPost> _approved = [];
  List<WallPost> _rejected = [];

  bool _loadingPending = true;
  bool _loadingReported = true;
  bool _loadingApproved = true;
  bool _loadingRejected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _subscribeAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pendingSub?.cancel();
    _reportedSub?.cancel();
    _approvedSub?.cancel();
    _rejectedSub?.cancel();
    super.dispose();
  }

  void _subscribeAll() {
    _pendingSub = WallService.I.watchPendingPosts().listen((posts) {
      if (mounted) setState(() { _pending = posts; _loadingPending = false; });
    });
    _reportedSub = WallService.I.watchReportedPosts().listen((posts) {
      if (mounted) setState(() { _reported = posts; _loadingReported = false; });
    });
    _approvedSub = WallService.I.watchApprovedPostsAdmin().listen((posts) {
      if (mounted) setState(() { _approved = posts; _loadingApproved = false; });
    });
    _rejectedSub = WallService.I.watchRejectedPosts().listen((posts) {
      if (mounted) setState(() { _rejected = posts; _loadingRejected = false; });
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ACCIONES DE MODERACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _approvePost(WallPost post) async {
    FeedbackEngine.I.confirm();
    final res = await WallService.I.moderateContent(
      contentType: 'post',
      postId: post.id,
      action: 'approve',
    );
    if (mounted) _showResult(res);
  }

  Future<void> _rejectPost(WallPost post) async {
    final reason = await _showRejectionDialog();
    if (reason == null || !mounted) return;

    final res = await WallService.I.moderateContent(
      contentType: 'post',
      postId: post.id,
      action: 'reject',
      rejectionReason: reason,
    );
    if (mounted) _showResult(res);
  }

  Future<void> _banUser(WallPost post) async {
    if (post.abuseHash == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignSystem.midnightLight,
        title: const Text(
          '⚠️ Banear usuario',
          style: TextStyle(color: AppDesignSystem.pureWhite, fontSize: 16),
        ),
        content: Text(
          'Esto bloqueará permanentemente al usuario ${post.alias} '
          '(hash: ${post.abuseHash}) y rechazará todos sus posts pendientes.',
          style: const TextStyle(color: AppDesignSystem.coolGray, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppDesignSystem.coolGray)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Banear', style: TextStyle(color: AppDesignSystem.struggle)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final res = await WallService.I.banUser(
      abuseHash: post.abuseHash!,
      reason: 'Admin ban from moderation panel',
    );
    if (mounted) _showResult(res);
  }

  Future<String?> _showRejectionDialog() async {
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppDesignSystem.midnightLight,
        title: const Text(
          'Razón de rechazo',
          style: TextStyle(color: AppDesignSystem.pureWhite, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: kRejectionReasons.map((reason) {
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                reason,
                style: const TextStyle(color: AppDesignSystem.coolGray, fontSize: 13),
              ),
              onTap: () => Navigator.pop(ctx, reason),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancelar', style: TextStyle(color: AppDesignSystem.coolGray)),
          ),
        ],
      ),
    );
  }

  void _showResult(WallPostResult result) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.message,
          style: const TextStyle(color: AppDesignSystem.pureWhite),
        ),
        backgroundColor: result.success
            ? AppDesignSystem.victory.withValues(alpha: 0.8)
            : AppDesignSystem.struggle.withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          'Moderación',
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
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppDesignSystem.gold,
          labelColor: AppDesignSystem.gold,
          unselectedLabelColor: AppDesignSystem.coolGray,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          tabAlignment: TabAlignment.start,
          onTap: (_) => FeedbackEngine.I.tabChange(),
          tabs: [
            Tab(text: 'Pendientes (${_pending.length})'),
            Tab(text: 'Reportados (${_reported.length})'),
            Tab(text: 'Aprobados (${_approved.length})'),
            Tab(text: 'Rechazados (${_rejected.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(_pending, _loadingPending, 'No hay posts pendientes 👍'),
          _buildList(_reported, _loadingReported, 'No hay posts reportados'),
          _buildList(_approved, _loadingApproved, 'No hay posts aprobados'),
          _buildList(_rejected, _loadingRejected, 'No hay posts rechazados'),
        ],
      ),
    );
  }

  Widget _buildList(List<WallPost> posts, bool loading, String emptyMessage) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppDesignSystem.gold),
      );
    }

    if (posts.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: TextStyle(
            fontSize: 14,
            color: AppDesignSystem.coolGray.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      itemCount: posts.length,
      itemBuilder: (context, index) {
        final post = posts[index];
        return AdminPostCard(
          post: post,
          onApprove: post.isPending ? () => _approvePost(post) : null,
          onReject: (post.isPending || post.isApproved) ? () => _rejectPost(post) : null,
          onBan: post.abuseHash != null ? () => _banUser(post) : null,
        );
      },
    );
  }
}
