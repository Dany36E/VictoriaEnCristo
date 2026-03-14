/// ═══════════════════════════════════════════════════════════════════════════
/// GIANT DAY EDITOR - Editor de Victoria por Gigante
/// Permite editar el estado de cada gigante para un día específico
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import '../services/victory_scoring_service.dart';
import '../services/feedback_engine.dart';
import '../models/content_enums.dart';

/// Editor completo para un día con control general y por gigante
class GiantDayEditor extends StatefulWidget {
  final DateTime date;
  final VoidCallback onChanged;
  
  const GiantDayEditor({
    super.key,
    required this.date,
    required this.onChanged,
  });

  @override
  State<GiantDayEditor> createState() => _GiantDayEditorState();
}

class _GiantDayEditorState extends State<GiantDayEditor> {
  Map<String, int> _giantStates = {};
  bool _isLoading = true;
  
  // Design constants
  static const Color _cardBg = Color(0xFFFFFFFF);
  static const Color _textDark = Color(0xFF0A0A12);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _victory = Color(0xFF27AE60);
  static const Color _victoryBg = Color(0xFFE8F5E9);
  static const Color _grace = Color(0xFF6B7280);
  static const Color _graceBg = Color(0xFFF3F4F6);
  static const Color _border = Color(0xFFE5E7EB);
  
  @override
  void initState() {
    super.initState();
    _loadGiantStates();
  }
  
  @override
  void didUpdateWidget(GiantDayEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date) {
      _loadGiantStates();
    }
  }
  
  void _loadGiantStates() {
    setState(() {
      _giantStates = VictoryScoringService.I.getDayGiantStates(widget.date);
      _isLoading = false;
    });
  }
  
  /// Formatea la fecha
  String get _formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(widget.date.year, widget.date.month, widget.date.day);
    
    if (selected == today) return 'Hoy';
    if (selected == today.subtract(const Duration(days: 1))) return 'Ayer';
    
    final weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final months = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return '${weekdays[widget.date.weekday - 1]} ${widget.date.day} ${months[widget.date.month - 1]}';
  }
  
  bool get _canEdit {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(widget.date.year, widget.date.month, widget.date.day);
    return !selected.isAfter(today);
  }
  
  int get _victoriesCount => _giantStates.values.where((v) => v == 1).length;
  int get _totalGiants => _giantStates.length;
  int get _requiredVictories => VictoryScoringService.I.getRequiredVictories();
  bool get _isVictoryDay => _victoriesCount >= _requiredVictories;
  
  Future<void> _setAllGiants(int value) async {
    FeedbackEngine.I.confirm();
    
    await VictoryScoringService.I.setDayAllGiants(widget.date, value);
    
    setState(() {
      _giantStates = VictoryScoringService.I.getDayGiantStates(widget.date);
    });
    
    widget.onChanged();
  }
  
  Future<void> _setGiantState(String giantId, int value) async {
    FeedbackEngine.I.tap();
    
    await VictoryScoringService.I.setDayGiantState(widget.date, giantId, value);
    
    setState(() {
      _giantStates[giantId] = value;
    });
    
    widget.onChanged();
  }
  
  String _getGiantDisplayName(String giantId) {
    // Intentar obtener el nombre del enum
    try {
      final giant = GiantId.values.firstWhere(
        (g) => g.id == giantId || g.name == giantId,
        orElse: () => GiantId.digital,
      );
      return giant.displayName;
    } catch (_) {
      // Fallback: capitalizar el ID
      return giantId.substring(0, 1).toUpperCase() + giantId.substring(1);
    }
  }
  
  String _getGiantEmoji(String giantId) {
    try {
      final giant = GiantId.values.firstWhere(
        (g) => g.id == giantId || g.name == giantId,
        orElse: () => GiantId.digital,
      );
      return giant.emoji;
    } catch (_) {
      return '🎯';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con fecha y score
          _buildHeader(),
          
          const SizedBox(height: 16),
          
          if (_canEdit) ...[
            // Control general: Todo ⭐ / Todo ✝️
            _buildGeneralControl(),
            
            const SizedBox(height: 16),
            
            // Divisor
            Divider(color: _border, height: 1),
            
            const SizedBox(height: 12),
            
            // Título de sección
            Text(
              'Detalle por área',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textDark.withOpacity(0.6),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Lista de gigantes
            ..._giantStates.entries.map((entry) => 
              _buildGiantToggle(entry.key, entry.value)
            ),
          ] else ...[
            // Día futuro
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _graceBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, color: _grace, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Día futuro - No editable',
                    style: TextStyle(
                      fontSize: 14,
                      color: _grace,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildHeader() {
    return Row(
      children: [
        // Ícono de fecha
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.calendar_today, color: _gold, size: 20),
        ),
        const SizedBox(width: 12),
        
        // Fecha y pregunta
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formattedDate,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _textDark,
                ),
              ),
              Text(
                _canEdit ? 'Progreso del día' : 'Día futuro',
                style: TextStyle(
                  fontSize: 13,
                  color: _textDark.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        
        // Score badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isVictoryDay ? _victoryBg : _graceBg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _isVictoryDay ? '⭐' : '✝️',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 6),
              Text(
                '$_victoriesCount/$_totalGiants',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _isVictoryDay ? _victory : _grace,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildGeneralControl() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            emoji: '⭐',
            label: 'Todo Victoria',
            color: _victory,
            bgColor: _victoryBg,
            onTap: () => _setAllGiants(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            emoji: '✝️',
            label: 'Todo Gracia',
            color: _grace,
            bgColor: _graceBg,
            onTap: () => _setAllGiants(0),
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required String emoji,
    required String label,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildGiantToggle(String giantId, int value) {
    final isVictory = value == 1;
    final name = _getGiantDisplayName(giantId);
    final emoji = _getGiantEmoji(giantId);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: isVictory ? _victoryBg.withOpacity(0.5) : _graceBg.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isVictory ? _victory.withOpacity(0.3) : _border,
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: Text(emoji, style: const TextStyle(fontSize: 22)),
          title: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _textDark,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botón Gracia
              _buildMiniToggle(
                emoji: '✝️',
                isSelected: !isVictory,
                color: _grace,
                onTap: () => _setGiantState(giantId, 0),
              ),
              const SizedBox(width: 8),
              // Botón Victoria
              _buildMiniToggle(
                emoji: '⭐',
                isSelected: isVictory,
                color: _victory,
                onTap: () => _setGiantState(giantId, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMiniToggle({
    required String emoji,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : _border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}
