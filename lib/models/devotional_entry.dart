/// ═══════════════════════════════════════════════════════════════════════════
/// DEVOTIONAL ENTRY — RFC-001 (Opción B)
///
/// Wrapper sobre [PlanDay] + [PlanMetadata]. Es el modelo unificado del
/// nuevo sistema de Devocionales: un único esquema compartido con Planes,
/// con metadata que permite personalización por gigante × etapa.
///
/// Compatible con el JSON legacy de `assets/content/devotionals.json`
/// (campos planos verse/reflection/challenge/prayer) vía
/// [DevotionalEntry.fromLegacyJson], y con el formato nuevo
/// `assets/content/devotional_pool.json`.
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'plan_day.dart';
import 'plan_metadata.dart';
import 'content_enums.dart';

/// Variante de duración de lectura.
enum DevotionalLength { quick, standard, deep }

extension DevotionalLengthX on DevotionalLength {
  /// Minutos estimados objetivo
  int get targetMinutes => switch (this) {
        DevotionalLength.quick => 2,
        DevotionalLength.standard => 8,
        DevotionalLength.deep => 15,
      };

  String get label => switch (this) {
        DevotionalLength.quick => '2 min',
        DevotionalLength.standard => '8 min',
        DevotionalLength.deep => '15 min',
      };
}

/// Entrada del pool de devocionales.
///
/// Es inmutable. La selección "Hoy para ti" se hace en
/// [PersonalizationEngine.pickDevotionalForToday].
class DevotionalEntry {
  /// ID estable. Convención: `dev_<source>_<idx>` o
  /// `dev_<giant>_<stage>_<short>`.
  final String id;

  /// Día legacy (1..30) si proviene del pool original. `null` si es nuevo.
  final int? legacyDay;

  /// Día del calendario al que pertenece (yyyy-mm-dd) si es atemporal-pool
  /// dejarlo en null y será asignado por el selector.
  final DateTime? assignedDate;

  /// Día estructurado (verse, reflection, prayer, actionSteps, checkIn).
  final PlanDay planDay;

  /// Metadata para personalización (giants, stage, techniques, reviewLevel).
  final PlanMetadata metadata;

  /// "Reto del día" (texto suelto que el legacy tenía como `challenge`).
  /// En el nuevo formato esto se modela como un solo `actionStep` "marcable".
  /// Se conserva como string para retro-compat de UI.
  final String? challenge;

  const DevotionalEntry({
    required this.id,
    required this.planDay,
    required this.metadata,
    this.legacyDay,
    this.assignedDate,
    this.challenge,
  });

  /// Versículo principal (atajo de UI)
  String get verse => planDay.scripture.text;
  String get verseReference => planDay.scripture.reference;
  String get reflection => planDay.reflection;
  String get prayer => planDay.prayer;
  String get title => planDay.title;

  /// Versión rápida (modo 2 min).
  DevotionalEntry get quick => DevotionalEntry(
        id: id,
        legacyDay: legacyDay,
        assignedDate: assignedDate,
        planDay: planDay.quickVersion,
        metadata: metadata,
        challenge: challenge,
      );

  /// Versión profunda — incluye check-in (modo 15 min).
  /// Si la entrada no trae check-in extra, devuelve la misma.
  DevotionalEntry get deep => this;

  /// Build a partir de la variante deseada.
  DevotionalEntry forLength(DevotionalLength len) {
    switch (len) {
      case DevotionalLength.quick:
        return quick;
      case DevotionalLength.standard:
        return this;
      case DevotionalLength.deep:
        return deep;
    }
  }

  /// Estima los minutos de lectura.
  int get estimatedMinutes => planDay.estimatedMinutes;

  // ───────────────────────────────────────────────────────────────────────
  // Serialización del formato NUEVO (pool unificado)
  // ───────────────────────────────────────────────────────────────────────

  factory DevotionalEntry.fromJson(Map<String, dynamic> json) {
    final planDayJson = json['planDay'] as Map<String, dynamic>?;
    final metadataJson = json['metadata'] as Map<String, dynamic>?;

    return DevotionalEntry(
      id: json['id'] as String? ?? 'dev_unknown',
      legacyDay: json['legacyDay'] as int?,
      assignedDate: json['assignedDate'] != null
          ? DateTime.tryParse(json['assignedDate'] as String)
          : null,
      planDay: planDayJson != null
          ? PlanDay.fromJson(planDayJson)
          : const PlanDay(
              dayIndex: 1,
              title: '',
              scripture: Scripture(reference: '', text: ''),
              reflection: '',
              prayer: '',
            ),
      metadata: metadataJson != null
          ? PlanMetadata.fromJson(metadataJson)
          : const PlanMetadata(
              giants: [],
              stage: ContentStage.habit,
              planType: PlanType.discipleship,
            ),
      challenge: json['challenge'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        if (legacyDay != null) 'legacyDay': legacyDay,
        if (assignedDate != null)
          'assignedDate': assignedDate!.toIso8601String().substring(0, 10),
        'planDay': planDay.toJson(),
        'metadata': metadata.toJson(),
        if (challenge != null) 'challenge': challenge,
      };

  // ───────────────────────────────────────────────────────────────────────
  // Adaptador del formato LEGACY (devotionals.json plano)
  // ───────────────────────────────────────────────────────────────────────

  /// Convierte un objeto JSON legacy (campos: day, title, verse,
  /// verseReference, reflection, challenge, prayer) en un [DevotionalEntry]
  /// usando heurísticas para inferir metadata si no se proveen overrides.
  factory DevotionalEntry.fromLegacyJson(
    Map<String, dynamic> json, {
    PlanMetadata? metadataOverride,
  }) {
    final day = (json['day'] as num?)?.toInt() ?? 1;
    final title = json['title'] as String? ?? 'Día $day';
    final verseText = json['verse'] as String? ?? '';
    final verseRef = json['verseReference'] as String? ?? '';
    final reflection = json['reflection'] as String? ?? '';
    final prayer = json['prayer'] as String? ?? '';
    final challenge = json['challenge'] as String?;

    final planDay = PlanDay(
      dayIndex: day,
      title: title,
      scripture: Scripture(reference: verseRef, text: verseText),
      reflection: reflection,
      prayer: prayer,
      actionSteps: challenge != null && challenge.isNotEmpty
          ? <String>[challenge]
          : const <String>[],
    );

    final metadata = metadataOverride ?? _inferMetadataForLegacyDay(day);

    return DevotionalEntry(
      id: 'dev_legacy_d${day.toString().padLeft(2, '0')}',
      legacyDay: day,
      planDay: planDay,
      metadata: metadata,
      challenge: challenge,
    );
  }

  /// Heurística mínima de metadata para los 30 devocionales originales.
  /// Esta tabla sale del audit del Equipo Foundations (M0) y se ajusta
  /// cuando Pastoral apruebe el pool oficial.
  static PlanMetadata _inferMetadataForLegacyDay(int day) {
    // Día → (giants, stage, techniques)
    final mapping = _legacyMetadataMap[day] ??
        const _LegacyMeta(<GiantId>[], ContentStage.habit, <TechniqueId>[]);

    return PlanMetadata(
      giants: mapping.giants,
      stage: mapping.stage,
      planType: PlanType.discipleship,
      techniques: mapping.techniques,
      reviewLevel: PlanReviewLevel.reviewed,
      tags: const ['legacy_30d'],
    );
  }
}

/// Tabla de mapeo del audit M0. Mantener cerca del modelo para que
/// pastoral pueda revisarla en un solo archivo.
class _LegacyMeta {
  final List<GiantId> giants;
  final ContentStage stage;
  final List<TechniqueId> techniques;
  const _LegacyMeta(this.giants, this.stage, this.techniques);
}

const Map<int, _LegacyMeta> _legacyMetadataMap = {
  1: _LegacyMeta(
      <GiantId>[], ContentStage.crisis, <TechniqueId>[TechniqueId.declarativeprayer]),
  2: _LegacyMeta(<GiantId>[], ContentStage.habit,
      <TechniqueId>[TechniqueId.scriptureMeditation]),
  3: _LegacyMeta(<GiantId>[GiantId.sexual], ContentStage.habit,
      <TechniqueId>[TechniqueId.environmentDesign, TechniqueId.urgeDelay]),
  4: _LegacyMeta(<GiantId>[GiantId.emotions], ContentStage.habit,
      <TechniqueId>[TechniqueId.accountability]),
  5: _LegacyMeta(<GiantId>[GiantId.mental], ContentStage.habit,
      <TechniqueId>[TechniqueId.cbtReframe]),
  6: _LegacyMeta(<GiantId>[GiantId.sexual, GiantId.health], ContentStage.habit,
      <TechniqueId>[TechniqueId.scriptureMeditation]),
  7: _LegacyMeta(<GiantId>[], ContentStage.habit,
      <TechniqueId>[TechniqueId.declarativeprayer]),
  8: _LegacyMeta(<GiantId>[], ContentStage.habit,
      <TechniqueId>[TechniqueId.scriptureMeditation]),
  9: _LegacyMeta(<GiantId>[], ContentStage.habit,
      <TechniqueId>[TechniqueId.declarativeprayer]),
  10: _LegacyMeta(<GiantId>[GiantId.emotions], ContentStage.restoration,
      <TechniqueId>[TechniqueId.cbtReframe]),
  11: _LegacyMeta(<GiantId>[GiantId.mental, GiantId.sexual], ContentStage.habit,
      <TechniqueId>[TechniqueId.cbtReframe, TechniqueId.cravingSurfing]),
  12: _LegacyMeta(<GiantId>[], ContentStage.habit,
      <TechniqueId>[TechniqueId.worship]),
  13: _LegacyMeta(<GiantId>[GiantId.sexual], ContentStage.habit,
      <TechniqueId>[TechniqueId.cbtReframe]),
  14: _LegacyMeta(<GiantId>[], ContentStage.maintenance,
      <TechniqueId>[TechniqueId.microCommitment]),
  15: _LegacyMeta(<GiantId>[GiantId.sexual, GiantId.digital], ContentStage.habit,
      <TechniqueId>[TechniqueId.environmentDesign]),
  16: _LegacyMeta(<GiantId>[GiantId.emotions], ContentStage.habit,
      <TechniqueId>[TechniqueId.accountability]),
  17: _LegacyMeta(<GiantId>[GiantId.emotions, GiantId.sexual], ContentStage.habit,
      <TechniqueId>[TechniqueId.triggerAwareness, TechniqueId.replacementHabit]),
  18: _LegacyMeta(<GiantId>[GiantId.emotions], ContentStage.restoration,
      <TechniqueId>[TechniqueId.cbtReframe]),
  19: _LegacyMeta(<GiantId>[], ContentStage.habit,
      <TechniqueId>[TechniqueId.microCommitment]),
  20: _LegacyMeta(<GiantId>[GiantId.emotions, GiantId.mental], ContentStage.habit,
      <TechniqueId>[TechniqueId.journaling]),
  21: _LegacyMeta(<GiantId>[], ContentStage.maintenance,
      <TechniqueId>[TechniqueId.microCommitment]),
  22: _LegacyMeta(<GiantId>[], ContentStage.habit,
      <TechniqueId>[TechniqueId.environmentDesign]),
  23: _LegacyMeta(<GiantId>[GiantId.mental], ContentStage.habit,
      <TechniqueId>[TechniqueId.scriptureMeditation]),
  24: _LegacyMeta(<GiantId>[], ContentStage.restoration,
      <TechniqueId>[TechniqueId.declarativeprayer]),
  25: _LegacyMeta(<GiantId>[GiantId.emotions], ContentStage.habit,
      <TechniqueId>[TechniqueId.journaling]),
  26: _LegacyMeta(<GiantId>[GiantId.emotions], ContentStage.habit,
      <TechniqueId>[TechniqueId.accountability]),
  27: _LegacyMeta(<GiantId>[GiantId.mental], ContentStage.habit,
      <TechniqueId>[TechniqueId.cbtReframe, TechniqueId.declarativeprayer]),
  28: _LegacyMeta(<GiantId>[], ContentStage.maintenance,
      <TechniqueId>[TechniqueId.microCommitment]),
  29: _LegacyMeta(<GiantId>[], ContentStage.maintenance,
      <TechniqueId>[TechniqueId.worship]),
  30: _LegacyMeta(<GiantId>[], ContentStage.maintenance,
      <TechniqueId>[TechniqueId.declarativeprayer]),
};
