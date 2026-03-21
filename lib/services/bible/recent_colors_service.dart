import 'package:shared_preferences/shared_preferences.dart';
import 'bible_user_data_service.dart';

/// Servicio de colores recientes para la paleta de resaltado bíblico.
/// Guarda en SharedPreferences (inmediato) y Firestore (sync multi-dispositivo).
class RecentColorsService {
  RecentColorsService._();
  static final I = RecentColorsService._();

  static const String _prefsKey = 'bible_recent_colors';
  static const int maxRecent = 5;

  Future<List<String>> getRecentColors() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_prefsKey) ?? [];
  }

  Future<void> addRecentColor(String colorHex) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_prefsKey) ?? [];
    current.remove(colorHex);
    current.insert(0, colorHex);
    final trimmed = current.take(maxRecent).toList();
    await prefs.setStringList(_prefsKey, trimmed);

    // Sync to Firestore
    BibleUserDataService.I.updateRecentColors(trimmed);
  }
}
