import 'dart:convert';
import 'package:flutter/services.dart';
import '../../models/learning/book_models.dart';

class BookRepository {
  BookRepository._();
  static final BookRepository I = BookRepository._();

  final List<BibleBook> _books = [];
  bool _loaded = false;

  List<BibleBook> get all => List.unmodifiable(_books);
  List<BibleBook> get ot => _books.where((b) => b.testament == 'AT').toList();
  List<BibleBook> get nt => _books.where((b) => b.testament == 'NT').toList();
  BibleBook? byId(String id) {
    try {
      return _books.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString('assets/content/bible_books.json');
      final data = json.decode(raw) as Map<String, dynamic>;
      final list = (data['books'] as List<dynamic>? ?? const []);
      _books
        ..clear()
        ..addAll(list
            .map((e) => BibleBook.fromJson(e as Map<String, dynamic>)));
      _books.sort((a, b) => a.order.compareTo(b.order));
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }
}
