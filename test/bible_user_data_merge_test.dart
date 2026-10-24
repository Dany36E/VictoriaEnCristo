import 'package:app_quitar/services/bible/bible_user_data_merge.dart';
import 'package:flutter_test/flutter_test.dart';

class _Item {
  final String id;
  final String key;
  final DateTime date;
  const _Item(this.id, this.key, this.date);
}

MergeResult<_Item> _merge(
  Map<String, _Item> current,
  List<_Item> incoming, {
  required bool authoritative,
}) => BibleUserDataMerge.merge<_Item>(
  current: current,
  incoming: incoming,
  keyOf: (i) => i.key,
  idOf: (i) => i.id,
  dateOf: (i) => i.date,
  authoritative: authoritative,
);

void main() {
  final base = DateTime(2024, 1, 1);
  _Item item(int n, {String? key, int minutes = 0}) =>
      _Item('id$n', key ?? 'k$n', base.add(Duration(minutes: n + minutes)));

  test('muestra todos los elementos, más allá de los antiguos límites', () {
    // Antes: .limit(150) para resaltados y .limit(200) para guardados/notas.
    final incoming = [for (var i = 0; i < 750; i++) item(i)];
    final r = _merge({}, incoming, authoritative: true);
    expect(r.items.length, 750);
    expect(r.duplicateIds, isEmpty);
  });

  test('snapshot de caché incompleto no borra lo que ya se conocía', () {
    final current = {for (var i = 0; i < 300; i++) 'k$i': item(i)};
    // La caché de Firestore solo tenía los 150 más recientes.
    final incoming = [for (var i = 150; i < 300; i++) item(i)];
    final r = _merge(current, incoming, authoritative: false);
    expect(r.items.length, 300);
    expect(r.items.containsKey('k0'), isTrue);
  });

  test('snapshot del servidor es la verdad: refleja borrados', () {
    final current = {for (var i = 0; i < 5; i++) 'k$i': item(i)};
    final incoming = [item(0), item(1), item(3), item(4)]; // k2 se borró
    final r = _merge(current, incoming, authoritative: true);
    expect(r.items.keys, isNot(contains('k2')));
    expect(r.items.length, 4);
  });

  test('un borrado local no reaparece con un snapshot de caché', () {
    // El borrado ya quitó k2 del estado actual y de la caché de Firestore.
    final current = {'k1': item(1), 'k3': item(3)};
    final r = _merge(current, [item(1), item(3)], authoritative: false);
    expect(r.items.keys, unorderedEquals(['k1', 'k3']));
  });

  test('duplicados del mismo versículo: gana el más reciente', () {
    final viejo = _Item('a', 'jn3:16', base);
    final nuevo = _Item('b', 'jn3:16', base.add(const Duration(days: 1)));
    final r = _merge({}, [nuevo, viejo], authoritative: true);
    expect(r.items['jn3:16']!.id, 'b');
    expect(r.duplicateIds, ['a']);

    final r2 = _merge({}, [viejo, nuevo], authoritative: true);
    expect(r2.items['jn3:16']!.id, 'b');
    expect(r2.duplicateIds, ['a']);
  });

  test('desde caché no se ordena borrar duplicados', () {
    final viejo = _Item('a', 'k', base);
    final nuevo = _Item('b', 'k', base.add(const Duration(days: 1)));
    final r = _merge({}, [viejo, nuevo], authoritative: false);
    expect(r.items['k']!.id, 'b');
    expect(r.duplicateIds, isEmpty);
  });

  test('sortedByDateDesc ordena del más reciente al más viejo', () {
    final r = BibleUserDataMerge.sortedByDateDesc<_Item>({
      'a': item(1),
      'b': item(5),
      'c': item(3),
    }, (i) => i.date);
    expect(r.map((i) => i.id), ['id5', 'id3', 'id1']);
  });
}
