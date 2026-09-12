enum BibleLanguage {
  spanish(code: 'es', label: 'Español', ttsLocale: 'es-MX'),
  english(code: 'en', label: 'English', ttsLocale: 'en-US');

  final String code;
  final String label;
  final String ttsLocale;

  const BibleLanguage({
    required this.code,
    required this.label,
    required this.ttsLocale,
  });
}

/// Versión/traducción bíblica disponible.
enum BibleVersion {
  rvr1960(
    id: 'RVR1960',
    displayName: 'Reina-Valera 1960',
    shortName: 'RVR60',
    fileName: 'Reina Valera 1960.xml',
    language: BibleLanguage.spanish,
  ),
  nvi(
    id: 'NVI',
    displayName: 'Nueva Versión Internacional',
    shortName: 'NVI',
    fileName: 'NVI.xml',
    language: BibleLanguage.spanish,
  ),
  lbla(
    id: 'LBLA',
    displayName: 'La Biblia de las Américas',
    shortName: 'LBLA',
    fileName: 'LBLA.xml',
    language: BibleLanguage.spanish,
  ),
  ntv(
    id: 'NTV',
    displayName: 'Nueva Traducción Viviente',
    shortName: 'NTV',
    fileName: 'NTV.xml',
    language: BibleLanguage.spanish,
  ),
  tla(
    id: 'TLA',
    displayName: 'Traducción en Lenguaje Actual',
    shortName: 'TLA',
    fileName: 'TLA.xml',
    language: BibleLanguage.spanish,
  ),
  nivEnglish(
    id: 'NIV_EN',
    displayName: 'New International Version',
    shortName: 'NIV',
    fileName: 'NIV.xml',
    language: BibleLanguage.english,
  ),
  nlt(
    id: 'NLT',
    displayName: 'New Living Translation',
    shortName: 'NLT',
    fileName: 'NLT.xml',
    language: BibleLanguage.english,
  ),
  nkjv(
    id: 'NKJV',
    displayName: 'New King James Version',
    shortName: 'NKJV',
    fileName: 'NKJV.xml',
    language: BibleLanguage.english,
  );

  final String id;
  final String displayName;
  final String shortName;
  final String fileName;
  final BibleLanguage language;

  const BibleVersion({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.fileName,
    required this.language,
  });

  bool get isEnglish => language == BibleLanguage.english;

  static List<BibleVersion> forLanguage(BibleLanguage language) => BibleVersion
      .values
      .where((version) => version.language == language)
      .toList(growable: false);

  /// Buscar versión por ID
  static BibleVersion fromId(String id) {
    return BibleVersion.values.firstWhere(
      (v) => v.id == id,
      orElse: () => BibleVersion.rvr1960,
    );
  }
}
