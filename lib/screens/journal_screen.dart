import 'package:flutter/material.dart';
import '../services/journal_service.dart';
import '../services/feedback_engine.dart';
import '../services/personalization_engine.dart';
import '../services/audio_engine.dart';
import '../models/content_item.dart';
import '../theme/app_theme.dart';

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
    AudioEngine.I.muteForScreen();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Diario'),
        actions: [
          if (_journalService.entries.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => _showStats(context, isDark),
              tooltip: 'Estadísticas',
            ),
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
        backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
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
    final prompt = _todayPrompt!.item;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppTheme.darkPrimary.withOpacity(0.2), AppTheme.darkPrimary.withOpacity(0.05)]
              : [AppTheme.primaryColor.withOpacity(0.1), AppTheme.primaryColor.withOpacity(0.02)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor).withOpacity(0.3),
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
                  color: (isDark ? AppTheme.darkAccent : AppTheme.accentColor).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 14,
                      color: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Reflexión del día',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Mostrar razón de recomendación
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
                        color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            prompt.prompt,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '• ${prompt.followUp}',
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                backgroundColor: isDark ? AppTheme.darkAccent : AppTheme.accentColor,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.book_outlined,
              size: 80,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              'Tu diario está vacío',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Escribe tus reflexiones, victorias y luchas.\nTe ayudará a ver tu progreso.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryCard(JournalEntry entry, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? AppTheme.darkCard : Colors.white,
      child: InkWell(
        onTap: () {
          FeedbackEngine.I.tap(); // Tap para abrir entrada
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
                    JournalService.moodEmojis[entry.mood] ?? '📝',
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
                            color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          JournalService.moodLabels[entry.mood] ?? 'Entrada',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: AppTheme.successColor),
                          const SizedBox(width: 4),
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
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
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
                        color: (isDark ? AppTheme.darkPrimary : AppTheme.primaryColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        trigger,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppTheme.darkPrimary : AppTheme.primaryColor,
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppTheme.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
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
                      width: 40,
                      height: 4,
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
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Porcentaje de victorias
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Text('🏆', style: TextStyle(fontSize: 40)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${victoryPercentage.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.successColor,
                                ),
                              ),
                              Text(
                                'Días de Victoria',
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Triggers más comunes
                  if (triggerStats.isNotEmpty) ...[
                    Text(
                      '⚠️ Triggers más comunes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...triggerStats.entries.take(5).map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.key,
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.emergencyColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${e.value}x',
                                style: TextStyle(
                                  color: AppTheme.emergencyColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Estados de ánimo
                  Text(
                    '😊 Estados de Ánimo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: moodStats.entries.map((e) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: (isDark ? AppTheme.darkSurface : Colors.grey.shade100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              JournalService.moodEmojis[e.key] ?? '📝',
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${e.value}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
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

/// Editor para crear/editar entradas del diario
class JournalEntryEditor extends StatefulWidget {
  final Function(JournalEntry) onSave;
  final JournalEntry? existingEntry;
  final String? initialPrompt;

  const JournalEntryEditor({
    super.key,
    required this.onSave,
    this.existingEntry,
    this.initialPrompt,
  });

  @override
  State<JournalEntryEditor> createState() => _JournalEntryEditorState();
}

class _JournalEntryEditorState extends State<JournalEntryEditor> {
  final TextEditingController _contentController = TextEditingController();
  String _selectedMood = 'neutral';
  bool _hadVictory = true;
  final List<String> _selectedTriggers = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingEntry != null) {
      _contentController.text = widget.existingEntry!.content;
      _selectedMood = widget.existingEntry!.mood;
      _hadVictory = widget.existingEntry!.hadVictory;
      _selectedTriggers.addAll(widget.existingEntry!.triggers);
    } else if (widget.initialPrompt != null) {
      // Prellenar con el prompt personalizado
      _contentController.text = '${widget.initialPrompt}\n\n';
      // Posicionar cursor al final
      _contentController.selection = TextSelection.fromPosition(
        TextPosition(offset: _contentController.text.length),
      );
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingEntry != null ? 'Editar Entrada' : 'Nueva Entrada'),
        actions: [
          TextButton(
            onPressed: _saveEntry,
            child: const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ¿Cómo te sientes?
            Text(
              '¿Cómo te sientes hoy?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: JournalService.moodEmojis.entries.map((e) {
                final isSelected = _selectedMood == e.key;
                return GestureDetector(
                  onTap: () {
                    FeedbackEngine.I.select(); // Seleccionar mood
                    setState(() => _selectedMood = e.key);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor).withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? (isDark ? AppTheme.darkAccent : AppTheme.accentColor)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(e.value, style: const TextStyle(fontSize: 32)),
                        const SizedBox(height: 4),
                        Text(
                          JournalService.moodLabels[e.key] ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // ¿Tuviste victoria?
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    _hadVictory ? Icons.emoji_events : Icons.refresh,
                    color: _hadVictory ? AppTheme.successColor : AppTheme.emergencyColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '¿Fue un día de victoria?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _hadVictory,
                    onChanged: (value) => setState(() => _hadVictory = value),
                    activeThumbColor: AppTheme.successColor,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Triggers
            Text(
              '¿Qué situaciones enfrentaste? (opcional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: JournalService.commonTriggers.map((trigger) {
                final isSelected = _selectedTriggers.contains(trigger);
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedTriggers.remove(trigger);
                      } else {
                        _selectedTriggers.add(trigger);
                      }
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.emergencyColor.withOpacity(0.1)
                          : (isDark ? AppTheme.darkSurface : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.emergencyColor : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      trigger,
                      style: TextStyle(
                        color: isSelected
                            ? AppTheme.emergencyColor
                            : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 24),
            
            // Contenido
            Text(
              'Escribe tu reflexión',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: TextField(
                controller: _contentController,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '¿Cómo fue tu día? ¿Qué aprendiste? ¿Cómo te sientes?',
                  hintStyle: TextStyle(
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _saveEntry() {
    if (_contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe algo antes de guardar')),
      );
      return;
    }

    FeedbackEngine.I.confirm(); // Guardar entrada (acción principal)

    final entry = JournalEntry(
      id: widget.existingEntry?.id ?? JournalService().generateId(),
      date: widget.existingEntry?.date ?? DateTime.now(),
      content: _contentController.text.trim(),
      mood: _selectedMood,
      triggers: _selectedTriggers,
      hadVictory: _hadVictory,
    );

    widget.onSave(entry);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entrada guardada ✓'),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }
}

/// Pantalla de detalle de una entrada
class JournalEntryDetail extends StatelessWidget {
  final JournalEntry entry;
  final VoidCallback onDelete;

  const JournalEntryDetail({
    super.key,
    required this.entry,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  JournalService.moodEmojis[entry.mood] ?? '📝',
                  style: const TextStyle(fontSize: 40),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatFullDate(entry.date),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        JournalService.moodLabels[entry.mood] ?? '',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.hadVictory)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.emoji_events, color: AppTheme.successColor),
                  ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Triggers
            if (entry.triggers.isNotEmpty) ...[
              Text(
                'Situaciones enfrentadas',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: entry.triggers.map((trigger) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.emergencyColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      trigger,
                      style: TextStyle(
                        color: AppTheme.emergencyColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
            
            // Contenido
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Text(
                entry.content,
                style: TextStyle(
                  fontSize: 16,
                  height: 1.7,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar entrada?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: onDelete,
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergencyColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    final months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'
    ];
    final weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    
    return '${weekdays[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
  }
}
