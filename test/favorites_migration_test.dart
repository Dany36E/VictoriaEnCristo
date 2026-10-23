import 'package:app_quitar/data/bible_verses.dart' as legacy;
import 'package:app_quitar/services/favorites_migration.dart';
import 'package:flutter_test/flutter_test.dart';

legacy.BibleVerse _fav(String ref, [String text = 'texto']) =>
    legacy.BibleVerse(verse: text, reference: ref, category: 'feliz');

void main() {
  test('migra todos los favoritos interpretables, con rangos', () {
    final plan = FavoritesMigration.plan(
      legacyFavorites: [
        _fav('Salmos 118:24'),
        _fav('1 Tesalonicenses 5:16-18'),
        _fav('Filipenses 4:6'),
      ],
      isSaved: (_, _, _) => false,
      alreadyMigrated: {},
    );
    expect(plan.toSave.length, 3);
    final rango = plan.toSave[1].reference;
    expect(rango.bookNumber, 52);
    expect(rango.verse, 16);
    expect(rango.endVerse, 18);
    expect(plan.unparseable, isEmpty);
    expect(plan.migrated.length, 3);
  });

  test('no duplica lo que ya estaba guardado en la Biblia', () {
    final plan = FavoritesMigration.plan(
      legacyFavorites: [_fav('Juan 3:16'), _fav('Romanos 8:28')],
      isSaved: (b, c, v) => b == 43 && c == 3 && v == 16,
      alreadyMigrated: {},
    );
    expect(plan.toSave.map((e) => e.reference.bookNumber), [45]);
    // Aunque no se guarde de nuevo, queda marcado como migrado.
    expect(
      plan.migrated,
      contains(FavoritesMigration.keyOf(_fav('Juan 3:16'))),
    );
  });

  test('solo una vez: lo ya migrado (y luego quitado) no vuelve', () {
    final primera = FavoritesMigration.plan(
      legacyFavorites: [_fav('Juan 3:16')],
      isSaved: (_, _, _) => false,
      alreadyMigrated: {},
    );
    expect(primera.toSave, hasLength(1));
    // La persona lo quitó de Guardados; la lista antigua sigue igual.
    final segunda = FavoritesMigration.plan(
      legacyFavorites: [_fav('Juan 3:16')],
      isSaved: (_, _, _) => false,
      alreadyMigrated: primera.migrated,
    );
    expect(segunda.toSave, isEmpty);
  });

  test('sin pérdida: lo que no se interpreta se conserva', () {
    final plan = FavoritesMigration.plan(
      legacyFavorites: [_fav('Proverbios'), _fav('Isaías 41:10')],
      isSaved: (_, _, _) => false,
      alreadyMigrated: {},
    );
    expect(plan.unparseable.single.reference, 'Proverbios');
    expect(plan.toSave.single.reference.bookNumber, 23);
  });

  test('duplicados en la lista antigua se guardan una sola vez', () {
    final plan = FavoritesMigration.plan(
      legacyFavorites: [_fav('Salmo 23:1'), _fav('Salmos 23:1')],
      isSaved: (_, _, _) => false,
      alreadyMigrated: {},
    );
    expect(plan.toSave, hasLength(1));
  });
}
