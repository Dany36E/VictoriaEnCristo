// ignore_for_file: avoid_relative_lib_imports, prefer_const_declarations
// Exporta los devocionales de `lib/data/devotionals.dart` a
// `assets/content/devotionals.json`. Se ejecuta una vez (offline) con:
//   dart run tool/export_devotionals.dart
// No forma parte del runtime de la app.
import 'dart:convert';
import 'dart:io';

import '../lib/data/devotionals.dart';

Future<void> main() async {
  final list = Devotionals.allDevotionals
      .map((d) => {
            'day': d.day,
            'title': d.title,
            'verse': d.verse,
            'verseReference': d.verseReference,
            'reflection': d.reflection,
            'challenge': d.challenge,
            'prayer': d.prayer,
          })
      .toList();
  final encoder = const JsonEncoder.withIndent('  ');
  final out = File('assets/content/devotionals.json');
  await out.create(recursive: true);
  await out.writeAsString(encoder.convert(list));
  // ignore: avoid_print
  print('Wrote ${list.length} devotionals to ${out.path}');
}
