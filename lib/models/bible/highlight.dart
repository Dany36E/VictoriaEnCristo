import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Colores predefinidos para resaltado bíblico
class HighlightColors {
  HighlightColors._();

  static const Color yellow = Color(0xFFFFF176);
  static const Color green = Color(0xFFA5D6A7);
  static const Color blue = Color(0xFF90CAF9);
  static const Color pink = Color(0xFFF48FB1);
  static const Color orange = Color(0xFFFFCC80);
  static const Color purple = Color(0xFFCE93D8);

  static const List<Color> defaults = [yellow, green, blue, pink, orange, purple];

  /// Convertir color a hex string para Firestore
  static String toHex(Color c) =>
      '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  /// Convertir hex string a Color
  static Color fromHex(String hex) {
    final clean = hex.replaceFirst('#', '');
    return Color(int.parse('FF$clean', radix: 16));
  }
}

/// Resaltado de un versículo
class Highlight {
  final String id; // Firestore doc ID
  final int bookNumber;
  final int chapter;
  final int verse;
  final String colorHex;
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.bookNumber,
    required this.chapter,
    required this.verse,
    required this.colorHex,
    required this.createdAt,
  });

  /// Clave del versículo para lookup rápido
  String get verseKey => '$bookNumber:$chapter:$verse';

  Color get color => HighlightColors.fromHex(colorHex);

  Map<String, dynamic> toMap() => {
        'bookNumber': bookNumber,
        'chapter': chapter,
        'verse': verse,
        'colorHex': colorHex,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory Highlight.fromMap(String id, Map<String, dynamic> map) => Highlight(
        id: id,
        bookNumber: map['bookNumber'] as int,
        chapter: map['chapter'] as int,
        verse: map['verse'] as int,
        colorHex: map['colorHex'] as String,
        createdAt: (map['createdAt'] as Timestamp).toDate(),
      );
}
