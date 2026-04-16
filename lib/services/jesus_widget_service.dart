/// ═══════════════════════════════════════════════════════════════════════════
/// JESUS WIDGET SERVICE - Lógica de sprites, fondos y mensajes del widget
/// Determina qué sprite de Jesús, fondo y mensaje mostrar según la racha
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/content_enums.dart';
import 'personalization_engine.dart';
import 'victory_scoring_service.dart';

class JesusWidgetService {
  // ═══════════════════════════════════════════════════════════════════════════
  // SINGLETON
  // ═══════════════════════════════════════════════════════════════════════════

  static final JesusWidgetService _instance = JesusWidgetService._internal();
  factory JesusWidgetService() => _instance;
  JesusWidgetService._internal();

  static JesusWidgetService get I => _instance;

  // ═══════════════════════════════════════════════════════════════════════════
  // PATHS BASE
  // ═══════════════════════════════════════════════════════════════════════════

  static const String _spritesPath = 'assets/widget/jesus';
  static const String _backgroundsPath = 'assets/widget/backgrounds';

  // ═══════════════════════════════════════════════════════════════════════════
  // SPRITE (Jesús)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve el path del sprite de Jesús según estado actual
  String getSprite({
    required int streakDays,
    required bool completedToday,
    required bool isNewUser,
  }) {
    // Usuario nuevo → bienvenida
    if (isNewUser) {
      return '$_spritesPath/NUEVO USUARIO.webp';
    }

    // Hitos altos — muestran sprite épico aunque completó hoy
    if (streakDays >= 365) return '$_spritesPath/Un año glorioso.webp';
    if (streakDays >= 100) return '$_spritesPath/Centurión de la fe.webp';
    if (streakDays >= 30) return '$_spritesPath/Un mes.webp';

    // Completó hoy (racha < 30) → celebración genérica
    if (completedToday) {
      return '$_spritesPath/VICTORIA DEL DÍA.webp';
    }

    // Hitos medios sin completar hoy
    if (streakDays >= 7) return '$_spritesPath/Primera semana.webp';

    // Racha perdida (0 días y no es nuevo)
    if (streakDays == 0) {
      return '$_spritesPath/RACHA PERDIDA.webp';
    }

    // Racha activa pero no completó hoy → ánimo
    if (streakDays >= 1) {
      return '$_spritesPath/ÁNIMO  EMPUJAR AL USUARIO.webp';
    }

    // Fallback: esperando
    return '$_spritesPath/ESPERANDO AL USUARIO.webp';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND (Fondo)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve el path del fondo según la racha
  String getBackground({required int streakDays}) {
    if (streakDays >= 365) return '$_backgroundsPath/Guardia Eterna.webp';
    if (streakDays >= 100) return '$_backgroundsPath/Armadura dorada.webp';
    if (streakDays >= 30) return '$_backgroundsPath/Batalla espiritual.webp';
    if (streakDays >= 14) return '$_backgroundsPath/Noche estrellada.webp';
    if (streakDays >= 7) return '$_backgroundsPath/Atardecer glorioso.webp';
    if (streakDays >= 3) return '$_backgroundsPath/Cielo de la fe.webp';
    if (streakDays >= 1) return '$_backgroundsPath/Pradera del amanecer.webp';
    return '$_backgroundsPath/Listo para empezar.webp';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // COLOR DE RACHA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Color del indicador de racha según nivel
  Color getStreakColor(int streakDays) {
    if (streakDays >= 365) return const Color(0xFFFFD700); // Oro brillante
    if (streakDays >= 100) return const Color(0xFFFFA500); // Naranja dorado
    if (streakDays >= 30) return const Color(0xFFE040FB); // Púrpura
    if (streakDays >= 14) return const Color(0xFF448AFF); // Azul
    if (streakDays >= 7) return const Color(0xFF69F0AE); // Verde menta
    if (streakDays >= 3) return const Color(0xFF81D4FA); // Celeste
    if (streakDays >= 1) return const Color(0xFFA5D6A7); // Verde suave
    return const Color(0xFF757575); // Gris (sin racha)
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // POOL DE MENSAJES (cargado desde JSON)
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, List<dynamic>>? _messagePool;

  Future<void> _ensurePoolLoaded() async {
    if (_messagePool != null) return;
    try {
      final json = await rootBundle.loadString('assets/content/widget_messages.json');
      final data = jsonDecode(json) as Map<String, dynamic>;
      _messagePool = {};
      for (final key in data.keys) {
        if (key.startsWith('_')) continue;
        _messagePool![key] = List<dynamic>.from(data[key] as List);
      }
    } catch (e) {
      debugPrint('🎯 [JESUS] Error loading message pool: $e');
      _messagePool = {};
    }
  }

  /// Franja horaria del día (7 franjas)
  String _getTimeSlot(int hour) {
    if (hour < 5) return 'night';
    if (hour < 8) return 'dawn';
    if (hour < 12) return 'morning';
    if (hour < 15) return 'midday';
    if (hour < 18) return 'afternoon';
    if (hour < 21) return 'evening';
    return 'latenight';
  }

  /// Selecciona un mensaje del pool usando hash determinístico por fecha
  /// para que Flutter y el widget Android muestren el mismo mensaje cada día
  String _pickFromPool(List<dynamic> candidates, DateTime today) {
    if (candidates.isEmpty) return '';
    final dayHash = today.year * 1000 + today.day + today.month * 37;
    final index = dayHash % candidates.length;
    final entry = candidates[index] as Map<String, dynamic>;
    final text = entry['text'] as String;
    final verse = entry['verse'] as String;
    return '$text\n— $verse';
  }

  /// Filtra mensajes por stage y/o giant del usuario
  List<dynamic> _filterMessages(
    List<dynamic> pool, {
    ContentStage? stage,
    List<String>? giants,
  }) {
    // Primero intentar match por stage + giant
    if (stage != null && giants != null && giants.isNotEmpty) {
      final stageName = stage.name;
      final byBoth = pool.where((m) {
        final map = m as Map<String, dynamic>;
        return map['stage'] == stageName && giants.contains(map['giant']);
      }).toList();
      if (byBoth.isNotEmpty) return byBoth;
    }

    // Luego por giant
    if (giants != null && giants.isNotEmpty) {
      final byGiant = pool.where((m) {
        final map = m as Map<String, dynamic>;
        return giants.contains(map['giant']);
      }).toList();
      if (byGiant.isNotEmpty) return byGiant;
    }

    // Luego por stage
    if (stage != null) {
      final stageName = stage.name;
      final byStage = pool.where((m) {
        final map = m as Map<String, dynamic>;
        return map['stage'] == stageName;
      }).toList();
      if (byStage.isNotEmpty) return byStage;
    }

    // Universales (sin stage ni giant)
    final universal = pool.where((m) {
      final map = m as Map<String, dynamic>;
      return !map.containsKey('stage') && !map.containsKey('giant');
    }).toList();
    return universal.isNotEmpty ? universal : pool;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MENSAJE MOTIVACIONAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mensaje que muestra Jesús según estado — usa pool de mensajes con versículos
  String getMessage({
    required int streakDays,
    required bool completedToday,
    required bool isNewUser,
  }) {
    // Versión síncrona usa el pool si ya está cargado, si no usa fallbacks
    final now = DateTime.now();

    if (_messagePool != null && _messagePool!.isNotEmpty) {
      return _getPoolMessage(
        streakDays: streakDays,
        completedToday: completedToday,
        isNewUser: isNewUser,
        now: now,
      );
    }

    // Fallback clásico (antes de que el pool cargue)
    return _getFallbackMessage(
      streakDays: streakDays,
      completedToday: completedToday,
      isNewUser: isNewUser,
    );
  }

  /// Inicializa el pool de mensajes (llamar desde init de la app)
  Future<void> init() async {
    await _ensurePoolLoaded();
  }

  String _getPoolMessage({
    required int streakDays,
    required bool completedToday,
    required bool isNewUser,
    required DateTime now,
  }) {
    // Determinar categoría del pool
    String poolKey;
    if (isNewUser) {
      poolKey = 'newuser';
    } else if (completedToday) {
      poolKey = 'completed';
    } else if (streakDays == 0) {
      poolKey = 'streakLost';
    } else {
      poolKey = _getTimeSlot(now.hour);
    }

    final pool = _messagePool![poolKey];
    if (pool == null || pool.isEmpty) {
      return _getFallbackMessage(
        streakDays: streakDays,
        completedToday: completedToday,
        isNewUser: isNewUser,
      );
    }

    // Obtener stage y giants del usuario para filtrado
    ContentStage? stage;
    List<String>? giants;
    try {
      stage = PersonalizationEngine.I.getUserStage();
      giants = VictoryScoringService.I.selectedGiants;
      if (giants.length == 1 && giants.first == 'general') giants = null;
    } catch (_) {
      // Servicios no inicializados aún
    }

    final filtered = _filterMessages(pool, stage: stage, giants: giants);
    return _pickFromPool(filtered, now);
  }

  /// Fallback clásico para antes de que cargue el pool
  String _getFallbackMessage({
    required int streakDays,
    required bool completedToday,
    required bool isNewUser,
  }) {
    if (isNewUser) return 'Todo camino comienza\ncon un primer paso';

    if (completedToday) {
      if (streakDays >= 365) return 'Un año de fidelidad.\n— Dios se glorifica en ti';
      if (streakDays >= 100) return '$streakDays días firme.\n— Tu fe mueve montañas';
      if (streakDays >= 30) return 'Un mes de victoria.\n— ¡Dios pelea por ti!';
      if (streakDays >= 7) return 'Una semana fiel.\n— ¡El Señor está contigo!';
      return '¡Victoria de hoy!\n— Cada día cuenta';
    }

    if (streakDays == 0) return 'Su misericordia es nueva\ncada mañana';
    if (streakDays >= 30) return '$streakDays días de racha.\n— ¡No te detengas!';
    if (streakDays >= 7) return '$streakDays días firme.\n— Registra tu victoria hoy';
    if (streakDays >= 1) return 'Llevas $streakDays día${streakDays > 1 ? 's' : ''}.\n— ¡Sigue adelante!';

    return 'Hoy es un buen día\npara empezar';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BADGE / BOTÓN — texto según franja horaria
  // ═══════════════════════════════════════════════════════════════════════════

  /// Texto del badge/botón del widget según franja horaria
  String getBadgeText({
    required bool completedToday,
    required bool isNewUser,
    bool checkinDone = false,
  }) {
    if (completedToday) return '✓ Día de victoria';
    if (isNewUser) return 'Empieza hoy';
    final hour = DateTime.now().hour;
    // Si hizo devocional matutino pero aún no registra victoria
    if (checkinDone && hour < 18) return '🙏 Devocional hecho';
    if (hour < 5) return '🌙 Descansa en paz';
    if (hour < 8) return '☀️ Buenos días';
    if (hour < 12) return '💪 Sigue firme';
    if (hour < 15) return '🛡️ En batalla';
    if (hour < 18) return '⏰ Casi es hora';
    return '⚔️ Registrar victoria';
  }
}
