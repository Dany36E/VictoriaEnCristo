import 'package:app_quitar/screens/journal_screen.dart';

import 'theme_matrix.dart';

void main() {
  setUpThemeMatrix();
  themeMatrix('journal', () => const JournalScreen());
}
