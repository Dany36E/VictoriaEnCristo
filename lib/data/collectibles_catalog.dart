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
  cover, // Portada — primera, más barata
  scene, // Escena clave del libro
  map, // Overlay geográfico
  devotional, // Devocional/meditación
  calligraphy, // Versículo emblemático en caligrafía
}

extension CollectibleKindInfo on CollectibleKind {
  String get label {
    switch (this) {
      case CollectibleKind.cover:
        return 'Sello';
      case CollectibleKind.scene:
        return 'Escena';
      case CollectibleKind.map:
        return 'Camino';
      case CollectibleKind.devotional:
        return 'Mesa';
      case CollectibleKind.calligraphy:
        return 'Palabra';
    }
  }

  String get storyAct {
    switch (this) {
      case CollectibleKind.cover:
        return 'Acto I · Abrir la puerta';
      case CollectibleKind.scene:
        return 'Acto II · Entrar en la escena';
      case CollectibleKind.map:
        return 'Acto III · Seguir el camino';
      case CollectibleKind.devotional:
        return 'Acto IV · Traerlo a tu vida';
      case CollectibleKind.calligraphy:
        return 'Acto V · Guardar la palabra';
    }
  }

  IconData get icon {
    switch (this) {
      case CollectibleKind.cover:
        return Icons.auto_stories_rounded;
      case CollectibleKind.scene:
        return Icons.landscape_rounded;
      case CollectibleKind.map:
        return Icons.route_rounded;
      case CollectibleKind.devotional:
        return Icons.local_fire_department_rounded;
      case CollectibleKind.calligraphy:
        return Icons.edit_note_rounded;
    }
  }

  /// Coste por defecto en talentos.
  int get defaultCost {
    switch (this) {
      case CollectibleKind.cover:
        return 5;
      case CollectibleKind.scene:
        return 15;
      case CollectibleKind.map:
        return 20;
      case CollectibleKind.devotional:
        return 25;
      case CollectibleKind.calligraphy:
        return 15;
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

  /// Nombre narrativo del ítem. Ej: "Sello de Génesis".
  final String title;

  /// Texto descriptivo corto que aparece en el preview.
  final String description;

  /// Microhistoria que conecta este ítem con el arco del libro.
  final String story;

  /// Recompensa emocional/visual que se obtiene al comprar esta pieza.
  final String rewardTitle;
  final String rewardDetail;

  const CollectibleItem({
    required this.id,
    required this.bookId,
    required this.kind,
    required this.cost,
    required this.title,
    required this.description,
    required this.story,
    required this.rewardTitle,
    required this.rewardDetail,
  });

  static String makeId(String bookId, CollectibleKind kind) => '$bookId:${kind.name}';
}

class CollectiblesCatalog {
  CollectiblesCatalog._();
  static final CollectiblesCatalog I = CollectiblesCatalog._();

  /// Overrides por libro: detalles específicos para libros clave. Si un libro
  /// no aparece, el sistema genera textos únicos desde sus metadatos bíblicos.
  static const Map<String, Map<CollectibleKind, String>> _descriptionOverrides = {
    'gen': {
      CollectibleKind.cover: 'Génesis · "En el principio..."',
      CollectibleKind.scene: 'La creación · Día por día',
      CollectibleKind.map: 'Edén · El primer mapa',
      CollectibleKind.devotional: 'Imagen de Dios · 5 días',
      CollectibleKind.calligraphy: '"En el principio creó Dios..."',
    },
    'exo': {
      CollectibleKind.cover: 'Éxodo · El gran rescate',
      CollectibleKind.scene: 'Mar Rojo · Camino seco',
      CollectibleKind.map: 'Egipto → Sinaí',
      CollectibleKind.devotional: 'Yo soy el que soy · 5 días',
      CollectibleKind.calligraphy: '"Y conocerán que yo soy Jehová."',
    },
    'sal': {
      CollectibleKind.cover: 'Salmos · Cantos del alma',
      CollectibleKind.scene: 'Arpa de David',
      CollectibleKind.map: 'Sión · La ciudad amada',
      CollectibleKind.devotional: 'Salmo 23 · 5 días',
      CollectibleKind.calligraphy: '"Jehová es mi pastor; nada me faltará."',
    },
    'isa': {
      CollectibleKind.cover: 'Isaías · Visión del Mesías',
      CollectibleKind.scene: 'El Siervo sufriente',
      CollectibleKind.map: 'Jerusalén en tiempos de Isaías',
      CollectibleKind.devotional: 'Consolad a mi pueblo · 5 días',
      CollectibleKind.calligraphy: '"Mas él herido fue por nuestras rebeliones."',
    },
    'mat': {
      CollectibleKind.cover: 'Mateo · El Rey prometido',
      CollectibleKind.scene: 'Sermón del monte',
      CollectibleKind.map: 'Galilea · El ministerio',
      CollectibleKind.devotional: 'Bienaventuranzas · 5 días',
      CollectibleKind.calligraphy: '"Bienaventurados los pobres en espíritu."',
    },
    'jua': {
      CollectibleKind.cover: 'Juan · El Verbo hecho carne',
      CollectibleKind.scene: 'Jesús lava los pies',
      CollectibleKind.map: 'Galilea y Judea',
      CollectibleKind.devotional: 'Yo soy · 7 declaraciones',
      CollectibleKind.calligraphy: '"Porque de tal manera amó Dios al mundo..."',
    },
    'rom': {
      CollectibleKind.cover: 'Romanos · El Evangelio explicado',
      CollectibleKind.scene: 'Pablo escribe a Roma',
      CollectibleKind.map: 'Roma imperial',
      CollectibleKind.devotional: 'Justificados por la fe · 5 días',
      CollectibleKind.calligraphy: '"El justo por la fe vivirá."',
    },
    'apo': {
      CollectibleKind.cover: 'Apocalipsis · Visión final',
      CollectibleKind.scene: 'Los siete sellos',
      CollectibleKind.map: 'Las siete iglesias',
      CollectibleKind.devotional: 'El Cordero vencedor · 5 días',
      CollectibleKind.calligraphy: '"He aquí, yo hago nuevas todas las cosas."',
    },
  };

  /// Devuelve los 5 ítems estándar para un libro dado.
  /// Requiere que [BookRepository] esté cargado (lo está vía LearningRegistry).
  List<CollectibleItem> itemsForBook(String bookId) {
    final book = BookRepository.I.byId(bookId);
    if (book == null) return const [];
    return CollectibleKind.values.map((kind) => _buildItem(book, kind)).toList();
  }

  /// Total esperado de coleccionables (66 libros × 5 = 330).
  int get totalCount => BookRepository.I.all.length * CollectibleKind.values.length;

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
    return _buildItem(book, kind);
  }

  int completionBonusForBook(String bookId) {
    final book = BookRepository.I.byId(bookId);
    if (book == null) return 10;
    final testamentBonus = book.testament == 'NT' ? 2 : 0;
    final finaleBonus = book.order == 66 ? 8 : 0;
    return 10 + testamentBonus + finaleBonus;
  }

  String completionRewardTitle(BibleBook book) => '${_guardianTitle(book)} de ${book.name}';

  String completionRewardDetail(BibleBook book) {
    return 'Completaste el mural de ${book.name}. Tu biblioteca conserva esta ruta como una insignia permanente y recuperas ${completionBonusForBook(book.id)} talentos.';
  }

  CollectibleItem _buildItem(BibleBook book, CollectibleKind kind) {
    final overrides = _descriptionOverrides[book.id] ?? const {};
    return CollectibleItem(
      id: CollectibleItem.makeId(book.id, kind),
      bookId: book.id,
      kind: kind,
      cost: kind.defaultCost,
      title: _titleFor(book, kind),
      description: overrides[kind] ?? _defaultDescription(book, kind),
      story: _storyFor(book, kind),
      rewardTitle: _rewardTitleFor(book, kind),
      rewardDetail: _rewardDetailFor(book, kind),
    );
  }

  String _titleFor(BibleBook book, CollectibleKind kind) {
    switch (kind) {
      case CollectibleKind.cover:
        return 'Sello de ${book.name}';
      case CollectibleKind.scene:
        return 'Ventana de ${book.name}';
      case CollectibleKind.map:
        return 'Ruta de ${book.name}';
      case CollectibleKind.devotional:
        return 'Mesa de ${book.name}';
      case CollectibleKind.calligraphy:
        return 'Palabra de ${book.name}';
    }
  }

  String _defaultDescription(BibleBook book, CollectibleKind kind) {
    switch (kind) {
      case CollectibleKind.cover:
        return '${book.name} · ${book.theme}';
      case CollectibleKind.scene:
        return _shortSentence(book.summary);
      case CollectibleKind.map:
        return '${book.category} · ${book.chapters} capítulos';
      case CollectibleKind.devotional:
        return 'Práctica: vivir ${_plainTheme(book)}';
      case CollectibleKind.calligraphy:
        return '${book.keyVerseRef} · ${book.keyVerse}';
    }
  }

  String _storyFor(BibleBook book, CollectibleKind kind) {
    switch (kind) {
      case CollectibleKind.cover:
        return 'Abres la puerta de ${book.name}: una ruta sobre ${_plainTheme(book)} queda marcada en tu biblioteca.';
      case CollectibleKind.scene:
        return 'La escena toma forma y deja de ser dato: ${_shortSentence(book.summary)}';
      case CollectibleKind.map:
        return 'Ubicas ${book.name} dentro de ${book.category}; ves dónde encaja en la gran historia de redención.';
      case CollectibleKind.devotional:
        return 'La historia baja a tu semana: conviertes ${_plainTheme(book)} en una respuesta concreta de fe.';
      case CollectibleKind.calligraphy:
        return 'Cierras el mural guardando una frase que puedes llevar contigo: ${book.keyVerseRef}.';
    }
  }

  String _rewardTitleFor(BibleBook book, CollectibleKind kind) {
    switch (kind) {
      case CollectibleKind.cover:
        return 'Entrada desbloqueada';
      case CollectibleKind.scene:
        return 'Escena viva';
      case CollectibleKind.map:
        return 'Ruta trazada';
      case CollectibleKind.devotional:
        return 'Aplicación personal';
      case CollectibleKind.calligraphy:
        return 'Verso ancla';
    }
  }

  String _rewardDetailFor(BibleBook book, CollectibleKind kind) {
    switch (kind) {
      case CollectibleKind.cover:
        return 'La tarjeta de ${book.name} despierta con color y empieza su mural.';
      case CollectibleKind.scene:
        return 'Añades una imagen central al recuerdo del libro.';
      case CollectibleKind.map:
        return 'La biblioteca conecta este libro con su lugar en la historia bíblica.';
      case CollectibleKind.devotional:
        return 'Ganas una frase de práctica para volver a ${book.name} con intención.';
      case CollectibleKind.calligraphy:
        return 'El versículo clave queda como cierre visual del mural.';
    }
  }

  String _guardianTitle(BibleBook book) {
    switch (book.category.toLowerCase()) {
      case 'pentateuco':
        return 'Guardián del Pacto';
      case 'históricos':
      case 'historico':
      case 'histórico':
        return 'Cronista del Reino';
      case 'poéticos':
        return 'Cantor del Alma';
      case 'profetas mayores':
      case 'profetas menores':
      case 'profético':
        return 'Centinela de la Promesa';
      case 'evangelios':
        return 'Testigo del Rey';
      case 'cartas paulinas':
      case 'pastorales':
      case 'general':
        return 'Portador de la Carta';
      default:
        return 'Custodio';
    }
  }

  String _plainTheme(BibleBook book) {
    final theme = book.theme.trim();
    if (theme.isEmpty) return 'su mensaje central';
    return theme.replaceAll(RegExp(r'[.]$'), '').toLowerCase();
  }

  String _shortSentence(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'Una escena clave de la historia de Dios se revela.';
    final end = clean.indexOf('.');
    if (end > 24) return clean.substring(0, end + 1);
    if (clean.length <= 120) return clean;
    return '${clean.substring(0, 117).trim()}...';
  }
}
