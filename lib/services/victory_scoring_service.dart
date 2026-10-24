/// ═══════════════════════════════════════════════════════════════════════════
/// VICTORY SCORING SERVICE - Sistema de Victoria Compuesta
/// Gestiona estados por gigante, cálculo de scores y umbral de victoria
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_service.dart';
import 'daily_practice_service.dart';
import 'user_pref_cloud_sync_service.dart';
import '../utils/fecha_calendario.dart';
import '../utils/time_utils.dart';

/// Cómo quedó registrado un día.
enum EstadoDia {
  /// El día no tiene registro.
  sinRegistro('none'),

  /// El día alcanzó el umbral de victoria.
  victoria('victory'),

  /// El día se registró con honestidad sin contar como victoria.
  gracia('grace');

  const EstadoDia(this.id);

  /// Valor que se guarda en Firestore (espejo del compañero).
  final String id;

  static EstadoDia desdeId(String? id) => EstadoDia.values.firstWhere(
    (e) => e.id == id,
    orElse: () => EstadoDia.sinRegistro,
  );
}

/// Por qué no se puede usar un día protegido ahora.
enum MotivoSinGracia {
  /// Hay un día que se puede cubrir.
  ninguno,

  /// Ya se usó el día protegido de este mes.
  sinTokens,

  /// No hay un día reciente cuya ausencia rompa la racha.
  nadaQueProteger,
}

class VictoryScoringService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final VictoryScoringService _instance = VictoryScoringService._internal();
  factory VictoryScoringService() => _instance;
  VictoryScoringService._internal();

  static VictoryScoringService get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // KEYS
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _keyVictoryByGiant = 'victory_by_giant_v1';
  static const String _keyMigrated = 'migrated_victory_to_by_giant';
  static const String _keyThreshold = 'victory_threshold';

  // Recaída y tokens de gracia
  static const String _keyLastBrokenStreak = 'last_broken_streak_v1';
  static const String _keyLastBreakDateISO = 'last_break_date_iso_v1';
  static const String _keyRelapseAckDateISO = 'relapse_ack_date_iso_v1';
  static const String _keyGraceTokens = 'grace_tokens_v1';
  static const String _keyGraceTokensMonthISO = 'grace_tokens_month_v1'; // YYYY-MM
  static const String _keyGraceDaysUsed = 'grace_days_used_v1'; // set<ISO>
  static const String _keyJourneyStartISO = 'journey_start_iso_v1';

  /// Días protegidos que se recargan cada mes (no se acumulan).
  static const int tokensDeGraciaPorMes = 1;

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFIGURACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  /// Umbral de victoria: 60% (3/5 gigantes = 0.6)
  static const double defaultThreshold = 0.60;

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADO
  // ═══════════════════════════════════════════════════════════════════════════

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  /// Cache: dateISO -> {giantId: 0/1}
  Map<String, Map<String, int>> _victoryByGiant = {};

  /// Gigantes seleccionados del usuario
  List<String> _selectedGiants = [];

  /// Umbral configurable
  double _threshold = defaultThreshold;

  // Estado de recaída / gracia
  int _lastBrokenStreak = 0;
  String? _lastBreakDateISO;
  String? _relapseAckDateISO; // última fecha donde el usuario cerró el flujo
  int _graceTokens = 0;
  Set<String> _graceDaysUsed = {};
  String? _journeyStartISO;

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICADORES
  // ═══════════════════════════════════════════════════════════════════════════

  final ValueNotifier<int> currentStreakNotifier = ValueNotifier(0);
  final ValueNotifier<bool> loggedTodayNotifier = ValueNotifier(false);
  final ValueNotifier<int> totalYearNotifier = ValueNotifier(0);
  final ValueNotifier<int> bestStreakNotifier = ValueNotifier(0);

  /// Se dispara cuando se detecta una recaída (streak >=3 cayó a 0).
  /// El valor es el streak que se perdió. `null` significa ya reconocido.
  final ValueNotifier<int?> relapseEventNotifier = ValueNotifier(null);

  /// Tokens de gracia disponibles este mes (se recargan a 1 cada mes).
  final ValueNotifier<int> graceTokensNotifier = ValueNotifier(0);

  /// Callback para write-through a cloud (lo configura ProgressSyncAdapter)
  /// Evita import circular: VictoryScoringService no importa el adapter.
  void Function(DateTime date)? onDayChanged;

  /// Reloj inyectable para pruebas (cambios de horario, fin de mes).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  DateTime _now() => clock();

  bool get isInitialized => _isInitialized;
  double get threshold => _threshold;
  List<String> get selectedGiants => List.from(_selectedGiants);

  // ═══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_isInitialized) {
      // Si ya estaba inicializado, solo refrescar datos. Los gigantes pueden
      // haber cambiado (p. ej. el usuario terminó el onboarding después de
      // arrancar con el gigante provisional 'general').
      await _loadVictoryByGiant();
      await _recargarGigantesSiCambiaron();
      _updateAllNotifiers();
      return;
    }

    try {
      _prefs = await SharedPreferences.getInstance();

      // Cargar gigantes seleccionados
      final onboarding = OnboardingService();
      await onboarding.init();
      _selectedGiants = onboarding.selectedGiants;

      // Si no hay gigantes, usar uno por defecto para evitar división por 0
      if (_selectedGiants.isEmpty) {
        _selectedGiants = ['general'];
      }

      // Cargar umbral
      _threshold = _prefs?.getDouble(_keyThreshold) ?? defaultThreshold;

      // Cargar estado de recaída / gracia
      _loadRelapseAndGraceState();

      // Cargar datos (SIEMPRE recargar de disco)
      await _loadVictoryByGiant();

      // Migración desde sistema antiguo
      await _migrateFromLegacy();

      _isInitialized = true;
      _updateAllNotifiers();

      debugPrint(
        '📊 [SCORING] Initialized: ${_selectedGiants.length} gigantes, ${_victoryByGiant.length} días, umbral=$_threshold',
      );
    } catch (e) {
      debugPrint('📊 [SCORING] Init error: $e');
      _isInitialized = true;
    }
  }

  /// Gigante provisional mientras el usuario no termina el onboarding.
  static const String _giganteProvisional = 'general';

  /// Relee los gigantes del onboarding (ver [aplicarGigantes]).
  Future<void> _recargarGigantesSiCambiaron() async {
    List<String> nuevos;
    try {
      nuevos = OnboardingService().selectedGiants;
    } catch (e) {
      debugPrint('📊 [SCORING] No se pudieron releer los gigantes: $e');
      return;
    }
    await aplicarGigantes(nuevos);
  }

  /// Cambia el conjunto de gigantes. Si antes se usaba el gigante
  /// provisional, conserva el resultado (victoria o gracia) de cada día ya
  /// registrado copiándolo a los gigantes reales: el usuario no pierde días.
  @visibleForTesting
  Future<void> aplicarGigantes(List<String> nuevos) async {
    if (nuevos.isEmpty || listEquals(nuevos, _selectedGiants)) return;
    final veniaDelProvisional =
        _selectedGiants.length == 1 &&
        _selectedGiants.first == _giganteProvisional;

    if (!veniaDelProvisional) {
      _selectedGiants = List<String>.from(nuevos);
      return;
    }

    // Resultado de cada día con los gigantes anteriores.
    final resultadoPrevio = <String, bool>{};
    for (final iso in _victoryByGiant.keys) {
      final fecha = _isoToDate(iso);
      if (fecha != null) resultadoPrevio[iso] = isVictoryDay(fecha);
    }
    _selectedGiants = List<String>.from(nuevos);
    var conservados = 0;
    resultadoPrevio.forEach((iso, eraVictoria) {
      final fecha = _isoToDate(iso)!;
      if (isVictoryDay(fecha) != eraVictoria) {
        _victoryByGiant[iso] = {
          for (final g in _selectedGiants) g: eraVictoria ? 1 : 0,
        };
        conservados++;
      }
    });
    if (conservados > 0) await _saveVictoryByGiant();
    debugPrint(
      '📊 [SCORING] Gigantes reales cargados (${nuevos.length}); '
      '$conservados días conservados',
    );
  }

  Future<void> _loadVictoryByGiant() async {
    try {
      final json = _prefs?.getString(_keyVictoryByGiant);
      if (json != null && json.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(json);
        _victoryByGiant = decoded.map((dateISO, giantMap) {
          if (giantMap is Map) {
            return MapEntry(
              dateISO,
              Map<String, int>.from(
                giantMap.map((k, v) => MapEntry(k.toString(), (v is int) ? v : 0)),
              ),
            );
          }
          return MapEntry(dateISO, <String, int>{});
        });
        debugPrint('📊 [SCORING] Loaded ${_victoryByGiant.length} days from storage');
      } else {
        _victoryByGiant = {};
        debugPrint('📊 [SCORING] No stored data, starting fresh');
      }
    } catch (e) {
      debugPrint('📊 [SCORING] Load error: $e');
      _victoryByGiant = {};
    }
  }

  Future<bool> _saveVictoryByGiant() async {
    try {
      final json = jsonEncode(_victoryByGiant);
      final success = await _prefs?.setString(_keyVictoryByGiant, json) ?? false;
      if (success) {
        debugPrint('📊 [SCORING] Saved ${_victoryByGiant.length} days to storage');
      }
      return success;
    } catch (e) {
      debugPrint('📊 [SCORING] Save error: $e');
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MIGRACIÓN
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _migrateFromLegacy() async {
    final migrated = _prefs?.getBool(_keyMigrated) ?? false;
    if (migrated) return;

    try {
      // Leer directamente del SharedPreferences del sistema antiguo
      final oldJson = _prefs?.getString('victory_days_set');
      Set<String> oldDays = {};
      if (oldJson != null) {
        final List<dynamic> list = jsonDecode(oldJson);
        oldDays = list.map((e) => e.toString()).toSet();
      }

      if (oldDays.isNotEmpty && _victoryByGiant.isEmpty) {
        debugPrint('📊 [SCORING] Migrando ${oldDays.length} días del sistema antiguo');

        for (final dateISO in oldDays) {
          // Marcar victoria en TODOS los gigantes (conservador hacia el usuario)
          _victoryByGiant[dateISO] = {for (final giant in _selectedGiants) giant: 1};
        }

        await _saveVictoryByGiant();
      }

      await _prefs?.setBool(_keyMigrated, true);
      debugPrint('📊 [SCORING] Migración completada');
    } catch (e) {
      debugPrint('📊 [SCORING] Migration error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA - LECTURA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Obtiene estados de todos los gigantes para un día
  /// Retorna {giantId: 0/1} para TODOS los gigantes seleccionados
  Map<String, int> getDayGiantStates(DateTime date) {
    final dateISO = _dateToISO(date);
    final stored = _victoryByGiant[dateISO] ?? {};

    // Asegurar que todos los gigantes seleccionados tienen un valor
    return {
      for (final giant in _selectedGiants) giant: stored[giant] ?? 0, // Default: gracia (0)
    };
  }

  /// Cuenta victorias del día
  int getDayVictoriesCount(DateTime date) {
    final states = getDayGiantStates(date);
    return states.values.where((v) => v == 1).length;
  }

  /// Total de gigantes seleccionados
  int getTotalGiantsCount() => _selectedGiants.length;

  /// Score del día [0.0 - 1.0]
  double getDayScore(DateTime date) {
    final total = getTotalGiantsCount();
    if (total == 0) return 0.0;
    return getDayVictoriesCount(date) / total;
  }

  /// ¿Es día de victoria? (score >= threshold)
  bool isVictoryDay(DateTime date) {
    final dateISO = _dateToISO(date);
    final hasEntry = _victoryByGiant.containsKey(dateISO);

    // Si no hay entrada para este día, NO es victoria
    if (!hasEntry) {
      return false;
    }

    final victories = getDayVictoriesCount(date);
    final required = getRequiredVictories();
    final result = victories >= required;

    return result;
  }

  /// Victorias mínimas requeridas para ⭐
  int getRequiredVictories() {
    final total = getTotalGiantsCount();
    if (total == 0) return 1;
    return ((_threshold * total).ceil()).clamp(1, total);
  }

  /// ¿Hay algún registro para hoy?
  bool isLoggedToday() {
    final dateISO = _dateToISO(_now());
    return _victoryByGiant.containsKey(dateISO);
  }

  /// ¿Hoy es día de victoria?
  bool isTodayVictory() => isVictoryDay(_now());

  /// Cómo quedó registrado [fecha]: sin registro, victoria o gracia.
  EstadoDia estadoDelDia(DateTime fecha) {
    if (!isDateLogged(fecha)) return EstadoDia.sinRegistro;
    return isVictoryDay(fecha) ? EstadoDia.victoria : EstadoDia.gracia;
  }

  /// Estado de hoy (fecha local del dispositivo).
  EstadoDia get estadoHoy => estadoDelDia(_now());

  /// Clave "AAAA-MM-DD" de hoy según el reloj del servicio.
  String get claveHoy => _dateToISO(_now());

  // ═══════════════════════════════════════════════════════════════════════════
  // API PÚBLICA - ESCRITURA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Establece estado de un gigante para un día
  Future<void> setDayGiantState(DateTime date, String giantId, int value) async {
    if (!_isInitialized) await init();

    // No permitir editar días futuros
    if (_isFuture(date)) return;

    final dateISO = _dateToISO(date);

    // Obtener o crear mapa del día
    _victoryByGiant[dateISO] ??= {};
    _victoryByGiant[dateISO]![giantId] = value.clamp(0, 1);

    await _saveVictoryByGiant();
    _updateAllNotifiers();

    debugPrint('📊 [SCORING] $dateISO.$giantId = $value');

    // Write-through: notificar al sync adapter para subir a cloud
    onDayChanged?.call(date);
  }

  /// Marca todos los gigantes con el mismo valor para un día
  Future<void> setDayAllGiants(DateTime date, int value) async {
    if (!_isInitialized) await init();

    // No permitir editar días futuros
    if (_isFuture(date)) return;

    final dateISO = _dateToISO(date);

    _victoryByGiant[dateISO] = {for (final giant in _selectedGiants) giant: value.clamp(0, 1)};

    await _saveVictoryByGiant();
    _updateAllNotifiers();

    debugPrint('📊 [SCORING] $dateISO.ALL = $value');

    // Write-through: notificar al sync adapter para subir a cloud
    onDayChanged?.call(date);
  }

  /// El día se puede cerrar a cualquier hora.
  bool canLogVictoryNow() => true;

  /// Registra victoria completa para hoy (todos gigantes = 1)
  Future<bool> logVictoryForToday() async {
    if (!canLogVictoryNow()) return false;
    await setDayAllGiants(_now(), 1);
    // Marca la práctica "victoria" del día.
    try {
      // Lazy import para evitar ciclo.
      // ignore: avoid_dynamic_calls
      DailyPracticeService.I.mark(DailyPractice.victory);
    } catch (_) {}
    return true;
  }

  /// Verifica si hay datos guardados para hoy (puede ser victoria o gracia)
  bool hasDataForToday() {
    final dateISO = _dateToISO(_now());
    return _victoryByGiant.containsKey(dateISO);
  }

  /// Verifica si hay datos guardados para una fecha arbitraria
  bool isDateLogged(DateTime date) {
    final dateISO = _dateToISO(date);
    return _victoryByGiant.containsKey(dateISO);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // ESTADÍSTICAS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Días de victoria en un mes (score >= threshold)
  Set<String> getVictoryDaysInMonth(DateTime month) {
    final yearMonth = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    return _victoryByGiant.keys.where((dateISO) => dateISO.startsWith(yearMonth)).where((dateISO) {
      final date = _isoToDate(dateISO);
      return date != null && isVictoryDay(date);
    }).toSet();
  }

  /// Total de días de victoria en un año
  int getTotalVictoriesForYear(int year) {
    return _victoryByGiant.keys.where((dateISO) => dateISO.startsWith('$year-')).where((dateISO) {
      final date = _isoToDate(dateISO);
      return date != null && isVictoryDay(date);
    }).length;
  }

  /// Racha actual (consecutivos hasta hoy con score >= threshold).
  /// Si hoy no es victoria, busca desde ayer. Recorre por días de calendario
  /// (no restando 24 h), así el cambio de horario no rompe la racha.
  int getCurrentStreak() {
    return FechaCalendario.rachaActual(hoy: _now(), esVictoria: isVictoryDay);
  }

  /// Mejor racha histórica (cruza años).
  int getBestStreakAllTime() {
    final victoryDates = _victoryByGiant.keys
        .map(FechaCalendario.desdeClave)
        .whereType<DateTime>()
        .where(isVictoryDay);
    return FechaCalendario.mejorRacha(victoryDates);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RECAÍDA Y TOKENS DE GRACIA
  // ═══════════════════════════════════════════════════════════════════════════

  int get lastBrokenStreak => _lastBrokenStreak;
  String? get lastBreakDateISO => _lastBreakDateISO;
  String? get journeyStartISO => _journeyStartISO;
  int get graceTokens => _graceTokens;
  Set<String> get graceDaysUsed => Set.from(_graceDaysUsed);

  /// Porcentaje de días libres desde el inicio del camino [0.0 – 1.0].
  double getFreedomPercentage() {
    final startIso = _journeyStartISO;
    if (startIso == null) return 0.0;
    final start = _isoToDate(startIso);
    if (start == null) return 0.0;
    final totalDays = FechaCalendario.diasEntre(start, _now()) + 1;
    if (totalDays <= 0) return 0.0;
    final victoryDays = _victoryByGiant.keys.where((iso) {
      final d = _isoToDate(iso);
      return d != null && !d.isBefore(start) && isVictoryDay(d);
    }).length;
    return (victoryDays / totalDays).clamp(0.0, 1.0);
  }

  /// Total de días desde que empezó el camino (para mostrar en UI).
  int getJourneyDayCount() {
    final startIso = _journeyStartISO;
    if (startIso == null) return 0;
    final start = _isoToDate(startIso);
    if (start == null) return 0;
    return FechaCalendario.diasEntre(start, _now()) + 1;
  }

  /// ¿Hay una recaída aún no reconocida por el usuario?
  bool get hasPendingRelapseAck {
    if (_lastBrokenStreak < 3) return false;
    if (_lastBreakDateISO == null) return false;
    return _relapseAckDateISO != _lastBreakDateISO;
  }

  /// Usuario confirmó que vio la pantalla de gracia.
  Future<void> acknowledgeRelapse() async {
    _relapseAckDateISO = _lastBreakDateISO;
    await _prefs?.setString(_keyRelapseAckDateISO, _relapseAckDateISO ?? '');
    UserPrefCloudSyncService.I.markDirty();
    relapseEventNotifier.value = null;
    debugPrint('📊 [RELAPSE] Acknowledged break on $_relapseAckDateISO');
  }

  /// Día que un día protegido puede cubrir ahora, o `null`.
  ///
  /// Reglas (las mismas que explica la tarjeta en Progreso):
  /// - Hay [tokensDeGraciaPorMes] por mes; no se acumulan.
  /// - Solo cubre ayer o anteayer (hoy todavía se puede registrar).
  /// - Solo si ese día no fue victoria y cubrirlo une la racha: el día
  ///   anterior fue victoria (y, si es anteayer, ayer también).
  DateTime? diaParaGracia() => _diaParaGracia(revisarTokens: true);

  /// Por qué no hay día protegido disponible (para explicarlo en la UI).
  MotivoSinGracia motivoSinGracia() {
    _refreshGraceTokensForCurrentMonth(notificar: false);
    if (_diaParaGracia(revisarTokens: false) == null) {
      return MotivoSinGracia.nadaQueProteger;
    }
    if (_graceTokens <= 0) return MotivoSinGracia.sinTokens;
    return MotivoSinGracia.ninguno;
  }

  DateTime? _diaParaGracia({required bool revisarTokens}) {
    if (revisarTokens) {
      _refreshGraceTokensForCurrentMonth(notificar: false);
      if (_graceTokens <= 0) return null;
    }
    final hoy = _now();
    final ayer = FechaCalendario.sumarDias(hoy, -1);
    final anteayer = FechaCalendario.sumarDias(hoy, -2);
    final hace3 = FechaCalendario.sumarDias(hoy, -3);
    if (!isVictoryDay(ayer) && isVictoryDay(anteayer)) return ayer;
    if (!isVictoryDay(anteayer) && isVictoryDay(hace3) && isVictoryDay(ayer)) {
      return anteayer;
    }
    return null;
  }

  /// ¿[fecha] fue cubierta con un día protegido?
  bool esDiaDeGracia(DateTime fecha) =>
      _graceDaysUsed.contains(_dateToISO(fecha));

  /// Usa 1 día protegido para cubrir [date]. Solo acepta el día que
  /// devuelve [diaParaGracia]; cualquier otro se rechaza.
  Future<bool> useGraceToken(DateTime date) async {
    if (!_isInitialized) await init();
    final elegible = diaParaGracia();
    if (elegible == null) return false;
    if (_dateToISO(elegible) != _dateToISO(date)) return false;

    final iso = _dateToISO(date);
    _victoryByGiant[iso] = {for (final g in _selectedGiants) g: 1};
    _graceDaysUsed.add(iso);
    _graceTokens -= 1;

    await _saveVictoryByGiant();
    await _prefs?.setInt(_keyGraceTokens, _graceTokens);
    await _prefs?.setStringList(_keyGraceDaysUsed, _graceDaysUsed.toList());
    UserPrefCloudSyncService.I.markDirty();

    graceTokensNotifier.value = _graceTokens;
    _updateAllNotifiers();
    // La racha volvió: la recaída detectada ya no está pendiente.
    if (hasPendingRelapseAck && getCurrentStreak() > 0) {
      await acknowledgeRelapse();
    }
    debugPrint('📊 [GRACE] Used token on $iso. Remaining: $_graceTokens');
    onDayChanged?.call(DateTime(date.year, date.month, date.day));
    return true;
  }

  void _loadRelapseAndGraceState() {
    _lastBrokenStreak = _prefs?.getInt(_keyLastBrokenStreak) ?? 0;
    _lastBreakDateISO = _prefs?.getString(_keyLastBreakDateISO);
    _relapseAckDateISO = _prefs?.getString(_keyRelapseAckDateISO);
    _graceDaysUsed = (_prefs?.getStringList(_keyGraceDaysUsed) ?? const []).toSet();
    _journeyStartISO = _prefs?.getString(_keyJourneyStartISO);
    if (_journeyStartISO == null) {
      _journeyStartISO = _dateToISO(_now());
      _prefs?.setString(_keyJourneyStartISO, _journeyStartISO!);
      UserPrefCloudSyncService.I.markDirty();
    }
    _refreshGraceTokensForCurrentMonth();
  }

  /// Recarga el token del mes. [notificar] en `false` cuando se llama
  /// mientras se construye la UI (no se puede avisar a los oyentes ahí).
  void _refreshGraceTokensForCurrentMonth({bool notificar = true}) {
    final now = _now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final savedMonth = _prefs?.getString(_keyGraceTokensMonthISO);
    if (savedMonth != currentMonth) {
      _graceTokens = tokensDeGraciaPorMes;
      _prefs?.setInt(_keyGraceTokens, _graceTokens);
      _prefs?.setString(_keyGraceTokensMonthISO, currentMonth);
      UserPrefCloudSyncService.I.markDirty();
      debugPrint('📊 [GRACE] New month $currentMonth: granted 1 token');
    } else {
      _graceTokens = _prefs?.getInt(_keyGraceTokens) ?? 0;
    }
    if (notificar) graceTokensNotifier.value = _graceTokens;
  }

  /// Detecta si la racha previa era >=3 y cayó a 0.
  void _detectRelapseIfAny(int previousStreak, int newStreak) {
    if (previousStreak >= 3 && newStreak == 0) {
      _lastBrokenStreak = previousStreak;
      _lastBreakDateISO = _dateToISO(_now());
      _prefs?.setInt(_keyLastBrokenStreak, _lastBrokenStreak);
      _prefs?.setString(_keyLastBreakDateISO, _lastBreakDateISO!);
      _relapseAckDateISO = null;
      _prefs?.setString(_keyRelapseAckDateISO, '');
      UserPrefCloudSyncService.I.markDirty();
      relapseEventNotifier.value = _lastBrokenStreak;
      debugPrint('📊 [RELAPSE] Detected break: $previousStreak → 0 on $_lastBreakDateISO');
    } else if (hasPendingRelapseAck) {
      relapseEventNotifier.value = _lastBrokenStreak;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NOTIFICADORES
  // ═══════════════════════════════════════════════════════════════════════════

  void _updateAllNotifiers() {
    final prev = currentStreakNotifier.value;
    final newStreak = getCurrentStreak();
    currentStreakNotifier.value = newStreak;
    loggedTodayNotifier.value = isLoggedToday();
    totalYearNotifier.value = getTotalVictoriesForYear(_now().year);
    bestStreakNotifier.value = getBestStreakAllTime();
    _detectRelapseIfAny(prev, newStreak);
  }

  /// Forzar refresh de notificadores (útil para UI)
  void refreshNotifiers() => _updateAllNotifiers();

  /// Llamado por el lifecycle observer cuando se detecta cambio de día.
  /// Re-evalúa streak y loggedToday con la fecha nueva.
  void refreshAfterDayChange() {
    debugPrint('📊 [SCORING] refreshAfterDayChange()');
    _updateAllNotifiers();
  }

  /// Restaurar datos desde cloud (llamado después de que ProgressRepository
  /// descarga datos de Firestore). Esto hidrata el servicio local con los
  /// datos de la nube sin hacer ningún upload.
  Future<void> restoreFromCloud(Map<String, Map<String, int>> cloudData) async {
    if (!_isInitialized) await init();

    debugPrint('📊 [SCORING] restoreFromCloud: hydrating ${cloudData.length} days from cloud');

    // Reemplazar datos locales con los de cloud (cloud es fuente de verdad)
    _victoryByGiant = Map.from(
      cloudData.map((dateISO, giants) => MapEntry(dateISO, Map<String, int>.from(giants))),
    );

    await _saveVictoryByGiant();
    _updateAllNotifiers();

    debugPrint('📊 [SCORING] restoreFromCloud: ✅ hydrated, streak=${getCurrentStreak()}');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WEEKLY STATUS (para mini-calendario semanal)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Retorna el estado de cada día de la semana actual (lunes→domingo)
  /// Cada elemento: {'date': DateTime, 'completed': bool, 'isToday': bool}
  List<Map<String, dynamic>> getWeeklyStatus() {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    // Lunes de esta semana, por calendario (no restando horas).
    final monday = FechaCalendario.sumarDias(today, -(today.weekday - 1));

    final result = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final u = FechaCalendario.sumarDias(monday, i);
      final day = DateTime(u.year, u.month, u.day);
      final isToday = day.year == today.year && day.month == today.month && day.day == today.day;
      final isFutureDay = day.isAfter(today);
      result.add({
        'date': day,
        'completed': isFutureDay ? false : isVictoryDay(day),
        'isToday': isToday,
      });
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  // Delegados a TimeUtils centralizado
  String _dateToISO(DateTime date) => TimeUtils.dateToISO(date);
  DateTime? _isoToDate(String iso) => TimeUtils.parseISO(iso);
  bool _isFuture(DateTime date) =>
      FechaCalendario.diasEntre(_now(), date) > 0;

  // ═══════════════════════════════════════════════════════════════════════════
  // DEBUG
  // ═══════════════════════════════════════════════════════════════════════════

  /// Reset completo del estado en memoria para poder re-inicializar el
  /// singleton entre tests. NO toca SharedPreferences.
  @visibleForTesting
  void resetForTesting() {
    _prefs = null;
    _isInitialized = false;
    _victoryByGiant = {};
    _selectedGiants = [];
    _threshold = defaultThreshold;
    _lastBrokenStreak = 0;
    _lastBreakDateISO = null;
    _relapseAckDateISO = null;
    _graceTokens = 0;
    _graceDaysUsed = {};
    _journeyStartISO = null;
    currentStreakNotifier.value = 0;
    loggedTodayNotifier.value = false;
    totalYearNotifier.value = 0;
    bestStreakNotifier.value = 0;
    relapseEventNotifier.value = null;
    graceTokensNotifier.value = 0;
    onDayChanged = null;
    clock = DateTime.now;
  }

  /// Carga directa de estado para pruebas unitarias (sin onboarding).
  @visibleForTesting
  Future<void> initForTesting({
    required List<String> giants,
    Map<String, Map<String, int>> days = const {},
  }) async {
    _prefs = await SharedPreferences.getInstance();
    _selectedGiants = List<String>.from(giants);
    _threshold = defaultThreshold;
    _victoryByGiant = {
      for (final e in days.entries) e.key: Map<String, int>.from(e.value),
    };
    _loadRelapseAndGraceState();
    _isInitialized = true;
    _updateAllNotifiers();
  }

  String debugDayStatus(DateTime date) {
    final states = getDayGiantStates(date);
    final victories = getDayVictoriesCount(date);
    final total = getTotalGiantsCount();
    final isVictory = isVictoryDay(date);
    return '$victories/$total ${isVictory ? '⭐' : '✝︎'} $states';
  }
}
