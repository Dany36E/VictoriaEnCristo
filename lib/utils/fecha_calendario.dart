/// ═══════════════════════════════════════════════════════════════════════════
/// FECHA CALENDARIO — aritmética de días por calendario, no por horas.
///
/// `fecha.subtract(Duration(days: 1))` resta 24 horas. El día del cambio de
/// horario dura 23 o 25 horas, así que restar 24 h a la medianoche local cae
/// en el día equivocado (y `difference().inDays` da 0 entre dos medianoches
/// consecutivas).
/// Aquí todo se hace con fechas UTC "solo fecha"
/// (`DateTime.utc(a, m, d)`), que no tienen horario de verano; los llamadores
/// solo leen año, mes y día.
/// ═══════════════════════════════════════════════════════════════════════════
library;

class FechaCalendario {
  FechaCalendario._();

  /// Fecha (año, mes, día) de [fecha] como UTC a medianoche.
  static DateTime soloFecha(DateTime fecha) =>
      DateTime.utc(fecha.year, fecha.month, fecha.day);

  /// [fecha] más [dias] días de calendario (pueden ser negativos).
  static DateTime sumarDias(DateTime fecha, int dias) =>
      DateTime.utc(fecha.year, fecha.month, fecha.day + dias);

  /// El día de calendario anterior a [fecha].
  static DateTime diaAnterior(DateTime fecha) => sumarDias(fecha, -1);

  /// Días de calendario de [desde] a [hasta] (positivo si [hasta] es después).
  static int diasEntre(DateTime desde, DateTime hasta) =>
      soloFecha(hasta).difference(soloFecha(desde)).inDays;

  /// Clave "AAAA-MM-DD" de [fecha] (la misma que usa `TimeUtils.dateToISO`).
  static String clave(DateTime fecha) =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';

  /// Lee una clave "AAAA-MM-DD" como fecha UTC; `null` si no es válida.
  static DateTime? desdeClave(String clave) {
    final partes = clave.split('-');
    if (partes.length != 3) return null;
    final a = int.tryParse(partes[0]);
    final m = int.tryParse(partes[1]);
    final d = int.tryParse(partes[2]);
    if (a == null || m == null || d == null) return null;
    final fecha = DateTime.utc(a, m, d);
    if (fecha.year != a || fecha.month != m || fecha.day != d) return null;
    return fecha;
  }

  /// Racha de días consecutivos que terminan hoy o ayer.
  ///
  /// Si [hoy] no cuenta como victoria, la racha puede seguir viva desde
  /// ayer (todavía no se registra el día). Recorre hacia atrás por calendario.
  static int rachaActual({
    required DateTime hoy,
    required bool Function(DateTime dia) esVictoria,
    int limite = 100000,
  }) {
    var dia = soloFecha(hoy);
    if (!esVictoria(dia)) {
      dia = diaAnterior(dia);
      if (!esVictoria(dia)) return 0;
    }
    var racha = 0;
    while (racha < limite && esVictoria(dia)) {
      racha++;
      dia = diaAnterior(dia);
    }
    return racha;
  }

  /// La racha más larga de días consecutivos dentro de [dias].
  static int mejorRacha(Iterable<DateTime> dias) {
    final unicos = <String, DateTime>{
      for (final d in dias) clave(d): soloFecha(d),
    }.values.toList()..sort();
    if (unicos.isEmpty) return 0;
    var mejor = 1;
    var actual = 1;
    for (var i = 1; i < unicos.length; i++) {
      if (diasEntre(unicos[i - 1], unicos[i]) == 1) {
        actual++;
        if (actual > mejor) mejor = actual;
      } else {
        actual = 1;
      }
    }
    return mejor;
  }
}
