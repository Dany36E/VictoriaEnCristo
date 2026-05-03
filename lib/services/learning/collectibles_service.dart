/// ═══════════════════════════════════════════════════════════════════════════
/// CollectiblesService — gestiona los ítems desbloqueados (parte de la
/// economía Talentos). El estado canónico vive en [TalentsService] para
/// minimizar escrituras Firestore (un solo doc, una sola sync).
///
/// Flujo típico:
///   final ok = await CollectiblesService.I.unlock(item);  // gasta talentos
///   if (ok) { mostrar item desbloqueado }
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

import '../../data/collectibles_catalog.dart';
import 'book_repository.dart';
import 'talents_service.dart';

class CollectibleUnlockResult {
  final bool unlocked;
  final bool completedBook;
  final int bonusTalents;
  final String? rewardTitle;
  final String? rewardDetail;

  const CollectibleUnlockResult({
    required this.unlocked,
    this.completedBook = false,
    this.bonusTalents = 0,
    this.rewardTitle,
    this.rewardDetail,
  });
}

class CollectiblesService {
  CollectiblesService._();
  static final CollectiblesService I = CollectiblesService._();

  /// Notificador del set de IDs desbloqueados. Espejo de
  /// [TalentsService.stateNotifier.value.unlocked].
  final ValueNotifier<Set<String>> unlockedNotifier = ValueNotifier({});

  bool _init = false;

  Future<void> init() async {
    if (_init) return;
    _init = true;
    // Asegurar que talents está listo (Registry los inicializa en orden,
    // pero por seguridad).
    await TalentsService.I.init();
    unlockedNotifier.value = TalentsService.I.stateNotifier.value.unlocked;
    TalentsService.I.stateNotifier.addListener(_syncFromTalents);
  }

  void _syncFromTalents() {
    final s = TalentsService.I.stateNotifier.value.unlocked;
    if (!setEquals(s, unlockedNotifier.value)) {
      unlockedNotifier.value = s;
    }
  }

  bool isUnlocked(String itemId) => TalentsService.I.stateNotifier.value.unlocked.contains(itemId);

  String bookCompletionRewardId(String bookId) => 'reward:book_complete:$bookId';

  bool hasBookCompletionReward(String bookId) =>
      TalentsService.I.stateNotifier.value.unlocked.contains(bookCompletionRewardId(bookId));

  /// Intenta desbloquear. Devuelve true si tenía saldo y se desbloqueó.
  Future<bool> unlock(CollectibleItem item) async {
    final result = await unlockWithResult(item);
    return result.unlocked;
  }

  /// Variante rica para UI: indica si este desbloqueo completó el libro y qué
  /// recompensa se otorgó.
  Future<CollectibleUnlockResult> unlockWithResult(CollectibleItem item) async {
    if (!_init) await init();
    if (isUnlocked(item.id)) {
      return const CollectibleUnlockResult(unlocked: true);
    }
    final paid = await TalentsService.I.spend(item.cost, reason: 'unlock:${item.id}');
    if (!paid) return const CollectibleUnlockResult(unlocked: false);

    final next = {...TalentsService.I.stateNotifier.value.unlocked, item.id};

    var completedBook = false;
    var bonusTalents = 0;
    String? rewardTitle;
    String? rewardDetail;
    final rewardId = bookCompletionRewardId(item.bookId);
    final book = BookRepository.I.byId(item.bookId);
    final bookItems = CollectiblesCatalog.I.itemsForBook(item.bookId);
    final justCompleted =
        bookItems.isNotEmpty &&
        bookItems.every((candidate) => next.contains(candidate.id)) &&
        !next.contains(rewardId);

    if (justCompleted && book != null) {
      completedBook = true;
      bonusTalents = CollectiblesCatalog.I.completionBonusForBook(book.id);
      rewardTitle = CollectiblesCatalog.I.completionRewardTitle(book);
      rewardDetail = CollectiblesCatalog.I.completionRewardDetail(book);
      next.add(rewardId);
    }

    await TalentsService.I.mirrorUnlocked(next);
    if (bonusTalents > 0) {
      await TalentsService.I.earn(bonusTalents, reason: 'collectibles_complete:${item.bookId}');
    }
    unlockedNotifier.value = next;
    return CollectibleUnlockResult(
      unlocked: true,
      completedBook: completedBook,
      bonusTalents: bonusTalents,
      rewardTitle: rewardTitle,
      rewardDetail: rewardDetail,
    );
  }

  // ── Estadísticas para UI ────────────────────────────────────────────────

  int unlockedInBook(String bookId) {
    final unlocked = TalentsService.I.stateNotifier.value.unlocked;
    return unlocked.where((id) => id.startsWith('$bookId:')).length;
  }

  int totalInBook(String bookId) => CollectiblesCatalog.I.itemsForBook(bookId).length;

  /// % desbloqueado en un libro (0..1).
  double progressInBook(String bookId) {
    final total = totalInBook(bookId);
    if (total == 0) return 0;
    return unlockedInBook(bookId) / total;
  }

  bool isBookComplete(String bookId) =>
      totalInBook(bookId) > 0 && unlockedInBook(bookId) >= totalInBook(bookId);

  int get totalUnlocked => TalentsService.I.stateNotifier.value.unlocked
      .where((id) => CollectiblesCatalog.I.byId(id) != null)
      .length;

  /// Total disponible en el catálogo (tras BookRepository cargado).
  int get totalAvailable => CollectiblesCatalog.I.totalCount;
}
