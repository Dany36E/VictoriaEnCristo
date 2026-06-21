/// ═══════════════════════════════════════════════════════════════════════════
/// FaithCheckbookRepository — carga "La Chequera del Banco de la Fe" (Spurgeon).
///
/// 366 lecturas diarias (incluye 29 de febrero). Se muestra la del día actual
/// del calendario y se puede navegar a días anteriores/siguientes.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../models/devotional/faith_checkbook_entry.dart';

class FaithCheckbookRepository {
  FaithCheckbookRepository._();
  static final FaithCheckbookRepository I = FaithCheckbookRepository._();

  List<FaithCheckbookEntry>? _entries;
  bool _loading = false;

  bool get isLoaded => _entries != null;
  List<FaithCheckbookEntry> get all => _entries ?? const [];

  /// Clave ordenable: mes*100 + día.
  int _key(int month, int day) => month * 100 + day;

  Future<void> load() async {
    if (_entries != null || _loading) return;
    _loading = true;
    try {
      final raw = await rootBundle.loadString(
        'assets/content/faith_checkbook.json',
      );
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      final entries = list.map(FaithCheckbookEntry.fromJson).toList()
        ..sort((a, b) => _key(a.month, a.day).compareTo(_key(b.month, b.day)));
      _entries = entries;
      debugPrint('📖 [CHEQUERA] Cargadas ${entries.length} lecturas');
    } catch (e) {
      debugPrint('📖 [CHEQUERA] Error cargando: $e');
      _entries = const [];
    } finally {
      _loading = false;
    }
  }

  /// Lectura para una fecha concreta. Si no existe exacta (p.ej. 29 feb en año
  /// no bisiesto), devuelve la lectura inmediatamente anterior disponible.
  FaithCheckbookEntry? entryForDate(DateTime date) {
    final list = all;
    if (list.isEmpty) return null;
    final target = _key(date.month, date.day);
    FaithCheckbookEntry? exact;
    FaithCheckbookEntry? prevBest;
    for (final e in list) {
      final k = _key(e.month, e.day);
      if (k == target) {
        exact = e;
        break;
      }
      if (k < target) prevBest = e;
    }
    return exact ?? prevBest ?? list.last;
  }

  FaithCheckbookEntry? entryForToday() => entryForDate(DateTime.now());

  int _indexOf(FaithCheckbookEntry entry) {
    final list = all;
    for (var i = 0; i < list.length; i++) {
      if (list[i].id == entry.id) return i;
    }
    return -1;
  }

  /// Lectura del día siguiente (circular dentro del año).
  FaithCheckbookEntry? next(FaithCheckbookEntry entry) {
    final list = all;
    if (list.isEmpty) return null;
    final i = _indexOf(entry);
    if (i < 0) return null;
    return list[(i + 1) % list.length];
  }

  /// Lectura del día anterior (circular dentro del año).
  FaithCheckbookEntry? previous(FaithCheckbookEntry entry) {
    final list = all;
    if (list.isEmpty) return null;
    final i = _indexOf(entry);
    if (i < 0) return null;
    return list[(i - 1 + list.length) % list.length];
  }

  bool isToday(FaithCheckbookEntry entry) {
    final now = DateTime.now();
    return entry.month == now.month && entry.day == now.day;
  }
}
