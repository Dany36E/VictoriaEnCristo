/// ═══════════════════════════════════════════════════════════════════════════
/// LearningRegistry — punto único de inicialización de la Escuela del Reino.
///
/// Antes: cada pantalla de aprendizaje invocaba 11+ servicios en su propio
/// `_bootstrap`. Y `main.dart` los inicializaba también en FASE 3. El doble
/// trabajo era inocuo (todos son idempotentes vía `if (_init) return`) pero
/// generaba ruido y un coste de ~10-15 ms innecesario por reentrada.
///
/// Ahora hay un único entrypoint: `LearningRegistry.I.initAll()`. Es:
///   • Idempotente (segunda llamada es no-op).
///   • Concurrente (todos los servicios cargan en paralelo).
///   • Observa estado vía [readyNotifier] para UIs que quieran reaccionar.
///
/// Mantenemos los singletons individuales sin cambios para no romper a
/// quienes ya los consumen (offline-first + SharedPreferences ya en su sitio).
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

import 'bible_map_progress_service.dart';
import 'bible_map_repository.dart';
import 'bible_order_progress_service.dart';
import 'book_progress_service.dart';
import 'book_repository.dart';
import 'collectibles_service.dart';
import 'fruit_progress_service.dart';
import 'fruit_repository.dart';
import 'heroes_progress_service.dart';
import 'heroes_repository.dart';
import 'journey_progress_service.dart';
import 'journey_repository.dart';
import 'learning_cloud_sync.dart';
import 'learning_progress_service.dart';
import 'parable_progress_service.dart';
import 'parable_repository.dart';
import 'prophecy_progress_service.dart';
import 'prophecy_repository.dart';
import 'question_repository.dart';
import 'talents_service.dart';
import 'timeline_progress_service.dart';
import 'timeline_repository.dart';
import 'verse_memory_service.dart';

class LearningRegistry {
  LearningRegistry._();
  static final LearningRegistry I = LearningRegistry._();

  bool _started = false;
  Future<void>? _inflight;

  /// True una vez todos los servicios han terminado de cargar al menos una vez.
  final ValueNotifier<bool> readyNotifier = ValueNotifier(false);
  bool get isReady => readyNotifier.value;

  /// Inicializa (en paralelo) todos los servicios y repositorios de aprendizaje.
  /// Es seguro llamarlo varias veces: solo trabaja la primera vez.
  Future<void> initAll() {
    if (readyNotifier.value) return Future.value();
    if (_inflight != null) return _inflight!;
    _started = true;
    _inflight = _doInit();
    return _inflight!;
  }

  Future<void> _doInit() async {
    final sw = Stopwatch()..start();
    try {
      // FASE A — pull remoto ANTES de cargar los servicios para que éstos
      // inicialicen con SharedPreferences ya hidratadas desde la nube.
      await LearningCloudSync.I.bootstrap();

      await Future.wait<void>([
        // Progreso global (XP / hearts / streak)
        LearningProgressService.I.init(),

        // Repositorios (datos JSON read-only)
        QuestionRepository.I.load(),
        JourneyRepository.I.load(),
        HeroesRepository.I.load(),
        BibleMapRepository.I.load(),
        ParableRepository.I.load(),
        TimelineRepository.I.load(),
        FruitRepository.I.load(),
        BookRepository.I.load(),
        ProphecyRepository.I.load(),

        // Servicios de progreso por módulo
        JourneyProgressService.I.init(),
        HeroesProgressService.I.init(),
        BibleMapProgressService.I.init(),
        ParableProgressService.I.init(),
        TimelineProgressService.I.init(),
        FruitProgressService.I.init(),
        BookProgressService.I.init(),
        ProphecyProgressService.I.init(),
        BibleOrderProgressService.I.init(),

        // Versículos memorizados (depende de Progress para contador dominados,
        // pero el ciclo es seguro: Progress se inicializa con valor por defecto
        // y VerseMemoryService publica el contador real cuando carga).
        VerseMemoryService.I.init(),

        // Economía Talentos + Coleccionables. Talents primero (lo wrap-ea
        // CollectiblesService) — Future.wait las pone en paralelo igualmente,
        // pero CollectiblesService.init() vuelve a llamar TalentsService.I.init()
        // que es idempotente.
        TalentsService.I.init(),
        CollectiblesService.I.init(),
      ]);

      // FASE C — observar todos los notifiers de servicios sincronizables.
      // Cada cambio → markDirty → push debounced (30 s). TalentsService ya
      // sincroniza por su cuenta al doc `learning/economy`.
      LearningCloudSync.I.attachListeners(<Listenable>[
        LearningProgressService.I.progressNotifier,
        JourneyProgressService.I.stateNotifier,
        HeroesProgressService.I.stateNotifier,
        BibleMapProgressService.I.stateNotifier,
        ParableProgressService.I.stateNotifier,
        TimelineProgressService.I.stateNotifier,
        FruitProgressService.I.stateNotifier,
        BookProgressService.I.stateNotifier,
        ProphecyProgressService.I.stateNotifier,
        BibleOrderProgressService.I.stateNotifier,
        VerseMemoryService.I.changeTickNotifier,
        VerseMemoryService.I.preferredVersionNotifier,
      ]);

      readyNotifier.value = true;
      debugPrint('🎓 [REGISTRY] Listo en ${sw.elapsedMilliseconds}ms');
    } catch (e, st) {
      debugPrint('🎓 [REGISTRY] Error en init: $e\n$st');
      // Marcamos ready de todas formas: cada servicio tiene su propio fallback
      // (lista vacía / estado inicial) y la UI no debe quedar bloqueada.
      readyNotifier.value = true;
    }
  }

  /// Solo para tests: permite forzar un re-init sin reiniciar el proceso.
  @visibleForTesting
  void resetForTesting() {
    _started = false;
    _inflight = null;
    readyNotifier.value = false;
  }

  /// Útil para debug: ¿alguien ya solicitó init aunque aún no termine?
  bool get hasStarted => _started;
}
