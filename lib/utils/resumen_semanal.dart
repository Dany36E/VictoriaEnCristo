/// ═══════════════════════════════════════════════════════════════════════════
/// RESUMEN SEMANAL — texto que recibe el compañero (opcional).
///
/// El mismo texto lo arma la Cloud Function `enviarResumenSemanal`
/// (functions/src/rendicionCuentas.ts, `construirTextoResumen`). Si cambias
/// una frase aquí, cámbiala allá: las pruebas de ambos lados usan el mismo
/// ejemplo y fallan si se separan.
/// ═══════════════════════════════════════════════════════════════════════════
library;

/// Qué decidió compartir el usuario en su resumen semanal.
class CompartirResumen {
  /// Cuántos días de la semana registró.
  final bool registro;

  /// Cuántos fueron victoria y cuántos gracia.
  final bool victoriaGracia;

  /// Su racha actual.
  final bool racha;

  /// Estado del Escudo de Pureza y bloqueos de la semana.
  final bool escudo;

  const CompartirResumen({
    this.registro = true,
    this.victoriaGracia = true,
    this.racha = true,
    this.escudo = true,
  });

  CompartirResumen copyWith({
    bool? registro,
    bool? victoriaGracia,
    bool? racha,
    bool? escudo,
  }) => CompartirResumen(
    registro: registro ?? this.registro,
    victoriaGracia: victoriaGracia ?? this.victoriaGracia,
    racha: racha ?? this.racha,
    escudo: escudo ?? this.escudo,
  );

  Map<String, bool> toMap() => {
    'registro': registro,
    'victoriaGracia': victoriaGracia,
    'racha': racha,
    'escudo': escudo,
  };

  factory CompartirResumen.fromMap(Map<String, dynamic>? m) => CompartirResumen(
    registro: m?['registro'] as bool? ?? true,
    victoriaGracia: m?['victoriaGracia'] as bool? ?? true,
    racha: m?['racha'] as bool? ?? true,
    escudo: m?['escudo'] as bool? ?? true,
  );
}

/// Datos de la semana (lunes a domingo) de quien comparte.
class DatosResumenSemanal {
  final int diasRegistrados;
  final int victorias;
  final int gracias;

  /// `null` si no se conoce.
  final int? racha;

  /// `null` si no usa el Escudo (iOS o nunca lo activó).
  final bool? escudoActivo;

  /// Sitios bloqueados por el Escudo en la semana; `null` si no hay dato.
  final int? bloqueos;

  const DatosResumenSemanal({
    required this.diasRegistrados,
    required this.victorias,
    required this.gracias,
    this.racha,
    this.escudoActivo,
    this.bloqueos,
  });
}

String _plural(int n, String uno, String varios) => n == 1 ? uno : varios;

/// Texto del resumen. Solo incluye lo que [compartir] permite.
String textoResumenSemanal({
  required String nombre,
  required DatosResumenSemanal datos,
  required CompartirResumen compartir,
}) {
  final lineas = <String>['Resumen semanal de $nombre'];
  if (compartir.registro) {
    lineas.add('• Registró ${datos.diasRegistrados} de 7 días.');
  }
  if (compartir.victoriaGracia) {
    lineas.add(
      '• ${datos.victorias} ${_plural(datos.victorias, 'día', 'días')} '
      'de victoria y ${datos.gracias} de gracia.',
    );
  }
  final racha = datos.racha;
  if (compartir.racha && racha != null) {
    lineas.add('• Racha actual: $racha ${_plural(racha, 'día', 'días')}.');
  }
  final escudo = datos.escudoActivo;
  if (compartir.escudo && escudo != null) {
    final bloqueos = datos.bloqueos;
    final detalle = bloqueos == null
        ? ''
        : ' · $bloqueos ${_plural(bloqueos, 'bloqueo', 'bloqueos')} '
              'esta semana';
    lineas.add('• Escudo de Pureza: ${escudo ? 'activo' : 'apagado'}$detalle.');
  }
  if (lineas.length == 1) {
    lineas.add('• Sigue en la batalla esta semana.');
  }
  lineas.add('Ora por $nombre y anímale esta semana.');
  return lineas.join('\n');
}
