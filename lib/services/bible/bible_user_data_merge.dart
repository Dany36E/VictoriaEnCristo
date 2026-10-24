/// ═══════════════════════════════════════════════════════════════════════════
/// Fusión de snapshots de Firestore con la caché local de datos bíblicos.
///
/// Antes cada colección se escuchaba con `.limit(150/200)` y el resultado
/// REEMPLAZABA el mapa completo (y la caché local): los elementos más viejos
/// desaparecían y al volver a guardarlos se creaban duplicados.
///
/// Ahora:
///   - Se escucha la colección completa (sin límite).
///   - Un snapshot del SERVIDOR es la verdad: reemplaza (así los borrados en
///     otro dispositivo también se reflejan).
///   - Un snapshot de CACHÉ (sin red, o la primera emisión) puede estar
///     incompleto: se UNE con lo que ya conocíamos, nunca borra.
///   - Si hay varios documentos para el mismo versículo, gana el más reciente
///     y los demás se devuelven en [MergeResult.duplicateIds] para borrarlos.
///
/// Dart puro para poder probarlo sin Firebase.
/// ═══════════════════════════════════════════════════════════════════════════
library;

class MergeResult<T> {
  /// Mapa final clave-de-versículo → elemento.
  final Map<String, T> items;

  /// IDs de documentos duplicados (más viejos) que conviene borrar.
  final List<String> duplicateIds;

  const MergeResult(this.items, this.duplicateIds);
}

class BibleUserDataMerge {
  BibleUserDataMerge._();

  /// Fusiona [incoming] (documentos del snapshot) con [current].
  ///
  /// [authoritative] = el snapshot viene del servidor (no de caché).
  static MergeResult<T> merge<T>({
    required Map<String, T> current,
    required Iterable<T> incoming,
    required String Function(T) keyOf,
    required String Function(T) idOf,
    required DateTime Function(T) dateOf,
    required bool authoritative,
  }) {
    final result = <String, T>{};
    final duplicates = <String>[];

    for (final item in incoming) {
      final key = keyOf(item);
      final previous = result[key];
      if (previous == null) {
        result[key] = item;
        continue;
      }
      if (idOf(previous) == idOf(item)) continue;
      // Duplicado: conservar el más reciente.
      if (dateOf(item).isAfter(dateOf(previous))) {
        duplicates.add(idOf(previous));
        result[key] = item;
      } else {
        duplicates.add(idOf(item));
      }
    }

    if (!authoritative) {
      // Caché posiblemente incompleta: conservar lo ya conocido que no venga.
      current.forEach((key, value) {
        result.putIfAbsent(key, () => value);
      });
      // Solo el servidor decide qué borrar.
      return MergeResult(result, const []);
    }
    return MergeResult(result, duplicates);
  }

  /// Lista ordenada (más reciente primero) a partir del mapa fusionado.
  static List<T> sortedByDateDesc<T>(
    Map<String, T> items,
    DateTime Function(T) dateOf,
  ) {
    final list = items.values.toList()
      ..sort((a, b) => dateOf(b).compareTo(dateOf(a)));
    return list;
  }
}
