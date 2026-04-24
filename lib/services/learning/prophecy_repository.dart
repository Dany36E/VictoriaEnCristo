import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/learning/prophecy_models.dart';

class ProphecyRepository {
  ProphecyRepository._();
  static final ProphecyRepository I = ProphecyRepository._();

  final List<ProphecyRound> _rounds = [];
  bool _loaded = false;

  List<ProphecyRound> get all => List.unmodifiable(_rounds);
  ProphecyRound? byId(String id) {
    try {
      return _rounds.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw =
          await rootBundle.loadString('assets/content/prophecies.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final list = (data['rounds'] as List<dynamic>? ?? const []);
      _rounds
        ..clear()
        ..addAll(list
            .map((e) => ProphecyRound.fromJson(e as Map<String, dynamic>)));
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }
}
