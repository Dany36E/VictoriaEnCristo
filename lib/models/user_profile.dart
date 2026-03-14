/// ═══════════════════════════════════════════════════════════════════════════
/// USER PROFILE MODEL - Modelo de perfil del usuario para Cloud Sync
/// Representa los datos de perfil almacenados en Firestore /users/{uid}
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Onboarding
  final bool onboardingCompleted;
  final List<String> selectedGiants;
  final Map<String, String> giantFrequencies;
  final double victoryThreshold;
  
  // Configuración
  final bool bgmEnabled;
  final bool sfxEnabled;
  final bool isDarkMode;
  final bool notificationsEnabled;
  
  // Compañero de Batalla
  final String? inviteCode;
  final String? publicName;
  
  // Admin (solo escritura desde admin SDK/Cloud Functions)
  final bool isAdmin;
  
  const UserProfile({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    required this.createdAt,
    required this.updatedAt,
    this.onboardingCompleted = false,
    this.selectedGiants = const [],
    this.giantFrequencies = const {},
    this.victoryThreshold = 0.60,
    this.bgmEnabled = true,
    this.sfxEnabled = true,
    this.isDarkMode = false,
    this.notificationsEnabled = true,
    this.inviteCode,
    this.publicName,
    this.isAdmin = false,
  });
  
  /// Crear desde documento Firestore
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return UserProfile(
      uid: doc.id,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: _timestampToDateTime(data['createdAt']) ?? DateTime.now(),
      updatedAt: _timestampToDateTime(data['updatedAt']) ?? DateTime.now(),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      selectedGiants: _toStringList(data['selectedGiants']),
      giantFrequencies: _toStringMap(data['giantFrequencies']),
      victoryThreshold: (data['victoryThreshold'] as num?)?.toDouble() ?? 0.60,
      bgmEnabled: data['bgmEnabled'] as bool? ?? true,
      sfxEnabled: data['sfxEnabled'] as bool? ?? true,
      isDarkMode: data['isDarkMode'] as bool? ?? false,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      inviteCode: data['inviteCode'] as String?,
      publicName: data['publicName'] as String?,
      isAdmin: data['isAdmin'] as bool? ?? false,
    );
  }
  
  /// Crear desde Map local (SharedPreferences/Hive)
  factory UserProfile.fromLocal(Map<String, dynamic> data) {
    return UserProfile(
      uid: data['uid'] as String? ?? '',
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      createdAt: DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updatedAt'] ?? '') ?? DateTime.now(),
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
      selectedGiants: _toStringList(data['selectedGiants']),
      giantFrequencies: _toStringMap(data['giantFrequencies']),
      victoryThreshold: (data['victoryThreshold'] as num?)?.toDouble() ?? 0.60,
      bgmEnabled: data['bgmEnabled'] as bool? ?? true,
      sfxEnabled: data['sfxEnabled'] as bool? ?? true,
      isDarkMode: data['isDarkMode'] as bool? ?? false,
      notificationsEnabled: data['notificationsEnabled'] as bool? ?? true,
      inviteCode: data['inviteCode'] as String?,
      publicName: data['publicName'] as String?,
      isAdmin: data['isAdmin'] as bool? ?? false,
    );
  }
  
  /// Crear perfil vacío/nuevo
  factory UserProfile.empty(String uid, {String? email, String? displayName}) {
    final now = DateTime.now();
    return UserProfile(
      uid: uid,
      email: email,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );
  }
  
  /// Convertir a Map para Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'onboardingCompleted': onboardingCompleted,
      'selectedGiants': selectedGiants,
      'giantFrequencies': giantFrequencies,
      'victoryThreshold': victoryThreshold,
      'bgmEnabled': bgmEnabled,
      'sfxEnabled': sfxEnabled,
      'isDarkMode': isDarkMode,
      'notificationsEnabled': notificationsEnabled,
      'inviteCode': inviteCode,
      'publicName': publicName,
    };
  }
  
  /// Convertir a Map para almacenamiento local
  Map<String, dynamic> toLocal() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'onboardingCompleted': onboardingCompleted,
      'selectedGiants': selectedGiants,
      'giantFrequencies': giantFrequencies,
      'victoryThreshold': victoryThreshold,
      'bgmEnabled': bgmEnabled,
      'sfxEnabled': sfxEnabled,
      'isDarkMode': isDarkMode,
      'notificationsEnabled': notificationsEnabled,
      'inviteCode': inviteCode,
      'publicName': publicName,
      'isAdmin': isAdmin,
    };
  }
  
  /// Crear copia con campos actualizados
  UserProfile copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? updatedAt,
    bool? onboardingCompleted,
    List<String>? selectedGiants,
    Map<String, String>? giantFrequencies,
    double? victoryThreshold,
    bool? bgmEnabled,
    bool? sfxEnabled,
    bool? isDarkMode,
    bool? notificationsEnabled,
    String? inviteCode,
    String? publicName,
    bool? isAdmin,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      selectedGiants: selectedGiants ?? this.selectedGiants,
      giantFrequencies: giantFrequencies ?? this.giantFrequencies,
      victoryThreshold: victoryThreshold ?? this.victoryThreshold,
      bgmEnabled: bgmEnabled ?? this.bgmEnabled,
      sfxEnabled: sfxEnabled ?? this.sfxEnabled,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      inviteCode: inviteCode ?? this.inviteCode,
      publicName: publicName ?? this.publicName,
      isAdmin: isAdmin ?? this.isAdmin,
    );
  }
  
  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════════════════════
  
  static DateTime? _timestampToDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
  
  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
  
  static Map<String, String> _toStringMap(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v.toString()));
    }
    return {};
  }
  
  @override
  String toString() => 'UserProfile(uid: $uid, name: $displayName, onboarding: $onboardingCompleted)';
}
