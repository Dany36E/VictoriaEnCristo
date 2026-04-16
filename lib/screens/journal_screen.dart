import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/journal_service.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/audio_engine.dart';
import '../models/content_item.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../utils/journal_export.dart';
import 'journal_entry_editor.dart';
import 'journal_entry_detail.dart';

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen> {
  final JournalService _journalService = JournalService();
  bool _isLoading = true;
  ScoredItem<JournalPromptItem>? _todayPrompt;

  @override
  void initState() {
    super.initState();
    AudioEngine.I.switchBgmContext(BgmContext.journal);
    _loadJournal();
    _loadTodayPrompt();
  }

  Future<void> _loadJournal() async {
    await _journalService.initialize();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTodayPrompt() async {
    try {
      final prompt = PersonalizationEngine.I.getRecommendedJournalPrompt();
      if (mounted && prompt != null) {
        setState(() => _todayPrompt = prompt);
      }
    } catch (e) {
      // Ignore - prompt is optional
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppThemeData.of(context);
    final isDark = t.isDark;
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Diario'),
        actions: [
          if (_journalService.entries.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.ios_share),
              onPressed: () {
                FeedbackEngine.I.tap();
                JournalExport.exportAndShare(context, _journalService.entries);
              },
              tooltip: 'Exportar diario',
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => _showStats(context, isDark),
              tooltip: 'Estadísticas',
            ),
          ],
        ],
      ),
      body: _buildBody(isDark),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          FeedbackEngine.I.confirm(); // Nueva entrada (CTA principal)
          _openNewEntry(context, isDark);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Entrada'),
        backgroundColor: t.accent,
        foregroundColor: isDark ? Colors.black87 : Colors.white,
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    // Si no hay entradas y no hay prompt, mostrar estado vacío
    if (_journalService.entries.isEmpty && _todayPrompt == null) {
      return _buildEmptyState(isDark);
    }

    return CustomScrollView(
      slivers: [
        // Prompt del día personalizado
        if (_todayPrompt != null)
          SliverToBoxAdapter(
            child: _buildTodayPromptCard(isDark),
          ),
        
        // Lista de entradas o mensaje si está vacío
        if (_journalService.entries.isEmpty)
          SliverFillRemaining(
            child: _buildEmptyState(isDark),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).padding.bottom + 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final entry = _journalService.entries[index];
                  return _buildEntryCard(entry, isDark);
                },
                childCount: _journalService.entries.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTodayPromptCard(bool isDark) {
    final t = AppThemeData.of(context);
    final prompt = _todayPrompt!.item;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            t.accent.withOpacity(isDark ? 0.2 : 0.1),
            t.accent.withOpacity(isDark ? 0.05 : 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: t.accent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: t.accent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 14,
                      color: t.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reflexión del día',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: t.accent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (_todayPrompt!.reason.isNotEmpty)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _todayPrompt!.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: t.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            prompt.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: t.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt.prompt,
            style: TextStyle(
              fontSize: 14,
              color: t.textSecondary,
              height: 1.5,
            ),
          ),
          if (prompt.followUp != null && prompt.followUp!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'También considera:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: t.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• ${prompt.followUp}',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: t.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                FeedbackEngine.I.confirm();
                _openNewEntryWithPrompt(context, isDark, prompt);
              },
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Escribir sobre esto'),
              style: ElevatedButton.styleFrom(
                backgroundColor: t.accent,
                foregroundColor: isDark ? Colors.black87 : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openNewEntryWithPrompt(BuildContext context, bool isDark, JournalPromptItem prompt) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryEditor(
          initialPrompt: '${prompt.title}\n\n${prompt.prompt}',
          onSave: (entry) async {
            await _journalService.addEntry(entry);
            setState(() {});
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    final t = AppThemeData.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: t.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              'Tu diario está vacío',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe tus reflexiones, victorias y luchas.\nTe ayudará a ver tu progreso.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: t.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(JournalEntry entry, bool isDark) {
    final t = AppThemeData.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: t.cardBg,
      child: InkWell(
        onTap: () {
          FeedbackEngine.I.tap();
          _openEntryDetail(context, entry, isDark);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    JournalService.moodEmojis[entry.mood] ?? 'ðŸ“',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate(entry.date),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: t.textPrimary,
                          ),
                        ),
                        Text(
                          JournalService.moodLabels[entry.mood] ?? 'Entrada',
                          style: TextStyle(
                            fontSize: 12,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (entry.hadVictory)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppTheme.successColor),
                          SizedBox(width: 4),
                          Text(
                            'Victoria',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.content.length > 100
                    ? '${entry.content.substring(0, 100)}...'
                    : entry.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: t.textPrimary,
                  height: 1.4,
                ),
              ),
              if (entry.triggers.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.triggers.take(3).map((trigger) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: t.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        trigger,
                        style: TextStyle(
                          fontSize: 11,
                          color: t.accent,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openNewEntry(BuildContext context, bool isDark) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryEditor(
          onSave: (entry) async {
            await _journalService.addEntry(entry);
            setState(() {});
          },
        ),
      ),
    );
  }

  void _openEntryDetail(BuildContext context, JournalEntry entry, bool isDark) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JournalEntryDetail(
          entry: entry,
          onDelete: () async {
            await _journalService.deleteEntry(entry.id);
            if (mounted) {
              setState(() {});
              if (context.mounted) {
                Navigator.pop(context);
              }
            }
          },
        ),
      ),
    );
  }

  void _showStats(BuildContext context, bool isDark) {
    final victoryPercentage = _journalService.getVictoryPercentage();
    final triggerStats = _journalService.getTriggerStats();
    final moodStats = _journalService.getMoodStats();
    final totalEntries = _journalService.entries.length;
    final victories = _journalService.entries.where((e) => e.hadVictory).length;

    // Weekly mood trend (last 4 weeks)
    final weeklyMoods = <int, Map<String, int>>{};
    final now = DateTime.now();
    for (int w = 0; w < 4; w++) {
      final weekStart = now.subtract(Duration(days: (w + 1) * 7));
      final weekEnd = now.subtract(Duration(days: w * 7));
      final weekEntries = _journalService.entries.where((e) =>
          e.date.isAfter(weekStart) && e.date.isBefore(weekEnd)).toList();
      final vCount = weekEntries.where((e) => e.hadVictory).length;
      weeklyMoods[w] = {'victory': vCount, 'total': weekEntries.length};
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppThemeData.of(context).cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final t = AppThemeData.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '📊 Estadísticas del Diario',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: t.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$totalEntries entradas en total',
                    style: TextStyle(color: t.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // ═══ VICTORY RING ═══
                  Center(
                    child: SizedBox(
                      width: 140, height: 140,
                      child: CustomPaint(
                        painter: _VictoryRingPainter(
                          progress: victoryPercentage / 100,
                          victoryColor: AppTheme.successColor,
                          bgColor: t.surface,
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${victoryPercentage.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 28, fontWeight: FontWeight.w700,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              Text('$victories victorias',
                                style: TextStyle(fontSize: 11, color: t.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ═══ WEEKLY TREND ═══
                  if (weeklyMoods.values.any((w) => (w['total'] ?? 0) > 0)) ...[
                    Text('📈 Tendencia semanal',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.textPrimary)),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(4, (i) {
                          final week = weeklyMoods[3 - i]!;
                          final total = week['total'] ?? 0;
                          final vic = week['victory'] ?? 0;
                          const maxH = 60.0;
                          final h = total > 0 ? (total / totalEntries.clamp(1, 100)) * maxH * 4 : 4.0;
                          final vicRatio = total > 0 ? vic / total : 0.0;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    height: h.clamp(4.0, maxH),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          AppTheme.successColor.withOpacity(0.8),
                                          Color.lerp(AppTheme.successColor, AppDesignSystem.struggle, 1.0 - vicRatio)!.withOpacity(0.6),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(i == 3 ? 'Esta' : 'Sem ${3 - i}',
                                    style: TextStyle(fontSize: 10, color: t.textSecondary)),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ═══ MOOD DISTRIBUTION ═══
                  Text('😊 Estados de Ánimo',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.textPrimary)),
                  const SizedBox(height: 12),
                  ...['victory', 'grateful', 'neutral', 'struggle'].map((mood) {
                    final count = moodStats[mood] ?? 0;
                    final ratio = totalEntries > 0 ? count / totalEntries : 0.0;
                    final moodColors = {
                      'victory': AppTheme.successColor,
                      'grateful': AppDesignSystem.gold,
                      'neutral': AppDesignSystem.coolGray,
                      'struggle': AppDesignSystem.struggle,
                    };
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Text(JournalService.moodEmojis[mood] ?? '📝', style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          SizedBox(width: 70, child: Text(
                            JournalService.moodLabels[mood] ?? mood,
                            style: TextStyle(fontSize: 13, color: t.textPrimary),
                          )),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: t.surface,
                                valueColor: AlwaysStoppedAnimation(moodColors[mood] ?? t.accent),
                                minHeight: 8,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(width: 28, child: Text('$count',
                            textAlign: TextAlign.end,
                            style: TextStyle(fontWeight: FontWeight.w600, color: t.textPrimary, fontSize: 13))),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),

                  // ═══ TRIGGER BARS ═══
                  if (triggerStats.isNotEmpty) ...[
                    Text('⚠️ Triggers más comunes',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: t.textPrimary)),
                    const SizedBox(height: 12),
                    ...triggerStats.entries.take(5).map((e) {
                      final maxCount = triggerStats.values.first;
                      final ratio = maxCount > 0 ? e.value / maxCount : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key, style: TextStyle(color: t.textPrimary, fontSize: 13)),
                                Text('${e.value}x', style: const TextStyle(
                                  color: AppDesignSystem.struggle, fontWeight: FontWeight.w600, fontSize: 13)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: ratio,
                                backgroundColor: t.surface,
                                valueColor: AlwaysStoppedAnimation(AppDesignSystem.struggle.withOpacity(0.7)),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final now = DateTime.now();
    
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hoy, ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
    
    return '${date.day} de ${months[date.month - 1]}';
  }
}

class _VictoryRingPainter extends CustomPainter {
  final double progress;
  final Color victoryColor;
  final Color bgColor;

  _VictoryRingPainter({
    required this.progress,
    required this.victoryColor,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = bgColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = victoryColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _VictoryRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
