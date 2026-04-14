import 'package:flutter/material.dart';
import '../services/journal_service.dart';
import '../services/feedback_engine.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';

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
    final t = AppThemeData.of(context);
    
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
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: JournalService.moodEmojis.entries.map((e) {
                final isSelected = _selectedMood == e.key;
                return GestureDetector(
                  onTap: () {
                    FeedbackEngine.I.select();
                    setState(() => _selectedMood = e.key);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? t.accent.withOpacity(0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? t.accent
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
                            color: t.textSecondary,
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
                color: t.cardBg,
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
                        color: t.textPrimary,
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
                color: t.textPrimary,
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
                          : t.surface,
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
                            : t.textSecondary,
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
                color: t.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: t.cardBg,
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
                    color: t.textSecondary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: TextStyle(
                  color: t.textPrimary,
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

    FeedbackEngine.I.confirm();

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
