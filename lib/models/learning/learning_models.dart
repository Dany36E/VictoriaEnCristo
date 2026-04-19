/// ═══════════════════════════════════════════════════════════════════════════
/// LEARNING MODELS — Escuela del Reino (Fase 1)
///
/// Contiene:
///   • LearningQuestion        — pregunta del quiz "Maná del día"
///   • QuestionType            — tipos de ejercicio soportados en Fase 1
///   • MemoryVerse             — versículo candidato a memorizar (Armadura)
///   • VerseMemoryState        — estado SRS por usuario por versículo
///   • LearningProgress        — XP / nivel / hearts del usuario
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════════
// QUESTION
// ═══════════════════════════════════════════════════════════════════════════

enum QuestionType {
  completeVerse,    // palabra faltante en versículo
  whoSaid,          // quién dijo / quién hizo esta acción
  trueFalse,        // afirmación verdadera/falsa
  multipleChoice,   // opción múltiple genérica (personaje/evento/lugar)
  orderEvents,      // ordena eventos cronológicamente
  matchPairs,       // conecta pares AT↔NT, tema↔versículo, etc.
  chooseReference,  // dado un versículo, elige la referencia correcta
  situational,      // dilema: dada una situación, elige la respuesta bíblica
}

QuestionType _typeFromId(String id) {
  switch (id) {
    case 'complete_verse':
      return QuestionType.completeVerse;
    case 'who_said':
      return QuestionType.whoSaid;
    case 'true_false':
      return QuestionType.trueFalse;
    case 'order_events':
      return QuestionType.orderEvents;
    case 'match_pairs':
      return QuestionType.matchPairs;
    case 'choose_reference':
      return QuestionType.chooseReference;
    case 'situational':
      return QuestionType.situational;
    case 'multiple_choice':
    default:
      return QuestionType.multipleChoice;
  }
}

/// Par para [QuestionType.matchPairs].
@immutable
class QuestionPair {
  final String left;
  final String right;
  const QuestionPair({required this.left, required this.right});
  factory QuestionPair.fromJson(Map<String, dynamic> j) => QuestionPair(
        left: j['left'] as String,
        right: j['right'] as String,
      );
}

@immutable
class LearningQuestion {
  final String id;
  final QuestionType type;

  /// Enunciado / pregunta principal.
  final String prompt;

  /// Opciones (para whoSaid, trueFalse con ['Verdadero','Falso'], y MC).
  /// Para completeVerse es ignorado (la respuesta es texto libre comparado).
  final List<String> options;

  /// Índice de la opción correcta (para whoSaid, trueFalse, MC).
  /// Para completeVerse se usa [answerText].
  final int correctIndex;

  /// Respuesta textual esperada (completeVerse): una sola palabra.
  final String? answerText;

  /// Explicación educativa tras responder.
  final String explanation;

  /// Referencia bíblica opcional para "ver más" (p.ej. "Juan 3:16").
  final String? reference;

  /// Tags: categoría doctrinal o temática ("fe", "identidad", "ira"...).
  final List<String> tags;

  /// Dificultad 1..3.
  final int difficulty;

  /// Pares para [QuestionType.matchPairs].
  final List<QuestionPair> pairs;

  /// Orden correcto (índices sobre [options]) para [QuestionType.orderEvents].
  /// Si es null o vacío se asume que [options] ya está en orden correcto.
  final List<int> correctOrder;

  /// Si true, se muestra un botón de "escuchar" (TTS) al lado del enunciado.
  final bool ttsEnabled;

  const LearningQuestion({
    required this.id,
    required this.type,
    required this.prompt,
    required this.options,
    required this.correctIndex,
    required this.explanation,
    this.answerText,
    this.reference,
    this.tags = const [],
    this.difficulty = 1,
    this.pairs = const [],
    this.correctOrder = const [],
    this.ttsEnabled = false,
  });

  factory LearningQuestion.fromJson(Map<String, dynamic> j) => LearningQuestion(
        id: j['id'] as String,
        type: _typeFromId(j['type'] as String),
        prompt: j['prompt'] as String,
        options: (j['options'] as List?)?.cast<String>() ?? const [],
        correctIndex: (j['correctIndex'] as num?)?.toInt() ?? 0,
        answerText: j['answerText'] as String?,
        explanation: (j['explanation'] as String?) ?? '',
        reference: j['reference'] as String?,
        tags: (j['tags'] as List?)?.cast<String>() ?? const [],
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 1,
        pairs: (j['pairs'] as List?)
                ?.map((e) => QuestionPair.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        correctOrder:
            (j['correctOrder'] as List?)?.map((e) => (e as num).toInt()).toList() ??
                const [],
        ttsEnabled: j['ttsEnabled'] as bool? ?? false,
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// MEMORY VERSE (Armadura)
// ═══════════════════════════════════════════════════════════════════════════

/// Versículo candidato a memorización. El texto NO se guarda aquí: se
/// obtiene en runtime de [BibleParserService] según la versión elegida.
@immutable
class MemoryVerse {
  final String id;                 // "eph_6_11"
  final int bookNumber;            // según estándar XML (Génesis=1..Apoc=66)
  final int chapter;
  final int verse;                 // primer verso del pasaje
  final int verseEnd;              // último verso (= verse si es un solo versículo)

  /// "Efesios 6:11" — referencia legible precomputada.
  final String reference;

  /// Situación en la que este versículo es un escudo:
  /// tentacion, ansiedad, soledad, ira, identidad, perdon, fe, proposito.
  final List<String> situations;

  /// Tema breve mostrado en tarjeta ("Armadura espiritual").
  final String topic;

  const MemoryVerse({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.verseEnd,
    required this.reference,
    required this.topic,
    this.situations = const [],
  });

  factory MemoryVerse.fromJson(Map<String, dynamic> j) => MemoryVerse(
        id: j['id'] as String,
        bookNumber: (j['bookNumber'] as num).toInt(),
        chapter: (j['chapter'] as num).toInt(),
        verse: (j['verse'] as num).toInt(),
        verseEnd: (j['verseEnd'] as num?)?.toInt() ?? (j['verse'] as num).toInt(),
        reference: j['reference'] as String,
        topic: (j['topic'] as String?) ?? '',
        situations: (j['situations'] as List?)?.cast<String>() ?? const [],
      );
}

/// Estado SRS por versículo (SM-2 simplificado).
@immutable
class VerseMemoryState {
  /// Nivel aprendizaje 0..5:
  ///   0 nuevo · 1 reconoce · 2 completa · 3 recita · 4 aplica · 5 dominado
  final int level;

  /// Factor de facilidad (1.3..3.0). Afecta cuántos días espaciar.
  final double ease;

  /// Próxima fecha en que toca repasar (ISO date).
  final String dueDate;

  /// Número de repasos acertados consecutivos.
  final int streak;

  /// Última vez que se estudió (ISO date, "" si nunca).
  final String lastReviewed;

  const VerseMemoryState({
    required this.level,
    required this.ease,
    required this.dueDate,
    required this.streak,
    required this.lastReviewed,
  });

  const VerseMemoryState.initial()
      : level = 0,
        ease = 2.5,
        dueDate = '',
        streak = 0,
        lastReviewed = '';

  VerseMemoryState copyWith({
    int? level,
    double? ease,
    String? dueDate,
    int? streak,
    String? lastReviewed,
  }) {
    return VerseMemoryState(
      level: level ?? this.level,
      ease: ease ?? this.ease,
      dueDate: dueDate ?? this.dueDate,
      streak: streak ?? this.streak,
      lastReviewed: lastReviewed ?? this.lastReviewed,
    );
  }

  Map<String, dynamic> toJson() => {
        'level': level,
        'ease': ease,
        'dueDate': dueDate,
        'streak': streak,
        'lastReviewed': lastReviewed,
      };

  factory VerseMemoryState.fromJson(Map<String, dynamic> j) => VerseMemoryState(
        level: (j['level'] as num?)?.toInt() ?? 0,
        ease: (j['ease'] as num?)?.toDouble() ?? 2.5,
        dueDate: (j['dueDate'] as String?) ?? '',
        streak: (j['streak'] as num?)?.toInt() ?? 0,
        lastReviewed: (j['lastReviewed'] as String?) ?? '',
      );
}

// ═══════════════════════════════════════════════════════════════════════════
// LEARNING PROGRESS (XP / nivel / hearts)
// ═══════════════════════════════════════════════════════════════════════════

/// 10 niveles espirituales. Cada nivel requiere XP acumulado creciente.
enum SpiritualLevel {
  semilla,     // 0 XP
  brote,       // 50
  raiz,        // 150
  tronco,      // 350
  rama,        // 700
  hoja,        // 1200
  flor,        // 2000
  fruto,       // 3200
  cosecha,     // 5000
  siervoFiel,  // 7500
}

extension SpiritualLevelInfo on SpiritualLevel {
  String get displayName {
    switch (this) {
      case SpiritualLevel.semilla:    return 'Semilla';
      case SpiritualLevel.brote:      return 'Brote';
      case SpiritualLevel.raiz:       return 'Raíz';
      case SpiritualLevel.tronco:     return 'Tronco';
      case SpiritualLevel.rama:       return 'Rama';
      case SpiritualLevel.hoja:       return 'Hoja';
      case SpiritualLevel.flor:       return 'Flor';
      case SpiritualLevel.fruto:      return 'Fruto';
      case SpiritualLevel.cosecha:    return 'Cosecha';
      case SpiritualLevel.siervoFiel: return 'Siervo fiel';
    }
  }

  int get xpRequired {
    switch (this) {
      case SpiritualLevel.semilla:    return 0;
      case SpiritualLevel.brote:      return 50;
      case SpiritualLevel.raiz:       return 150;
      case SpiritualLevel.tronco:     return 350;
      case SpiritualLevel.rama:       return 700;
      case SpiritualLevel.hoja:       return 1200;
      case SpiritualLevel.flor:       return 2000;
      case SpiritualLevel.fruto:      return 3200;
      case SpiritualLevel.cosecha:    return 5000;
      case SpiritualLevel.siervoFiel: return 7500;
    }
  }

  String get emoji {
    switch (this) {
      case SpiritualLevel.semilla:    return '🌱';
      case SpiritualLevel.brote:      return '🌿';
      case SpiritualLevel.raiz:       return '🍃';
      case SpiritualLevel.tronco:     return '🌳';
      case SpiritualLevel.rama:       return '🌴';
      case SpiritualLevel.hoja:       return '🍀';
      case SpiritualLevel.flor:       return '🌸';
      case SpiritualLevel.fruto:      return '🍇';
      case SpiritualLevel.cosecha:    return '🌾';
      case SpiritualLevel.siervoFiel: return '👑';
    }
  }

  static SpiritualLevel forXp(int xp) {
    SpiritualLevel current = SpiritualLevel.semilla;
    for (final lvl in SpiritualLevel.values) {
      if (xp >= lvl.xpRequired) current = lvl;
    }
    return current;
  }

  /// Siguiente nivel (o null si es el máximo).
  SpiritualLevel? get next {
    final i = index + 1;
    if (i >= SpiritualLevel.values.length) return null;
    return SpiritualLevel.values[i];
  }
}

@immutable
class LearningProgress {
  /// XP acumulado total.
  final int totalXp;

  /// Sesiones "Maná" completadas.
  final int sessionsCompleted;

  /// Versículos en nivel 5 (dominados).
  final int versesMastered;

  /// Corazones disponibles hoy (se regeneran a 3 cada día).
  final int hearts;

  /// Fecha (ISO) en que se regeneraron los hearts.
  final String heartsRefillDate;

  /// Última fecha en que se cerró una sesión (para streak de estudio).
  final String lastStudyDate;

  /// Racha de días estudiando.
  final int studyStreak;

  const LearningProgress({
    required this.totalXp,
    required this.sessionsCompleted,
    required this.versesMastered,
    required this.hearts,
    required this.heartsRefillDate,
    required this.lastStudyDate,
    required this.studyStreak,
  });

  const LearningProgress.initial()
      : totalXp = 0,
        sessionsCompleted = 0,
        versesMastered = 0,
        hearts = 3,
        heartsRefillDate = '',
        lastStudyDate = '',
        studyStreak = 0;

  SpiritualLevel get level => SpiritualLevelInfo.forXp(totalXp);

  /// Progreso 0..1 hacia el siguiente nivel.
  double get progressToNext {
    final curr = level;
    final next = curr.next;
    if (next == null) return 1.0;
    final span = next.xpRequired - curr.xpRequired;
    if (span <= 0) return 1.0;
    final within = (totalXp - curr.xpRequired).clamp(0, span);
    return within / span;
  }

  LearningProgress copyWith({
    int? totalXp,
    int? sessionsCompleted,
    int? versesMastered,
    int? hearts,
    String? heartsRefillDate,
    String? lastStudyDate,
    int? studyStreak,
  }) {
    return LearningProgress(
      totalXp: totalXp ?? this.totalXp,
      sessionsCompleted: sessionsCompleted ?? this.sessionsCompleted,
      versesMastered: versesMastered ?? this.versesMastered,
      hearts: hearts ?? this.hearts,
      heartsRefillDate: heartsRefillDate ?? this.heartsRefillDate,
      lastStudyDate: lastStudyDate ?? this.lastStudyDate,
      studyStreak: studyStreak ?? this.studyStreak,
    );
  }

  Map<String, dynamic> toJson() => {
        'totalXp': totalXp,
        'sessionsCompleted': sessionsCompleted,
        'versesMastered': versesMastered,
        'hearts': hearts,
        'heartsRefillDate': heartsRefillDate,
        'lastStudyDate': lastStudyDate,
        'studyStreak': studyStreak,
      };

  factory LearningProgress.fromJson(Map<String, dynamic> j) => LearningProgress(
        totalXp: (j['totalXp'] as num?)?.toInt() ?? 0,
        sessionsCompleted: (j['sessionsCompleted'] as num?)?.toInt() ?? 0,
        versesMastered: (j['versesMastered'] as num?)?.toInt() ?? 0,
        hearts: (j['hearts'] as num?)?.toInt() ?? 3,
        heartsRefillDate: (j['heartsRefillDate'] as String?) ?? '',
        lastStudyDate: (j['lastStudyDate'] as String?) ?? '',
        studyStreak: (j['studyStreak'] as num?)?.toInt() ?? 0,
      );
}
