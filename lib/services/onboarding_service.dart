import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/profile_repository.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// ONBOARDING SERVICE
/// Gestiona el estado del onboarding y persiste las selecciones del usuario
/// 
/// CLOUD SYNC AWARE:
/// - Si hay usuario autenticado, delega a ProfileRepository (cloud + cache)
/// - Si no hay usuario, usa SharedPreferences como fallback
/// ═══════════════════════════════════════════════════════════════════════════

class OnboardingService {
  static const String _keyOnboardingCompleted = 'onboarding_completed';
  static const String _keySelectedGiants = 'selected_giants';
  static const String _keySelectedIntensity = 'selected_intensity';
  static const String _keyGiantFrequencies = 'giant_frequencies_json';
  
  // Singleton
  static final OnboardingService _instance = OnboardingService._internal();
  factory OnboardingService() => _instance;
  OnboardingService._internal();
  
  SharedPreferences? _prefs;
  
  /// Getter para verificar si hay un usuario autenticado
  bool get _hasCloudProfile {
    final user = FirebaseAuth.instance.currentUser;
    return user != null && ProfileRepository.I.currentProfile != null;
  }
  
  /// Inicializar el servicio
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// ═══════════════════════════════════════════════════════════════════════════
  /// ESTADO DEL ONBOARDING
  /// ═══════════════════════════════════════════════════════════════════════════
  
  /// Verificar si el usuario ya completó el onboarding
  /// Prioriza cloud si hay usuario autenticado
  bool get isOnboardingCompleted {
    // Prioridad: Cloud profile > Local SharedPreferences
    if (_hasCloudProfile) {
      return ProfileRepository.I.currentProfile!.onboardingCompleted;
    }
    return _prefs?.getBool(_keyOnboardingCompleted) ?? false;
  }
  
  /// Marcar el onboarding como completado
  /// Sincroniza a cloud si hay usuario autenticado
  Future<void> markOnboardingCompleted() async {
    // Siempre guardar local como cache
    await _prefs?.setBool(_keyOnboardingCompleted, true);
    debugPrint('✅ Onboarding marcado como completado (local)');
    
    // Sincronizar a cloud si hay usuario
    if (_hasCloudProfile) {
      await ProfileRepository.I.updateProfile(
        (profile) => profile.copyWith(onboardingCompleted: true),
      );
      debugPrint('☁️ Onboarding sincronizado a cloud');
    }
  }
  
  /// Resetear el onboarding (útil para testing)
  /// ⚠️ SOLO limpia cache local, NO borra datos en la nube
  Future<void> resetOnboarding() async {
    await _prefs?.remove(_keyOnboardingCompleted);
    await _prefs?.remove(_keySelectedGiants);
    await _prefs?.remove(_keySelectedIntensity);
    await _prefs?.remove(_keyGiantFrequencies);
    debugPrint('🔄 Onboarding local reseteado (cache limpiado)');
  }
  
  /// ═══════════════════════════════════════════════════════════════════════════
  /// GIGANTES SELECCIONADOS
  /// ═══════════════════════════════════════════════════════════════════════════
  
  /// Guardar los gigantes seleccionados
  /// Sincroniza a cloud si hay usuario autenticado
  Future<void> saveSelectedGiants(List<String> giants) async {
    // Guardar local
    await _prefs?.setStringList(_keySelectedGiants, giants);
    debugPrint('💾 Gigantes guardados (local): $giants');
    
    // Sincronizar a cloud
    if (_hasCloudProfile) {
      await ProfileRepository.I.updateProfile(
        (profile) => profile.copyWith(selectedGiants: giants),
      );
      debugPrint('☁️ Gigantes sincronizados a cloud');
    }
  }
  
  /// Obtener los gigantes seleccionados
  /// Prioriza cloud si hay usuario autenticado
  List<String> get selectedGiants {
    if (_hasCloudProfile) {
      return ProfileRepository.I.currentProfile!.selectedGiants;
    }
    return _prefs?.getStringList(_keySelectedGiants) ?? [];
  }
  
  /// ═══════════════════════════════════════════════════════════════════════════
  /// INTENSIDAD SELECCIONADA
  /// ═══════════════════════════════════════════════════════════════════════════
  
  /// Guardar la intensidad seleccionada (legacy - mantener compatibilidad)
  Future<void> saveSelectedIntensity(String intensity) async {
    await _prefs?.setString(_keySelectedIntensity, intensity);
    debugPrint('💾 Intensidad guardada: $intensity');
  }
  
  /// Obtener la intensidad seleccionada (legacy)
  String? get selectedIntensity {
    return _prefs?.getString(_keySelectedIntensity);
  }
  
  /// ═══════════════════════════════════════════════════════════════════════════
  /// FRECUENCIAS POR GIGANTE (NUEVO)
  /// ═══════════════════════════════════════════════════════════════════════════
  
  /// Guardar frecuencias por gigante
  /// Sincroniza a cloud si hay usuario autenticado
  Future<void> saveGiantFrequencies(Map<String, String> frequencies) async {
    // Guardar local
    final jsonString = jsonEncode(frequencies);
    await _prefs?.setString(_keyGiantFrequencies, jsonString);
    debugPrint('💾 Frecuencias guardadas (local): $frequencies');
    
    // Sincronizar a cloud
    if (_hasCloudProfile) {
      await ProfileRepository.I.updateProfile(
        (profile) => profile.copyWith(giantFrequencies: frequencies),
      );
      debugPrint('☁️ Frecuencias sincronizadas a cloud');
    }
  }
  
  /// Cargar frecuencias por gigante
  /// Prioriza cloud si hay usuario autenticado
  Map<String, String> loadGiantFrequencies() {
    // Prioridad: Cloud
    if (_hasCloudProfile) {
      final cloudFreqs = ProfileRepository.I.currentProfile!.giantFrequencies;
      if (cloudFreqs.isNotEmpty) {
        return cloudFreqs;
      }
    }
    
    // Fallback: Local
    final jsonString = _prefs?.getString(_keyGiantFrequencies);
    if (jsonString == null || jsonString.isEmpty) {
      // Migración: si existe intensidad global, usarla para todos
      final globalIntensity = selectedIntensity;
      if (globalIntensity != null) {
        final giants = selectedGiants;
        if (giants.isNotEmpty) {
          debugPrint('🔄 Migrando intensidad global a frecuencias por gigante');
          return { for (var g in giants) g: globalIntensity };
        }
      }
      return {};
    }
    
    try {
      final decoded = jsonDecode(jsonString);
      return Map<String, String>.from(decoded);
    } catch (e) {
      debugPrint('⚠️ Error parsing giant frequencies: $e');
      return {};
    }
  }
  
  /// ═══════════════════════════════════════════════════════════════════════════
  /// COMPLETAR ONBOARDING
  /// ═══════════════════════════════════════════════════════════════════════════
  
  /// Guardar todas las selecciones y marcar como completado (legacy)
  Future<void> completeOnboarding({
    required List<String> giants,
    required String intensity,
  }) async {
    await saveSelectedGiants(giants);
    await saveSelectedIntensity(intensity);
    await markOnboardingCompleted();
    
    debugPrint('🎉 Onboarding completado:');
    debugPrint('   Gigantes: $giants');
    debugPrint('   Intensidad: $intensity');
  }
  
  /// Guardar con frecuencias por gigante (NUEVO)
  /// Este método actualiza tanto local como cloud en una transacción
  Future<bool> completeOnboardingWithFrequencies({
    required List<String> giants,
    required Map<String, String> frequencies,
  }) async {
    try {
      // Guardar local primero como backup
      await _prefs?.setStringList(_keySelectedGiants, giants);
      await _prefs?.setString(_keyGiantFrequencies, jsonEncode(frequencies));
      await _prefs?.setBool(_keyOnboardingCompleted, true);
      
      debugPrint('🎉 Onboarding completado (local):');
      debugPrint('   Gigantes: $giants');
      debugPrint('   Frecuencias: $frequencies');
      
      // Sincronizar a cloud si hay usuario
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        debugPrint('☁️ Intentando sincronizar onboarding a cloud...');
        final cloudSuccess = await ProfileRepository.I.completeOnboarding(
          giants: giants,
          frequencies: frequencies,
        );
        
        if (!cloudSuccess) {
          debugPrint('❌ Cloud save failed (updateProfile returned false)');
          // Reintentar una vez con connectUser explícito
          debugPrint('🔄 Retrying: forcing connectUser before save...');
          await ProfileRepository.I.connectUser(user.uid);
          final retrySuccess = await ProfileRepository.I.completeOnboarding(
            giants: giants,
            frequencies: frequencies,
          );
          if (!retrySuccess) {
            debugPrint('❌ Retry also failed - returning false');
            return false;
          }
          debugPrint('✅ Retry succeeded');
        }
        debugPrint('☁️ Onboarding sincronizado a cloud');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error al completar onboarding: $e');
      return false;
    }
  }
  
  /// ═══════════════════════════════════════════════════════════════════════════
  /// MAPEO DE IDS A NOMBRES LEGIBLES
  /// ═══════════════════════════════════════════════════════════════════════════
  
  /// Obtener el nombre legible de un gigante
  static String getGiantName(String id) {
    const Map<String, String> giantNames = {
      'digital': 'Mundo Digital',
      'sexual': 'Pureza Sexual',
      'health': 'Cuerpo & Salud',
      'substances': 'Sustancias',
      'mental': 'Batallas Mentales',
      'emotions': 'Emociones Tóxicas',
    };
    return giantNames[id] ?? id;
  }
  
  /// Obtener el emoji de un gigante
  static String getGiantEmoji(String id) {
    const Map<String, String> giantEmojis = {
      'digital': '📱',
      'sexual': '🔞',
      'health': '🍬',
      'substances': '🥃',
      'mental': '🤯',
      'emotions': '💔',
    };
    return giantEmojis[id] ?? '⚔️';
  }
  
  /// Obtener el nombre legible de una intensidad
  static String getIntensityName(String id) {
    const Map<String, String> intensityNames = {
      'daily': 'Diario',
      'weekly': 'Semanal',
      'occasional': 'Ocasional',
    };
    return intensityNames[id] ?? id;
  }
  
  /// Obtener el emoji de una intensidad
  static String getIntensityEmoji(String id) {
    const Map<String, String> intensityEmojis = {
      'daily': '🔥',
      'weekly': '🟡',
      'occasional': '🟢',
    };
    return intensityEmojis[id] ?? '⚡';
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// MODELO DE DATOS DEL USUARIO
/// Representa el perfil de batalla del usuario
/// ═══════════════════════════════════════════════════════════════════════════

class UserBattleProfile {
  final List<String> selectedGiants;
  final String intensity;
  final DateTime createdAt;
  
  const UserBattleProfile({
    required this.selectedGiants,
    required this.intensity,
    required this.createdAt,
  });
  
  /// Crear desde OnboardingService
  factory UserBattleProfile.fromOnboardingService(OnboardingService service) {
    return UserBattleProfile(
      selectedGiants: service.selectedGiants,
      intensity: service.selectedIntensity ?? 'occasional',
      createdAt: DateTime.now(),
    );
  }
  
  /// Convertir a Map (para Firestore)
  Map<String, dynamic> toMap() {
    return {
      'selectedGiants': selectedGiants,
      'intensity': intensity,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  /// Crear desde Map (desde Firestore)
  factory UserBattleProfile.fromMap(Map<String, dynamic> map) {
    return UserBattleProfile(
      selectedGiants: List<String>.from(map['selectedGiants'] ?? []),
      intensity: map['intensity'] ?? 'occasional',
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }
  
  /// Obtener nombres legibles de los gigantes
  List<String> get giantNames {
    return selectedGiants.map((id) => OnboardingService.getGiantName(id)).toList();
  }
  
  /// Obtener el nombre legible de la intensidad
  String get intensityName => OnboardingService.getIntensityName(intensity);
  
  @override
  String toString() {
    return 'UserBattleProfile(giants: $giantNames, intensity: $intensityName)';
  }
}
