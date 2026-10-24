/// ═══════════════════════════════════════════════════════════════════════════
/// Migración de «Mis Favoritos» (lista local antigua) a los versículos
/// guardados de la Biblia (Firestore), que ahora son el único sistema.
///
/// Lógica pura para poder probarla sin Firebase:
///   - Cada favorito se identifica por su referencia («Salmos 118:24»).
///   - Solo se migra una vez: las referencias ya migradas se recuerdan, así
///     un versículo que la persona quitó después no reaparece.
///   - Si el versículo ya estaba guardado en la Biblia no se duplica.
///   - Lo que no se puede interpretar NO se pierde: queda en la lista local
///     y se sigue mostrando en Favoritos.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import '../data/bible_verses.dart' as legacy;
import '../utils/bible_reference_parser.dart';

class FavoriteToSave {
  final legacy.BibleVerse favorite;
  final BibleReference reference;
  const FavoriteToSave(this.favorite, this.reference);
}

class FavoritesMigrationPlan {
  /// Favoritos que hay que guardar como versículos de la Biblia.
  final List<FavoriteToSave> toSave;

  /// Favoritos cuya referencia no se pudo interpretar (se conservan).
  final List<legacy.BibleVerse> unparseable;

  /// Conjunto actualizado de referencias ya migradas (para persistir).
  final Set<String> migrated;

  const FavoritesMigrationPlan({
    required this.toSave,
    required this.unparseable,
    required this.migrated,
  });
}

class FavoritesMigration {
  FavoritesMigration._();

  /// Clave estable de un favorito antiguo (referencia normalizada).
  static String keyOf(legacy.BibleVerse v) => BibleReferenceParser.stripAccents(
    v.reference.trim(),
  ).replaceAll(RegExp(r'\s+'), ' ');

  static FavoritesMigrationPlan plan({
    required Iterable<legacy.BibleVerse> legacyFavorites,
    required bool Function(int book, int chapter, int verse) isSaved,
    required Set<String> alreadyMigrated,
  }) {
    final toSave = <FavoriteToSave>[];
    final unparseable = <legacy.BibleVerse>[];
    final migrated = {...alreadyMigrated};
    final planned = <String>{};

    for (final fav in legacyFavorites) {
      final ref = BibleReferenceParser.parse(fav.reference);
      if (ref == null || ref.verse == null) {
        unparseable.add(fav);
        continue;
      }
      final key = keyOf(fav);
      if (migrated.contains(key)) continue;
      migrated.add(key);
      final verseKey = '${ref.bookNumber}:${ref.chapter}:${ref.verse}';
      if (isSaved(ref.bookNumber, ref.chapter, ref.verse!)) continue;
      if (!planned.add(verseKey)) continue; // duplicado en la lista antigua
      toSave.add(FavoriteToSave(fav, ref));
    }
    return FavoritesMigrationPlan(
      toSave: toSave,
      unparseable: unparseable,
      migrated: migrated,
    );
  }
}
