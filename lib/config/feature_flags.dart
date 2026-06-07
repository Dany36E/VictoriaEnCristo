library;

/// Flags de producto para apagar funciones costosas sin desmantelar todo el
/// código de una sola vez.
class FeatureFlags {
  FeatureFlags._();

  /// Las insignias globales quedan deshabilitadas para evitar lecturas y
  /// suscripciones adicionales en Firestore.
  static const bool badgesEnabled = false;

  /// La capa de Talentos/Coleccionables también queda fuera del flujo normal.
  /// Conservamos el código por compatibilidad local, pero sin sincronización
  /// cloud ni entrypoints visibles.
  static const bool learningCollectiblesEnabled = false;
}
