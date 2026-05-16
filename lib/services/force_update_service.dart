import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

/// Controla la actualización forzada de la app.
///
/// Firestore — documento: `app_config/android`
/// Campo:  `min_build` (int) — si el build instalado es menor, se fuerza update.
///
/// Ejemplo: subir a `min_build: 3` para forzar actualización a todos los
/// usuarios con build 1 ó 2.
class ForceUpdateService {
  ForceUpdateService._();
  static final ForceUpdateService I = ForceUpdateService._();

  /// Build number actual de la app (el número después del + en pubspec.yaml).
  /// ⚠️ Actualizar cuando se haga bump del versionCode en pubspec.yaml.
  static const int currentBuild = 2;

  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.victoriaencristo.app';

  /// Retorna `true` si el build instalado es menor que `min_build` en Firestore.
  /// Si Firestore no responde o el documento no existe, retorna `false`
  /// para no bloquear la app por falta de conectividad.
  Future<bool> isUpdateRequired() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app_config')
          .doc('android')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));
      if (!doc.exists) return false;
      final minBuild = doc.data()?['min_build'];
      if (minBuild is! int) return false;
      return currentBuild < minBuild;
    } catch (_) {
      // Sin internet o error: no bloquear la app.
      return false;
    }
  }

  /// Abre la ficha de la app en Play Store.
  Future<void> openPlayStore() async {
    final uri = Uri.parse(_playStoreUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
