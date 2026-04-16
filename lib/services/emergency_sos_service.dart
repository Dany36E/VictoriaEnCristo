import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/content_enums.dart';
import '../models/content_item.dart';
import 'content_repository.dart';
import 'personalization_engine.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// EMERGENCY SOS SERVICE
/// Carga pasos de emergencia personalizados por gigante y selecciona
/// contenido dinámico (versículos, oraciones) del ContentRepository
/// ═══════════════════════════════════════════════════════════════════════════

class EmergencySosService {
  // Singleton
  static final EmergencySosService _instance = EmergencySosService._internal();
  factory EmergencySosService() => _instance;
  EmergencySosService._internal();
  static EmergencySosService get I => _instance;

  final ContentRepository _repo = ContentRepository.I;
  final PersonalizationEngine _engine = PersonalizationEngine.I;
  final _random = Random();

  Map<String, dynamic>? _stepsData;

  /// Inicializar cargando emergency_steps.json
  Future<void> init() async {
    if (_stepsData != null) return;
    try {
      final jsonString = await rootBundle.loadString(
        'assets/content/emergency_steps.json',
      );
      _stepsData = json.decode(jsonString) as Map<String, dynamic>;
      debugPrint('🆘 EmergencySosService inicializado');
    } catch (e) {
      debugPrint('⚠️ Error cargando emergency_steps.json: $e');
    }
  }

  /// Obtener pasos personalizados para el gigante primario del usuario
  List<PersonalizedStep> getPersonalizedSteps() {
    final giantId = _engine.primaryGiant;
    final giantKey = giantId?.name ?? 'general';

    final giants = _stepsData?['giants'] as Map<String, dynamic>? ?? {};
    final giantData = giants[giantKey] as Map<String, dynamic>? ??
        giants['general'] as Map<String, dynamic>? ??
        {};
    final rawSteps = giantData['steps'] as List<dynamic>? ?? [];

    // Obtener versículo personalizado del ContentRepository
    final verse = _getPersonalizedVerse(giantId);

    return rawSteps.map((stepJson) {
      final step = stepJson as Map<String, dynamic>;
      final showVerse = step['show_verse'] == true;

      return PersonalizedStep(
        emoji: step['emoji'] as String? ?? '🛑',
        title: step['title'] as String? ?? '',
        instruction: step['instruction'] as String? ?? '',
        detail: step['detail'] as String?,
        duration: step['duration'] as int? ?? 5,
        // Insertar oración personalizada si el step tiene prayer
        prayer: step['prayer'] as String?,
        // Insertar versículo si show_verse es true
        verse: showVerse ? verse : null,
      );
    }).toList();
  }

  /// Nombre del gigante primario para mostrar en la UI
  String getGiantDisplayName() {
    final giantId = _engine.primaryGiant;
    final giantKey = giantId?.name ?? 'general';
    final giants = _stepsData?['giants'] as Map<String, dynamic>? ?? {};
    final giantData = giants[giantKey] as Map<String, dynamic>?;
    return giantData?['name'] as String? ?? 'General';
  }

  /// Selecciona un versículo de crisis personalizado por gigante
  VerseItem? _getPersonalizedVerse(GiantId? giantId) {
    if (!_repo.isInitialized) return null;

    // Primero: versículos de crisis + gigante del usuario
    var candidates = _repo.getCrisisVerses();
    if (giantId != null) {
      final filtered = _repo.filterByGiants(candidates, [giantId]);
      if (filtered.isNotEmpty) candidates = filtered;
    }
    // Fallback: cualquier versículo de crisis
    if (candidates.isEmpty) {
      candidates = _repo.getCrisisVerses();
    }
    // Fallback final: cualquier versículo del gigante
    if (candidates.isEmpty && giantId != null) {
      candidates = _repo.getVersesForGiants([giantId]);
    }
    if (candidates.isEmpty) return null;
    return candidates[_random.nextInt(candidates.length)];
  }
}

/// Paso de emergencia ya personalizado, listo para renderizar
class PersonalizedStep {
  final String emoji;
  final String title;
  final String instruction;
  final String? detail;
  final int duration;
  final String? prayer;
  final VerseItem? verse;

  const PersonalizedStep({
    required this.emoji,
    required this.title,
    required this.instruction,
    this.detail,
    required this.duration,
    this.prayer,
    this.verse,
  });
}
