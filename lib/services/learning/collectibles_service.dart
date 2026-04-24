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
import 'talents_service.dart';

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

  bool isUnlocked(String itemId) =>
      TalentsService.I.stateNotifier.value.unlocked.contains(itemId);

  /// Intenta desbloquear. Devuelve true si tenía saldo y se desbloqueó.
  Future<bool> unlock(CollectibleItem item) async {
    if (!_init) await init();
    if (isUnlocked(item.id)) return true;
    final paid = await TalentsService.I.spend(
      item.cost,
      reason: 'unlock:${item.id}',
    );
    if (!paid) return false;
    final next = {
      ...TalentsService.I.stateNotifier.value.unlocked,
      item.id,
    };
    await TalentsService.I.mirrorUnlocked(next);
    unlockedNotifier.value = next;
    return true;
  }

  // ── Estadísticas para UI ────────────────────────────────────────────────

  int unlockedInBook(String bookId) {
    final unlocked = TalentsService.I.stateNotifier.value.unlocked;
    return unlocked.where((id) => id.startsWith('$bookId:')).length;
  }

  int totalInBook(String bookId) =>
      CollectiblesCatalog.I.itemsForBook(bookId).length;

  /// % desbloqueado en un libro (0..1).
  double progressInBook(String bookId) {
    final total = totalInBook(bookId);
    if (total == 0) return 0;
    return unlockedInBook(bookId) / total;
  }

  bool isBookComplete(String bookId) =>
      totalInBook(bookId) > 0 &&
      unlockedInBook(bookId) >= totalInBook(bookId);

  int get totalUnlocked =>
      TalentsService.I.stateNotifier.value.unlocked.length;

  /// Total disponible en el catálogo (tras BookRepository cargado).
  int get totalAvailable => CollectiblesCatalog.I.totalCount;
}
