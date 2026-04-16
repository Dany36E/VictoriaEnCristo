import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../theme/app_theme_data.dart';
import '../services/daily_verse_service.dart';
import '../services/personalization_engine.dart';
import '../services/feedback_engine.dart';
import '../services/widget_sync_service.dart';
import '../utils/time_utils.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// MORNING CHECK-IN SHEET
/// Rutina matutina guiada: saludo, versículo, intención, oración breve
/// Se muestra una vez al día al abrir la app
/// ═══════════════════════════════════════════════════════════════════════════

class MorningCheckinSheet extends StatefulWidget {
  const MorningCheckinSheet({super.key});

  /// Verifica si ya se mostró hoy
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('morning_checkin_last_shown');
    final today = TimeUtils.todayISO();
    return lastShown != today;
  }

  /// Marca como mostrado hoy y sincroniza widget
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('morning_checkin_last_shown', TimeUtils.todayISO());
    // Actualizar widget nativo para reflejar que hizo devocional
    WidgetSyncService.I.syncWidget();
  }

  @override
  State<MorningCheckinSheet> createState() => _MorningCheckinSheetState();
}

class _MorningCheckinSheetState extends State<MorningCheckinSheet> {
  int _step = 0; // 0=greeting, 1=verse, 2=intention, 3=prayer
  String _todayIntention = '';
  String _todayPrayer = '';

  @override
  void initState() {
    super.initState();
    _loadRotatingContent();
  }

  Future<void> _loadRotatingContent() async {
    final stage = PersonalizationEngine.I.getUserStage().name;
    final now = DateTime.now();
    final dayHash = now.year * 1000 + now.day + now.month * 37;

    // Cargar intenciones
    try {
      final ijson = await rootBundle.loadString('assets/content/daily_intentions.json');
      final idata = jsonDecode(ijson) as Map<String, dynamic>;
      final stageList = (idata[stage] as List?)?.cast<String>() ?? [];
      final universalList = (idata['universal'] as List?)?.cast<String>() ?? [];
      final pool = [...stageList, ...universalList];
      if (pool.isNotEmpty) {
        _todayIntention = pool[dayHash % pool.length];
      }
    } catch (_) {}

    // Cargar oraciones
    try {
      final pjson = await rootBundle.loadString('assets/content/daily_prayers.json');
      final pdata = jsonDecode(pjson) as Map<String, dynamic>;
      final stageList = (pdata[stage] as List?)?.cast<String>() ?? [];
      final universalList = (pdata['universal'] as List?)?.cast<String>() ?? [];
      final pool = [...stageList, ...universalList];
      if (pool.isNotEmpty) {
        // Usar offset para que intención y oración no coincidan en patrón
        _todayPrayer = pool[(dayHash + 7) % pool.length];
      }
    } catch (_) {}

    if (mounted) setState(() {});
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Buenos días';
    if (hour < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }

  String get _greetingEmoji {
    final hour = DateTime.now().hour;
    if (hour < 12) return '🌅';
    if (hour < 18) return '☀️';
    return '🌙';
  }

  @override
  Widget build(BuildContext context) {
    final td = AppThemeData.of(context);
    final verse = DailyVerseService.I.getForTodaySync();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: td.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: td.textSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Content based on step
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildStep(td, verse),
              ),

              const SizedBox(height: 24),

              // Navigation
              _buildNavigation(td),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStep(AppThemeData td, dynamic verse) {
    switch (_step) {
      case 0:
        return _buildGreeting(td).animate().fadeIn(duration: 400.ms);
      case 1:
        return _buildVerse(td, verse).animate().fadeIn(duration: 400.ms);
      case 2:
        return _buildIntention(td).animate().fadeIn(duration: 400.ms);
      case 3:
        return _buildPrayer(td).animate().fadeIn(duration: 400.ms);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildGreeting(AppThemeData td) {
    final stage = PersonalizationEngine.I.getUserStage();
    final stageMsg = switch (stage.name) {
      'crisis' => 'Dios está contigo en cada momento.',
      'habit' => 'Cada día construyes una nueva historia.',
      'maintenance' => 'Tu fidelidad inspira.',
      'restoration' => 'Su gracia es nueva cada mañana.',
      _ => 'Un nuevo día, una nueva oportunidad.',
    };

    return Column(
      key: const ValueKey('greeting'),
      children: [
        Text(
          _greetingEmoji,
          style: const TextStyle(fontSize: 48),
        ),
        const SizedBox(height: 12),
        Text(
          '$_greeting, guerrero',
          style: GoogleFonts.cinzel(
            color: td.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          stageMsg,
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: td.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVerse(AppThemeData td, dynamic verse) {
    return Column(
      key: const ValueKey('verse'),
      children: [
        const Icon(
          Icons.menu_book_rounded,
          color: AppDesignSystem.gold,
          size: 32,
        ),
        const SizedBox(height: 12),
        Text(
          'Versículo del día',
          style: GoogleFonts.manrope(
            color: AppDesignSystem.gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '"${verse.verse}"',
          textAlign: TextAlign.center,
          style: GoogleFonts.crimsonPro(
            color: td.textPrimary,
            fontSize: 17,
            fontStyle: FontStyle.italic,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '— ${verse.reference}',
          style: GoogleFonts.manrope(
            color: td.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildIntention(AppThemeData td) {
    return Column(
      key: const ValueKey('intention'),
      children: [
        const Icon(
          Icons.shield_rounded,
          color: AppDesignSystem.victory,
          size: 32,
        ),
        const SizedBox(height: 12),
        Text(
          'Intención del día',
          style: GoogleFonts.manrope(
            color: AppDesignSystem.victory,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _todayIntention.isNotEmpty
              ? _todayIntention
              : 'Hoy elijo caminar en victoria.\nCon la ayuda de Dios, resistiré toda tentación.\nNo dependo de mis fuerzas, sino de Su poder.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            color: td.textPrimary,
            fontSize: 15,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildPrayer(AppThemeData td) {
    return Column(
      key: const ValueKey('prayer'),
      children: [
        const Icon(
          Icons.favorite_rounded,
          color: Color(0xFFE8C97A),
          size: 32,
        ),
        const SizedBox(height: 12),
        Text(
          'Oración breve',
          style: GoogleFonts.manrope(
            color: const Color(0xFFE8C97A),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _todayPrayer.isNotEmpty
              ? _todayPrayer
              : 'Señor, te entrego este día.\nCúbreme con Tu gracia.\nGuarda mis ojos, mis manos y mi corazón.\nQue cada paso me acerque más a Ti.\nAmén.',
          textAlign: TextAlign.center,
          style: GoogleFonts.crimsonPro(
            color: td.textPrimary,
            fontSize: 16,
            fontStyle: FontStyle.italic,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation(AppThemeData td) {
    final isLast = _step == 3;

    return Row(
      children: [
        // Skip button
        TextButton(
          onPressed: () {
            MorningCheckinSheet.markShown();
            Navigator.of(context).pop();
          },
          child: Text(
            'Saltar',
            style: GoogleFonts.manrope(
              color: td.textSecondary.withOpacity(0.5),
              fontSize: 13,
            ),
          ),
        ),
        const Spacer(),
        // Step indicator dots
        Row(
          children: List.generate(4, (i) => Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == _step
                  ? AppDesignSystem.gold
                  : td.textSecondary.withOpacity(0.15),
            ),
          )),
        ),
        const Spacer(),
        // Next/Done button
        ElevatedButton(
          onPressed: () {
            FeedbackEngine.I.tap();
            if (isLast) {
              MorningCheckinSheet.markShown();
              Navigator.of(context).pop();
            } else {
              setState(() => _step++);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isLast
                ? AppDesignSystem.victory
                : AppDesignSystem.gold,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isLast ? 'Comenzar' : 'Siguiente',
            style: GoogleFonts.manrope(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
