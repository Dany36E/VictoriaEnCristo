import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';
import '../../models/bible/bible_version.dart';
import 'bible_parser_service.dart';

/// Resultado de concordancia: referencia + snippet del versículo
class ConcordanceResult {
  final int bookNumber;
  final String bookName;
  final int chapter;
  final int verse;
  final String snippet;

  const ConcordanceResult({
    required this.bookNumber,
    required this.bookName,
    required this.chapter,
    required this.verse,
    required this.snippet,
  });

  String get reference => '$bookName $chapter:$verse';

  Map<String, dynamic> toJson() => {
        'b': bookNumber,
        'n': bookName,
        'c': chapter,
        'v': verse,
        's': snippet,
      };

  factory ConcordanceResult.fromJson(Map<String, dynamic> j) =>
      ConcordanceResult(
        bookNumber: j['b'] as int,
        bookName: j['n'] as String,
        chapter: j['c'] as int,
        verse: j['v'] as int,
        snippet: j['s'] as String,
      );
}

/// ═══════════════════════════════════════════════════════════════════════════
/// BIBLE CONCORDANCE SERVICE - Singleton
///
/// Busca una palabra en TODA la Biblia (versión activa).
/// No genera índice invertido persistente — hace búsqueda lineal
/// en el XML parseado (ya en memoria gracias a BibleParserService).
/// Resultados agrupados por libro.
/// ═══════════════════════════════════════════════════════════════════════════
class BibleConcordanceService {
  static final BibleConcordanceService _instance =
      BibleConcordanceService._internal();
  factory BibleConcordanceService() => _instance;
  static BibleConcordanceService get I => _instance;
  BibleConcordanceService._internal();

  /// Buscar una palabra en toda la Biblia.
  /// Retorna lista de resultados agrupables por libro.
  Future<List<ConcordanceResult>> searchWord(
    String word,
    BibleVersion version, {
    int maxResults = 500,
    bool exactMatch = false,
  }) async {
    if (word.trim().length < 2) return [];
    await BibleParserService.I.ensureVersionLoaded(version);
    final doc = BibleParserService.I.getParsedDoc(version);
    if (doc == null) return [];

    // Ejecutar búsqueda en isolate para no bloquear UI
    final xmlString = doc.toXmlString();
    final results = await compute(_searchInIsolate, _SearchParams(
      xmlString: xmlString,
      word: word.trim(),
      versionId: version.id,
      maxResults: maxResults,
      exactMatch: exactMatch,
    ));
    return results;
  }
}

class _SearchParams {
  final String xmlString;
  final String word;
  final String versionId;
  final int maxResults;
  final bool exactMatch;
  const _SearchParams({
    required this.xmlString,
    required this.word,
    required this.versionId,
    required this.maxResults,
    this.exactMatch = false,
  });
}

/// Nombres canónicos (copia local para isolate)
const Map<int, String> _canonicalNames = {
  1: 'Génesis', 2: 'Éxodo', 3: 'Levítico', 4: 'Números', 5: 'Deuteronomio',
  6: 'Josué', 7: 'Jueces', 8: 'Rut', 9: '1 Samuel', 10: '2 Samuel',
  11: '1 Reyes', 12: '2 Reyes', 13: '1 Crónicas', 14: '2 Crónicas',
  15: 'Esdras', 16: 'Nehemías', 17: 'Ester', 18: 'Job', 19: 'Salmos',
  20: 'Proverbios', 21: 'Eclesiastés', 22: 'Cantares', 23: 'Isaías',
  24: 'Jeremías', 25: 'Lamentaciones', 26: 'Ezequiel', 27: 'Daniel',
  28: 'Oseas', 29: 'Joel', 30: 'Amós', 31: 'Abdías', 32: 'Jonás',
  33: 'Miqueas', 34: 'Nahúm', 35: 'Habacuc', 36: 'Sofonías', 37: 'Hageo',
  38: 'Zacarías', 39: 'Malaquías',
  40: 'Mateo', 41: 'Marcos', 42: 'Lucas', 43: 'Juan', 44: 'Hechos',
  45: 'Romanos', 46: '1 Corintios', 47: '2 Corintios', 48: 'Gálatas',
  49: 'Efesios', 50: 'Filipenses', 51: 'Colosenses',
  52: '1 Tesalonicenses', 53: '2 Tesalonicenses',
  54: '1 Timoteo', 55: '2 Timoteo', 56: 'Tito', 57: 'Filemón',
  58: 'Hebreos', 59: 'Santiago', 60: '1 Pedro', 61: '2 Pedro',
  62: '1 Juan', 63: '2 Juan', 64: '3 Juan', 65: 'Judas', 66: 'Apocalipsis',
};

/// Normaliza texto para búsqueda (minúsculas, sin acentos)
String _normalize(String s) {
  return s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');
}

/// Top-level function para ejecutar en Isolate
List<ConcordanceResult> _searchInIsolate(_SearchParams params) {
  // Parsear el XML dentro del isolate
  final doc = __parseXml(params.xmlString);
  final normalizedWord = _normalize(params.word);
  final results = <ConcordanceResult>[];

  final testaments = doc.rootElement.findAllElements('testament');
  for (final testament in testaments) {
    for (final book in testament.findAllElements('book')) {
      final bookNum = int.parse(book.getAttribute('number')!);
      final bookName = book.getAttribute('name') ??
          _canonicalNames[bookNum] ??
          'Libro $bookNum';

      for (final chapter in book.findAllElements('chapter')) {
        final chapNum = int.parse(chapter.getAttribute('number')!);
        for (final verse in chapter.findAllElements('verse')) {
          final text = verse.innerText;
          final normalizedText = _normalize(text);
          final bool matches;
          if (params.exactMatch) {
            // Word boundary: check character before and after
            int idx = 0;
            bool found = false;
            while (true) {
              final pos = normalizedText.indexOf(normalizedWord, idx);
              if (pos < 0) break;
              final before = pos > 0 ? normalizedText[pos - 1] : ' ';
              final after = pos + normalizedWord.length < normalizedText.length
                  ? normalizedText[pos + normalizedWord.length]
                  : ' ';
              if (!RegExp(r'[a-záéíóúüñ]').hasMatch(before) &&
                  !RegExp(r'[a-záéíóúüñ]').hasMatch(after)) {
                found = true;
                break;
              }
              idx = pos + 1;
            }
            matches = found;
          } else {
            matches = normalizedText.contains(normalizedWord);
          }
          if (matches) {
            results.add(ConcordanceResult(
              bookNumber: bookNum,
              bookName: bookName,
              chapter: chapNum,
              verse: int.parse(verse.getAttribute('number')!),
              snippet: text.length > 120 ? '${text.substring(0, 117)}...' : text,
            ));
            if (results.length >= params.maxResults) return results;
          }
        }
      }
    }
  }
  return results;
}

// Importar xml dentro del isolate (top-level)
XmlDocument __parseXml(String s) => XmlDocument.parse(s);
