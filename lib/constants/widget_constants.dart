/// ═══════════════════════════════════════════════════════════════════════════
/// WIDGET CONSTANTS - Constantes centralizadas para widgets nativos
/// Evita nulls y garantiza consistencia entre Flutter y código nativo
/// ═══════════════════════════════════════════════════════════════════════════
library;

/// Package name de la app Android
const String kAndroidPackageName = 'com.example.app_quitar';

/// Provider del widget 2x2 (único tamaño soportado)
/// DEBE coincidir con AndroidManifest.xml: android:name=".VictoryWidget2x2Provider"
const String kAndroidWidget2x2Provider = 'VictoryWidget2x2Provider';

/// Nombre completo calificado del provider 2x2
const String kAndroidWidget2x2QualifiedName = 
    '$kAndroidPackageName.$kAndroidWidget2x2Provider';

/// Nombre del widget iOS
const String kIOSWidgetName = 'VictoryWidget';

/// App Group para iOS
const String kIOSAppGroup = 'group.com.example.appquitar';

/// Validar que las constantes del widget no estén vacías
bool validateWidgetConstants() {
  return kAndroidPackageName.isNotEmpty &&
         kAndroidWidget2x2Provider.isNotEmpty &&
         kIOSWidgetName.isNotEmpty &&
         kIOSAppGroup.isNotEmpty;
}
