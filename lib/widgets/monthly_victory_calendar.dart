/// ═══════════════════════════════════════════════════════════════════════════
/// MONTHLY VICTORY CALENDAR - Calendario Mensual de Victorias
/// Diseño amigable y cálido · fácil de leer
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/feedback_engine.dart';

class MonthlyVictoryCalendar extends StatelessWidget {
  final DateTime visibleMonth;
  final Set<String> victoryDaysISO;
  final DateTime selectedDate;
  final Function(DateTime) onSelectDay;
  final Function(DateTime) onMonthChanged;
  final Set<String> journalDaysISO;
  final Set<String> bibleDaysISO;
  final Set<String> planDaysISO;

  static const Color _gold = Color(0xFFD4A853);
  static const Color _textPrimary = Color(0xFFF0F0F0);
  static const Color _textMuted = Color(0xFF8A8A9A);
  static const Color _victory = Color(0xFF66BB6A);
  static const Color _warmBg = Color(0xFF1A1520);
  static const Color _journal = Color(0xFFCE93D8);
  static const Color _bible = Color(0xFFE8C97A);
  static const Color _plan = Color(0xFF64B5F6);

  const MonthlyVictoryCalendar({
    super.key,
    required this.visibleMonth,
    required this.victoryDaysISO,
    required this.selectedDate,
    required this.onSelectDay,
    required this.onMonthChanged,
    this.journalDaysISO = const {},
    this.bibleDaysISO = const {},
    this.planDaysISO = const {},
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildMonthHeader(),
          const SizedBox(height: 16),
          _buildWeekDaysRow(),
          const SizedBox(height: 8),
          _buildDaysGrid(),
          const SizedBox(height: 14),
          _buildLegend(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildMonthHeader() {
    const monthNames = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildNavButton(
          icon: Icons.chevron_left_rounded,
          onTap: () {
            FeedbackEngine.I.tabChange();
            onMonthChanged(DateTime(visibleMonth.year, visibleMonth.month - 1, 1));
          },
        ),
        Text(
          '${monthNames[visibleMonth.month]} ${visibleMonth.year}',
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _textPrimary,
          ),
        ),
        _buildNavButton(
          icon: Icons.chevron_right_rounded,
          onTap: () {
            FeedbackEngine.I.tabChange();
            onMonthChanged(DateTime(visibleMonth.year, visibleMonth.month + 1, 1));
          },
        ),
      ],
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _textPrimary.withOpacity(0.7), size: 24),
      ),
    );
  }

  Widget _buildWeekDaysRow() {
    const weekDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: weekDays.map((day) => SizedBox(
        width: 40,
        child: Text(
          day,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: _textMuted.withOpacity(0.5),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildDaysGrid() {
    final days = _generateDaysForMonth();

    return Column(
      children: List.generate(
        (days.length / 7).ceil(),
        (weekIndex) {
          final startIndex = weekIndex * 7;
          final weekDays = days.sublist(
            startIndex,
            (startIndex + 7).clamp(0, days.length),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: weekDays.map((dayInfo) =>
                _buildDayTile(dayInfo)
              ).toList(),
            ),
          );
        },
      ),
    );
  }

  List<_DayInfo> _generateDaysForMonth() {
    final days = <_DayInfo>[];

    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final lastOfMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);
    int firstWeekday = firstOfMonth.weekday;

    // Días del mes anterior
    final prevMonth = DateTime(visibleMonth.year, visibleMonth.month, 0);
    for (int i = firstWeekday - 1; i > 0; i--) {
      final day = prevMonth.day - i + 1;
      days.add(_DayInfo(
        day: day,
        date: DateTime(prevMonth.year, prevMonth.month, day),
        isCurrentMonth: false, isToday: false, isSelected: false,
        isVictory: false, isFuture: false,
      ));
    }

    // Días del mes actual
    final today = DateTime.now();
    for (int day = 1; day <= lastOfMonth.day; day++) {
      final date = DateTime(visibleMonth.year, visibleMonth.month, day);
      final dateStr = _dateToString(date);
      final isToday = date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;
      final isSelected = date.year == selectedDate.year &&
                         date.month == selectedDate.month &&
                         date.day == selectedDate.day;
      final isFuture = date.isAfter(today);
      final isVictory = victoryDaysISO.contains(dateStr);
      final hasJournal = journalDaysISO.contains(dateStr);
      final hasBible = bibleDaysISO.contains(dateStr);
      final hasPlan = planDaysISO.contains(dateStr);

      days.add(_DayInfo(
        day: day, date: date, isCurrentMonth: true,
        isToday: isToday, isSelected: isSelected,
        isVictory: isVictory, isFuture: isFuture,
        hasJournal: hasJournal, hasBible: hasBible, hasPlan: hasPlan,
      ));
    }

    // Completar última semana
    int remainingDays = 7 - (days.length % 7);
    if (remainingDays < 7) {
      for (int i = 1; i <= remainingDays; i++) {
        days.add(_DayInfo(
          day: i,
          date: DateTime(visibleMonth.year, visibleMonth.month + 1, i),
          isCurrentMonth: false, isToday: false, isSelected: false,
          isVictory: false, isFuture: true,
        ));
      }
    }

    return days;
  }

  Widget _buildDayTile(_DayInfo dayInfo) {
    // Colores
    Color bgColor = Colors.transparent;
    Color textColor = _textMuted.withOpacity(0.2);

    if (dayInfo.isCurrentMonth && !dayInfo.isFuture) {
      textColor = _textPrimary.withOpacity(0.85);
      bgColor = Colors.white.withOpacity(0.03);
    }

    if (dayInfo.isFuture && dayInfo.isCurrentMonth) {
      textColor = _textMuted.withOpacity(0.25);
      bgColor = Colors.transparent;
    }

    // Victoria: fondo verde sutil
    if (dayInfo.isVictory && dayInfo.isCurrentMonth) {
      bgColor = _victory.withOpacity(0.12);
    }

    Border? border;
    if (dayInfo.isSelected) {
      border = Border.all(color: _gold, width: 2);
      bgColor = _gold.withOpacity(0.18);
    } else if (dayInfo.isToday) {
      bgColor = _gold.withOpacity(0.12);
    }

    // Indicador de victoria: checkmark ✓
    Widget? indicator;
    if (dayInfo.isCurrentMonth && !dayInfo.isFuture && dayInfo.isVictory) {
      indicator = Icon(
        Icons.check_rounded,
        size: 12,
        color: _victory,
      );
    }

    return GestureDetector(
      onTap: dayInfo.isCurrentMonth ? () {
        FeedbackEngine.I.select();
        onSelectDay(dayInfo.date);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 46,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayInfo.day.toString(),
              style: GoogleFonts.manrope(
                fontSize: 14,
                fontWeight: dayInfo.isToday || dayInfo.isVictory ? FontWeight.w700 : FontWeight.w500,
                color: dayInfo.isVictory && dayInfo.isCurrentMonth ? _victory : textColor,
              ),
            ),
            if (indicator != null) ...[
              const SizedBox(height: 1),
              indicator,            ] else if (_hasOverlayDots(dayInfo)) ...[
              const SizedBox(height: 1),
              _buildOverlayDots(dayInfo),            ] else if (dayInfo.isToday && !dayInfo.isSelected) ...[  
              const SizedBox(height: 2),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: _gold,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasOverlayDots(_DayInfo d) =>
      d.isCurrentMonth && !d.isFuture && (d.hasJournal || d.hasBible || d.hasPlan);

  Widget _buildOverlayDots(_DayInfo d) {
    final dots = <Color>[];
    if (d.hasBible) dots.add(_bible);
    if (d.hasJournal) dots.add(_journal);
    if (d.hasPlan) dots.add(_plan);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: dots.take(3).map((c) => Container(
        width: 4, height: 4,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      )).toList(),
    );
  }

  Widget _buildLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: [
        _buildLegendItem(emoji: '✅', label: 'Victoria'),
        _buildLegendItem(emoji: '🕊️', label: 'Gracia'),
        if (journalDaysISO.isNotEmpty || bibleDaysISO.isNotEmpty || planDaysISO.isNotEmpty) ...[
          _buildDotLegend(color: _bible, label: 'Biblia'),
          _buildDotLegend(color: _journal, label: 'Diario'),
          _buildDotLegend(color: _plan, label: 'Plan'),
        ],
      ],
    );
  }

  Widget _buildDotLegend({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.manrope(fontSize: 11, color: _textMuted)),
      ],
    );
  }

  Widget _buildLegendItem({required String emoji, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.manrope(
            fontSize: 12,
            color: _textMuted.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _dateToString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _DayInfo {
  final int day;
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isVictory;
  final bool isFuture;
  final bool hasJournal;
  final bool hasBible;
  final bool hasPlan;

  _DayInfo({
    required this.day, required this.date, required this.isCurrentMonth,
    required this.isToday, required this.isSelected, required this.isVictory,
    required this.isFuture, this.hasJournal = false, this.hasBible = false,
    this.hasPlan = false,
  });
}
