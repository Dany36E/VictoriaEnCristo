/// Decodificador de códigos morfológicos para griego (Robinson/SBLGNT)
/// y hebreo (OSHB).
library;
import '../models/bible/interlinear_word.dart';

class MorphDecoder {
  MorphDecoder._();

  /// Decodifica un código morfológico a MorphAnalysis.
  /// [code] ejemplo griego: "N-----NSM-" o "V-PAI-3S"
  /// [code] ejemplo hebreo: "HVqp3ms" o "HNcmpa"
  static MorphAnalysis decode(String code) {
    if (code.isEmpty) {
      return const MorphAnalysis(partOfSpeech: 'Desconocido');
    }

    // Hebreo (comienza con H)
    if (code.startsWith('H')) {
      return _decodeHebrew(code);
    }

    // Griego (formato MorphGNT: POS + parse code)
    return _decodeGreek(code);
  }

  // ═══ GRIEGO (MorphGNT SBLGNT) ═══

  static MorphAnalysis _decodeGreek(String code) {
    // MorphGNT format: 2-char POS + 8-char parse
    // e.g., "N-" + "----NSM-" or "V-" + "PAI-3S--"
    if (code.length < 2) {
      return MorphAnalysis(partOfSpeech: _greekPOS[code] ?? code);
    }

    final posCode = code.substring(0, 2).replaceAll('-', '');
    final pos = _greekPOS[posCode] ?? _greekPOS[code[0]] ?? posCode;

    if (code.length < 10) {
      return MorphAnalysis(partOfSpeech: pos);
    }

    final parse = code.substring(2);

    // For verbs: T V M - P N --
    if (posCode == 'V' || code[0] == 'V') {
      return MorphAnalysis(
        partOfSpeech: pos,
        tense: _greekTense[parse[0]],
        voice: _greekVoice[parse[1]],
        mood: _greekMood[parse[2]],
        person: _greekPerson[parse[4]],
        grammaticalNumber: _greekNumber[parse[5]],
      );
    }

    // For nouns/adjectives/articles/pronouns: ----CNGD
    return MorphAnalysis(
      partOfSpeech: pos,
      grammaticalCase: _greekCase[parse[4]],
      grammaticalNumber: _greekNumber[parse[5]],
      gender: _greekGender[parse[6]],
    );
  }

  // ═══ HEBREO (OSHB) ═══

  static MorphAnalysis _decodeHebrew(String code) {
    // Format: H{POS}{details} e.g. "HVqp3ms", "HNcmpa", "HR/Ncfsa"
    // Remove H prefix and handle compound forms (/)
    final parts = code.substring(1).split('/');
    final main = parts.last; // Take the main word element

    if (main.isEmpty) {
      return const MorphAnalysis(partOfSpeech: 'Desconocido');
    }

    final posChar = main[0];
    final pos = _hebrewPOS[posChar] ?? posChar;

    if (main.length < 2) {
      return MorphAnalysis(partOfSpeech: pos);
    }

    // Verbs: V{stem}{conj}{person}{gender}{number}
    if (posChar == 'V' && main.length >= 4) {
      return MorphAnalysis(
        partOfSpeech: pos,
        tense: _hebrewStem[main[1]],
        mood: _hebrewConjugation[main[2]],
        person: main.length > 3 ? _hebrewPerson[main[3]] : null,
        gender: main.length > 4 ? _hebrewGender[main[4]] : null,
        grammaticalNumber: main.length > 5 ? _hebrewNumber[main[5]] : null,
      );
    }

    // Nouns/adjectives: N{type}{gender}{number}{state}
    if ((posChar == 'N' || posChar == 'A') && main.length >= 3) {
      return MorphAnalysis(
        partOfSpeech: pos,
        gender: _hebrewGender[main[2]],
        grammaticalNumber: main.length > 3 ? _hebrewNumber[main[3]] : null,
        grammaticalCase: main.length > 4 ? _hebrewState[main[4]] : null,
      );
    }

    return MorphAnalysis(partOfSpeech: pos);
  }

  // ═══ LOOKUP TABLES ═══

  static const _greekPOS = <String, String>{
    'N': 'Sustantivo',
    'V': 'Verbo',
    'A': 'Adjetivo',
    'D': 'Adverbio',
    'P': 'Preposición',
    'R': 'Pronombre',
    'C': 'Conjunción',
    'T': 'Artículo',
    'I': 'Interjección',
    'X': 'Partícula',
    'RA': 'Artículo',
    'RD': 'Pronombre demostrativo',
    'RP': 'Pronombre personal',
    'RR': 'Pronombre relativo',
    'RI': 'Pronombre interrogativo',
  };

  static const _greekTense = <String, String>{
    'P': 'Presente',
    'I': 'Imperfecto',
    'F': 'Futuro',
    'A': 'Aoristo',
    'X': 'Perfecto',
    'Y': 'Pluscuamperfecto',
  };

  static const _greekVoice = <String, String>{
    'A': 'Activa',
    'M': 'Media',
    'P': 'Pasiva',
  };

  static const _greekMood = <String, String>{
    'I': 'Indicativo',
    'S': 'Subjuntivo',
    'O': 'Optativo',
    'M': 'Imperativo',
    'N': 'Infinitivo',
    'P': 'Participio',
  };

  static const _greekPerson = <String, String>{
    '1': '1ra persona',
    '2': '2da persona',
    '3': '3ra persona',
  };

  static const _greekNumber = <String, String>{
    'S': 'Singular',
    'P': 'Plural',
  };

  static const _greekGender = <String, String>{
    'M': 'Masculino',
    'F': 'Femenino',
    'N': 'Neutro',
  };

  static const _greekCase = <String, String>{
    'N': 'Nominativo',
    'G': 'Genitivo',
    'D': 'Dativo',
    'A': 'Acusativo',
    'V': 'Vocativo',
  };

  // Hebreo
  static const _hebrewPOS = <String, String>{
    'N': 'Sustantivo',
    'V': 'Verbo',
    'A': 'Adjetivo',
    'R': 'Pronombre',
    'T': 'Partícula',
    'D': 'Adverbio',
    'P': 'Preposición',
    'C': 'Conjunción',
    'S': 'Sufijo',
  };

  static const _hebrewStem = <String, String>{
    'q': 'Qal',
    'N': 'Nifal',
    'p': 'Piel',
    'P': 'Pual',
    'h': 'Hifil',
    'H': 'Hofal',
    't': 'Hitpael',
  };

  static const _hebrewConjugation = <String, String>{
    'p': 'Perfecto',
    'i': 'Imperfecto',
    'w': 'Consecutivo',
    'v': 'Imperativo',
    'a': 'Participio activo',
    's': 'Participio pasivo',
    'c': 'Constructo infinitivo',
    'r': 'Absoluto infinitivo',
  };

  static const _hebrewPerson = <String, String>{
    '1': '1ra persona',
    '2': '2da persona',
    '3': '3ra persona',
  };

  static const _hebrewGender = <String, String>{
    'm': 'Masculino',
    'f': 'Femenino',
    'b': 'Ambos',
    'c': 'Común',
  };

  static const _hebrewNumber = <String, String>{
    's': 'Singular',
    'p': 'Plural',
    'd': 'Dual',
  };

  static const _hebrewState = <String, String>{
    'a': 'Absoluto',
    'c': 'Constructo',
    'd': 'Determinado',
  };
}
