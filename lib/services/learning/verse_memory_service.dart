/// ═══════════════════════════════════════════════════════════════════════════
/// VerseMemoryService — Armadura: versículos memorizados con SRS
///
/// • Carga la lista de versículos candidatos desde JSON.
/// • Mantiene por-versículo un VerseMemoryState en SharedPreferences.
/// • Permite al usuario elegir su versión bíblica preferida para memorización.
///   (persistida; por defecto la del reader o RVR1960).
/// • SRS tipo SM-2 simplificado: calidad ∈ {0,1,2} (fallo, difícil, correcto).
///
/// Niveles (0..5):
///   0 Nuevo         — no visto aún
///   1 Reconoce      — multiple-choice del texto
///   2 Completa      — llena 1..2 palabras clave
///   3 Recita        — recita con pista inicial
///   4 Aplica        — evoca situación + texto sin pista
///   5 Dominado      — se convierte en «escudo»
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/bible/bible_version.dart';
import '../../models/learning/learning_models.dart';
import '../../utils/time_utils.dart';
import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class VerseMemoryService {
  VerseMemoryService._();
  static final VerseMemoryService I = VerseMemoryService._();

  static const String _kStates = 'verse_memory_states_v1'; // JSON map id->state
  static const String _kVersion = 'verse_memory_version_v1'; // BibleVersion.id

  SharedPreferences? _prefs;
  bool _init = false;

  List<MemoryVerse> _catalog = const [];
  final Map<String, VerseMemoryState> _states = {};

  final ValueNotifier<int> changeTickNotifier = ValueNotifier(0);
  final ValueNotifier<BibleVersion> preferredVersionNotifier =
      ValueNotifier(BibleVersion.rvr1960);

  // ══════════════════════════════════════════════════════════════════════════
  // INIT
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> init() async {
    if (_init) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadCatalog();
    _loadStates();
    _loadVersionPref();
    _init = true;
    debugPrint(
        '🛡️ [ARMORY] Init catalog=${_catalog.length} states=${_states.length} '
        'version=${preferredVersionNotifier.value.id}');
  }

  Future<void> _loadCatalog() async {
    try {
      final raw =
          await rootBundle.loadString('assets/content/learning_verses.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _catalog = list.map(MemoryVerse.fromJson).toList();
    } catch (e) {
      debugPrint('🛡️ [ARMORY] Error loading catalog: $e');
      _catalog = const [];
    }
  }

  void _loadStates() {
    _states.clear();
    final raw = _prefs?.getString(_kStates);
    if (raw == null || raw.isEmpty) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      for (final entry in j.entries) {
        _states[entry.key] =
            VerseMemoryState.fromJson(entry.value as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('🛡️ [ARMORY] Error parsing states: $e');
    }
  }

  Future<void> _persistStates() async {
    final j = <String, dynamic>{
      for (final e in _states.entries) e.key: e.value.toJson(),
    };
    await _prefs?.setString(_kStates, jsonEncode(j));
    changeTickNotifier.value = changeTickNotifier.value + 1;
    // Actualizar contador de dominados en progreso
    LearningProgressService.I.setVersesMastered(masteredCount);
  }

  void _loadVersionPref() {
    final id = _prefs?.getString(_kVersion);
    if (id != null) {
      preferredVersionNotifier.value = BibleVersion.fromId(id);
    }
  }

  Future<void> setPreferredVersion(BibleVersion v) async {
    preferredVersionNotifier.value = v;
    await _prefs?.setString(_kVersion, v.id);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // QUERIES
  // ══════════════════════════════════════════════════════════════════════════

  List<MemoryVerse> get catalog => _catalog;

  VerseMemoryState stateFor(String verseId) =>
      _states[verseId] ?? const VerseMemoryState.initial();

  int get masteredCount =>
      _states.values.where((s) => s.level >= 5).length;

  int get inProgressCount =>
      _states.values.where((s) => s.level > 0 && s.level < 5).length;

  /// Los versículos que tocan repaso hoy (dueDate <= hoy y level>=1).
  List<MemoryVerse> dueToday() {
    final today = TimeUtils.dateToISO(DateTime.now());
    return _catalog.where((v) {
      final s = _states[v.id];
      if (s == null || s.level == 0 || s.level >= 5) return false;
      if (s.dueDate.isEmpty) return true;
      return s.dueDate.compareTo(today) <= 0;
    }).toList();
  }

  /// Los que aún no se han iniciado (level 0 / no state).
  List<MemoryVerse> newVerses() {
    return _catalog.where((v) {
      final s = _states[v.id];
      return s == null || s.level == 0;
    }).toList();
  }

  /// Los que ya están dominados (level 5).
  List<MemoryVerse> mastered() {
    return _catalog.where((v) {
      final s = _states[v.id];
      return s != null && s.level >= 5;
    }).toList();
  }

  /// Un resumen contable para badges/UI.
  ({int total, int mastered, int inProgress, int due, int notStarted}) summary() {
    final due = dueToday().length;
    return (
      total: _catalog.length,
      mastered: masteredCount,
      inProgress: inProgressCount,
      due: due,
      notStarted: newVerses().length,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // SRS UPDATE
  // ══════════════════════════════════════════════════════════════════════════

  /// Registra el resultado de un repaso.
  /// quality: 0 = fallo, 1 = difícil, 2 = correcto.
  /// Devuelve el nuevo estado.
  Future<VerseMemoryState> recordReview({
    required String verseId,
    required int quality,
  }) async {
    await init();
    final prev = stateFor(verseId);
    final today = TimeUtils.dateToISO(DateTime.now());

    int newLevel = prev.level;
    int newStreak = prev.streak;
    double newEase = prev.ease;
    int intervalDays;

    if (quality == 0) {
      // Falló: bajar un nivel (mínimo 1), reset streak, ease -0.2 (>=1.3).
      newLevel = (prev.level - 1).clamp(1, 5);
      newStreak = 0;
      newEase = (prev.ease - 0.2).clamp(1.3, 3.0);
      intervalDays = 1;
    } else {
      newStreak = prev.streak + 1;
      if (quality == 1) {
        newEase = (prev.ease - 0.05).clamp(1.3, 3.0);
      } else {
        newEase = (prev.ease + 0.1).clamp(1.3, 3.0);
      }
      // Subir nivel con 2 aciertos consecutivos en calidad 2, o 3 en calidad 1.
      final threshold = quality == 2 ? 2 : 3;
      if (newStreak >= threshold && prev.level < 5) {
        newLevel = prev.level + 1;
        newStreak = 0; // reset al subir de nivel
        // Bonus XP por subir de nivel (solo en Armadura)
        LearningProgressService.I.addXp(newLevel == 5 ? 25 : 8);
        // Talentos: dominar un versículo (level 5) es un hito. Otros niveles
        // ya están bien recompensados con XP.
        if (newLevel == 5) {
          TalentsHooks.verseMastered(verseId);
        }
      } else if (prev.level == 0) {
        // Primera vez que lo estudia → pasa a level 1
        newLevel = 1;
        newStreak = 1;
        LearningProgressService.I.addXp(3);
      }

      // intervalo base en días según nivel
      const baseInterval = [1, 1, 3, 7, 14, 30];
      final base = baseInterval[newLevel.clamp(0, 5)];
      intervalDays = (base * newEase).round().clamp(1, 60);
    }

    final nextDue = DateTime.parse(today).add(Duration(days: intervalDays));
    final nextState = VerseMemoryState(
      level: newLevel,
      ease: newEase,
      dueDate: TimeUtils.dateToISO(nextDue),
      streak: newStreak,
      lastReviewed: today,
    );

    _states[verseId] = nextState;
    await _persistStates();
    LearningProgressService.I.recordStudyActivity();
    return nextState;
  }

  /// Inicia un versículo por primera vez (opcional antes del primer repaso).
  Future<void> ensureStarted(String verseId) async {
    await init();
    if (_states.containsKey(verseId)) return;
    _states[verseId] = const VerseMemoryState.initial();
    await _persistStates();
  }
}
