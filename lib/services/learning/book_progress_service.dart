import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'learning_progress_service.dart';
import 'talents_hooks.dart';

class BookProgressState {
  final Set<String> studied;
  final Map<String, int> bestScores;
  const BookProgressState({
    this.studied = const {},
    this.bestScores = const {},
  });
  BookProgressState copyWith({
    Set<String>? studied,
    Map<String, int>? bestScores,
  }) =>
      BookProgressState(
        studied: studied ?? this.studied,
        bestScores: bestScores ?? this.bestScores,
      );
}

class BookProgressService {
  BookProgressService._();
  static final BookProgressService I = BookProgressService._();

  static const _kStudied = 'book.studied';
  static const _kScores = 'book.scores';

  final ValueNotifier<BookProgressState> stateNotifier =
      ValueNotifier(const BookProgressState());
  BookProgressState get state => stateNotifier.value;

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    final studied = (p.getStringList(_kStudied) ?? const <String>[]).toSet();
    final raw = p.getString(_kScores);
    Map<String, int> scores = {};
    if (raw != null) {
      try {
        final m = json.decode(raw) as Map<String, dynamic>;
        scores = m.map((k, v) => MapEntry(k, (v as num).toInt()));
      } catch (_) {}
    }
    stateNotifier.value =
        BookProgressState(studied: studied, bestScores: scores);
  }

  Future<int> completeBook({
    required String bookId,
    required int score,
    required int xpReward,
  }) async {
    final p = await SharedPreferences.getInstance();
    final cur = state;
    final newStudied = {...cur.studied, bookId};
    final prev = cur.bestScores[bookId] ?? 0;
    final newScores = Map<String, int>.from(cur.bestScores);
    if (score > prev) newScores[bookId] = score;
    await p.setStringList(_kStudied, newStudied.toList());
    await p.setString(_kScores, json.encode(newScores));
    stateNotifier.value =
        cur.copyWith(studied: newStudied, bestScores: newScores);
    var xp = 0;
    if (!cur.studied.contains(bookId)) {
      xp = xpReward;
      await LearningProgressService.I.addXp(xp);
      await LearningProgressService.I.recordStudyActivity();
      TalentsHooks.bookStudied(bookId);
    }
    return xp;
  }
}
