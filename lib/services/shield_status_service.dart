/// ═══════════════════════════════════════════════════════════════════════════
/// ESTADO DEL ESCUDO — latido para avisar al compañero si el Escudo se apaga.
///
/// La app publica en `shieldStatus/{uid}` (solo el dueño escribe):
/// - si el usuario quiere el Escudo encendido y si la VPN está corriendo,
/// - un latido (`lastSeenAt`, hora del servidor) al abrir o volver a la app,
/// - el último apagado (por el usuario, permiso revocado o detenido por el
///   sistema) y el último encendido. Android los guarda aunque la app esté
///   cerrada y aquí se reportan la siguiente vez que la app se abre,
/// - bloqueos por día (solo cuentas, nunca sitios).
///
/// Una Cloud Function revisa cada hora a quienes activaron avisos y, si el
/// Escudo está apagado o sin señal por más de 24 h, avisa a los compañeros
/// elegidos (sin detalles). Ver functions/src/rendicionCuentas.ts.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'accountability_service.dart';
import 'battle_partner_service.dart';
import 'purity_guard_service.dart';

/// Motivos de cambio que entiende la Cloud Function.
class MotivoEscudo {
  MotivoEscudo._();
  static const encendido = 'on';
  static const apagadoPorUsuario = 'user_off';
  static const permisoRevocado = 'revoked';
  static const detenido = 'stopped';

  static const todos = {
    encendido,
    apagadoPorUsuario,
    permisoRevocado,
    detenido,
  };
}

/// Un apagado del Escudo: por qué y cuándo.
@immutable
class CambioEscudo {
  final String motivo;
  final DateTime momento;
  const CambioEscudo(this.motivo, this.momento);
}

/// Lo que Android guardó desde el último reporte (puede ser de cuando la app
/// estaba cerrada): último apagado y último encendido.
@immutable
class EventosNativosEscudo {
  final CambioEscudo? apagado;
  final DateTime? encendido;
  const EventosNativosEscudo({this.apagado, this.encendido});
}

/// Cambios a publicar: el último apagado y el último encendido.
@immutable
class CambiosEscudo {
  final CambioEscudo? apagado;
  final DateTime? encendido;
  const CambiosEscudo({this.apagado, this.encendido});
}

/// Decide qué cambios publicar con lo que se sabe ahora.
///
/// Se guardan por separado el último apagado y el último encendido para no
/// perder un apagado que ocurrió con la app cerrada aunque al abrirla el
/// Escudo vuelva a encenderse: el compañero se entera de que estuvo apagado.
@visibleForTesting
CambiosEscudo decidirCambiosEscudo({
  required bool deseado,
  required bool activo,
  required bool? ultimoActivoReportado,
  required EventosNativosEscudo? nativo,
  required DateTime ahora,
}) {
  var apagado = nativo?.apagado;
  var encendido = nativo?.encendido;
  if (!activo && apagado == null) {
    if (ultimoActivoReportado == true) {
      apagado = CambioEscudo(
        deseado ? MotivoEscudo.detenido : MotivoEscudo.apagadoPorUsuario,
        ahora,
      );
    } else if (ultimoActivoReportado == null && deseado) {
      // Primer reporte: lo quería encendido y no está corriendo.
      apagado = CambioEscudo(MotivoEscudo.detenido, ahora);
    }
  }
  if (activo) {
    final ultimoApagado = apagado?.momento;
    if ((encendido == null && ultimoActivoReportado != true) ||
        (ultimoApagado != null &&
            (encendido == null || encendido.isBefore(ultimoApagado)))) {
      encendido = ahora;
    }
  }
  return CambiosEscudo(apagado: apagado, encendido: encendido);
}

class ShieldStatusService with WidgetsBindingObserver {
  ShieldStatusService._();
  static final ShieldStatusService I = ShieldStatusService._();

  static const _prefUltimoActivo = 'shield.ultimoActivoReportado';

  bool _iniciado = false;
  Future<void>? _enCurso;
  bool _pendiente = false;

  /// Empieza a reportar: ahora, al volver a la app y en cada cambio del
  /// Escudo. Idempotente.
  void iniciar() {
    if (_iniciado || !PurityGuardService.I.isEngineSupported) return;
    _iniciado = true;
    WidgetsBinding.instance.addObserver(this);
    PurityGuardService.I.active.addListener(_alCambiar);
    unawaited(AccountabilityService.I.cargar().then((_) => reportar()));
  }

  void _alCambiar() => unawaited(reportar());

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(PurityGuardService.I.refresh().then((_) => reportar()));
    }
  }

  /// Publica el estado actual. Si ya hay un reporte en curso, se encadena
  /// uno más al terminar (no se pierden cambios seguidos).
  Future<void> reportar() {
    final actual = _enCurso;
    if (actual != null) {
      _pendiente = true;
      return actual;
    }
    final futuro = _reportar().whenComplete(() {
      _enCurso = null;
      if (_pendiente) {
        _pendiente = false;
        unawaited(reportar());
      }
    });
    _enCurso = futuro;
    return futuro;
  }

  Future<void> _reportar() async {
    final guard = PurityGuardService.I;
    if (!guard.isEngineSupported) return;
    String? uid;
    try {
      uid = FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return;
    }
    if (uid == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final deseado = await guard.isDesired();
      final activo = guard.active.value;
      final cambios = decidirCambiosEscudo(
        deseado: deseado,
        activo: activo,
        ultimoActivoReportado: prefs.getBool(_prefUltimoActivo),
        nativo: await guard.consumeShieldEvents(),
        ahora: DateTime.now(),
      );
      final apagado = cambios.apagado;
      final encendido = cambios.encendido;
      final bloqueos = await guard.blocksByDay();
      final rendicion = AccountabilityService.I;
      await rendicion.cargar();
      final avisos = rendicion.ajustes.value.avisosEscudo;
      // Si no se pudieron leer los ajustes, no se toca `alertsEnabled`
      // (no apagar los avisos del compañero por un fallo de red).
      final avisosConocidos = rendicion.cargadoParaUsuarioActual;

      final datos = <String, dynamic>{
        'enabledByUser': deseado,
        'vpnActive': activo,
        if (avisosConocidos) 'alertsEnabled': avisos.isNotEmpty,
        'platform': 'android',
        'lastSeenAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (bloqueos.isNotEmpty) 'blocksByDay': bloqueos,
        if (apagado != null) 'lastOffReason': apagado.motivo,
        if (apagado != null) 'lastOffAt': Timestamp.fromDate(apagado.momento),
        if (encendido != null) 'lastOnAt': Timestamp.fromDate(encendido),
      };
      // Sin await: con conexión lenta la escritura queda en la cola local de
      // Firestore y sale sola; no bloquea la app.
      unawaited(
        FirebaseFirestore.instance
            .collection('shieldStatus')
            .doc(uid)
            // mergeFields reemplaza cada campo completo: el mapa de bloqueos
            // no se acumula sin fin en el servidor.
            .set(datos, SetOptions(mergeFields: datos.keys.toList()))
            .catchError((Object e) {
              debugPrint('🛡️ [ESCUDO] No se pudo reportar el estado: $e');
            }),
      );
      await prefs.setBool(_prefUltimoActivo, activo);
      // El compañero con avisos ve "Escudo activo/apagado" en su tarjeta.
      if (avisos.isNotEmpty) {
        unawaited(BattlePartnerService.I.syncPublicProgress());
      }
    } catch (e) {
      debugPrint('🛡️ [ESCUDO] Error al reportar: $e');
    }
  }
}
