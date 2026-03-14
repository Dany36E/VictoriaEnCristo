/// ═══════════════════════════════════════════════════════════════════════════
/// MONTHLY VICTORY CALENDAR - Calendario Mensual de Victorias
/// Muestra días de victoria (⭐) y gracia (✝️) en un calendario navegable
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/feedback_engine.dart';

/// Calendario mensual que muestra días de victoria y gracia
class MonthlyVictoryCalendar extends StatelessWidget {
  final DateTime visibleMonth;
  final Set<String> victoryDaysISO;
  final DateTime selectedDate;
  final Function(DateTime) onSelectDay;
  final Function(DateTime) onMonthChanged;
  final bool useLightTheme;
  
  // Design constants - Dark theme
  static const Color _midnight = Color(0xFF0A0A12);
  static const Color _midnightLight = Color(0xFF121225);
  static const Color _gold = Color(0xFFD4AF37);
  static const Color _goldLight = Color(0xFFE8C872);
  static const Color _pearlGray = Color(0xFF9E9E9E);
  static const Color _cardBg = Color(0xFF1A1A2E);
  
  // Design constants - Light theme
  static const Color _lightBg = Color(0xFFFFFFFF);
  static const Color _lightSurface = Color(0xFFF6F7FB);
  static const Color _lightText = Color(0xFF0A0A12);
  static const Color _lightBorder = Color(0xFFE5E7EB);
  static const Color _victory = Color(0xFF27AE60);
  
  const MonthlyVictoryCalendar({
    super.key,
    required this.visibleMonth,
    required this.victoryDaysISO,
    required this.selectedDate,
    required this.onSelectDay,
    required this.onMonthChanged,
    this.useLightTheme = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: useLightTheme 
          ? null 
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_midnightLight, _midnight],
            ),
        color: useLightTheme ? _lightBg : null,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: useLightTheme ? _lightBorder : _gold.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: useLightTheme 
              ? Colors.black.withOpacity(0.05)
              : Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header con navegación de mes
          _buildMonthHeader(),
          const SizedBox(height: 16),
          
          // Días de la semana
          _buildWeekDaysRow(),
          const SizedBox(height: 8),
          
          // Grid de días
          _buildDaysGrid(),
          const SizedBox(height: 16),
          
          // Leyenda
          _buildLegend(),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
  }
  
  Widget _buildMonthHeader() {
    final monthNames = [
      '', 'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Botón mes anterior
        _buildNavButton(
          icon: Icons.chevron_left_rounded,
          onTap: () {
            FeedbackEngine.I.tabChange();
            onMonthChanged(DateTime(visibleMonth.year, visibleMonth.month - 1, 1));
          },
        ),
        
        // Título del mes
        useLightTheme 
          ? Text(
              '${monthNames[visibleMonth.month]} ${visibleMonth.year}',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _lightText,
                letterSpacing: 1.0,
              ),
            )
          : ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [_gold, _goldLight],
              ).createShader(bounds),
              child: Text(
                '${monthNames[visibleMonth.month]} ${visibleMonth.year}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        
        // Botón mes siguiente
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: useLightTheme ? _lightSurface : _cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: useLightTheme ? _lightBorder : _gold.withOpacity(0.3),
          ),
        ),
        child: Icon(
          icon,
          color: useLightTheme ? _lightText : _gold,
          size: 24,
        ),
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
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: useLightTheme 
              ? _lightText.withOpacity(0.6)
              : _pearlGray.withOpacity(0.8),
            letterSpacing: 0.5,
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
    
    // Primer día del mes
    final firstOfMonth = DateTime(visibleMonth.year, visibleMonth.month, 1);
    // Último día del mes
    final lastOfMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);
    
    // Día de la semana del primer día (1 = Lunes, 7 = Domingo)
    int firstWeekday = firstOfMonth.weekday;
    
    // Agregar días del mes anterior
    final prevMonth = DateTime(visibleMonth.year, visibleMonth.month, 0);
    for (int i = firstWeekday - 1; i > 0; i--) {
      final day = prevMonth.day - i + 1;
      days.add(_DayInfo(
        day: day,
        date: DateTime(prevMonth.year, prevMonth.month, day),
        isCurrentMonth: false,
        isToday: false,
        isSelected: false,
        isVictory: false,
        isFuture: false,
      ));
    }
    
    // Agregar días del mes actual
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
      
      days.add(_DayInfo(
        day: day,
        date: date,
        isCurrentMonth: true,
        isToday: isToday,
        isSelected: isSelected,
        isVictory: isVictory,
        isFuture: isFuture,
      ));
    }
    
    // Agregar días del mes siguiente para completar la última semana
    int remainingDays = 7 - (days.length % 7);
    if (remainingDays < 7) {
      for (int i = 1; i <= remainingDays; i++) {
        days.add(_DayInfo(
          day: i,
          date: DateTime(visibleMonth.year, visibleMonth.month + 1, i),
          isCurrentMonth: false,
          isToday: false,
          isSelected: false,
          isVictory: false,
          isFuture: true,
        ));
      }
    }
    
    return days;
  }
  
  Widget _buildDayTile(_DayInfo dayInfo) {
    // Determinar el icono a mostrar
    Widget? iconWidget;
    
    if (dayInfo.isCurrentMonth && !dayInfo.isFuture) {
      if (dayInfo.isVictory) {
        // Victoria: estrella dorada
        iconWidget = const Text(
          '⭐',
          style: TextStyle(fontSize: 14),
        );
      } else {
        // Gracia: cruz sutil (no agresiva)
        iconWidget = Text(
          '✝️',
          style: TextStyle(
            fontSize: 12,
            color: useLightTheme 
              ? _lightText.withOpacity(0.4)
              : _pearlGray.withOpacity(0.6),
          ),
        );
      }
    }
    
    // Colores basados en estado y tema
    Color bgColor = Colors.transparent;
    Color textColor = useLightTheme 
      ? _lightText.withOpacity(0.3)
      : _pearlGray.withOpacity(0.4);
    Border? border;
    
    if (dayInfo.isCurrentMonth) {
      textColor = useLightTheme 
        ? _lightText.withOpacity(0.9)
        : Colors.white.withOpacity(0.9);
      bgColor = useLightTheme 
        ? _lightSurface.withOpacity(0.7)
        : _cardBg.withOpacity(0.5);
      
      if (dayInfo.isToday) {
        bgColor = useLightTheme 
          ? _victory.withOpacity(0.1)
          : _gold.withOpacity(0.15);
      }
      
      if (dayInfo.isSelected) {
        border = Border.all(
          color: useLightTheme ? _victory : _gold,
          width: 2,
        );
        bgColor = useLightTheme 
          ? _victory.withOpacity(0.15)
          : _gold.withOpacity(0.2);
      }
      
      if (dayInfo.isFuture) {
        textColor = useLightTheme 
          ? _lightText.withOpacity(0.25)
          : _pearlGray.withOpacity(0.3);
        bgColor = Colors.transparent;
      }
    }
    
    return GestureDetector(
      onTap: dayInfo.isCurrentMonth ? () {
        FeedbackEngine.I.select();
        onSelectDay(dayInfo.date);
      } : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 40,
        height: 48,
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
              style: TextStyle(
                fontSize: 14,
                fontWeight: dayInfo.isToday ? FontWeight.bold : FontWeight.w500,
                color: textColor,
              ),
            ),
            if (iconWidget != null) ...[
              const SizedBox(height: 2),
              iconWidget,
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Victoria
        _buildLegendItem('⭐', 'Victoria', useLightTheme ? _victory : _gold),
        const SizedBox(width: 24),
        // Gracia
        _buildLegendItem('✝️', 'Gracia', useLightTheme 
          ? _lightText.withOpacity(0.5)
          : _pearlGray.withOpacity(0.6)),
      ],
    );
  }
  
  Widget _buildLegendItem(String icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          icon,
          style: const TextStyle(fontSize: 14),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: useLightTheme 
              ? _lightText.withOpacity(0.6)
              : _pearlGray.withOpacity(0.7),
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

/// Información de un día para el calendario
class _DayInfo {
  final int day;
  final DateTime date;
  final bool isCurrentMonth;
  final bool isToday;
  final bool isSelected;
  final bool isVictory;
  final bool isFuture;
  
  _DayInfo({
    required this.day,
    required this.date,
    required this.isCurrentMonth,
    required this.isToday,
    required this.isSelected,
    required this.isVictory,
    required this.isFuture,
  });
}
