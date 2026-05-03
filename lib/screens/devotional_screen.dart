import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/content_enums.dart';
import '../models/devotional_entry.dart';
import '../services/audio_engine.dart';
import '../services/audio_service.dart';
import '../services/daily_practice_service.dart';
import '../services/devotional_picker.dart';
import '../services/devotional_repository.dart';
import '../services/devotional_rollout_service.dart';
import '../services/devotional_telemetry.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/user_pref_cloud_sync_service.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// DEVOTIONAL SCREEN v2 — "Hoy para ti"
///
/// Cambios respecto a v1:
/// - Una entrada por día, personalizada por gigante × etapa.
/// - Selector manual de gigante (chip → bottom sheet).
/// - Modos de lectura: 2 min / 8 min / 15 min.
/// - Completado solo al pulsar "Terminé" o ≥80% scroll + ≥60s dwell.
/// - Telemetría completa (RFC-003).
/// ═══════════════════════════════════════════════════════════════════════════

class DevotionalScreen extends StatefulWidget {
  const DevotionalScreen({super.key, this.source = DevotionalSource.unknown});

  final DevotionalSource source;

  @override
  State<DevotionalScreen> createState() => _DevotionalScreenState();
}

class _DevotionalScreenState extends State<DevotionalScreen> {
  static const _prefKeyChallengePrefix = 'devotional_v2_challenge_';
  static const _prefKeyLength = 'devotional_v2_length';
  static const _prefKeyOverrideGiantPrefix = 'devotional_v2_override_giant_';

  // ───────────── Estado ─────────────
  DevotionalSelection? _selection;
  DevotionalRolloutAssignment? _rollout;
  DevotionalLength _length = DevotionalLength.standard;
  bool _loading = true;
  bool _challengeCompleted = false;
  bool _markedAsCompleted = false;
  bool _ttsPlaying = false;
  bool _ttsPaused = false;

  final ScrollController _scrollCtl = ScrollController();
  final AudioService _audioService = AudioService();
  StreamSubscription<TtsState>? _ttsSub;
  late final DateTime _openedAt;
  DateTime? _audioStartedAt;
  double _maxScrollFraction = 0;

  String get _todayKey {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _scrollCtl.addListener(_onScroll);
    _ttsSub = _audioService.stateStream.listen(_onTtsState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AudioEngine.I.switchBgmContext(BgmContext.prayer);
      _bootstrap();
    });
  }

  @override
  void dispose() {
    _scrollCtl.removeListener(_onScroll);
    _scrollCtl.dispose();
    _ttsSub?.cancel();
    unawaited(_audioService.stop());
    AudioEngine.I.switchBgmContext(BgmContext.home);
    if (!_markedAsCompleted && _selection != null) {
      DevotionalTelemetry.I.skipped(
        entryId: _selection!.entry.id,
        lastSection: 'unknown',
        dwellMs: DateTime.now().difference(_openedAt).inMilliseconds,
      );
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final lengthIdx = prefs.getInt(_prefKeyLength) ?? DevotionalLength.standard.index;
    _length = DevotionalLength.values[lengthIdx.clamp(0, DevotionalLength.values.length - 1)];

    final overrideId = prefs.getString('$_prefKeyOverrideGiantPrefix$_todayKey');
    GiantId? overrideGiant;
    if (overrideId != null) {
      for (final g in GiantId.values) {
        if (g.id == overrideId) {
          overrideGiant = g;
          break;
        }
      }
    }

    await DevotionalRepository.I.ensureLoaded();
    final rollout = await DevotionalRolloutService.I.assignment();
    await _audioService.initialize();
    final selection = await PersonalizationEngine.I.pickDevotionalForToday(
      giantOverride: overrideGiant,
    );

    final challengeDone = prefs.getBool('$_prefKeyChallengePrefix${selection.entry.id}') ?? false;

    if (!mounted) return;
    setState(() {
      _selection = selection;
      _rollout = rollout;
      _challengeCompleted = challengeDone;
      _loading = false;
    });

    DevotionalTelemetry.I.opened(
      entryId: selection.entry.id,
      giant: selection.matchedGiant?.id,
      stage: selection.matchedStage.id,
      source: widget.source,
      mode: _modeFromLength(_length),
    );
    DevotionalTelemetry.I.rolloutAssigned(
      entryId: selection.entry.id,
      variant: rollout.variant.id,
      bucket: rollout.bucket,
      rolloutPercent: rollout.rolloutPercent,
      forced: rollout.forced,
    );
    if (selection.reasonCode == 'crisis') {
      DevotionalTelemetry.I.crisisVariantShown(
        entryId: selection.entry.id,
        primaryGiant: selection.matchedGiant?.id,
      );
    }
  }

  void _onScroll() {
    if (_markedAsCompleted) return;
    if (!_scrollCtl.hasClients) return;
    final pos = _scrollCtl.position;
    if (pos.maxScrollExtent <= 0) return;
    final frac = (pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0);
    if (frac > _maxScrollFraction) _maxScrollFraction = frac;

    if (_maxScrollFraction >= 0.8) {
      final dwellMs = DateTime.now().difference(_openedAt).inMilliseconds;
      if (dwellMs >= 60000) {
        _markCompleted(trigger: 'scroll_dwell');
      }
    }
  }

  void _onTtsState(TtsState state) {
    if (state == TtsState.stopped && _audioStartedAt != null && _selection != null) {
      DevotionalTelemetry.I.audioPlayed(
        entryId: _selection!.entry.id,
        durationMs: DateTime.now().difference(_audioStartedAt!).inMilliseconds,
      );
      _audioStartedAt = null;
    }

    if (!mounted) return;
    setState(() {
      _ttsPlaying = state == TtsState.playing;
      _ttsPaused = state == TtsState.paused;
    });
  }

  bool get _canUseTts =>
      _audioService.audioEnabled &&
      _audioService.ttsAvailable &&
      _rollout?.variant != DevotionalRolloutVariant.controlMinimal;

  Future<void> _toggleAudio() async {
    if (_selection == null || !_canUseTts) return;
    if (_ttsPlaying) {
      await _audioService.pause();
      FeedbackEngine.I.tap();
      return;
    }
    if (_ttsPaused) {
      await _audioService.resume();
      FeedbackEngine.I.tap();
      return;
    }

    _audioStartedAt = DateTime.now();
    await _audioService.speak(_buildTtsText(), label: _selection!.entry.id);
    FeedbackEngine.I.confirm();
  }

  String _buildTtsText() {
    final selection = _selection!;
    final entry = selection.entry.forLength(_length);
    final buffer = StringBuffer()
      ..writeln(entry.title)
      ..writeln()
      ..writeln('Versículo. ${entry.verse}')
      ..writeln(entry.verseReference);

    if (entry.reflection.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Reflexión.')
        ..writeln(entry.reflection);
    }
    final challenge = selection.entry.challenge;
    if (challenge != null && challenge.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Reto del día.')
        ..writeln(challenge);
    }
    if (entry.prayer.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Oración.')
        ..writeln(entry.prayer);
    }
    return buffer.toString();
  }

  DevotionalReadMode _modeFromLength(DevotionalLength len) => switch (len) {
    DevotionalLength.quick => DevotionalReadMode.quick,
    DevotionalLength.standard => DevotionalReadMode.standard,
    DevotionalLength.deep => DevotionalReadMode.deep,
  };

  Future<void> _markCompleted({required String trigger}) async {
    if (_markedAsCompleted || _selection == null) return;
    _markedAsCompleted = true;
    DailyPracticeService.I.mark(DailyPractice.devotional);
    final dwellMs = DateTime.now().difference(_openedAt).inMilliseconds;
    DevotionalTelemetry.I.completed(
      entryId: _selection!.entry.id,
      mode: _modeFromLength(_length),
      totalMs: dwellMs,
      sectionsViewed: 4,
      trigger: trigger,
    );
    if (trigger == 'cta') FeedbackEngine.I.confirm();
    if (mounted) setState(() {});
  }

  Future<void> _toggleChallenge() async {
    if (_selection == null) return;
    final entry = _selection!.entry;
    final newVal = !_challengeCompleted;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefKeyChallengePrefix${entry.id}', newVal);
    UserPrefCloudSyncService.I.markDirty();
    setState(() => _challengeCompleted = newVal);
    if (newVal) {
      FeedbackEngine.I.confirm();
    } else {
      FeedbackEngine.I.tap();
    }
  }

  Future<void> _setLength(DevotionalLength len) async {
    setState(() => _length = len);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefKeyLength, len.index);
    UserPrefCloudSyncService.I.markDirty();
    FeedbackEngine.I.tap();
  }

  Future<void> _openGiantPicker() async {
    final current = _selection?.matchedGiant;
    final selected = await showModalBottomSheet<_GiantPick>(
      context: context,
      backgroundColor: AppThemeData.of(context).cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _GiantPickerSheet(current: current),
    );
    if (selected == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefKeyOverrideGiantPrefix$_todayKey';
    if (selected.giant == null) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, selected.giant!.id);
    }
    UserPrefCloudSyncService.I.markDirty();

    if (_selection != null) {
      DevotionalTelemetry.I.giantOverride(
        entryId: _selection!.entry.id,
        fromGiant: current?.id ?? 'auto',
        toGiant: selected.giant?.id ?? 'auto',
      );
    }

    setState(() {
      _loading = true;
      _markedAsCompleted = false;
      _maxScrollFraction = 0;
    });
    final newSelection = await PersonalizationEngine.I.pickDevotionalForToday(
      giantOverride: selected.giant,
    );
    if (!mounted) return;
    setState(() {
      _selection = newSelection;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeData = AppThemeData.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: themeData.scaffoldBg,
      body: _loading || _selection == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                CustomScrollView(controller: _scrollCtl, slivers: _buildSlivers(themeData, isDark)),
                _buildStickyCta(themeData),
              ],
            ),
    );
  }

  List<Widget> _buildSlivers(AppThemeData themeData, bool isDark) {
    final sel = _selection!;
    final entry = sel.entry.forLength(_length);

    return [
      SliverAppBar(
        pinned: true,
        expandedHeight: 140,
        backgroundColor: themeData.scaffoldBg,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: themeData.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_canUseTts)
            IconButton(
              icon: Icon(
                _ttsPlaying
                    ? Icons.pause_circle_filled_rounded
                    : (_ttsPaused ? Icons.play_circle_fill_rounded : Icons.volume_up_rounded),
                color: themeData.textPrimary,
              ),
              tooltip: _ttsPlaying ? 'Pausar lectura' : 'Escuchar devocional',
              onPressed: _toggleAudio,
            ),
          IconButton(
            icon: Icon(Icons.tune_rounded, color: themeData.textPrimary),
            tooltip: 'Cambiar enfoque',
            onPressed: _openGiantPicker,
          ),
        ],
        flexibleSpace: FlexibleSpaceBar(
          background: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [themeData.accent.withOpacity(0.15), themeData.scaffoldBg],
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(56, 8, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Devocional',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: themeData.textPrimary,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoy para ti',
                      style: TextStyle(fontSize: 14, color: themeData.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDesignSystem.spacingM,
            8,
            AppDesignSystem.spacingM,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ContextChip(selection: sel, onTap: () => _showWhyThisSheet(themeData, sel)),
              const SizedBox(height: 12),
              _LengthSelector(current: _length, onChanged: _setLength, themeData: themeData),
              if (_canUseTts && (_rollout?.showAudioCard ?? false)) ...[
                const SizedBox(height: 12),
                _audioGuideCard(themeData),
              ],
            ],
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppDesignSystem.spacingM)),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppDesignSystem.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: themeData.textPrimary,
                  letterSpacing: 0.2,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingL),
              _section(
                themeData: themeData,
                isDark: isDark,
                icon: Icons.menu_book_rounded,
                label: 'VERSÍCULO',
                accentColor: const Color(0xFF7B68EE),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.verse,
                      style: TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: themeData.textPrimary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '— ${entry.verseReference}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: themeData.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDesignSystem.spacingM),
              if (entry.reflection.isNotEmpty) ...[
                _section(
                  themeData: themeData,
                  isDark: isDark,
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'REFLEXIÓN',
                  accentColor: const Color(0xFFF39C12),
                  child: SelectableText(
                    entry.reflection,
                    style: TextStyle(fontSize: 16, color: themeData.textPrimary, height: 1.7),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
              ],
              if (sel.entry.challenge != null && sel.entry.challenge!.isNotEmpty) ...[
                _section(
                  themeData: themeData,
                  isDark: isDark,
                  icon: Icons.emoji_events_rounded,
                  label: 'RETO DEL DÍA',
                  accentColor: const Color(0xFF27AE60),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sel.entry.challenge!,
                        style: TextStyle(fontSize: 15, color: themeData.textPrimary, height: 1.6),
                      ),
                      const SizedBox(height: 12),
                      _challengeChip(themeData),
                    ],
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingM),
              ],
              if (entry.prayer.isNotEmpty) ...[
                _section(
                  themeData: themeData,
                  isDark: isDark,
                  icon: Icons.favorite_rounded,
                  label: 'ORACIÓN',
                  accentColor: const Color(0xFFE74C3C),
                  child: SelectableText(
                    entry.prayer,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: themeData.textPrimary,
                      height: 1.7,
                    ),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.spacingL),
              ],
              SizedBox(
                height: MediaQuery.of(context).padding.bottom + AppDesignSystem.spacingXL + 72,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _challengeChip(AppThemeData themeData) {
    return GestureDetector(
      onTap: _toggleChallenge,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _challengeCompleted
              ? const Color(0xFF27AE60).withOpacity(0.15)
              : themeData.textSecondary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusS),
          border: Border.all(
            color: _challengeCompleted
                ? const Color(0xFF27AE60).withOpacity(0.4)
                : themeData.textSecondary.withOpacity(0.15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _challengeCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 20,
              color: _challengeCompleted ? const Color(0xFF27AE60) : themeData.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              _challengeCompleted ? '¡Reto completado!' : 'Marcar reto como completado',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _challengeCompleted ? const Color(0xFF27AE60) : themeData.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioGuideCard(AppThemeData themeData) {
    final icon = _ttsPlaying
        ? Icons.pause_rounded
        : (_ttsPaused ? Icons.play_arrow_rounded : Icons.graphic_eq_rounded);
    final label = _ttsPlaying
        ? 'Pausar lectura'
        : (_ttsPaused ? 'Continuar lectura' : 'Escuchar devocional');

    return InkWell(
      onTap: _toggleAudio,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: themeData.accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(color: themeData.accent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: themeData.accent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: themeData.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              _length.label,
              style: TextStyle(
                color: themeData.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStickyCta(AppThemeData themeData) {
    final completed = _markedAsCompleted;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: BoxDecoration(
            color: themeData.scaffoldBg.withOpacity(0.94),
            border: Border(top: BorderSide(color: themeData.textSecondary.withOpacity(0.10))),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: completed ? null : () => _markCompleted(trigger: 'cta'),
              icon: Icon(completed ? Icons.check_circle_rounded : Icons.task_alt_rounded),
              label: Text(
                completed ? 'Devocional completado' : 'Terminé',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: completed ? const Color(0xFF27AE60) : themeData.accent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF27AE60),
                disabledForegroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showWhyThisSheet(AppThemeData themeData, DevotionalSelection selection) {
    showModalBottomSheet(
      context: context,
      backgroundColor: themeData.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: themeData.accent, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Por qué este devocional hoy?',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: themeData.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              selection.reasonHuman,
              style: TextStyle(fontSize: 15, color: themeData.textPrimary, height: 1.5),
            ),
            const SizedBox(height: 10),
            Text(
              'Elegimos cada lectura según tu gigante principal y tu etapa actual. Puedes cambiar el enfoque en cualquier momento.',
              style: TextStyle(fontSize: 13, color: themeData.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  _openGiantPicker();
                },
                icon: const Icon(Icons.tune_rounded),
                label: const Text('Cambiar enfoque'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section({
    required AppThemeData themeData,
    required bool isDark,
    required IconData icon,
    required String label,
    required Color accentColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: themeData.cardBg.withOpacity(isDark ? 0.5 : 0.85),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: accentColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accentColor.withOpacity(0.25), accentColor.withOpacity(0.10)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: accentColor),
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: accentColor,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// CHIP DE CONTEXTO ("Para tu lucha con X · Etapa Y")
// ═══════════════════════════════════════════════════════════════════════════

class _ContextChip extends StatelessWidget {
  const _ContextChip({required this.selection, required this.onTap});
  final DevotionalSelection selection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final themeData = AppThemeData.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: themeData.accent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: themeData.accent.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: themeData.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                selection.reasonHuman,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: themeData.accent,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline_rounded, size: 14, color: themeData.accent.withOpacity(0.7)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SELECTOR DE LONGITUD (2 / 8 / 15 min)
// ═══════════════════════════════════════════════════════════════════════════

class _LengthSelector extends StatelessWidget {
  const _LengthSelector({required this.current, required this.onChanged, required this.themeData});

  final DevotionalLength current;
  final ValueChanged<DevotionalLength> onChanged;
  final AppThemeData themeData;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: DevotionalLength.values.map((len) {
        final selected = len == current;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onChanged(len),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: selected ? themeData.accent : themeData.cardBg.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? themeData.accent : themeData.textSecondary.withOpacity(0.15),
                ),
              ),
              child: Text(
                len.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected ? Colors.white : themeData.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// BOTTOM SHEET — Selector manual de gigante
// ═══════════════════════════════════════════════════════════════════════════

class _GiantPick {
  final GiantId? giant; // null = automático
  const _GiantPick(this.giant);
}

class _GiantPickerSheet extends StatelessWidget {
  const _GiantPickerSheet({required this.current});
  final GiantId? current;

  @override
  Widget build(BuildContext context) {
    final themeData = AppThemeData.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '¿En qué quieres enfocarte hoy?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: themeData.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Elige un gigante o deja que la app elija por ti según tu lucha principal.',
                style: TextStyle(fontSize: 13, color: themeData.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              _giantTile(
                context,
                themeData,
                emoji: '✨',
                title: 'Automático',
                subtitle: 'Hoy para ti — según tu gigante principal',
                selected: current == null,
                onTap: () => Navigator.pop(context, const _GiantPick(null)),
              ),
              const SizedBox(height: 8),
              ...GiantId.values.map(
                (g) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _giantTile(
                    context,
                    themeData,
                    emoji: g.emoji,
                    title: g.displayName,
                    subtitle: g.description,
                    selected: current == g,
                    onTap: () => Navigator.pop(context, _GiantPick(g)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _giantTile(
    BuildContext context,
    AppThemeData themeData, {
    required String emoji,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? themeData.accent.withOpacity(0.12) : themeData.cardBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
          border: Border.all(
            color: selected ? themeData.accent : themeData.textSecondary.withOpacity(0.12),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: themeData.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.5, color: themeData.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
            if (selected) Icon(Icons.check_circle_rounded, color: themeData.accent),
          ],
        ),
      ),
    );
  }
}
