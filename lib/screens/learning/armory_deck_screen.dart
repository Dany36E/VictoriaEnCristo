/// ═══════════════════════════════════════════════════════════════════════════
/// ArmoryDeckScreen — lista de versículos para memorizar (con selector de
/// versión bíblica) y estado SRS por cada uno.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../../models/bible/bible_version.dart';
import '../../models/learning/learning_models.dart';
import '../../services/feedback_engine.dart';
import '../../services/learning/verse_memory_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_theme_data.dart';
import 'verse_study_screen.dart';

class ArmoryDeckScreen extends StatefulWidget {
  const ArmoryDeckScreen({super.key});

  @override
  State<ArmoryDeckScreen> createState() => _ArmoryDeckScreenState();
}

class _ArmoryDeckScreenState extends State<ArmoryDeckScreen> {
  @override
  void initState() {
    super.initState();
    VerseMemoryService.I.init();
  }

  Future<void> _pickVersion() async {
    final current = VerseMemoryService.I.preferredVersionNotifier.value;
    final t = AppThemeData.of(context);
    final picked = await showModalBottomSheet<BibleVersion>(
      context: context,
      backgroundColor: t.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 6),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: t.textSecondary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDesignSystem.spacingM),
                child: Text(
                  'Elige la versión para memorizar',
                  style: AppDesignSystem.headlineSmall(
                    context,
                    color: t.textPrimary,
                  ),
                ),
              ),
              ...BibleVersion.values.map((v) {
                final selected = v == current;
                return ListTile(
                  leading: Icon(
                    selected
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_off_rounded,
                    color: selected ? AppDesignSystem.gold : t.textSecondary,
                  ),
                  title: Text(
                    v.displayName,
                    style: AppDesignSystem.bodyLarge(
                      context,
                      color: t.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    v.shortName,
                    style: AppDesignSystem.labelSmall(
                      context,
                      color: t.textSecondary,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, v),
                );
              }),
              const SizedBox(height: AppDesignSystem.spacingM),
            ],
          ),
          ),
        );
      },
    );
    if (picked != null) {
      await VerseMemoryService.I.setPreferredVersion(picked);
      FeedbackEngine.I.tap();
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBg,
      appBar: AppBar(
        backgroundColor: t.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: t.textPrimary),
        title: Text(
          'Armadura',
          style: AppDesignSystem.headlineMedium(context, color: t.textPrimary),
        ),
        actions: [
          ValueListenableBuilder<BibleVersion>(
            valueListenable: VerseMemoryService.I.preferredVersionNotifier,
            builder: (context, v, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: TextButton.icon(
                  onPressed: _pickVersion,
                  icon: const Icon(Icons.menu_book_rounded, size: 18),
                  label: Text(v.shortName),
                  style: TextButton.styleFrom(
                    foregroundColor: AppDesignSystem.gold,
                    textStyle: AppDesignSystem.labelLarge(context),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: VerseMemoryService.I.changeTickNotifier,
        builder: (context, _, _) {
          final due = VerseMemoryService.I.dueToday();
          final newOnes = VerseMemoryService.I.newVerses();
          final mastered = VerseMemoryService.I.mastered();
          return ListView(
            padding: const EdgeInsets.all(AppDesignSystem.spacingM),
            children: [
              _buildHeaderHint(context, t),
              const SizedBox(height: AppDesignSystem.spacingM),
              if (due.isNotEmpty) ...[
                _SectionTitle(
                  label: 'Para repasar hoy',
                  count: due.length,
                  color: AppDesignSystem.gold,
                ),
                ...due.map((v) => _VerseTile(
                      verse: v,
                      onOpen: () => _openStudy(v),
                    )),
                const SizedBox(height: AppDesignSystem.spacingM),
              ],
              if (newOnes.isNotEmpty) ...[
                _SectionTitle(
                  label: 'Nuevos',
                  count: newOnes.length,
                  color: const Color(0xFF7CB8E8),
                ),
                ...newOnes.map((v) => _VerseTile(
                      verse: v,
                      onOpen: () => _openStudy(v),
                    )),
                const SizedBox(height: AppDesignSystem.spacingM),
              ],
              if (mastered.isNotEmpty) ...[
                _SectionTitle(
                  label: 'Dominados',
                  count: mastered.length,
                  color: AppDesignSystem.victory,
                ),
                ...mastered.map((v) => _VerseTile(
                      verse: v,
                      onOpen: () => _openStudy(v),
                    )),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderHint(BuildContext context, AppThemeData t) {
    return Container(
      padding: const EdgeInsets.all(AppDesignSystem.spacingM),
      decoration: BoxDecoration(
        color: t.cardBg,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        border: Border.all(color: t.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_moon_rounded,
              color: AppDesignSystem.gold, size: 22),
          const SizedBox(width: AppDesignSystem.spacingS),
          Expanded(
            child: Text(
              'Memoriza versículos clave. Los que domines se vuelven «escudos» para la tentación.',
              style: AppDesignSystem.bodyMedium(
                context,
                color: t.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openStudy(MemoryVerse v) async {
    FeedbackEngine.I.tap();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VerseStudyScreen(verse: v)),
    );
    if (mounted) setState(() {});
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionTitle({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 4,
        bottom: AppDesignSystem.spacingS,
        top: AppDesignSystem.spacingS,
      ),
      child: Row(
        children: [
          Container(width: 4, height: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: AppDesignSystem.labelMedium(context, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: AppDesignSystem.labelMedium(context, color: color.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }
}

class _VerseTile extends StatelessWidget {
  final MemoryVerse verse;
  final VoidCallback onOpen;

  const _VerseTile({required this.verse, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final state = VerseMemoryService.I.stateFor(verse.id);
    final level = state.level;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDesignSystem.spacingS),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
        child: Container(
          padding: const EdgeInsets.all(AppDesignSystem.spacingM),
          decoration: BoxDecoration(
            color: t.cardBg,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusM),
            border: Border.all(color: t.cardBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      verse.reference,
                      style: AppDesignSystem.headlineSmall(
                        context,
                        color: t.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      verse.topic,
                      style: AppDesignSystem.bodyMedium(
                        context,
                        color: t.textSecondary,
                      ),
                    ),
                    if (verse.situations.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: verse.situations
                            .map((s) => _Tag(label: s))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppDesignSystem.spacingS),
              _LevelPill(level: level),
              const SizedBox(width: 6),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final int level;
  const _LevelPill({required this.level});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final color = level >= 5
        ? AppDesignSystem.victory
        : level >= 3
            ? AppDesignSystem.gold
            : level >= 1
                ? const Color(0xFF7CB8E8)
                : t.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        'Nv $level',
        style: AppDesignSystem.labelSmall(context, color: color),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: t.textSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusFull),
      ),
      child: Text(
        label,
        style: AppDesignSystem.labelSmall(context, color: t.textSecondary),
      ),
    );
  }
}
