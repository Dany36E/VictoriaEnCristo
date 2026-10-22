/// Listas de Notas escritas como prefijo de cada línea: viñetas («• »),
/// numeradas («1. ») y de tareas («☐ » / «☑ »), como en Notas de Apple.
library;

enum TipoLista { vinetas, numerada, tareas }

const String marcaVineta = '• ';
const String tareaPendiente = '☐ ';
const String tareaHecha = '☑ ';

final RegExp _numerada = RegExp(r'^(\d{1,3})\. ');

/// Reemplaza [inicio, fin) por [texto].
class EdicionTexto {
  final int inicio;
  final int fin;
  final String texto;

  const EdicionTexto(this.inicio, this.fin, this.texto);

  @override
  String toString() => 'EdicionTexto($inicio, $fin, "$texto")';
}

/// Ediciones (de la última a la primera) y dónde queda el cursor.
class ResultadoEdicion {
  final List<EdicionTexto> ediciones;
  final int cursor;

  const ResultadoEdicion(this.ediciones, this.cursor);

  String aplicarA(String texto) {
    var t = texto;
    for (final e in ediciones) {
      t = t.replaceRange(e.inicio, e.fin, e.texto);
    }
    return t;
  }
}

class ListaDeLinea {
  final TipoLista tipo;
  final int largo;
  final bool hecha;
  final int numero;

  const ListaDeLinea(this.tipo, this.largo, {this.hecha = false, this.numero = 0});
}

int inicioDeLinea(String texto, int offset) {
  final o = offset.clamp(0, texto.length);
  return o == 0 ? 0 : texto.lastIndexOf('\n', o - 1) + 1;
}

int finDeLinea(String texto, int offset) {
  final i = texto.indexOf('\n', offset.clamp(0, texto.length));
  return i == -1 ? texto.length : i;
}

/// Lista de la línea que empieza en [inicio], o null.
ListaDeLinea? listaEn(String texto, int inicio) {
  final resto = texto.substring(inicio);
  if (resto.startsWith(marcaVineta)) {
    return const ListaDeLinea(TipoLista.vinetas, 2);
  }
  if (resto.startsWith(tareaPendiente)) {
    return const ListaDeLinea(TipoLista.tareas, 2);
  }
  if (resto.startsWith(tareaHecha)) {
    return const ListaDeLinea(TipoLista.tareas, 2, hecha: true);
  }
  final m = _numerada.firstMatch(resto);
  if (m != null) {
    return ListaDeLinea(
      TipoLista.numerada,
      m.group(0)!.length,
      numero: int.parse(m.group(1)!),
    );
  }
  return null;
}

/// Inicios de las líneas que toca [inicio, fin).
List<int> lineasTocadas(String texto, int inicio, int fin) {
  final lineas = <int>[inicioDeLinea(texto, inicio)];
  var i = texto.indexOf('\n', lineas.first);
  while (i != -1 && i < fin) {
    lineas.add(i + 1);
    i = texto.indexOf('\n', i + 1);
  }
  return lineas;
}

/// Pone o quita [tipo] en las líneas seleccionadas. Si todas ya son de ese
/// tipo, se quita; si no, se pone (reemplazando otra lista).
ResultadoEdicion alternarLista(
  String texto,
  int inicio,
  int fin,
  TipoLista tipo,
) {
  final lineas = lineasTocadas(texto, inicio, fin);
  final todas = lineas.every((l) => listaEn(texto, l)?.tipo == tipo);
  final ediciones = <EdicionTexto>[];
  var numero = 1;
  var cursor = inicio;
  for (final l in lineas) {
    final actual = listaEn(texto, l);
    final quitar = actual?.largo ?? 0;
    final poner = todas
        ? ''
        : switch (tipo) {
            TipoLista.vinetas => marcaVineta,
            TipoLista.tareas =>
              actual?.tipo == TipoLista.tareas && actual!.hecha
                  ? tareaHecha
                  : tareaPendiente,
            TipoLista.numerada => '${numero++}. ',
          };
    ediciones.add(EdicionTexto(l, l + quitar, poner));
    if (l <= inicio) cursor += poner.length - quitar;
  }
  final orden = ediciones.reversed.toList();
  final largo = ResultadoEdicion(orden, 0).aplicarA(texto).length;
  return ResultadoEdicion(orden, cursor.clamp(0, largo));
}

/// Tras un salto de línea (el cursor está justo después del «\n»): sigue
/// la lista en la línea nueva, o la termina si el elemento quedó vacío.
ResultadoEdicion? continuarLista(String texto, int cursor) {
  if (cursor <= 0 || cursor > texto.length || texto[cursor - 1] != '\n') {
    return null;
  }
  final inicioPrevia = inicioDeLinea(texto, cursor - 1);
  final lista = listaEn(texto, inicioPrevia);
  if (lista == null) return null;
  final contenido = texto.substring(inicioPrevia + lista.largo, cursor - 1);
  if (contenido.trim().isEmpty) {
    // Elemento vacío: se quita la marca y el salto, como en Notas.
    return ResultadoEdicion([EdicionTexto(inicioPrevia, cursor, '')], inicioPrevia);
  }
  final marca = switch (lista.tipo) {
    TipoLista.vinetas => marcaVineta,
    TipoLista.tareas => tareaPendiente,
    TipoLista.numerada => '${lista.numero + 1}. ',
  };
  return ResultadoEdicion([EdicionTexto(cursor, cursor, marca)], cursor + marca.length);
}

/// Si [offset] cae sobre la casilla de una tarea, la marca o desmarca y deja
/// el cursor al final de esa línea.
ResultadoEdicion? alternarTareaEn(String texto, int offset) {
  final inicio = inicioDeLinea(texto, offset);
  final lista = listaEn(texto, inicio);
  if (lista?.tipo != TipoLista.tareas || offset > inicio + 2) return null;
  final nueva = lista!.hecha ? tareaPendiente : tareaHecha;
  return ResultadoEdicion(
    [EdicionTexto(inicio, inicio + 2, nueva)],
    finDeLinea(texto, inicio),
  );
}
