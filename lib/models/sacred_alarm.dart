import 'dart:convert';

enum SacredAlarmActivityType {
  prayer,
  worship,
  meditation,
  gratitude,
  intercession,
  declaration,
  examen,
}

extension SacredAlarmActivityTypeX on SacredAlarmActivityType {
  String get id => name;

  String get label {
    return switch (this) {
      SacredAlarmActivityType.prayer => 'Oracion',
      SacredAlarmActivityType.worship => 'Adoracion',
      SacredAlarmActivityType.meditation => 'Meditacion',
      SacredAlarmActivityType.gratitude => 'Gratitud',
      SacredAlarmActivityType.intercession => 'Intercesion',
      SacredAlarmActivityType.declaration => 'Declaracion',
      SacredAlarmActivityType.examen => 'Examen del corazon',
    };
  }

  String get shortInstruction {
    return switch (this) {
      SacredAlarmActivityType.prayer =>
        'Haz una oracion honesta y breve antes de apagar la campana.',
      SacredAlarmActivityType.worship => 'Adora a Dios por quien es, no solo por lo que ha hecho.',
      SacredAlarmActivityType.meditation =>
        'Lee el pasaje despacio y repite la frase que mas te confronte.',
      SacredAlarmActivityType.gratitude => 'Nombra tres motivos concretos de gratitud.',
      SacredAlarmActivityType.intercession =>
        'Ora por una persona especifica durante este momento.',
      SacredAlarmActivityType.declaration =>
        'Declara el pasaje en voz baja como una verdad para este dia.',
      SacredAlarmActivityType.examen =>
        'Pregunta que hay en tu corazon y entregalo sin esconderte.',
    };
  }

  String get iconGlyph {
    return switch (this) {
      SacredAlarmActivityType.prayer => '🙏',
      SacredAlarmActivityType.worship => '🎵',
      SacredAlarmActivityType.meditation => '📖',
      SacredAlarmActivityType.gratitude => '✨',
      SacredAlarmActivityType.intercession => '🤲',
      SacredAlarmActivityType.declaration => '⚔️',
      SacredAlarmActivityType.examen => '🕯️',
    };
  }

  static SacredAlarmActivityType fromId(String id) {
    return SacredAlarmActivityType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => SacredAlarmActivityType.prayer,
    );
  }
}

enum SacredAlarmEventStatus { scheduled, ringing, completed, missed }

extension SacredAlarmEventStatusX on SacredAlarmEventStatus {
  static SacredAlarmEventStatus fromId(String id) {
    return SacredAlarmEventStatus.values.firstWhere(
      (status) => status.name == id,
      orElse: () => SacredAlarmEventStatus.scheduled,
    );
  }
}

class SacredAlarmWindow {
  final String id;
  final int startMinute;
  final int endMinute;

  const SacredAlarmWindow({required this.id, required this.startMinute, required this.endMinute});

  SacredAlarmWindow copyWith({String? id, int? startMinute, int? endMinute}) {
    return SacredAlarmWindow(
      id: id ?? this.id,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
    );
  }

  bool contains(int minute) => minute >= startMinute && minute <= endMinute;

  Map<String, dynamic> toJson() {
    return {'id': id, 'startMinute': startMinute, 'endMinute': endMinute};
  }

  factory SacredAlarmWindow.fromJson(Map<String, dynamic> json) {
    return SacredAlarmWindow(
      id: json['id'] as String? ?? 'window-${DateTime.now().millisecondsSinceEpoch}',
      startMinute: _intFromJson(json['startMinute'], 7 * 60),
      endMinute: _intFromJson(json['endMinute'], 22 * 60),
    );
  }
}

class SacredAlarmFixedRule {
  final String id;
  final bool enabled;
  final int minuteOfDay;
  final List<int> weekdays;
  final SacredAlarmActivityType? activityType;

  const SacredAlarmFixedRule({
    required this.id,
    required this.minuteOfDay,
    required this.weekdays,
    this.enabled = true,
    this.activityType,
  });

  SacredAlarmFixedRule copyWith({
    String? id,
    bool? enabled,
    int? minuteOfDay,
    List<int>? weekdays,
    SacredAlarmActivityType? activityType,
    bool clearActivityType = false,
  }) {
    return SacredAlarmFixedRule(
      id: id ?? this.id,
      enabled: enabled ?? this.enabled,
      minuteOfDay: minuteOfDay ?? this.minuteOfDay,
      weekdays: weekdays ?? this.weekdays,
      activityType: clearActivityType ? null : (activityType ?? this.activityType),
    );
  }

  bool matchesDate(DateTime date) => enabled && weekdays.contains(date.weekday);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'enabled': enabled,
      'minuteOfDay': minuteOfDay,
      'weekdays': weekdays,
      'activityType': activityType?.id,
    };
  }

  factory SacredAlarmFixedRule.fromJson(Map<String, dynamic> json) {
    final rawWeekdays = json['weekdays'];
    final weekdays = rawWeekdays is List
        ? rawWeekdays
              .map((day) => _intFromJson(day, 0))
              .where((day) => day >= 1 && day <= 7)
              .toSet()
              .toList()
        : <int>[];
    final rawActivity = json['activityType'];
    return SacredAlarmFixedRule(
      id: json['id'] as String? ?? 'rule-${DateTime.now().millisecondsSinceEpoch}',
      enabled: json['enabled'] as bool? ?? true,
      minuteOfDay: _intFromJson(json['minuteOfDay'], 7 * 60),
      weekdays: weekdays..sort(),
      activityType: rawActivity is String && rawActivity.isNotEmpty
          ? SacredAlarmActivityTypeX.fromId(rawActivity)
          : null,
    );
  }
}

class SacredAlarmConfig {
  final bool enabled;
  final bool randomMode;
  final bool strictMode;
  final int startMinute;
  final int endMinute;
  final int randomCount;
  final int minGapMinutes;
  final List<SacredAlarmActivityType> activities;
  final List<SacredAlarmWindow> windows;
  final List<SacredAlarmFixedRule> fixedRules;
  final bool enforceMinimumVolume;
  final int minimumVolumePercent;
  final int scheduleDaysAhead;

  const SacredAlarmConfig({
    this.enabled = false,
    this.randomMode = true,
    this.strictMode = true,
    this.startMinute = 7 * 60,
    this.endMinute = 22 * 60,
    this.randomCount = 3,
    this.minGapMinutes = 90,
    this.activities = SacredAlarmActivityType.values,
    this.windows = const [],
    this.fixedRules = const [],
    this.enforceMinimumVolume = true,
    this.minimumVolumePercent = 50,
    this.scheduleDaysAhead = 21,
  });

  List<SacredAlarmWindow> get effectiveWindows {
    if (windows.isNotEmpty) return windows;
    return [SacredAlarmWindow(id: 'legacy', startMinute: startMinute, endMinute: endMinute)];
  }

  SacredAlarmConfig copyWith({
    bool? enabled,
    bool? randomMode,
    bool? strictMode,
    int? startMinute,
    int? endMinute,
    int? randomCount,
    int? minGapMinutes,
    List<SacredAlarmActivityType>? activities,
    List<SacredAlarmWindow>? windows,
    List<SacredAlarmFixedRule>? fixedRules,
    bool? enforceMinimumVolume,
    int? minimumVolumePercent,
    int? scheduleDaysAhead,
  }) {
    return SacredAlarmConfig(
      enabled: enabled ?? this.enabled,
      randomMode: randomMode ?? this.randomMode,
      strictMode: strictMode ?? this.strictMode,
      startMinute: startMinute ?? this.startMinute,
      endMinute: endMinute ?? this.endMinute,
      randomCount: randomCount ?? this.randomCount,
      minGapMinutes: minGapMinutes ?? this.minGapMinutes,
      activities: activities ?? this.activities,
      windows: windows ?? this.windows,
      fixedRules: fixedRules ?? this.fixedRules,
      enforceMinimumVolume: enforceMinimumVolume ?? this.enforceMinimumVolume,
      minimumVolumePercent: minimumVolumePercent ?? this.minimumVolumePercent,
      scheduleDaysAhead: scheduleDaysAhead ?? this.scheduleDaysAhead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enabled': enabled,
      'randomMode': randomMode,
      'strictMode': strictMode,
      'startMinute': startMinute,
      'endMinute': endMinute,
      'randomCount': randomCount,
      'minGapMinutes': minGapMinutes,
      'activities': activities.map((activity) => activity.id).toList(),
      'windows': windows.map((window) => window.toJson()).toList(),
      'fixedRules': fixedRules.map((rule) => rule.toJson()).toList(),
      'enforceMinimumVolume': enforceMinimumVolume,
      'minimumVolumePercent': minimumVolumePercent,
      'scheduleDaysAhead': scheduleDaysAhead,
    };
  }

  factory SacredAlarmConfig.fromJson(Map<String, dynamic> json) {
    final rawActivities = json['activities'];
    final parsedActivities = rawActivities is List
        ? rawActivities.whereType<String>().map(SacredAlarmActivityTypeX.fromId).toSet().toList()
        : SacredAlarmActivityType.values;
    final rawWindows = json['windows'];
    final parsedWindows = rawWindows is List
        ? rawWindows
              .whereType<Map>()
              .map((entry) => SacredAlarmWindow.fromJson(Map<String, dynamic>.from(entry)))
              .toList()
        : <SacredAlarmWindow>[];
    final rawRules = json['fixedRules'];
    final parsedRules = rawRules is List
        ? rawRules
              .whereType<Map>()
              .map((entry) => SacredAlarmFixedRule.fromJson(Map<String, dynamic>.from(entry)))
              .toList()
        : <SacredAlarmFixedRule>[];

    return SacredAlarmConfig(
      enabled: json['enabled'] as bool? ?? false,
      randomMode: json['randomMode'] as bool? ?? true,
      strictMode: json['strictMode'] as bool? ?? true,
      startMinute: _intFromJson(json['startMinute'], 7 * 60),
      endMinute: _intFromJson(json['endMinute'], 22 * 60),
      randomCount: _intFromJson(json['randomCount'], 3),
      minGapMinutes: _intFromJson(json['minGapMinutes'], 90),
      activities: parsedActivities.isEmpty ? SacredAlarmActivityType.values : parsedActivities,
      windows: parsedWindows,
      fixedRules: parsedRules,
      enforceMinimumVolume: json['enforceMinimumVolume'] as bool? ?? true,
      minimumVolumePercent: _intFromJson(json['minimumVolumePercent'], 50),
      scheduleDaysAhead: _intFromJson(json['scheduleDaysAhead'], 21),
    );
  }

  String encode() => jsonEncode(toJson());

  static SacredAlarmConfig decode(String? source) {
    if (source == null || source.isEmpty) return const SacredAlarmConfig();
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return SacredAlarmConfig.fromJson(decoded);
      }
    } catch (_) {}
    return const SacredAlarmConfig();
  }
}

class SacredAlarmEvent {
  final String id;
  final String dateIso;
  final int scheduledAtMs;
  final SacredAlarmActivityType activityType;
  final String verse;
  final String reference;
  final SacredAlarmEventStatus status;
  final int? firedAtMs;
  final int? completedAtMs;
  final bool locked;
  final String sourceType;
  final String sourceId;

  const SacredAlarmEvent({
    required this.id,
    required this.dateIso,
    required this.scheduledAtMs,
    required this.activityType,
    required this.verse,
    required this.reference,
    this.status = SacredAlarmEventStatus.scheduled,
    this.firedAtMs,
    this.completedAtMs,
    this.locked = true,
    this.sourceType = 'random',
    this.sourceId = 'random',
  });

  DateTime get scheduledAt => DateTime.fromMillisecondsSinceEpoch(scheduledAtMs);
  bool get isResolved => status == SacredAlarmEventStatus.completed;
  bool get isActive => status == SacredAlarmEventStatus.ringing;

  SacredAlarmEvent copyWith({
    SacredAlarmEventStatus? status,
    int? firedAtMs,
    int? completedAtMs,
    bool clearFiredAt = false,
    bool clearCompletedAt = false,
  }) {
    return SacredAlarmEvent(
      id: id,
      dateIso: dateIso,
      scheduledAtMs: scheduledAtMs,
      activityType: activityType,
      verse: verse,
      reference: reference,
      status: status ?? this.status,
      firedAtMs: clearFiredAt ? null : (firedAtMs ?? this.firedAtMs),
      completedAtMs: clearCompletedAt ? null : (completedAtMs ?? this.completedAtMs),
      locked: locked,
      sourceType: sourceType,
      sourceId: sourceId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'dateIso': dateIso,
      'scheduledAtMs': scheduledAtMs,
      'activityType': activityType.id,
      'verse': verse,
      'reference': reference,
      'status': status.name,
      'firedAtMs': firedAtMs,
      'completedAtMs': completedAtMs,
      'locked': locked,
      'sourceType': sourceType,
      'sourceId': sourceId,
    };
  }

  Map<String, dynamic> toNativeJson({
    bool enforceMinimumVolume = true,
    int minimumVolumePercent = 50,
  }) {
    return {
      'id': id,
      'scheduledAtMs': scheduledAtMs,
      'title': '${activityType.iconGlyph} ${activityType.label}',
      'body': '$reference - ${_truncate(verse, 96)}',
      'activityLabel': activityType.label,
      'instruction': activityType.shortInstruction,
      'verse': verse,
      'reference': reference,
      'route': '/sacred-alarm?sessionId=$id',
      'asset': 'flutter_assets/assets/sounds/Worship_pads.mp3',
      'enforceMinimumVolume': enforceMinimumVolume,
      'minimumVolumePercent': minimumVolumePercent,
    };
  }

  factory SacredAlarmEvent.fromJson(Map<String, dynamic> json) {
    return SacredAlarmEvent(
      id: json['id'] as String,
      dateIso: json['dateIso'] as String,
      scheduledAtMs: json['scheduledAtMs'] as int,
      activityType: SacredAlarmActivityTypeX.fromId(json['activityType'] as String? ?? ''),
      verse: json['verse'] as String? ?? '',
      reference: json['reference'] as String? ?? '',
      status: SacredAlarmEventStatusX.fromId(json['status'] as String? ?? ''),
      firedAtMs: json['firedAtMs'] as int?,
      completedAtMs: json['completedAtMs'] as int?,
      locked: json['locked'] as bool? ?? true,
      sourceType: json['sourceType'] as String? ?? 'random',
      sourceId: json['sourceId'] as String? ?? 'random',
    );
  }

  static String encodeList(List<SacredAlarmEvent> events) {
    return jsonEncode(events.map((event) => event.toJson()).toList());
  }

  static List<SacredAlarmEvent> decodeList(String? source) {
    if (source == null || source.isEmpty) return const [];
    try {
      final decoded = jsonDecode(source);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((entry) => SacredAlarmEvent.fromJson(Map<String, dynamic>.from(entry)))
            .toList();
      }
    } catch (_) {}
    return const [];
  }

  static String _truncate(String source, int maxLength) {
    if (source.length <= maxLength) return source;
    return '${source.substring(0, maxLength).trimRight()}...';
  }
}

int _intFromJson(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}
