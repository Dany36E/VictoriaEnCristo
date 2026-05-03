import 'package:flutter/foundation.dart';

class PlatformCapabilities {
  const PlatformCapabilities._();

  static bool get isDesktop {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
  }

  static bool get supportsHomeWidgets {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS => true,
      _ => false,
    };
  }

  static bool get supportsFcm {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  static bool get supportsCrashlytics {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  static bool get supportsFirebaseAnalytics {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  static bool get supportsGoogleSignIn {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android ||
      TargetPlatform.iOS ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  static bool get supportsGoogleSignInPlugin {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  static bool get supportsFirebaseAuthProviderSignIn {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows => true,
      _ => false,
    };
  }

  /// Whether the just_audio plugin (and related audio playback plugins) is
  /// available on the current platform. Currently disabled on Windows and
  /// Linux because just_audio has no implementation there and any platform
  /// call (init/setAsset/play/...) throws MissingPluginException, which
  /// can crash the Flutter engine when raised from background isolates.
  static bool get supportsAudioPlayback {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  /// Whether flutter_local_notifications is supported on this platform.
  static bool get supportsLocalNotifications {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  /// Whether the app can run the strict native Sacred Alarms flow: exact-ish
  /// scheduling plus a foreground alarm service that must be dismissed in-app.
  static bool get supportsStrictSacredAlarms {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android;
  }

  /// Whether cloud_firestore runTransaction works reliably on this platform.
  /// On Windows the firestore plugin frequently raises platform-channel
  /// thread errors that crash the engine when used inside a transaction.
  static bool get supportsFirestoreTransactions {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.linux => false,
      _ => true,
    };
  }

  static String get currentLabel {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
