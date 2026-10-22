/// Etiquetas «#palabra» dentro de los apuntes, como en Notas de Apple:
/// se escriben en el texto y sirven para filtrar la lista.
library;

final RegExp _etiqueta = RegExp(
  r'(?<![\p{L}\p{N}_])#([\p{L}\p{N}_]{2,30})',
  unicode: true,
);

/// Etiquetas de [texto], en minúsculas y sin repetir, en orden de aparición.
List<String> etiquetasDe(String texto) {
  final vistas = <String>{};
  for (final m in _etiqueta.allMatches(texto)) {
    vistas.add(m.group(1)!.toLowerCase());
  }
  return vistas.toList(growable: false);
}

/// Dónde está cada etiqueta en [texto] (con el «#»), para colorearla.
List<(int, int)> rangosEtiquetas(String texto) => [
  for (final m in _etiqueta.allMatches(texto)) (m.start, m.end),
];
