/// ═══════════════════════════════════════════════════════════════════════════
/// TIME UTILS - Utilidades centralizadas de fecha / hora
/// Reemplaza los múltiples `_dateToISO()` duplicados en el codebase
/// ═══════════════════════════════════════════════════════════════════════════
library;

class TimeUtils {
  TimeUtils._();

  /// Fecha actual como ISO string "YYYY-MM-DD"
  static String todayISO() => dateToISO(DateTime.now());

  /// Convierte cualquier DateTime a ISO date string "YYYY-MM-DD"
  static String dateToISO(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// DateTime del inicio de hoy (00:00:00)
  static DateTime todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// ¿Dos fechas son el mismo día?
  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// ¿La fecha es posterior a hoy (sin considerar hora)?
  static bool isFuture(DateTime date) {
    final today = todayStart();
    final dateStart = DateTime(date.year, date.month, date.day);
    return dateStart.isAfter(today);
  }

  /// Parse ISO string "YYYY-MM-DD" a DateTime (null-safe)
  static DateTime? parseISO(String iso) {
    try {
      final parts = iso.split('-');
      if (parts.length != 3) return null;
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (e) {
      return null;
    }
  }
}
