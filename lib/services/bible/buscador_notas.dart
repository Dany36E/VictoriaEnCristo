import '../../models/bible/bible_note.dart';
import '../../models/bible/bosquejo_sermon.dart';
import '../../models/bible/chapter_study_note.dart';
import '../../models/bible/etiquetas_nota.dart';
import '../../models/bible/rich_note_document.dart';
import '../../models/bible/sermon_note.dart';
import '../../models/bible/study_chapter_answers.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// BUSCADOR DE NOTAS — busca a la vez en todo lo que el usuario escribió:
/// notas de capítulo, apuntes de predicación, Modo Estudio, notas de
/// versículo y bosquejos. Sin acentos ni mayúsculas («efesios» encuentra
/// «Efesios», «gracia» encuentra «GRACIA»). Lógica pura: se prueba sin
/// Firebase.
/// ═══════════════════════════════════════════════════════════════════════════

enum TipoNotaBuscada { capitulo, apunte, estudio, versiculo, bosquejo }

extension TipoNotaBuscadaTexto on TipoNotaBuscada {
  String get etiqueta => switch (this) {
    TipoNotaBuscada.capitulo => 'Nota de capítulo',
    TipoNotaBuscada.apunte => 'Apunte',
    TipoNotaBuscada.estudio => 'Modo Estudio',
    TipoNotaBuscada.versiculo => 'Nota de versículo',
    TipoNotaBuscada.bosquejo => 'Bosquejo',
  };
}

class ResultadoNota {
  final TipoNotaBuscada tipo;

  /// Id de la nota en su servicio (para abrirla).
  final String id;
  final String titulo;
  final String referencia;

  /// Trozo del texto alrededor de la coincidencia.
  final String fragmento;

  /// Dónde está la coincidencia dentro de [fragmento] (fin exclusivo);
  /// -1 si coincidió por la etiqueta o no hay consulta.
  final int inicio;
  final int fin;
  final List<String> etiquetas;
  final DateTime fecha;

  /// La nota original (ChapterStudyNote, SermonNote, …).
  final Object origen;

  const ResultadoNota({
    required this.tipo,
    required this.id,
    required this.titulo,
    required this.referencia,
    required this.fragmento,
    required this.inicio,
    required this.fin,
    required this.etiquetas,
    required this.fecha,
    required this.origen,
  });

  bool get tieneResaltado => inicio >= 0 && fin > inicio;
}

/// Marca de las notas de versículo que copia el Modo Estudio (ya aparecen
/// como resultado de «Modo Estudio»; no se repiten).
const String _marcaEspejoEstudio = '⟦modo-estudio⟧';

class BuscadorNotas {
  BuscadorNotas._();

  static const _acentos = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', //
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e', //
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i', //
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', //
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u', //
    'ñ': 'n',
  };

  /// Minúsculas y sin acentos, carácter por carácter: el resultado mide lo
  /// mismo que [texto], así que las posiciones sirven para el original.
  static String normalizar(String texto) {
    final b = StringBuffer();
    for (final unidad in texto.split('')) {
      final bajo = unidad.toLowerCase();
      final c = bajo.length == 1 ? bajo : unidad;
      b.write(_acentos[c] ?? c);
    }
    return b.toString();
  }

  /// Trozo de [texto] alrededor de la primera aparición de [consulta]
  /// (ya normalizada). Null si no aparece.
  static ({String fragmento, int inicio, int fin})? fragmento(
    String texto,
    String consulta, {
    int contexto = 60,
  }) {
    if (consulta.isEmpty) return null;
    final limpio = texto.replaceAll(kMarcaAdjunto, ' ').replaceAll('\n', ' ');
    final i = normalizar(limpio).indexOf(consulta);
    if (i < 0) return null;
    var desde = (i - contexto).clamp(0, limpio.length);
    var hasta = (i + consulta.length + contexto).clamp(0, limpio.length);
    // Cortar en un espacio para no partir palabras.
    if (desde > 0) {
      final espacio = limpio.indexOf(' ', desde);
      if (espacio >= 0 && espacio < i) desde = espacio + 1;
    }
    if (hasta < limpio.length) {
      final espacio = limpio.lastIndexOf(' ', hasta);
      if (espacio > i + consulta.length) hasta = espacio;
    }
    final prefijo = desde > 0 ? '…' : '';
    final sufijo = hasta < limpio.length ? '…' : '';
    final trozo = '$prefijo${limpio.substring(desde, hasta)}$sufijo';
    final inicio = i - desde + prefijo.length;
    return (fragmento: trozo, inicio: inicio, fin: inicio + consulta.length);
  }

  static String _inicioDe(String texto, {int largo = 140}) {
    final limpio = texto
        .replaceAll(kMarcaAdjunto, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return limpio.length <= largo ? limpio : '${limpio.substring(0, largo)}…';
  }

  /// Busca [consulta] en todas las notas. Con [etiqueta], solo las notas que
  /// la llevan (sirve también con la consulta vacía). Sin consulta ni
  /// etiqueta, no devuelve nada.
  static List<ResultadoNota> buscar(
    String consulta, {
    String? etiqueta,
    Iterable<ChapterStudyNote> notasCapitulo = const [],
    Iterable<SermonNote> apuntes = const [],
    Iterable<StudyChapterAnswers> estudios = const [],
    Iterable<BibleNote> notasVersiculo = const [],
    Iterable<BosquejoSermon> bosquejos = const [],
  }) {
    final q = normalizar(consulta.trim());
    final filtro = etiqueta?.toLowerCase();
    if (q.isEmpty && filtro == null) return const [];
    final resultados = <ResultadoNota>[];

    void probar({
      required TipoNotaBuscada tipo,
      required String id,
      required String titulo,
      required String referencia,
      required String cuerpo,
      required List<String> etiquetas,
      required DateTime fecha,
      required Object origen,
    }) {
      if (filtro != null && !etiquetas.contains(filtro)) return;
      ({String fragmento, int inicio, int fin})? hallado;
      if (q.isNotEmpty) {
        hallado =
            fragmento(cuerpo, q) ??
            fragmento(titulo, q) ??
            fragmento(referencia, q);
        final porEtiqueta = etiquetas.any((e) => normalizar(e).contains(q));
        if (hallado == null && !porEtiqueta) return;
      }
      resultados.add(
        ResultadoNota(
          tipo: tipo,
          id: id,
          titulo: titulo,
          referencia: referencia,
          fragmento: hallado?.fragmento ?? _inicioDe(cuerpo),
          inicio: hallado?.inicio ?? -1,
          fin: hallado?.fin ?? -1,
          etiquetas: etiquetas,
          fecha: fecha,
          origen: origen,
        ),
      );
    }

    for (final n in notasCapitulo) {
      // Las copias que hace el Modo Estudio ya salen como «Modo Estudio».
      if (n.tags.contains('modo-estudio')) continue;
      probar(
        tipo: TipoNotaBuscada.capitulo,
        id: n.id,
        titulo: n.title.trim().isEmpty ? n.reference : n.title.trim(),
        referencia: n.reference,
        cuerpo: n.content,
        etiquetas: {
          ...n.tags.map((t) => t.toLowerCase()),
          ...etiquetasDe('${n.title}\n${n.content}'),
        }.toList(),
        fecha: n.updatedAt,
        origen: n,
      );
    }

    for (final a in apuntes) {
      final notas = richNotePlainText(a.notes);
      final cuerpo = [
        notas,
        a.takeaway,
        a.speaker,
        for (final adj in a.adjuntos) adj.pie,
        for (final v in a.verses) '${v.reference} ${v.text}',
      ].where((t) => t.trim().isNotEmpty).join('\n');
      probar(
        tipo: TipoNotaBuscada.apunte,
        id: a.id,
        titulo: a.title.trim().isEmpty ? 'Apunte sin título' : a.title.trim(),
        referencia: a.centralPassage?.label ?? '',
        cuerpo: cuerpo,
        etiquetas: etiquetasDe('${a.title}\n$notas\n${a.takeaway}'),
        fecha: a.updatedAt,
        origen: a,
      );
    }

    for (final e in estudios) {
      final general = richNotePlainText(e.generalNotes);
      final cuerpo = [
        ...e.answers.values,
        general,
        e.hopeMessage,
      ].where((t) => t.trim().isNotEmpty).join('\n');
      probar(
        tipo: TipoNotaBuscada.estudio,
        id: e.chapterKey,
        titulo: 'Estudio · ${e.reference}',
        referencia: e.reference,
        cuerpo: cuerpo,
        etiquetas: etiquetasDe(cuerpo),
        fecha: e.updatedAt,
        origen: e,
      );
    }

    for (final v in notasVersiculo) {
      if (v.text.startsWith(_marcaEspejoEstudio)) continue;
      probar(
        tipo: TipoNotaBuscada.versiculo,
        id: v.verseKey,
        titulo: v.reference,
        referencia: v.reference,
        cuerpo: v.text,
        etiquetas: etiquetasDe(v.text),
        fecha: v.updatedAt,
        origen: v,
      );
    }

    for (final b in bosquejos) {
      probar(
        tipo: TipoNotaBuscada.bosquejo,
        id: b.id,
        titulo: b.tituloVisible,
        referencia: b.textoPrincipal,
        cuerpo: b.textoBuscable,
        etiquetas: etiquetasDe(b.textoBuscable),
        fecha: b.updatedAt,
        origen: b,
      );
    }

    resultados.sort((a, b) => b.fecha.compareTo(a.fecha));
    return resultados;
  }

  /// Todas las etiquetas que hay en las notas, para filtrar.
  static List<String> todasLasEtiquetas({
    Iterable<ChapterStudyNote> notasCapitulo = const [],
    Iterable<SermonNote> apuntes = const [],
    Iterable<BibleNote> notasVersiculo = const [],
  }) {
    final todas = <String>{
      for (final n in notasCapitulo)
        if (!n.tags.contains('modo-estudio')) ...[
          ...n.tags.map((t) => t.toLowerCase()),
          ...etiquetasDe('${n.title}\n${n.content}'),
        ],
      for (final a in apuntes)
        ...etiquetasDe(
          '${a.title}\n${richNotePlainText(a.notes)}\n${a.takeaway}',
        ),
      for (final v in notasVersiculo)
        if (!v.text.startsWith(_marcaEspejoEstudio)) ...etiquetasDe(v.text),
    };
    return todas.toList()..sort();
  }
}
