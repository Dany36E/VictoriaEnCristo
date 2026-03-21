import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../models/bible/book_introduction.dart';

/// Servicio para introducciones de libros bíblicos.
class BookIntroService {
  BookIntroService._();
  static final instance = BookIntroService._();

  Map<int, BookIntroduction>? _intros; // bookNumber → intro
  bool _loaded = false;

  /// Nombre JSON para cada libro (lowercase, sin tildes).
  static const _bookKeys = <int, String>{
    1: 'genesis', 2: 'exodus', 3: 'leviticus', 4: 'numbers',
    5: 'deuteronomy', 6: 'joshua', 7: 'judges', 8: 'ruth',
    9: '1samuel', 10: '2samuel', 11: '1kings', 12: '2kings',
    13: '1chronicles', 14: '2chronicles', 15: 'ezra', 16: 'nehemiah',
    17: 'esther', 18: 'job', 19: 'psalms', 20: 'proverbs',
    21: 'ecclesiastes', 22: 'song_of_solomon', 23: 'isaiah',
    24: 'jeremiah', 25: 'lamentations', 26: 'ezekiel', 27: 'daniel',
    28: 'hosea', 29: 'joel', 30: 'amos', 31: 'obadiah',
    32: 'jonah', 33: 'micah', 34: 'nahum', 35: 'habakkuk',
    36: 'zephaniah', 37: 'haggai', 38: 'zechariah', 39: 'malachi',
    40: 'matthew', 41: 'mark', 42: 'luke', 43: 'john',
    44: 'acts', 45: 'romans', 46: '1corinthians', 47: '2corinthians',
    48: 'galatians', 49: 'ephesians', 50: 'philippians',
    51: 'colossians', 52: '1thessalonians', 53: '2thessalonians',
    54: '1timothy', 55: '2timothy', 56: 'titus', 57: 'philemon',
    58: 'hebrews', 59: 'james', 60: '1peter', 61: '2peter',
    62: '1john', 63: '2john', 64: '3john', 65: 'jude',
    66: 'revelation',
  };

  /// Obtiene la introducción de un libro.
  Future<BookIntroduction?> getIntroduction(int bookNumber) async {
    await _ensureLoaded();
    return _intros?[bookNumber];
  }

  /// Obtiene la introducción a un capítulo específico.
  Future<String?> getChapterIntro(int bookNumber, int chapter) async {
    await _ensureLoaded();
    return _intros?[bookNumber]?.chapterIntros[chapter];
  }

  /// Verifica si un libro tiene introducción disponible.
  Future<bool> hasIntroduction(int bookNumber) async {
    await _ensureLoaded();
    return _intros?.containsKey(bookNumber) ?? false;
  }

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;

    try {
      final raw = await rootBundle
          .loadString('assets/bible/books_intro/books_introduction.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      _intros = {};

      for (final entry in _bookKeys.entries) {
        final bookData = data[entry.value];
        if (bookData != null) {
          _intros![entry.key] =
              BookIntroduction.fromJson(bookData as Map<String, dynamic>);
        }
      }
    } catch (e) {
      debugPrint('BookIntroService: Error cargando intros: $e');
      _intros = {};
    }
  }
}
