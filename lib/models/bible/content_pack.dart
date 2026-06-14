/// Paquete de contenido descargable on-demand.
///
/// Los archivos de cada pack se almacenan en:
///   `{appDocDir}/content_packs/{subdirectory}/`
///
/// Las ZIPs se descargan desde URLs en Firestore `/config/bibleDownloads`
/// bajo la clave `firestoreKey`. La descarga real requiere el paquete
/// `archive` (pendiente de confirmación en pubspec.yaml).
enum ContentPack {
  guzikCommentary(
    id: 'guzik_commentary',
    displayName: 'Comentario Guzik',
    subdirectory: 'guzik',
    firestoreKey: 'guzikCommentaryUrl',
    estimatedSizeMb: 25,
  ),
  interlinearGreek(
    id: 'interlinear_greek',
    displayName: 'Interlineal Griego (NT)',
    subdirectory: 'interlinear_greek',
    firestoreKey: 'interlinearGreekUrl',
    estimatedSizeMb: 14,
  ),
  interlinearHebrew(
    id: 'interlinear_hebrew',
    displayName: 'Interlineal Hebreo (AT)',
    subdirectory: 'interlinear_hebrew',
    firestoreKey: 'interlinearHebrewUrl',
    estimatedSizeMb: 15,
  );

  const ContentPack({
    required this.id,
    required this.displayName,
    required this.subdirectory,
    required this.firestoreKey,
    required this.estimatedSizeMb,
  });

  final String id;
  final String displayName;
  final String subdirectory;
  final String firestoreKey;
  final int estimatedSizeMb;
}
