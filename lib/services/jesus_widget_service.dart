/// ═══════════════════════════════════════════════════════════════════════════
/// JESUS WIDGET SERVICE - Lógica de sprites, fondos y mensajes del widget
/// Determina qué sprite de Jesús, fondo y mensaje mostrar según la racha
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';

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
      return '$_spritesPath/NUEVO USUARIO.png';
    }

    // Completó hoy → celebración
    if (completedToday) {
      return '$_spritesPath/VICTORIA DEL DÍA.png';
    }

    // Hitos de racha (solo si tiene racha activa y NO completó hoy)
    if (streakDays >= 365) return '$_spritesPath/Un año glorioso.png';
    if (streakDays >= 100) return '$_spritesPath/Centurión de la fe.png';
    if (streakDays >= 30) return '$_spritesPath/Un mes.png';
    if (streakDays >= 7) return '$_spritesPath/Primera semana.png';

    // Racha perdida (0 días y no es nuevo)
    if (streakDays == 0) {
      return '$_spritesPath/RACHA PERDIDA.png';
    }

    // Racha activa pero no completó hoy → ánimo
    if (streakDays >= 1) {
      return '$_spritesPath/ÁNIMO  EMPUJAR AL USUARIO.png';
    }

    // Fallback: esperando
    return '$_spritesPath/ESPERANDO AL USUARIO.png';
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BACKGROUND (Fondo)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Devuelve el path del fondo según la racha
  String getBackground({required int streakDays}) {
    if (streakDays >= 365) return '$_backgroundsPath/Guardia Eterna.png';
    if (streakDays >= 100) return '$_backgroundsPath/Armadura dorada.png';
    if (streakDays >= 30) return '$_backgroundsPath/Batalla espiritual.png';
    if (streakDays >= 14) return '$_backgroundsPath/Noche estrellada.png';
    if (streakDays >= 7) return '$_backgroundsPath/Atardecer glorioso.png';
    if (streakDays >= 3) return '$_backgroundsPath/Cielo de la fe.png';
    if (streakDays >= 1) return '$_backgroundsPath/Pradera del amanecer.png';
    return '$_backgroundsPath/Listo para empezar.png';
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
  // MENSAJE MOTIVACIONAL
  // ═══════════════════════════════════════════════════════════════════════════

  /// Mensaje que muestra Jesús según estado
  String getMessage({
    required int streakDays,
    required bool completedToday,
    required bool isNewUser,
  }) {
    if (isNewUser) return '¡Bienvenido, guerrero!\nComienza tu camino de victoria';

    if (completedToday) {
      if (streakDays >= 365) return '¡Un año caminando conmigo!\n¡Eres un guerrero eterno!';
      if (streakDays >= 100) return '¡100 días de victoria!\n¡Centurión de la fe!';
      if (streakDays >= 30) return '¡Un mes entero!\nTu armadura brilla';
      if (streakDays >= 7) return '¡Una semana completa!\n¡Sigue adelante!';
      return '¡Victoria de hoy registrada!\n¡Bien hecho, soldado!';
    }

    // No completó hoy
    if (streakDays == 0) return 'Tu racha se reinició\nPero hoy puedes empezar de nuevo';
    if (streakDays >= 30) return '¡$streakDays días de racha!\nNo te detengas ahora';
    if (streakDays >= 7) return '$streakDays días seguidos\n¡Registra tu victoria hoy!';
    if (streakDays >= 1) return 'Llevas $streakDays día${streakDays > 1 ? 's' : ''}\n¡No pierdas la racha!';

    return '¡Registra tu primera victoria!';
  }
}
