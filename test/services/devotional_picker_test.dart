// Tests unitarios — Equipo QA
//
// Cubren:
// - DevotionalEntry: parsing legacy y nuevo formato
// - DevotionalRepository: filtros byFilter, byLegacyDay
// - DevotionalPicker: tabla determinista por (gigante × etapa) + override
//
// Estos tests NO requieren binding de Flutter (no widgets).
// Se ejecutan offline contra entradas inyectadas vía seedForTesting.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:app_quitar/models/content_enums.dart';
import 'package:app_quitar/models/devotional_entry.dart';
import 'package:app_quitar/models/plan_day.dart';
import 'package:app_quitar/models/plan_metadata.dart';
import 'package:app_quitar/services/devotional_picker.dart';
import 'package:app_quitar/services/devotional_repository.dart';
import 'package:app_quitar/services/personalization_engine.dart';

DevotionalEntry _make({
  required String id,
  GiantId? giant,
  required ContentStage stage,
  PlanReviewLevel reviewLevel = PlanReviewLevel.approved,
}) {
  return DevotionalEntry(
    id: id,
    planDay: PlanDay(
      dayIndex: 1,
      title: 'Test $id',
      scripture: const Scripture(reference: 'Test 1:1', text: 'Texto de prueba'),
      reflection: 'Reflexión de prueba con suficiente texto para no estar vacía.',
      prayer: 'Oración de prueba.',
      actionSteps: const ['Paso 1'],
    ),
    metadata: PlanMetadata(
      giants: giant != null ? <GiantId>[giant] : const <GiantId>[],
      stage: stage,
      planType: PlanType.discipleship,
      reviewLevel: reviewLevel,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DevotionalRepository.I.resetForTesting();
  });

  group('DevotionalEntry', () {
    test('fromLegacyJson preserva contenido y mapea metadata heurística', () {
      final entry = DevotionalEntry.fromLegacyJson(<String, dynamic>{
        'day': 3,
        'title': 'Correr Hacia la Libertad',
        'verse': 'Huid de la fornicación.',
        'verseReference': '1 Corintios 6:18',
        'reflection': 'La Biblia no dice resiste...',
        'challenge': 'Identifica 1 o 2 situaciones que te exponen.',
        'prayer': 'Padre, gracias...',
      });

      expect(entry.legacyDay, 3);
      expect(entry.id, 'dev_legacy_d03');
      expect(entry.title, 'Correr Hacia la Libertad');
      expect(entry.verseReference, '1 Corintios 6:18');
      expect(entry.metadata.giants, contains(GiantId.sexual));
      expect(entry.metadata.stage, ContentStage.habit);
      expect(entry.challenge, isNotNull);
    });

    test('forLength devuelve versión rápida sin reflexión', () {
      final entry = _make(id: 'a', stage: ContentStage.habit);
      final quick = entry.forLength(DevotionalLength.quick);
      expect(quick.reflection, isEmpty);
      expect(quick.verse, entry.verse);
      expect(quick.prayer, entry.prayer);
    });

    test('toJson + fromJson es round-trip', () {
      final original = _make(id: 'rt', giant: GiantId.mental, stage: ContentStage.crisis);
      final json = original.toJson();
      final round = DevotionalEntry.fromJson(json);
      expect(round.id, original.id);
      expect(round.metadata.stage, ContentStage.crisis);
      expect(round.metadata.giants, contains(GiantId.mental));
    });
  });

  group('DevotionalRepository.byFilter', () {
    test('filtra por gigante y etapa', () {
      DevotionalRepository.I.seedForTesting([
        _make(id: 'a', giant: GiantId.sexual, stage: ContentStage.habit),
        _make(id: 'b', giant: GiantId.sexual, stage: ContentStage.crisis),
        _make(id: 'c', giant: GiantId.mental, stage: ContentStage.habit),
        _make(id: 'd', stage: ContentStage.habit), // sin gigante (general)
      ]);

      final sexualHabit = DevotionalRepository.I.byFilter(
        giant: GiantId.sexual,
        stage: ContentStage.habit,
      );
      // Debe incluir 'a' (sexual+habit) y 'd' (general+habit)
      expect(sexualHabit.map((e) => e.id), containsAll(<String>['a', 'd']));
      expect(sexualHabit.map((e) => e.id), isNot(contains('b')));
      expect(sexualHabit.map((e) => e.id), isNot(contains('c')));
    });

    test('requireApproved excluye reviewed', () {
      DevotionalRepository.I.seedForTesting([
        _make(id: 'ok', stage: ContentStage.habit),
        _make(id: 'low',
            stage: ContentStage.habit, reviewLevel: PlanReviewLevel.reviewed),
      ]);
      final approved =
          DevotionalRepository.I.byFilter(requireApproved: true);
      expect(approved.map((e) => e.id), <String>['ok']);
    });
  });

  group('DevotionalPicker — selección determinista', () {
    test('crisis activa → entrada de restoration', () async {
      DevotionalRepository.I.seedForTesting([
        _make(id: 'restore_sex',
            giant: GiantId.sexual, stage: ContentStage.restoration),
        _make(id: 'habit_sex',
            giant: GiantId.sexual, stage: ContentStage.habit),
      ]);

      final result = await PersonalizationEngine.I.pickDevotionalForToday(
        giantOverride: GiantId.sexual,
        crisisOverride: true,
        userKey: 'test_uid',
      );

      // Override marca reasonCode = 'override' pero la etapa elegida es restoration.
      expect(result.matchedStage, ContentStage.restoration);
      expect(result.entry.id, 'restore_sex');
    });

    test('default → match por etapa + gigante', () async {
      DevotionalRepository.I.seedForTesting([
        _make(id: 'mental_habit',
            giant: GiantId.mental, stage: ContentStage.habit),
        _make(id: 'sexual_habit',
            giant: GiantId.sexual, stage: ContentStage.habit),
      ]);

      final result = await PersonalizationEngine.I.pickDevotionalForToday(
        giantOverride: GiantId.mental,
        userKey: 'test_uid_2',
      );

      expect(result.entry.id, 'mental_habit');
      expect(result.reasonCode, 'override');
    });

    test('determinismo: misma fecha + misma key → misma entrada', () async {
      // Repo con varias opciones para que pueda haber variación si no hay seed.
      DevotionalRepository.I.seedForTesting([
        _make(id: 'a', giant: GiantId.emotions, stage: ContentStage.habit),
        _make(id: 'b', giant: GiantId.emotions, stage: ContentStage.habit),
        _make(id: 'c', giant: GiantId.emotions, stage: ContentStage.habit),
      ]);

      final fixedDate = DateTime(2026, 5, 1);
      final r1 = await PersonalizationEngine.I.pickDevotionalForToday(
        giantOverride: GiantId.emotions,
        userKey: 'fixed_uid',
        when: fixedDate,
      );

      // Reset history (la persistencia hace que la 2da llamada filtre la 1ra).
      SharedPreferences.setMockInitialValues({});

      final r2 = await PersonalizationEngine.I.pickDevotionalForToday(
        giantOverride: GiantId.emotions,
        userKey: 'fixed_uid',
        when: fixedDate,
      );

      expect(r1.entry.id, r2.entry.id);
    });

    test('fallback cuando no hay match con esa combinación', () async {
      DevotionalRepository.I.seedForTesting([
        _make(id: 'general',
            giant: null, stage: ContentStage.maintenance),
      ]);

      final result = await PersonalizationEngine.I.pickDevotionalForToday(
        giantOverride: GiantId.sexual,
        userKey: 'fallback_test',
      );

      // No hay sexual+maintenance, pero la entrada general es válida
      // (giants vacío matchea cualquier gigante).
      expect(result.entry.id, 'general');
    });
  });
}
