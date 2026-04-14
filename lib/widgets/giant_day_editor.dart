/// ═══════════════════════════════════════════════════════════════════════════
/// GIANT DAY EDITOR - Editor de Victoria por Gigante
/// Diseño amigable y cálido
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/victory_scoring_service.dart';
import '../services/feedback_engine.dart';
import '../models/content_enums.dart';

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

  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textMuted = Color(0xFF8A8A9A);
  static const Color _victory = Color(0xFF66BB6A);
  static const Color _warmBg = Color(0xFF1A1520);

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
    try {
      final giant = GiantId.values.firstWhere(
        (g) => g.id == giantId || g.name == giantId,
        orElse: () => GiantId.digital,
      );
      return giant.displayName;
    } catch (e) {
      debugPrint('🎯 [GIANT] _giantName($giantId): $e');
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
    } catch (e) {
      debugPrint('🎯 [GIANT] _giantEmoji($giantId): $e');
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
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _warmBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),

          if (_canEdit) ...[
            _buildGeneralControl(),
            const SizedBox(height: 16),
            Text(
              'Detalle por área',
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _textMuted,
              ),
            ),
            const SizedBox(height: 10),
            ..._giantStates.entries.map((entry) =>
              _buildGiantToggle(entry.key, entry.value)
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔮', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Text(
                    'Día futuro',
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      color: _textMuted,
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
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _isVictoryDay
                ? _victory.withOpacity(0.15)
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              _isVictoryDay ? '🏆' : '📅',
              style: const TextStyle(fontSize: 20),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formattedDate,
                style: GoogleFonts.manrope(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              Text(
                'Progreso del día',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  color: _textMuted.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        // Score badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _isVictoryDay
                ? _victory.withOpacity(0.15)
                : Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _isVictoryDay
                  ? _victory.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: Text(
            '$_victoriesCount/$_totalGiants',
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _isVictoryDay ? _victory : _textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralControl() {
    return Row(
      children: [
        Expanded(
          child: _buildBulkButton(
            emoji: '✅',
            label: 'Todo Victoria',
            color: _victory,
            onTap: () => _setAllGiants(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildBulkButton(
            emoji: '🕊️',
            label: 'Todo Gracia',
            color: _textMuted,
            onTap: () => _setAllGiants(0),
          ),
        ),
      ],
    );
  }

  Widget _buildBulkButton({
    required String emoji,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.20)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.manrope(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isVictory
              ? _victory.withOpacity(0.08)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isVictory
                ? _victory.withOpacity(0.25)
                : Colors.white.withOpacity(0.06),
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textPrimary.withOpacity(0.9),
                ),
              ),
            ),
            // Toggle buttons
            _buildMiniToggle(
              emoji: '🕊️',
              isSelected: !isVictory,
              color: _textMuted,
              onTap: () => _setGiantState(giantId, 0),
            ),
            const SizedBox(width: 8),
            _buildMiniToggle(
              emoji: '✅',
              isSelected: isVictory,
              color: _victory,
              onTap: () => _setGiantState(giantId, 1),
            ),
          ],
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(
              fontSize: isSelected ? 18 : 14,
            ),
          ),
        ),
      ),
    );
  }
}
