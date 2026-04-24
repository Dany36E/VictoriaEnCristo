/// ═══════════════════════════════════════════════════════════════════════════
/// DailyPracticeService — 4 prácticas diarias (checklist "4/4 hoy")
///
/// Prácticas:
///   1. devocional leído
///   2. oración realizada
///   3. entrada de diario escrita
///   4. victoria registrada (día en streak)
///
/// Persistencia: SharedPreferences con clave por fecha ISO (YYYY-MM-DD).
/// Al cambiar de día, los flags se resetean automáticamente (lectura por fecha).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/time_utils.dart';

enum DailyPractice { devotional, prayer, journal, victory, study }

class DailyPracticeSnapshot {
  final bool devotional;
  final bool prayer;
  final bool journal;
  final bool victory;
  final bool study;

  const DailyPracticeSnapshot({
    required this.devotional,
    required this.prayer,
    required this.journal,
    required this.victory,
    required this.study,
  });

  int get completedCount =>
      (devotional ? 1 : 0) +
      (prayer ? 1 : 0) +
      (journal ? 1 : 0) +
      (victory ? 1 : 0) +
      (study ? 1 : 0);

  int get total => 5;

  bool get isComplete => completedCount == total;

  bool get(DailyPractice p) {
    switch (p) {
      case DailyPractice.devotional:
        return devotional;
      case DailyPractice.prayer:
        return prayer;
      case DailyPractice.journal:
        return journal;
      case DailyPractice.victory:
        return victory;
      case DailyPractice.study:
        return study;
    }
  }
}

class DailyPracticeService {
  DailyPracticeService._();
  static final DailyPracticeService I = DailyPracticeService._();

  static const String _prefix = 'daily_practice_v1:'; // + ISO -> JSON

  SharedPreferences? _prefs;
  bool _isInitialized = false;

  final ValueNotifier<DailyPracticeSnapshot> snapshotNotifier =
      ValueNotifier(const DailyPracticeSnapshot(
    devotional: false,
    prayer: false,
    journal: false,
    victory: false,
    study: false,
  ));

  Future<void> init() async {
    if (_isInitialized) {
      _recomputeSnapshot();
      return;
    }
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    _recomputeSnapshot();
    debugPrint('📋 [DailyPractice] Init snapshot: ${snapshotNotifier.value.completedCount}/5');
  }

  /// Marca una práctica como hecha para hoy (idempotente).
  Future<void> mark(DailyPractice p) async {
    if (!_isInitialized) await init();
    final todayIso = TimeUtils.dateToISO(DateTime.now());
    final data = _readRaw(todayIso);
    switch (p) {
      case DailyPractice.devotional:
        data['devotional'] = true;
        break;
      case DailyPractice.prayer:
        data['prayer'] = true;
        break;
      case DailyPractice.journal:
        data['journal'] = true;
        break;
      case DailyPractice.victory:
        data['victory'] = true;
        break;
      case DailyPractice.study:
        data['study'] = true;
        break;
    }
    await _writeRaw(todayIso, data);
    _recomputeSnapshot();
  }

  /// Desmarca una práctica (permite al usuario corregir si tocó por error).
  Future<void> unmark(DailyPractice p) async {
    if (!_isInitialized) await init();
    final todayIso = TimeUtils.dateToISO(DateTime.now());
    final data = _readRaw(todayIso);
    switch (p) {
      case DailyPractice.devotional:
        data.remove('devotional');
        break;
      case DailyPractice.prayer:
        data.remove('prayer');
        break;
      case DailyPractice.journal:
        data.remove('journal');
        break;
      case DailyPractice.victory:
        data.remove('victory');
        break;
      case DailyPractice.study:
        data.remove('study');
        break;
    }
    await _writeRaw(todayIso, data);
    _recomputeSnapshot();
  }

  /// Recalcula snapshot desde flags persistidos.
  void _recomputeSnapshot() {
    final todayIso = TimeUtils.dateToISO(DateTime.now());
    final raw = _readRaw(todayIso);

    snapshotNotifier.value = DailyPracticeSnapshot(
      devotional: raw['devotional'] == true,
      prayer: raw['prayer'] == true,
      journal: raw['journal'] == true,
      victory: raw['victory'] == true,
      study: raw['study'] == true,
    );
  }

  /// Permite a las pantallas pedir refresh tras eventos externos.
  void refresh() => _recomputeSnapshot();

  Map<String, dynamic> _readRaw(String iso) {
    final s = _prefs?.getString(_prefix + iso);
    if (s == null || s.isEmpty) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(s);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _writeRaw(String iso, Map<String, dynamic> data) async {
    await _prefs?.setString(_prefix + iso, jsonEncode(data));
  }
}
