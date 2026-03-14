/// Configuración del Widget de pantalla de inicio
/// Permite personalizar apariencia y contenido con modo discreto
library;

import 'dart:convert';

/// Plantilla visual del widget
enum WidgetTemplate {
  /// Solo título neutro + ícono (máxima discreción)
  discreet,
  /// Muestra un versículo del día
  verse,
  /// Muestra la racha de días
  streak,
  /// Combinación de título + verso + racha
  combo,
}

/// Nivel de privacidad del widget
enum WidgetPrivacyMode {
  /// No muestra términos sensibles ni referencias religiosas explícitas
  discreet,
  /// Muestra contenido normal con referencias cristianas
  normal,
}

/// Tema visual del widget
enum WidgetTheme {
  /// Fondo claro, amigable como nota
  lightCard,
  /// Fondo oscuro, premium
  darkCard,
}

/// Títulos predefinidos para modo discreto
class WidgetTitlePresets {
  static const List<String> discreet = [
    'Rutina diaria',
    'Reflexión',
    'Hoy',
    'Un paso a la vez',
    'Constancia',
    'Mi momento',
    'Recordatorio',
  ];
  
  static const List<String> normal = [
    'Victoria en Cristo',
    'Mi victoria diaria',
    'Fe y fortaleza',
    'Camino de pureza',
    'Gracia diaria',
  ];
  
  static String get defaultDiscreet => discreet.first;
  static String get defaultNormal => normal.first;
}

/// Configuración completa del widget de pantalla de inicio
class WidgetConfig {
  final WidgetTemplate template;
  final WidgetPrivacyMode privacyMode;
  final String titleText;
  final bool showStreak;
  final bool showVerse;
  final bool showCTA;
  final WidgetTheme theme;
  final DateTime lastUpdated;

  const WidgetConfig({
    this.template = WidgetTemplate.discreet,
    this.privacyMode = WidgetPrivacyMode.discreet,
    this.titleText = 'Rutina diaria',
    this.showStreak = true,
    this.showVerse = false,
    this.showCTA = true,
    this.theme = WidgetTheme.lightCard,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? const _DefaultDateTime();

  /// Configuración por defecto (máxima discreción)
  factory WidgetConfig.defaultConfig() {
    return WidgetConfig(
      template: WidgetTemplate.discreet,
      privacyMode: WidgetPrivacyMode.discreet,
      titleText: WidgetTitlePresets.defaultDiscreet,
      showStreak: true,
      showVerse: false,
      showCTA: true,
      theme: WidgetTheme.lightCard,
      lastUpdated: DateTime.now(),
    );
  }

  /// Crea una copia con campos modificados
  WidgetConfig copyWith({
    WidgetTemplate? template,
    WidgetPrivacyMode? privacyMode,
    String? titleText,
    bool? showStreak,
    bool? showVerse,
    bool? showCTA,
    WidgetTheme? theme,
    DateTime? lastUpdated,
  }) {
    return WidgetConfig(
      template: template ?? this.template,
      privacyMode: privacyMode ?? this.privacyMode,
      titleText: titleText ?? this.titleText,
      showStreak: showStreak ?? this.showStreak,
      showVerse: showVerse ?? this.showVerse,
      showCTA: showCTA ?? this.showCTA,
      theme: theme ?? this.theme,
      lastUpdated: lastUpdated ?? DateTime.now(),
    );
  }

  /// Convierte a Map para persistencia
  Map<String, dynamic> toJson() {
    return {
      'template': template.index,
      'privacyMode': privacyMode.index,
      'titleText': titleText,
      'showStreak': showStreak,
      'showVerse': showVerse,
      'showCTA': showCTA,
      'theme': theme.index,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  /// Crea desde Map
  factory WidgetConfig.fromJson(Map<String, dynamic> json) {
    return WidgetConfig(
      template: WidgetTemplate.values[json['template'] as int? ?? 0],
      privacyMode: WidgetPrivacyMode.values[json['privacyMode'] as int? ?? 0],
      titleText: json['titleText'] as String? ?? WidgetTitlePresets.defaultDiscreet,
      showStreak: json['showStreak'] as bool? ?? true,
      showVerse: json['showVerse'] as bool? ?? false,
      showCTA: json['showCTA'] as bool? ?? true,
      theme: WidgetTheme.values[json['theme'] as int? ?? 0],
      lastUpdated: json['lastUpdated'] != null 
          ? DateTime.tryParse(json['lastUpdated'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  /// Serializa a JSON string
  String toJsonString() => jsonEncode(toJson());

  /// Deserializa desde JSON string
  factory WidgetConfig.fromJsonString(String jsonString) {
    try {
      return WidgetConfig.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
    } catch (_) {
      return WidgetConfig.defaultConfig();
    }
  }

  /// Obtiene el título según el modo de privacidad
  String get effectiveTitle {
    if (privacyMode == WidgetPrivacyMode.discreet) {
      // En modo discreto, asegurar que el título no sea sensible
      if (WidgetTitlePresets.normal.contains(titleText)) {
        return WidgetTitlePresets.defaultDiscreet;
      }
    }
    return titleText;
  }

  /// Texto de la racha según privacidad
  String getStreakText(int days) {
    if (privacyMode == WidgetPrivacyMode.discreet) {
      if (days == 0) return 'Comienza hoy';
      if (days == 1) return '1 día';
      return '$days días';
    } else {
      if (days == 0) return 'Comienza tu victoria';
      if (days == 1) return '1 día de victoria';
      return '$days días de victoria';
    }
  }

  /// Label de la racha según privacidad
  String get streakLabel {
    return privacyMode == WidgetPrivacyMode.discreet ? 'Progreso' : 'Racha';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WidgetConfig &&
        other.template == template &&
        other.privacyMode == privacyMode &&
        other.titleText == titleText &&
        other.showStreak == showStreak &&
        other.showVerse == showVerse &&
        other.showCTA == showCTA &&
        other.theme == theme;
  }

  @override
  int get hashCode {
    return Object.hash(
      template,
      privacyMode,
      titleText,
      showStreak,
      showVerse,
      showCTA,
      theme,
    );
  }
}

/// Helper para DateTime por defecto en const constructor
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => DateTime.now();
}

/// Datos que se envían al widget nativo
class WidgetPayload {
  final String title;
  final String line1;
  final String line2;
  final int streakValue;
  final String verseSnippet;
  final String verseReference;
  final String dateISO;
  final bool showStreak;
  final bool showVerse;
  final bool showCTA;
  final String ctaText;
  final bool isLightTheme;
  final bool isDiscreetMode;

  const WidgetPayload({
    required this.title,
    required this.line1,
    required this.line2,
    required this.streakValue,
    required this.verseSnippet,
    required this.verseReference,
    required this.dateISO,
    required this.showStreak,
    required this.showVerse,
    required this.showCTA,
    required this.ctaText,
    required this.isLightTheme,
    required this.isDiscreetMode,
  });

  /// Payload por defecto (fallback neutral)
  factory WidgetPayload.fallback() {
    return WidgetPayload(
      title: 'Rutina diaria',
      line1: 'Respira. Sigue hoy.',
      line2: 'Abre la app cuando puedas.',
      streakValue: 0,
      verseSnippet: '',
      verseReference: '',
      dateISO: DateTime.now().toIso8601String().split('T').first,
      showStreak: false,
      showVerse: false,
      showCTA: true,
      ctaText: 'Abrir',
      isLightTheme: true,
      isDiscreetMode: true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'line1': line1,
      'line2': line2,
      'streakValue': streakValue,
      'verseSnippet': verseSnippet,
      'verseReference': verseReference,
      'dateISO': dateISO,
      'showStreak': showStreak,
      'showVerse': showVerse,
      'showCTA': showCTA,
      'ctaText': ctaText,
      'isLightTheme': isLightTheme,
      'isDiscreetMode': isDiscreetMode,
    };
  }

  String toJsonString() => jsonEncode(toJson());
}
