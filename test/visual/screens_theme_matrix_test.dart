// Cada pantalla principal en todos los temas: desbordes, fondos de botones
// que no cubren su texto y contraste WCAG. Capturas en build/qa/.
import 'package:app_quitar/data/bible_verses.dart' as frasco;
import 'package:app_quitar/models/bible/bible_verse.dart';
import 'package:app_quitar/models/bible/bible_version.dart';
import 'package:app_quitar/services/learning/book_progress_service.dart';
import 'package:app_quitar/services/learning/book_repository.dart';
import 'package:app_quitar/screens/bible/lienzo_dibujo_screen.dart';
import 'package:app_quitar/screens/battle_partner/add_partner_screen.dart';
import 'package:app_quitar/screens/bible/all_chapter_notes_screen.dart';
import 'package:app_quitar/screens/bible/all_notes_screen.dart';
import 'package:app_quitar/screens/bible/bible_dictionary_screen.dart';
import 'package:app_quitar/screens/bible/bible_home_screen.dart';
import 'package:app_quitar/screens/bible/bible_parallel_screen.dart';
import 'package:app_quitar/screens/bible/bible_search_screen.dart';
import 'package:app_quitar/screens/bible/bible_settings_screen.dart';
import 'package:app_quitar/screens/bible/bible_timeline_screen.dart';
import 'package:app_quitar/screens/bible/blb_setup_screen.dart';
import 'package:app_quitar/screens/bible/collections_screen.dart';
import 'package:app_quitar/screens/bible/gospel_harmony_screen.dart';
import 'package:app_quitar/screens/bible/ot_quotes_screen.dart';
import 'package:app_quitar/screens/bible/saved_verses_screen.dart';
import 'package:app_quitar/screens/bible/sermon_notes_saved_screen.dart';
import 'package:app_quitar/screens/bible/template_picker_screen.dart';
import 'package:app_quitar/screens/bible/typology_screen.dart';
import 'package:app_quitar/screens/categories/crecimiento_espiritual_screen.dart';
import 'package:app_quitar/screens/categories/hermanos_en_cristo_screen.dart';
import 'package:app_quitar/screens/categories/vida_espiritual_screen.dart';
import 'package:app_quitar/screens/devotional_screen.dart';
import 'package:app_quitar/screens/emergency_screen.dart';
import 'package:app_quitar/screens/emotional_verse_jar_screen.dart';
import 'package:app_quitar/screens/exercises_screen.dart';
import 'package:app_quitar/screens/favorites_screen.dart';
import 'package:app_quitar/screens/home_screen.dart';
import 'package:app_quitar/screens/learning/armory_deck_screen.dart';
import 'package:app_quitar/screens/learning/bible_maps_screen.dart';
import 'package:app_quitar/screens/learning/bible_order_screen.dart';
import 'package:app_quitar/screens/learning/bookshelf_screen.dart';
import 'package:app_quitar/screens/learning/fruit_garden_screen.dart';
import 'package:app_quitar/screens/learning/game_headbanz_screen.dart';
import 'package:app_quitar/screens/learning/game_lightning_screen.dart';
import 'package:app_quitar/screens/learning/game_race_screen.dart';
import 'package:app_quitar/screens/learning/games_home_screen.dart';
import 'package:app_quitar/screens/learning/heroes_gallery_screen.dart';
import 'package:app_quitar/screens/learning/journey_map_screen.dart';
import 'package:app_quitar/screens/learning/my_kingdom_screen.dart';
import 'package:app_quitar/screens/learning/parables_gallery_screen.dart';
import 'package:app_quitar/screens/learning/prophecies_home_screen.dart';
import 'package:app_quitar/screens/learning/talents_library_screen.dart';
import 'package:app_quitar/screens/learning/timeline_lessons_screen.dart';
import 'package:app_quitar/screens/legal_consent_screen.dart';
import 'package:app_quitar/screens/login_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_selection_screen.dart';
import 'package:app_quitar/screens/onboarding/onboarding_welcome_screen.dart';
import 'package:app_quitar/screens/plan_library_screen.dart';
import 'package:app_quitar/screens/prayers_screen.dart';
import 'package:app_quitar/screens/privacy_center_screen.dart';
import 'package:app_quitar/screens/profile_screen.dart';
import 'package:app_quitar/screens/purity/purity_guard_screen.dart';
import 'package:app_quitar/screens/purity/remote_guardian_screen.dart';
import 'package:app_quitar/screens/sacred_alarms_screen.dart';
import 'package:app_quitar/screens/verses_screen.dart';
import 'package:app_quitar/screens/wall/wall_screen.dart';
import 'package:app_quitar/screens/widget_settings_screen.dart';
import 'package:app_quitar/widgets/share_verse_modal.dart';
import 'package:app_quitar/screens/settings_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'theme_matrix.dart';

// Fuera de la matriz, porque no se pueden dibujar en una prueba de widgets:
// - AdminWallScreen, BattlePartnerScreen, LearningHomeScreen y ProgressScreen
//   llaman a Firestore, Auth o Analytics al abrir (necesitan el plugin nativo).
// - ManaSessionScreen elige preguntas al azar en cada ejecución.
// - BibleStatsScreen y ApiSetupWizardScreen usan Instrument Serif y Source
//   Code Pro, que no están en google_fonts/ (se descargan en tiempo real).
// - SermonNotesModeScreen y StudyModeScreen cargan el texto de la Biblia antes
//   de dibujarse: en la prueba se quedan en el indicador de carga.
void main() {
  setUpThemeMatrix();
  // Biblioteca: en la app los libros se cargan al abrirla (LearningRegistry).
  // Dos quedan estudiados para medir también el lomo café.
  setUpAll(() async {
    await BookRepository.I.load();
    final libros = BookRepository.I.all;
    BookProgressService.I.stateNotifier.value = BookProgressState(
      studied: {libros[0].id, libros[1].id},
      bestScores: {libros[0].id: 3},
    );
  });
  themeMatrix('add_partner', () => const AddPartnerScreen());
  themeMatrix('all_chapter_notes', () => const AllChapterNotesScreen());
  themeMatrix('all_notes', () => const AllNotesScreen());
  themeMatrix('bible_dictionary', () => const BibleDictionaryScreen());
  themeMatrix('bible_home', () => const BibleHomeScreen());
  themeMatrix(
    'bible_parallel',
    () => const BibleParallelScreen(
      bookNumber: 43,
      bookName: 'Juan',
      chapter: 3,
      primaryVersion: BibleVersion.rvr1960,
    ),
  );
  themeMatrix('bible_search', () => const BibleSearchScreen());
  themeMatrix('bible_settings', () => const BibleSettingsScreen());
  themeMatrix('bible_timeline', () => const BibleTimelineScreen());
  themeMatrix('blb_setup', () => const BlbSetupScreen());
  themeMatrix('collections', () => const CollectionsScreen());
  themeMatrix('gospel_harmony', () => const GospelHarmonyScreen());
  themeMatrix('lienzo_dibujo', () => const LienzoDibujoScreen());
  themeMatrix('ot_quotes', () => const OTQuotesScreen());
  themeMatrix('saved_verses', () => const SavedVersesScreen());
  themeMatrix('sermon_notes_saved', () => const SermonNotesSavedScreen());
  themeMatrix('typology', () => const TypologyScreen());
  themeMatrix(
    'compartir_plantillas',
    () => const TemplatePickerScreen(verse: _filipenses),
  );
  themeMatrix(
    'compartir_versiculo',
    () => const Scaffold(
      body: Align(
        alignment: Alignment.bottomCenter,
        child: ShareVerseModal(
          verse: frasco.BibleVerse(
            verse: 'Todo lo puedo en Cristo que me fortalece.',
            reference: 'Filipenses 4:13',
            category: 'fortaleza',
          ),
        ),
      ),
    ),
  );
  themeMatrix(
    'crecimiento_espiritual',
    () => const CrecimientoEspiritualScreen(),
  );
  themeMatrix('hermanos_en_cristo', () => const HermanosEnCristoScreen());
  themeMatrix('vida_espiritual', () => const VidaEspiritualScreen());
  themeMatrix(
    'devotional',
    () => const DevotionalScreen(),
    contenidoDelDia: true,
  );
  themeMatrix('emergency', () => const EmergencyScreen());
  themeMatrix('emotional_verse_jar', () => const EmotionalVerseJarScreen());
  themeMatrix('exercises', () => const ExercisesScreen());
  themeMatrix('favorites', () => const FavoritesScreen());
  themeMatrix('armory_deck', () => const ArmoryDeckScreen());
  themeMatrix('bible_maps', () => const BibleMapsScreen());
  themeMatrix('bible_order', () => const BibleOrderScreen());
  themeMatrix('bookshelf', () => const BookshelfScreen());
  themeMatrix('fruit_garden', () => const FruitGardenScreen());
  themeMatrix('game_headbanz', () => const GameHeadbanzScreen());
  themeMatrix('game_lightning', () => const GameLightningScreen());
  themeMatrix('game_race', () => const GameRaceScreen());
  themeMatrix('games_home', () => const GamesHomeScreen());
  themeMatrix('heroes_gallery', () => const HeroesGalleryScreen());
  themeMatrix('journey_map', () => const JourneyMapScreen());
  themeMatrix('my_kingdom', () => const MyKingdomScreen());
  themeMatrix('parables_gallery', () => const ParablesGalleryScreen());
  themeMatrix('prophecies_home', () => const PropheciesHomeScreen());
  themeMatrix('talents_library', () => const TalentsLibraryScreen());
  themeMatrix('timeline_lessons', () => const TimelineLessonsScreen());
  themeMatrix('legal_consent', () => const LegalConsentScreen());
  themeMatrix('giant_selection', () => const GiantSelectionScreen());
  themeMatrix('onboarding_welcome', () => const OnboardingWelcomeScreen());
  themeMatrix('plan_library', () => const PlanLibraryScreen());
  themeMatrix('prayers', () => const PrayersScreen());
  themeMatrix('privacy_center', () => const PrivacyCenterScreen());
  themeMatrix('purity_guard', () => const PurityGuardScreen());
  themeMatrix('remote_guardian', () => const RemoteGuardianScreen());
  themeMatrix('sacred_alarms', () => const SacredAlarmsScreen());
  themeMatrix('verses', () => const VersesScreen());
  themeMatrix('wall', () => const WallScreen());
  themeMatrix('widget_settings', () => const WidgetSettingsScreen());
  themeMatrix('home', () => const HomeScreen(), contenidoDelDia: true);
  themeMatrix('login', () => const LoginScreen());
  themeMatrix('profile', () => const ProfileScreen());
  themeMatrix('settings', () => SettingsScreen(onThemeChanged: () {}));
}

const _filipenses = BibleVerse(
  bookName: 'Filipenses',
  bookNumber: 50,
  chapter: 4,
  verse: 13,
  text: 'Todo lo puedo en Cristo que me fortalece.',
  version: 'RVR1960',
);
