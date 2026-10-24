// Matriz visual de las pantallas de prioridad de gigantes: ordenar en el
// onboarding, editor «Mis gigantes» y emergencia con chips de gigantes.
import 'package:app_quitar/screens/emergency_screen.dart';
import 'package:app_quitar/screens/mis_gigantes_screen.dart';
import 'package:app_quitar/screens/onboarding/giant_ranking_screen.dart';
import 'package:app_quitar/services/emergency_sos_service.dart';
import 'package:app_quitar/services/onboarding_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_matrix.dart';

void main() {
  setUpThemeMatrix();
  setUpAll(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('selected_giants', [
      'sexual',
      'digital',
      'mental',
    ]);
    await prefs.setString(
      'giant_frequencies_json',
      '{"sexual":"daily","digital":"weekly","mental":"occasional"}',
    );
    await prefs.setBool(OnboardingService.keyGiantOrderExplicit, true);
    await OnboardingService().init();
    await EmergencySosService.I.init();
  });

  themeMatrix(
    'giant_ranking',
    () => const GiantRankingScreen(
      selectedGiants: ['sexual', 'digital', 'mental'],
    ),
  );
  themeMatrix('mis_gigantes', () => const MisGigantesScreen());
  themeMatrix(
    'emergency_gigantes',
    () => const EmergencyScreen(),
    contenidoDelDia: true,
  );
}
