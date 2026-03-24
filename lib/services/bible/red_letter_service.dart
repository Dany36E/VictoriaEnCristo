import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Servicio para identificar versículos con palabras de Cristo (rojo).
/// Carga un índice pequeño (~50KB) al inicializar.
class RedLetterService {
  RedLetterService._();
  static final instance = RedLetterService._();

  /// Set de claves "BOOK.CHAPTER.VERSE" que son palabras de Cristo.
  Set<String>? _redLetterKeys;

  Completer<void>? _initCompleter;
  bool get isInitialized => _initCompleter?.isCompleted ?? false;

  /// Mapa bookNumber → código usado en el índice red-letter.
  static const _bookNumberToCode = <int, String>{
    40: 'MAT', 41: 'MRK', 42: 'LUK', 43: 'JHN', 66: 'REV',
  };

  /// Inicializa el servicio cargando el índice.
  Future<void> init() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      final raw = await rootBundle.loadString(
        'assets/bible/red_letter/red_letter_index.json',
      );
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _redLetterKeys = map.keys.toSet();
    } catch (e) {
      debugPrint('RedLetterService: Error cargando índice: $e');
      _redLetterKeys = {};
    }
    _initCompleter!.complete();
  }

  /// Verifica si un versículo contiene palabras de Cristo.
  bool isRedLetter(int bookNumber, int chapter, int verse) {
    final code = _bookNumberToCode[bookNumber];
    if (code == null) return false;
    return _redLetterKeys?.contains('$code.$chapter.$verse') ?? false;
  }

  /// Todos los libros que tienen palabras de Cristo.
  static const redLetterBooks = {40, 41, 42, 43, 66};

  /// True si el libro puede contener palabras de Cristo.
  static bool bookHasRedLetters(int bookNumber) =>
      redLetterBooks.contains(bookNumber);
}
