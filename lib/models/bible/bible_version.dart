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
    copyright: 'Reina-Valera 1960 © Sociedades Bíblicas en América Latina, 1960. Renovado © Sociedades Bíblicas Unidas, 1988.',
  ),
  nvi(
    id: 'NVI',
    displayName: 'Nueva Versión Internacional',
    shortName: 'NVI',
    fileName: 'NVI.xml',
    language: BibleLanguage.spanish,
    copyright: 'Nueva Versión Internacional® © 1999, 2015 por Biblica, Inc.®',
  ),
  lbla(
    id: 'LBLA',
    displayName: 'La Biblia de las Américas',
    shortName: 'LBLA',
    fileName: 'LBLA.xml',
    language: BibleLanguage.spanish,
    copyright: 'La Biblia de las Américas © 1986, 1995, 1997 The Lockman Foundation.',
  ),
  ntv(
    id: 'NTV',
    displayName: 'Nueva Traducción Viviente',
    shortName: 'NTV',
    fileName: 'NTV.xml',
    language: BibleLanguage.spanish,
    copyright: 'Nueva Traducción Viviente © Tyndale House Foundation, 2010.',
  ),
  tla(
    id: 'TLA',
    displayName: 'Traducción en Lenguaje Actual',
    shortName: 'TLA',
    fileName: 'TLA.xml',
    language: BibleLanguage.spanish,
    copyright: 'Traducción en lenguaje actual © Sociedades Bíblicas Unidas, 2000.',
  ),
  nivEnglish(
    id: 'NIV_EN',
    displayName: 'New International Version',
    shortName: 'NIV',
    fileName: 'NIV.xml',
    language: BibleLanguage.english,
    copyright: 'New International Version® © 1973, 1978, 1984, 2011 by Biblica, Inc.®',
  ),
  nlt(
    id: 'NLT',
    displayName: 'New Living Translation',
    shortName: 'NLT',
    fileName: 'NLT.xml',
    language: BibleLanguage.english,
    copyright: 'Holy Bible, New Living Translation © 1996, 2004, 2015 by Tyndale House Foundation.',
  ),
  nkjv(
    id: 'NKJV',
    displayName: 'New King James Version',
    shortName: 'NKJV',
    fileName: 'NKJV.xml',
    language: BibleLanguage.english,
    copyright: 'New King James Version® © 1982 by Thomas Nelson.',
  );

  final String id;
  final String displayName;
  final String shortName;
  final String fileName;
  final BibleLanguage language;

  /// Aviso de derechos de autor de la traducción. Se muestra en el lector
  /// (al final del capítulo y en la ficha de la versión), en Ajustes de la
  /// Biblia y en los créditos. Única fuente de verdad: no duplicar el texto.
  final String copyright;

  const BibleVersion({
    required this.id,
    required this.displayName,
    required this.shortName,
    required this.fileName,
    required this.language,
    required this.copyright,
  });

  /// Abreviatura que acompaña al texto compartido: «Juan 3:16 (RVR1960)».
  String get shareAbbreviation => isEnglish ? shortName : id;

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
