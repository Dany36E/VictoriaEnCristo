// Estado de hoy del compañero: victoria vs. gracia, solo para SU fecha de hoy.
import 'package:app_quitar/models/battle_partner_data.dart';
import 'package:app_quitar/services/battle_partner_service.dart';
import 'package:app_quitar/services/victory_scoring_service.dart';
import 'package:app_quitar/widgets/battle_partner_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

BattlePartnerData _p(Map<String, dynamic> extra) =>
    BattlePartnerData.fromFirestore({
      'partnerUid': 'p1',
      'partnerName': 'Juan',
      'status': 'active',
      'streakDays': 5,
      ...extra,
    });

void main() {
  // 23 oct 2026 15:00 UTC.
  final ahora = DateTime.utc(2026, 10, 23, 15);
  // La inactividad (>48 h) se mide con el reloj real.
  final abierto = Timestamp.fromDate(
    DateTime.now().subtract(const Duration(hours: 1)),
  );

  test('gracia de hoy no se muestra como victoria', () {
    final p = _p({
      'dayState': 'grace',
      'dayKey': '2026-10-23',
      'utcOffsetMin': -360,
      'victoryToday': false,
      'lastOpenedAt': abierto,
    });
    expect(p.estadoHoy(ahora: ahora), EstadoHoyCompanero.gracia);
    expect(textoEstadoCompanero(p, ahora: ahora), 'Hoy registró gracia');
  });

  test('victoria de hoy', () {
    final p = _p({
      'dayState': 'victory',
      'dayKey': '2026-10-23',
      'utcOffsetMin': -360,
      'lastOpenedAt': abierto,
    });
    expect(p.estadoHoy(ahora: ahora), EstadoHoyCompanero.victoria);
    expect(textoEstadoCompanero(p, ahora: ahora), 'Victoria hoy · 5 días');
  });

  test('la victoria de ayer ya no cuenta como hoy', () {
    final p = _p({
      'dayState': 'victory',
      'dayKey': '2026-10-22',
      'utcOffsetMin': -360,
      'victoryToday': true,
      'lastOpenedAt': abierto,
    });
    expect(p.estadoHoy(ahora: ahora), EstadoHoyCompanero.sinRegistro);
    expect(textoEstadoCompanero(p, ahora: ahora), 'Sin registrar hoy');
  });

  test('usa la zona horaria del compañero, no la de quien mira', () {
    // En Madrid (UTC+2) ya es 24 de octubre a las 23:30 UTC del 23.
    final tarde = DateTime.utc(2026, 10, 23, 23, 30);
    final madrid = _p({
      'dayState': 'victory',
      'dayKey': '2026-10-24',
      'utcOffsetMin': 120,
    });
    expect(madrid.estadoHoy(ahora: tarde), EstadoHoyCompanero.victoria);
    final mexico = _p({
      'dayState': 'victory',
      'dayKey': '2026-10-23',
      'utcOffsetMin': -360,
    });
    expect(mexico.estadoHoy(ahora: tarde), EstadoHoyCompanero.victoria);
  });

  test('formato anterior: victoryToday solo cuenta si se publicó hoy', () {
    final hoy = _p({
      'victoryToday': true,
      'progressUpdatedAt': Timestamp.fromDate(DateTime.now()),
    });
    expect(hoy.estadoHoy(), EstadoHoyCompanero.victoria);
    final viejo = _p({
      'victoryToday': true,
      'progressUpdatedAt': Timestamp.fromDate(
        DateTime.now().subtract(const Duration(days: 2)),
      ),
    });
    expect(viejo.estadoHoy(), EstadoHoyCompanero.sinRegistro);
  });

  test('el reflejo publicado separa victoria y gracia con la fecha', () {
    const dia = DiaPublicado(
      estado: EstadoDia.gracia,
      clave: '2026-10-23',
      utcOffsetMin: -360,
    );
    expect(dia.reflejo(streak: 4), {
      'streakDays': 4,
      'victoryToday': false,
      'dayState': 'grace',
      'dayKey': '2026-10-23',
      'utcOffsetMin': -360,
    });
  });

  test('liberar borra todos los campos de progreso reflejados', () {
    expect(
      kPartnerMirrorFields,
      containsAll([
        'streakDays',
        'victoryToday',
        'dayState',
        'dayKey',
        'lastOpenedAt',
        'shieldOn',
      ]),
    );
  });

  test('liberar a tu guardián exige resolver el candado (sin respaldo local)', () {
    expect(
      resultadoPorErrorDeLiberar('failed-precondition', {'motivo': 'guardian_lock'}),
      ResultadoLiberar.requiereCandado,
    );
    expect(
      resultadoPorErrorDeLiberar('permission-denied', {'motivo': 'pin'}),
      ResultadoLiberar.pinIncorrecto,
    );
    expect(resultadoPorErrorDeLiberar('not-found', null), isNull);
  });
}
