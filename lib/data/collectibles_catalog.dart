/// ═══════════════════════════════════════════════════════════════════════════
/// Catálogo de coleccionables — 66 libros × 5 ítems = 330 piezas.
///
/// Las definiciones se generan programáticamente desde [BookRepository] para
/// no tener que mantener 330 entradas a mano. Cada libro produce su set
/// estándar (portada, escena, mapa, devocional, versículo en caligrafía).
///
/// Para personalizar un libro concreto (ej. añadir "palabra hebrea" sólo a
/// Génesis), agregar una entrada en [_overrides] y se mergea con las
/// estándar.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

import '../models/learning/book_models.dart';
import '../services/learning/book_repository.dart';

enum CollectibleKind {
  cover,        // Portada — primera, más barata
  scene,        // Escena clave del libro
  map,          // Overlay geográfico
  devotional,   // Devocional/meditación
  calligraphy,  // Versículo emblemático en caligrafía
}

extension CollectibleKindInfo on CollectibleKind {
  String get label {
    switch (this) {
      case CollectibleKind.cover:       return 'Portada';
      case CollectibleKind.scene:       return 'Escena';
      case CollectibleKind.map:         return 'Mapa';
      case CollectibleKind.devotional:  return 'Devocional';
      case CollectibleKind.calligraphy: return 'Caligrafía';
    }
  }

  IconData get icon {
    switch (this) {
      case CollectibleKind.cover:       return Icons.menu_book_rounded;
      case CollectibleKind.scene:       return Icons.image_rounded;
      case CollectibleKind.map:         return Icons.public_rounded;
      case CollectibleKind.devotional:  return Icons.spa_rounded;
      case CollectibleKind.calligraphy: return Icons.brush_rounded;
    }
  }

  /// Coste por defecto en talentos.
  int get defaultCost {
    switch (this) {
      case CollectibleKind.cover:       return 5;
      case CollectibleKind.scene:       return 15;
      case CollectibleKind.map:         return 20;
      case CollectibleKind.devotional:  return 25;
      case CollectibleKind.calligraphy: return 15;
    }
  }
}

@immutable
class CollectibleItem {
  /// ID estable: `"<bookId>:<kind>"`.
  final String id;
  final String bookId;
  final CollectibleKind kind;
  final int cost;
  /// Texto descriptivo corto que aparece en el preview.
  final String description;

  const CollectibleItem({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.cost,
    required this.description,
  });

  static String makeId(String bookId, CollectibleKind kind) =>
      '$bookId:${kind.name}';
}

class CollectiblesCatalog {
  CollectiblesCatalog._();
  static final CollectiblesCatalog I = CollectiblesCatalog._();

  /// Overrides por libro: descripciones específicas (más evocadoras que las
  /// genéricas). Si un libro no aparece, se usan las plantillas por defecto.
  static const Map<String, Map<CollectibleKind, String>> _overrides = {
    'gn': {
      CollectibleKind.cover: 'Génesis · "En el principio…"',
      CollectibleKind.scene: 'La creación · Día por día',
      CollectibleKind.map: 'Edén · El primer mapa',
      CollectibleKind.devotional: 'Imagen de Dios · 5 días',
      CollectibleKind.calligraphy: '«En el principio creó Dios…»',
    },
    'ex': {
      CollectibleKind.cover: 'Éxodo · El gran rescate',
      CollectibleKind.scene: 'Mar Rojo · Camino seco',
      CollectibleKind.map: 'Egipto → Sinaí',
      CollectibleKind.devotional: 'Yo soy el que soy · 5 días',
      CollectibleKind.calligraphy: '«Y conocerán que yo soy Jehová.»',
    },
    'sal': {
      CollectibleKind.cover: 'Salmos · Cantos del alma',
      CollectibleKind.scene: 'Arpa de David',
      CollectibleKind.map: 'Sión · La ciudad amada',
      CollectibleKind.devotional: 'Salmo 23 · 5 días',
      CollectibleKind.calligraphy: '«Jehová es mi pastor; nada me faltará.»',
    },
    'is': {
      CollectibleKind.cover: 'Isaías · Visión del Mesías',
      CollectibleKind.scene: 'El Siervo sufriente',
      CollectibleKind.map: 'Jerusalén en tiempos de Isaías',
      CollectibleKind.devotional: 'Consolad a mi pueblo · 5 días',
      CollectibleKind.calligraphy: '«Mas él herido fue por nuestras rebeliones.»',
    },
    'mt': {
      CollectibleKind.cover: 'Mateo · El Rey prometido',
      CollectibleKind.scene: 'Sermón del monte',
      CollectibleKind.map: 'Galilea · El ministerio',
      CollectibleKind.devotional: 'Bienaventuranzas · 5 días',
      CollectibleKind.calligraphy: '«Bienaventurados los pobres en espíritu.»',
    },
    'jn': {
      CollectibleKind.cover: 'Juan · El Verbo hecho carne',
      CollectibleKind.scene: 'Jesús lava los pies',
      CollectibleKind.map: 'Galilea y Judea',
      CollectibleKind.devotional: 'Yo soy · 7 declaraciones',
      CollectibleKind.calligraphy: '«Porque de tal manera amó Dios al mundo…»',
    },
    'ro': {
      CollectibleKind.cover: 'Romanos · El Evangelio explicado',
      CollectibleKind.scene: 'Pablo escribe a Roma',
      CollectibleKind.map: 'Roma imperial',
      CollectibleKind.devotional: 'Justificados por la fe · 5 días',
      CollectibleKind.calligraphy: '«El justo por la fe vivirá.»',
    },
    'ap': {
      CollectibleKind.cover: 'Apocalipsis · Visión final',
      CollectibleKind.scene: 'Los siete sellos',
      CollectibleKind.map: 'Las siete iglesias',
      CollectibleKind.devotional: 'El Cordero vencedor · 5 días',
      CollectibleKind.calligraphy: '«He aquí, yo hago nuevas todas las cosas.»',
    },
  };

  /// Devuelve los 5 ítems estándar para un libro dado.
  /// Requiere que [BookRepository] esté cargado (lo está vía LearningRegistry).
  List<CollectibleItem> itemsForBook(String bookId) {
    final book = BookRepository.I.byId(bookId);
    if (book == null) return const [];
    final overrides = _overrides[bookId] ?? const {};
    return CollectibleKind.values.map((kind) {
      return CollectibleItem(
        id: CollectibleItem.makeId(bookId, kind),
        bookId: bookId,
        kind: kind,
        cost: kind.defaultCost,
        description: overrides[kind] ?? _defaultDescription(book, kind),
      );
    }).toList();
  }

  /// Total esperado de coleccionables (66 libros × 5 = 330).
  int get totalCount =>
      BookRepository.I.all.length * CollectibleKind.values.length;

  /// Resuelve un ítem por su id (`"<bookId>:<kind>"`). null si no existe.
  CollectibleItem? byId(String id) {
    final parts = id.split(':');
    if (parts.length != 2) return null;
    final book = BookRepository.I.byId(parts[0]);
    if (book == null) return null;
    final kind = CollectibleKind.values.firstWhere(
      (k) => k.name == parts[1],
      orElse: () => CollectibleKind.cover,
    );
    if (kind.name != parts[1]) return null;
    final overrides = _overrides[book.id] ?? const {};
    return CollectibleItem(
      id: id,
      bookId: book.id,
      kind: kind,
      cost: kind.defaultCost,
      description: overrides[kind] ?? _defaultDescription(book, kind),
    );
  }

  String _defaultDescription(BibleBook book, CollectibleKind kind) {
    switch (kind) {
      case CollectibleKind.cover:
        return '${book.name} · Portada';
      case CollectibleKind.scene:
        return 'Escena clave de ${book.name}';
      case CollectibleKind.map:
        return 'Geografía de ${book.name}';
      case CollectibleKind.devotional:
        return 'Devocional · 5 días sobre ${book.name}';
      case CollectibleKind.calligraphy:
        return 'Versículo emblemático de ${book.name}';
    }
  }
}
