/// Versión/traducción bíblica disponible.
enum BibleVersion {
  rvr1960(
    id: 'RVR1960',
    displayName: 'Reina-Valera 1960',
    shortName: 'RVR60',
    fileName: 'Reina Valera 1960.xml',
  ),
  nvi(
    id: 'NVI',
    displayName: 'Nueva Versión Internacional',
    shortName: 'NVI',
    fileName: 'NVI.xml',
  ),
  lbla(
    id: 'LBLA',
    displayName: 'La Biblia de las Américas',
    shortName: 'LBLA',
    fileName: 'LBLA.xml',
  ),
  ntv(
    id: 'NTV',
    displayName: 'Nueva Traducción Viviente',
    shortName: 'NTV',
    fileName: 'NTV.xml',
  ),
  tla(
    id: 'TLA',
    displayName: 'Traducción en Lenguaje Actual',
    shortName: 'TLA',
    fileName: 'TLA.xml',
  );

  final String id;
  final String displayName;
  final String shortName;
  final String fileName;

  const BibleVersion({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.fileName,
  });

  /// Buscar versión por ID
  static BibleVersion fromId(String id) {
    return BibleVersion.values.firstWhere(
      (v) => v.id == id,
      orElse: () => BibleVersion.rvr1960,
    );
  }
}
